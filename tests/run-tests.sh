#!/usr/bin/env bash
set -uo pipefail

# migrate-kit detection test suite
# Validates detect-stack.sh against known fixture projects.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_SCRIPT="$TESTS_DIR/../plugin/skills/migrate-kit/scripts/detect-stack.sh"
FIXTURES_DIR="$TESTS_DIR/fixtures"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

# Verify dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

if [ ! -x "$DETECT_SCRIPT" ]; then
  echo "Error: detect-stack.sh not found or not executable at $DETECT_SCRIPT"
  exit 1
fi

# Helper: run a single test case
# Arguments:
#   $1 - fixture directory name
#   $2 - expected framework
#   $3 - expected version (use "" to skip version check)
#   $4 - expected package manager
#   $5 - label for display
#   $6 - (optional) additional JSON field checks as "key=value key=value ..."
run_test() {
  local fixture_name="$1"
  local expected_framework="$2"
  local expected_version="$3"
  local expected_pm="$4"
  local label="$5"
  local extra_checks="${6:-}"

  TOTAL=$((TOTAL + 1))

  local fixture_dir="$FIXTURES_DIR/$fixture_name"
  if [ ! -d "$fixture_dir" ]; then
    printf "  FAIL %-28s fixture directory not found\n" "$label:"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Run detection from fixture directory
  local output
  output=$(cd "$fixture_dir" && bash "$DETECT_SCRIPT" 2>/dev/null)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    printf "  FAIL %-28s detect-stack.sh exited with code %d\n" "$label:" "$exit_code"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Validate JSON output
  if ! echo "$output" | jq . &>/dev/null; then
    printf "  FAIL %-28s invalid JSON output\n" "$label:"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  local actual_framework actual_version actual_pm related_deps_count
  actual_framework=$(echo "$output" | jq -r '.framework')
  actual_version=$(echo "$output" | jq -r '.currentVersion')
  actual_pm=$(echo "$output" | jq -r '.packageManager')
  related_deps_count=$(echo "$output" | jq '.relatedDeps | length')

  local errors=""

  # Check framework
  if [ "$actual_framework" != "$expected_framework" ]; then
    errors="${errors}framework expected=$expected_framework got=$actual_framework; "
  fi

  # Check version (if expected is non-empty)
  if [ -n "$expected_version" ]; then
    if [ "$actual_version" != "$expected_version" ]; then
      # Also accept if the actual version starts with the expected major
      local expected_major="${expected_version%%.*}"
      local actual_major="${actual_version%%.*}"
      if [ "$actual_major" != "$expected_major" ]; then
        errors="${errors}version expected=$expected_version got=$actual_version; "
      fi
    fi
  fi

  # Check package manager
  if [ "$actual_pm" != "$expected_pm" ]; then
    errors="${errors}packageManager expected=$expected_pm got=$actual_pm; "
  fi

  # Check related deps is not empty (skip for unknown framework)
  if [ "$expected_framework" != "unknown" ] && [ "$related_deps_count" -eq 0 ] 2>/dev/null; then
    errors="${errors}relatedDeps is empty; "
  fi

  # Extra field checks (e.g. "hasTests=true hasCi=false")
  if [ -n "$extra_checks" ]; then
    for check in $extra_checks; do
      local key="${check%%=*}"
      local expected_val="${check#*=}"
      local actual_val
      actual_val=$(echo "$output" | jq -r ".$key // empty" 2>/dev/null)
      if [ "$actual_val" != "$expected_val" ]; then
        errors="${errors}${key} expected=$expected_val got=$actual_val; "
      fi
    done
  fi

  # Report result
  if [ -z "$errors" ]; then
    local version_display=""
    if [ -n "$actual_version" ] && [ "$actual_version" != "null" ] && [ "$actual_version" != "" ]; then
      version_display=" version=$actual_version"
    fi
    printf "  PASS %-28s framework=%s%s\n" "$label:" "$actual_framework" "$version_display"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf "  FAIL %-28s %s\n" "$label:" "$errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Helper for tests where version should be empty/absent
run_test_no_version() {
  local fixture_name="$1"
  local expected_framework="$2"
  local expected_pm="$3"
  local label="$4"
  local extra_checks="${5:-}"

  TOTAL=$((TOTAL + 1))

  local fixture_dir="$FIXTURES_DIR/$fixture_name"
  if [ ! -d "$fixture_dir" ]; then
    printf "  FAIL %-28s fixture directory not found\n" "$label:"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  local output
  output=$(cd "$fixture_dir" && bash "$DETECT_SCRIPT" 2>/dev/null)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    printf "  FAIL %-28s detect-stack.sh exited with code %d\n" "$label:" "$exit_code"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  if ! echo "$output" | jq . &>/dev/null; then
    printf "  FAIL %-28s invalid JSON output\n" "$label:"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  local actual_framework actual_version actual_pm
  actual_framework=$(echo "$output" | jq -r '.framework')
  actual_version=$(echo "$output" | jq -r '.currentVersion')
  actual_pm=$(echo "$output" | jq -r '.packageManager')

  local errors=""

  if [ "$actual_framework" != "$expected_framework" ]; then
    errors="${errors}framework expected=$expected_framework got=$actual_framework; "
  fi

  # Version should be empty
  if [ -n "$actual_version" ] && [ "$actual_version" != "null" ]; then
    errors="${errors}version expected=empty got=$actual_version; "
  fi

  if [ "$actual_pm" != "$expected_pm" ]; then
    errors="${errors}packageManager expected=$expected_pm got=$actual_pm; "
  fi

  # Extra field checks
  if [ -n "$extra_checks" ]; then
    for check in $extra_checks; do
      local key="${check%%=*}"
      local expected_val="${check#*=}"
      local actual_val
      actual_val=$(echo "$output" | jq -r ".$key // empty" 2>/dev/null)
      if [ "$actual_val" != "$expected_val" ]; then
        errors="${errors}${key} expected=$expected_val got=$actual_val; "
      fi
    done
  fi

  if [ -z "$errors" ]; then
    printf "  PASS %-28s framework=%s (no version)\n" "$label:" "$actual_framework"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf "  FAIL %-28s %s\n" "$label:" "$errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo ""
echo "  migrate-kit Test Suite"
echo "  =========================="
echo ""
echo "  ── Core Detection ──────────────────────────────"

#                fixture dir             framework    version      pm        label
run_test         "angular-17"            "angular"    "17.3.2"     "npm"     "angular-17"
run_test         "react-18"              "react"      "18.2.0"     "npm"     "react-18"
run_test         "nextjs-15"             "nextjs"     "15.0.0"     "npm"     "nextjs-15"
run_test         "vue-3"                 "vue"        "3.4.0"      "npm"     "vue-3"
run_test         "flutter"               "flutter"    ""           "pub"     "flutter"
run_test         "django"                "django"     "5.1.2"      "unknown" "django"
run_test         "nextjs-16-turbopack"   "nextjs"     "16.0.0"     "npm"     "nextjs-16"
run_test         "monorepo-npm"          "react"      "19.0.0"     "npm"     "monorepo-npm"

echo ""
echo "  ── Package Manager Detection ─────────────────"

run_test         "pnpm-workspace"        "vue"        "3.5.0"      "pnpm"   "pnpm-workspace"
run_test         "yarn-berry"            "react"      "19.0.0"     "yarn"   "yarn-berry"
run_test         "bun-react"             "react"      "19.2.0"     "bun"    "bun-react"
run_test         "turborepo-react"       "react"      "18.3.0"     "npm"    "turborepo"

echo ""
echo "  ── Monorepo / Workspace ──────────────────────"

run_test         "nx-monorepo"           "angular"    "18.2.0"     "npm"    "nx-monorepo"

echo ""
echo "  ── Framework Priority (overlap) ──────────────"

run_test         "nextjs-react-overlap"  "nextjs"     "15.1.0"     "npm"    "next > react"
run_test         "nuxt-vue-overlap"      "nuxt"       "3.12.0"     "npm"    "nuxt > vue"
run_test         "sveltekit-svelte-overlap" "sveltekit" "2.5.0"    "npm"    "sveltekit > svelte"
run_test         "nestjs-express-overlap" "nestjs"     "10.3.0"    "npm"    "nestjs > express"

echo ""
echo "  ── Version Parsing Edge Cases ────────────────"

run_test_no_version "no-version"         "react"      "npm"        "wildcard (*|latest)"
run_test         "version-ranges"        "angular"    "18.0.0"     "npm"    "range (>=X <Y)"
run_test         "peer-deps-only"        "react"      "19.0.0"     "npm"    "peer+devDeps only"

echo ""
echo "  ── Non-JS Frameworks ─────────────────────────"

run_test         "django-pipfile"        "django"     "4.2"        "pipenv" "django-pipfile"
run_test         "django-poetry"         "django"     "5.2"        "poetry" "django-poetry"
run_test         "rails"                 "rails"      "7.1.3"      "bundler" "rails"
run_test         "express-standalone"    "express"    "4.21.0"     "npm"    "express"

echo ""
echo "  ── Graceful Degradation ──────────────────────"

run_test         "empty-package-json"    "unknown"    ""           "unknown" "invalid JSON"
run_test         "flutter-no-version"    "flutter"    ""           "pub"    "flutter (no lib/)"

echo ""
echo "  ── Regression ────────────────────────────────"

run_test         "guardrails-not-rails"  "react"      "18.2.0"     "npm"    "guardrails!=rails"
run_test_no_version "flask-not-django"  "unknown"    "unknown"             "flask manage.py!=django"

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS_COUNT/$TOTAL passed"

if [ $FAIL_COUNT -gt 0 ]; then
  echo "  $FAIL_COUNT test(s) failed."
  exit 1
else
  echo "  All tests passed."
  exit 0
fi
