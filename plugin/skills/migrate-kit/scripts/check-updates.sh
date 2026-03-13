#!/usr/bin/env bash
set -euo pipefail

# migrate-kit reference freshness checker
# Compares documented versions against latest published releases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS_DIR="$SCRIPT_DIR/../references"

# ── Capability detection ──────────────────────────────────────────────

HAS_NPM=false
HAS_PIP=false
HAS_GH=false
HAS_CURL=false
HAS_JQ=false

command -v npm  &>/dev/null && HAS_NPM=true
command -v pip3 &>/dev/null && HAS_PIP=true || command -v pip &>/dev/null && HAS_PIP=true
command -v gh   &>/dev/null && HAS_GH=true
command -v curl &>/dev/null && HAS_CURL=true
command -v jq   &>/dev/null && HAS_JQ=true

# ── Helpers ───────────────────────────────────────────────────────────

# Extract the highest target version from "## Framework X → Y" headers.
# Looks for headers with an arrow (→) and returns the version after the
# last arrow in the highest-versioned header.
extract_documented_version() {
  local file="$1"
  local pattern="$2"

  [ ! -f "$file" ] && return 0

  grep -E "^## ${pattern} [0-9]" "$file" 2>/dev/null \
    | grep '→' \
    | sed -E 's/.*→[[:space:]]*//' \
    | sed -E 's/[[:space:]]*\(.*\)//' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -1 \
    || true
}

