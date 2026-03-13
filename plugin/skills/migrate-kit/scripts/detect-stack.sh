#!/usr/bin/env bash
set -euo pipefail

# migrate-kit stack detection script
# Detects framework, version, related deps, and project metadata

# --- Require jq ---
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install it with: brew install jq (macOS) or apt-get install jq (Debian/Ubuntu)" >&2
  exit 1
fi

FRAMEWORK="unknown"
CURRENT_VERSION=""
RELATED_DEPS="{}"
NODE_VERSION=""
PACKAGE_MANAGER="unknown"
HAS_TESTS="false"
HAS_CI="false"
PROJECT_SIZE_FILES=0
PROJECT_SIZE_COMPONENTS=0
PROJECT_SIZE_SERVICES=0

# --- Detect Node.js version ---
if command -v node &>/dev/null; then
  NODE_VERSION=$(node -v 2>/dev/null | sed 's/^v//')
fi

# --- Detect package manager ---
if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
  PACKAGE_MANAGER="bun"
elif [ -f "pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
elif [ -f "yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
elif [ -f "package-lock.json" ]; then
  PACKAGE_MANAGER="npm"
elif [ -f "Pipfile.lock" ]; then
  PACKAGE_MANAGER="pipenv"
elif [ -f "poetry.lock" ]; then
  PACKAGE_MANAGER="poetry"
elif [ -f "Gemfile.lock" ]; then
  PACKAGE_MANAGER="bundler"
elif [ -f "pubspec.lock" ]; then
  PACKAGE_MANAGER="pub"
elif [ -f "go.sum" ]; then
  PACKAGE_MANAGER="go"
elif [ -f "Cargo.lock" ]; then
  PACKAGE_MANAGER="cargo"
fi

# --- Cache parsed package.json ---
PKG_JSON=""
PKG_JSON_VALID="false"
if [ -f "package.json" ]; then
  PKG_JSON=$(cat package.json 2>/dev/null || echo "")
  if echo "$PKG_JSON" | jq empty 2>/dev/null; then
    PKG_JSON_VALID="true"
  fi
fi

# --- Helper: check if a dependency exists in package.json ---
pkg_has_dep() {
  local pkg="$1"
  [ "$PKG_JSON_VALID" = "true" ] || return 1
  echo "$PKG_JSON" | jq -e --arg p "$pkg" '
    (.dependencies[$p] // .devDependencies[$p] // .peerDependencies[$p]) != null
  ' &>/dev/null
}

# --- Helper: extract version from package.json, stripping range prefixes ---
get_pkg_version() {
  local pkg="$1"
  [ "$PKG_JSON_VALID" = "true" ] || return 0
  local raw
  raw=$(echo "$PKG_JSON" | jq -r --arg p "$pkg" '
    (.dependencies[$p] // .devDependencies[$p] // .peerDependencies[$p]) // empty
  ' 2>/dev/null) || return 0
  # Strip version range prefixes: ^, ~, >=, >, <=, <, =
  echo "$raw" | sed -E 's/^[~^><=]+//'
}

# --- Helper: build related deps JSON from package.json ---
build_deps_json() {
  [ "$PKG_JSON_VALID" = "true" ] || { echo "{}"; return; }

  # Build a JSON array of requested package names
  local pkg_array
  pkg_array=$(printf '%s\n' "$@" | jq -R . | jq -sc .)

  echo "$PKG_JSON" | jq -c --argjson pkgs "$pkg_array" '
    def strip_prefix: sub("^[~^><=]+"; "");
    [.dependencies, .devDependencies, .peerDependencies]
    | map(select(. != null)) | add // {}
    | . as $all
    | reduce $pkgs[] as $p ({}; if $all[$p] then . + {($p): ($all[$p] | strip_prefix)} else . end)
  ' 2>/dev/null || echo "{}"
}

# --- Detect CI ---
if [ -d ".github/workflows" ] || [ -f ".gitlab-ci.yml" ] || [ -f "Jenkinsfile" ] || [ -f ".circleci/config.yml" ] || [ -f "bitbucket-pipelines.yml" ] || [ -f "azure-pipelines.yml" ]; then
  HAS_CI="true"
fi

# --- Detect tests ---
if [ -f "jest.config.js" ] || [ -f "jest.config.ts" ] || [ -f "vitest.config.ts" ] || [ -f "karma.conf.js" ] || [ -f "cypress.config.js" ] || [ -f "cypress.config.ts" ] || [ -f "playwright.config.ts" ] || [ -f "pytest.ini" ] || [ -f "setup.py" ] || [ -f "phpunit.xml" ]; then
  HAS_TESTS="true"
elif [ "$PKG_JSON_VALID" = "true" ] && echo "$PKG_JSON" | jq -e '.scripts.test != null' &>/dev/null; then
  HAS_TESTS="true"
elif [ -f "pubspec.yaml" ] && [ -d "test" ]; then
  HAS_TESTS="true"
fi

# --- Count project files ---
if [ "$PKG_JSON_VALID" = "true" ]; then
  PROJECT_SIZE_FILES=$(find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" \) -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" 2>/dev/null | wc -l | tr -d ' ')
  PROJECT_SIZE_COMPONENTS=$(find . \( -name "*.component.ts" -o -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" \) -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.stories.*" 2>/dev/null | wc -l | tr -d ' ')
  PROJECT_SIZE_SERVICES=$(find . \( -name "*.service.ts" -o -name "*.service.js" \) -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d ' ')
elif [ -f "pubspec.yaml" ]; then
  PROJECT_SIZE_FILES=$(find lib -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
  PROJECT_SIZE_COMPONENTS=$(find lib -name "*.dart" -not -name "*_test.dart" 2>/dev/null | wc -l | tr -d ' ')
elif [ -f "manage.py" ]; then
  PROJECT_SIZE_FILES=$(find . -name "*.py" -not -path "*/venv/*" -not -path "*/__pycache__/*" 2>/dev/null | wc -l | tr -d ' ')
elif [ -f "Gemfile" ]; then
  PROJECT_SIZE_FILES=$(find . \( -name "*.rb" -o -name "*.erb" \) -not -path "*/vendor/*" 2>/dev/null | wc -l | tr -d ' ')
fi

# ===== Framework Detection (order matters: most specific first) =====

# --- Angular ---
if pkg_has_dep "@angular/core"; then
  FRAMEWORK="angular"
  CURRENT_VERSION=$(get_pkg_version "@angular/core")
  RELATED_DEPS=$(build_deps_json "@angular/core" "@angular/cli" "@angular/common" "@angular/router" "@angular/forms" "@angular/platform-browser" "rxjs" "typescript" "zone.js" "@ngrx/store" "@ngrx/effects")

# --- Next.js ---
elif pkg_has_dep "next"; then
  FRAMEWORK="nextjs"
  CURRENT_VERSION=$(get_pkg_version "next")
  RELATED_DEPS=$(build_deps_json "next" "react" "react-dom" "typescript" "next-auth" "next-intl" "@next/font" "@next/image")

# --- Nuxt ---
elif pkg_has_dep "nuxt"; then
  FRAMEWORK="nuxt"
  CURRENT_VERSION=$(get_pkg_version "nuxt")
  RELATED_DEPS=$(build_deps_json "nuxt" "vue" "@nuxtjs/i18n" "@pinia/nuxt" "typescript")

# --- SvelteKit ---
elif pkg_has_dep "@sveltejs/kit"; then
  FRAMEWORK="sveltekit"
  CURRENT_VERSION=$(get_pkg_version "@sveltejs/kit")
  RELATED_DEPS=$(build_deps_json "@sveltejs/kit" "svelte" "@sveltejs/adapter-auto" "vite" "typescript")

# --- NestJS ---
elif pkg_has_dep "@nestjs/core"; then
  FRAMEWORK="nestjs"
  CURRENT_VERSION=$(get_pkg_version "@nestjs/core")
  RELATED_DEPS=$(build_deps_json "@nestjs/core" "@nestjs/common" "@nestjs/platform-express" "rxjs" "typescript")

# --- Vue ---
elif pkg_has_dep "vue"; then
  FRAMEWORK="vue"
  CURRENT_VERSION=$(get_pkg_version "vue")
  RELATED_DEPS=$(build_deps_json "vue" "vue-router" "pinia" "vuex" "vue-i18n" "typescript" "vite")

# --- React (generic) ---
elif pkg_has_dep "react"; then
  FRAMEWORK="react"
  CURRENT_VERSION=$(get_pkg_version "react")
  RELATED_DEPS=$(build_deps_json "react" "react-dom" "react-router" "react-router-dom" "typescript" "vite" "@vitejs/plugin-react")

# --- Flutter (not JSON — uses grep) ---
elif [ -f "pubspec.yaml" ]; then
  FRAMEWORK="flutter"
  CURRENT_VERSION=$(grep -E '^\s*sdk:\s*flutter' pubspec.yaml 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  if [ -z "$CURRENT_VERSION" ] && command -v flutter &>/dev/null; then
    CURRENT_VERSION=$(flutter --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  DART_VERSION=""
  if command -v dart &>/dev/null; then
    DART_VERSION=$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  RELATED_DEPS=$(jq -nc --arg flutter "$CURRENT_VERSION" --arg dart "$DART_VERSION" \
    '{flutter: $flutter, dart: $dart}')

# --- Django (not JSON — uses grep) ---
elif [ -f "manage.py" ]; then
  FRAMEWORK="django"
  if [ -f "requirements.txt" ]; then
    CURRENT_VERSION=$(grep -iE '^django[=>~]' requirements.txt 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  elif [ -f "Pipfile" ]; then
    CURRENT_VERSION=$(grep -A1 'django' Pipfile 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  fi
  PYTHON_VERSION=""
  if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  fi
  RELATED_DEPS=$(jq -nc --arg django "$CURRENT_VERSION" --arg python "$PYTHON_VERSION" \
    '{django: $django, python: $python}')

# --- Rails (not JSON — uses grep) ---
elif [ -f "Gemfile" ] && grep -q "rails" Gemfile 2>/dev/null; then
  FRAMEWORK="rails"
  CURRENT_VERSION=$(grep -E "gem ['\"]rails['\"]" Gemfile 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
  if [ -z "$CURRENT_VERSION" ] && [ -f "Gemfile.lock" ]; then
    CURRENT_VERSION=$(grep -A1 "rails (" Gemfile.lock 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  RUBY_VERSION=""
  if command -v ruby &>/dev/null; then
    RUBY_VERSION=$(ruby --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  RELATED_DEPS=$(jq -nc --arg rails "$CURRENT_VERSION" --arg ruby "$RUBY_VERSION" \
    '{rails: $rails, ruby: $ruby}')

# --- Express ---
elif pkg_has_dep "express"; then
  FRAMEWORK="express"
  CURRENT_VERSION=$(get_pkg_version "express")
  RELATED_DEPS=$(build_deps_json "express" "typescript" "cors" "helmet" "morgan")
fi

# --- Output JSON using jq for safe encoding ---
jq -n \
  --arg framework "$FRAMEWORK" \
  --arg currentVersion "$CURRENT_VERSION" \
  --arg latestVersion "" \
  --argjson relatedDeps "$RELATED_DEPS" \
  --arg nodeVersion "$NODE_VERSION" \
  --arg packageManager "$PACKAGE_MANAGER" \
  --argjson hasTests "$HAS_TESTS" \
  --argjson hasCi "$HAS_CI" \
  --argjson files "$PROJECT_SIZE_FILES" \
  --argjson components "$PROJECT_SIZE_COMPONENTS" \
  --argjson services "$PROJECT_SIZE_SERVICES" \
  '{
    framework: $framework,
    currentVersion: $currentVersion,
    latestVersion: $latestVersion,
    relatedDeps: $relatedDeps,
    nodeVersion: $nodeVersion,
    packageManager: $packageManager,
    hasTests: $hasTests,
    hasCi: $hasCi,
    projectSize: {
      files: $files,
      components: $components,
      services: $services
    }
  }'