# Vue uses non-standard headers: "Vue 2 → Vue 3" and "3.2 → 3.3 → 3.4 → 3.5"
extract_vue_documented_version() {
  local file="$1"

  [ ! -f "$file" ] && return 0

  # Check for minor upgrade chain like "(3.2 → 3.3 → 3.4 → 3.5)"
  local minor_chain
  minor_chain=$(grep -E '^## .*Minor Upgrades' "$file" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+' \
    | sort -t. -k1,1n -k2,2n \
    | tail -1 || true)

  if [ -n "$minor_chain" ]; then
    echo "$minor_chain"
    return 0
  fi

  # Fallback: major version from "Vue 2 → Vue 3"
  grep -E '^## Vue [0-9]+ → Vue [0-9]+' "$file" 2>/dev/null \
    | grep -oE '[0-9]+' \
    | sort -n \
    | tail -1 \
    || true
}

# Extract documented Flutter version from the reference file.
# Flutter headers don't use "→" between versions, so we scan the file
# body for the highest "Flutter X.Y.Z" mention.
extract_flutter_documented_version() {
  local file="$1"

  [ ! -f "$file" ] && return 0

  # Extract all version numbers from Flutter headers (both source and target versions)
  # Headers look like: "### Flutter 3.38 → 3.41"
  grep -iE '(Flutter|→)[[:space:]]*[0-9]+\.[0-9]+' "$file" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -1 \
    || true
}

# Compare two version strings. Returns 0 (true) if latest > documented.
# Compares only as many segments as the documented version has:
#   documented "21"   → compare major only (21 vs 22.0.0 → update needed)
#   documented "3.5"  → compare major.minor only (3.5 vs 3.5.30 → up to date)
#   documented "6.0"  → compare major.minor only (6.0 vs 5.2.1 → up to date)
version_gt() {
  local latest="$1"
  local documented="$2"

  latest="${latest#v}"
  documented="${documented#v}"

  # Count how many dot-separated segments the documented version has
  local doc_depth
  doc_depth=$(echo "$documented" | tr '.' '\n' | wc -l | tr -d ' ')

  # Truncate latest to the same depth for comparison
  local latest_trimmed="$latest"
  if [ "$doc_depth" -eq 1 ]; then
    latest_trimmed=$(echo "$latest" | cut -d. -f1)
  elif [ "$doc_depth" -eq 2 ]; then
    latest_trimmed=$(echo "$latest" | cut -d. -f1-2)
  fi

  # If both are equal at the compared depth, no update needed
  if [ "$latest_trimmed" = "$documented" ]; then
    return 1
  fi

  # Numeric comparison for major-only
  if [ "$doc_depth" -eq 1 ]; then
    [ "$latest_trimmed" -gt "$documented" ] 2>/dev/null && return 0
    return 1
  fi

  # Sort-based comparison for multi-segment versions
  local highest
  highest=$(printf '%s\n%s\n' "$latest_trimmed" "$documented" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  if [ "$highest" = "$latest_trimmed" ] && [ "$latest_trimmed" != "$documented" ]; then
    return 0
  fi

  return 1
}

# Fetch latest version from npm registry. Returns empty string on failure.
# Uses a 15-second timeout to avoid hanging on unreachable/private registries.
npm_latest() {
  local pkg="$1"
  if [ "$HAS_NPM" = true ]; then
    npm view "$pkg" version --fetch-timeout=15000 2>/dev/null || true
  fi
}

# ── Fetch latest published versions ──────────────────────────────────

fetch_angular_latest()  { npm_latest "@angular/core"; }
fetch_react_latest()    { npm_latest "react"; }
fetch_nextjs_latest()   { npm_latest "next"; }
fetch_vue_latest()      { npm_latest "vue"; }

fetch_flutter_latest() {
  # Primary: official Flutter release manifest (most reliable source of stable versions).
  local flutter_releases_url="https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json"

  if [ "$HAS_CURL" = true ] && [ "$HAS_JQ" = true ]; then
    local ver
    ver=$(curl -sf --connect-timeout 5 --max-time 10 "$flutter_releases_url" \
      | jq -r '[.releases[] | select(.channel == "stable")] | .[0].version' 2>/dev/null || true)
    if [ -n "$ver" ]; then
      echo "$ver"
      return 0
    fi
  elif [ "$HAS_CURL" = true ]; then
    local ver
    ver=$(curl -sf --connect-timeout 5 --max-time 10 "$flutter_releases_url" \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data.get('releases', []):
    if r.get('channel') == 'stable':
        print(r['version'])
        break
" 2>/dev/null || true)
    if [ -n "$ver" ]; then
      echo "$ver"
      return 0
    fi
  fi

  # Fallback: GitHub API via gh. Flutter marks all GitHub releases as non-prerelease,
  # so we filter out tags containing "pre", "beta", "alpha", or "dev".
  if [ "$HAS_GH" = true ]; then
    gh api repos/flutter/flutter/releases --jq '
      [.[] | select(.tag_name | test("pre|beta|alpha|dev|rc") | not)] | .[0].tag_name // empty
    ' 2>/dev/null || true
  fi
}

fetch_django_latest() {
  # Primary: PyPI JSON API (most reliable — always returns the actual latest)
  if [ "$HAS_CURL" = true ] && [ "$HAS_JQ" = true ]; then
    local ver
    ver=$(curl -sf --connect-timeout 5 --max-time 10 "https://pypi.org/pypi/django/json" \
      | jq -r '.info.version' 2>/dev/null || true)
    if [ -n "$ver" ]; then
      echo "$ver"
      return 0
    fi
  elif [ "$HAS_CURL" = true ]; then
    local ver
    ver=$(curl -sf --connect-timeout 5 --max-time 10 "https://pypi.org/pypi/django/json" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])" 2>/dev/null || true)
    if [ -n "$ver" ]; then
      echo "$ver"
      return 0
    fi
  fi

  # Fallback: pip index (may return LTS version instead of latest)
  if [ "$HAS_PIP" = true ]; then
    local pip_cmd="pip"
    command -v pip3 &>/dev/null && pip_cmd="pip3"
    $pip_cmd index versions django 2>/dev/null \
      | head -1 \
      | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' \
      | head -1 || true
  fi
}

# ── Extract documented versions from reference files ─────────────────

doc_angular=$(extract_documented_version "$REFS_DIR/angular.md" "Angular")
doc_react=$(extract_documented_version "$REFS_DIR/react.md" "React")
doc_nextjs=$(extract_documented_version "$REFS_DIR/nextjs.md" "Next\\.js")
doc_vue=$(extract_vue_documented_version "$REFS_DIR/vue.md")
doc_flutter=$(extract_flutter_documented_version "$REFS_DIR/flutter.md")
doc_django=$(extract_documented_version "$REFS_DIR/python.md" "Django")

# ── Fetch latest versions with graceful degradation ──────────────────

latest_angular=""
latest_react=""
latest_nextjs=""
latest_vue=""
latest_flutter=""
latest_django=""

skip_angular=false
skip_react=false
skip_nextjs=false
skip_vue=false
skip_flutter=false
skip_django=false

echo "Fetching latest versions..." >&2

if [ "$HAS_NPM" = true ]; then
  latest_angular=$(fetch_angular_latest)
  latest_react=$(fetch_react_latest)
  latest_nextjs=$(fetch_nextjs_latest)
  latest_vue=$(fetch_vue_latest)
else
  echo "  npm not found — skipping JavaScript frameworks" >&2
  skip_angular=true; skip_react=true; skip_nextjs=true; skip_vue=true
fi

if [ "$HAS_CURL" = true ] || [ "$HAS_GH" = true ]; then
  latest_flutter=$(fetch_flutter_latest)
  if [ -z "$latest_flutter" ]; then
    echo "  Could not fetch Flutter version (network error?)" >&2
    skip_flutter=true
  fi
else
  echo "  Neither curl nor gh found — skipping Flutter" >&2
  skip_flutter=true
fi

latest_django=$(fetch_django_latest)
if [ -z "$latest_django" ]; then
  if [ "$HAS_PIP" != true ] && [ "$HAS_CURL" != true ]; then
    echo "  Neither pip nor curl found — skipping Django" >&2
  else
    echo "  Could not fetch Django version (network error?)" >&2
  fi
  skip_django=true
fi

# ── Report ───────────────────────────────────────────────────────────

needs_update=0

print_row() {
  local name="$1"
  local doc="$2"
  local latest="$3"
  local skip="$4"

  local padded
  padded=$(printf '%-10s' "$name")

  if [ "$skip" = true ]; then
    echo "⏭  $padded skipped (tools unavailable)"
    return
  fi

  if [ -z "$doc" ]; then
    echo "⚠️  $padded documented: ???    latest: ${latest:-???}  ← COULD NOT PARSE DOCS"
    return
  fi

  if [ -z "$latest" ]; then
    echo "⚠️  $padded documented: $doc    latest: ???  ← COULD NOT FETCH"
    return
  fi

  local latest_clean="${latest#v}"

  if version_gt "$latest_clean" "$doc"; then
    echo "⚠️  $padded documented: $doc    latest: $latest_clean  ← UPDATE NEEDED"
    needs_update=1
  else
    echo "✅ $padded documented: $doc    latest: $latest_clean"
  fi
}

echo ""
echo "📊 Reference Freshness Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

print_row "Angular"  "$doc_angular"  "$latest_angular"  "$skip_angular"
print_row "React"    "$doc_react"    "$latest_react"    "$skip_react"
print_row "Next.js"  "$doc_nextjs"   "$latest_nextjs"   "$skip_nextjs"
print_row "Vue"      "$doc_vue"      "$latest_vue"      "$skip_vue"
print_row "Flutter"  "$doc_flutter"  "$latest_flutter"  "$skip_flutter"
print_row "Django"   "$doc_django"   "$latest_django"   "$skip_django"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$needs_update" -eq 1 ]; then
  echo ""
  echo "Some reference docs need updating."
  exit 1
else
  echo ""
  echo "All reference docs are up to date."
  exit 0
fi
