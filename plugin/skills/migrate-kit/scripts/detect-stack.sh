#!/usr/bin/env bash
set -euo pipefail

# migrate-kit stack detection script
# Detects framework, version, related deps, and project metadata

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

# --- Helper: extract version from package.json ---
get_pkg_version() {
  local pkg="$1"
  if [ -f "package.json" ]; then
    grep "\"$pkg\"" package.json 2>/dev/null | head -1 | sed -E 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"[\^~]?([0-9][^"]*)".*$/\1/'
  fi
}

# --- Helper: build related deps JSON ---
build_deps_json() {
  local deps=""
  for pkg in "$@"; do
    local ver
    ver=$(get_pkg_version "$pkg")
    if [ -n "$ver" ]; then
      [ -n "$deps" ] && deps="$deps, "
      deps="$deps\"$pkg\": \"$ver\""
    fi
  done
  echo "{$deps}"
}

# --- Detect CI ---
if [ -d ".github/workflows" ] || [ -f ".gitlab-ci.yml" ] || [ -f "Jenkinsfile" ] || [ -f ".circleci/config.yml" ] || [ -f "bitbucket-pipelines.yml" ] || [ -f "azure-pipelines.yml" ]; then
  HAS_CI="true"
fi

# --- Detect tests ---
if [ -f "jest.config.js" ] || [ -f "jest.config.ts" ] || [ -f "vitest.config.ts" ] || [ -f "karma.conf.js" ] || [ -f "cypress.config.js" ] || [ -f "cypress.config.ts" ] || [ -f "playwright.config.ts" ] || [ -f "pytest.ini" ] || [ -f "setup.py" ] || [ -f "phpunit.xml" ]; then
  HAS_TESTS="true"
elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
  HAS_TESTS="true"
elif [ -f "pubspec.yaml" ] && [ -d "test" ]; then
  HAS_TESTS="true"
fi

# --- Count project files ---
if [ -f "package.json" ]; then
  PROJECT_SIZE_FILES=$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" 2>/dev/null | grep -v node_modules | grep -v '.next' | grep -v dist | wc -l | tr -d ' ')
  PROJECT_SIZE_COMPONENTS=$(find . -name "*.component.ts" -o -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" 2>/dev/null | grep -v node_modules | grep -v '.next' | grep -v dist | grep -v '.test.' | grep -v '.spec.' | grep -v '.stories.' | wc -l | tr -d ' ')
  PROJECT_SIZE_SERVICES=$(find . -name "*.service.ts" -o -name "*.service.js" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
elif [ -f "pubspec.yaml" ]; then
  PROJECT_SIZE_FILES=$(find lib -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
  PROJECT_SIZE_COMPONENTS=$(find lib -name "*.dart" 2>/dev/null | grep -v '_test.dart' | wc -l | tr -d ' ')
elif [ -f "manage.py" ]; then
  PROJECT_SIZE_FILES=$(find . -name "*.py" 2>/dev/null | grep -v venv | grep -v __pycache__ | wc -l | tr -d ' ')
elif [ -f "Gemfile" ]; then
  PROJECT_SIZE_FILES=$(find . -name "*.rb" -o -name "*.erb" 2>/dev/null | grep -v vendor | wc -l | tr -d ' ')
fi

# ===== Framework Detection (order matters: most specific first) =====

# --- Angular ---
if [ -f "package.json" ] && grep -q "@angular/core" package.json 2>/dev/null; then
  FRAMEWORK="angular"
  CURRENT_VERSION=$(get_pkg_version "@angular/core")
  RELATED_DEPS=$(build_deps_json "@angular/core" "@angular/cli" "@angular/common" "@angular/router" "@angular/forms" "@angular/platform-browser" "rxjs" "typescript" "zone.js" "@ngrx/store" "@ngrx/effects")

# --- Next.js ---
elif [ -f "package.json" ] && grep -q "\"next\"" package.json 2>/dev/null; then
  FRAMEWORK="nextjs"
  CURRENT_VERSION=$(get_pkg_version "next")
  RELATED_DEPS=$(build_deps_json "next" "react" "react-dom" "typescript" "next-auth" "next-intl" "@next/font" "@next/image")

# --- Nuxt ---
elif [ -f "package.json" ] && grep -q "\"nuxt\"" package.json 2>/dev/null; then
  FRAMEWORK="nuxt"
  CURRENT_VERSION=$(get_pkg_version "nuxt")
  RELATED_DEPS=$(build_deps_json "nuxt" "vue" "@nuxtjs/i18n" "@pinia/nuxt" "typescript")

# --- SvelteKit ---
elif [ -f "package.json" ] && grep -q "@sveltejs/kit" package.json 2>/dev/null; then
  FRAMEWORK="sveltekit"
  CURRENT_VERSION=$(get_pkg_version "@sveltejs/kit")
  RELATED_DEPS=$(build_deps_json "@sveltejs/kit" "svelte" "@sveltejs/adapter-auto" "vite" "typescript")

# --- NestJS ---
elif [ -f "package.json" ] && grep -q "@nestjs/core" package.json 2>/dev/null; then
  FRAMEWORK="nestjs"
  CURRENT_VERSION=$(get_pkg_version "@nestjs/core")
  RELATED_DEPS=$(build_deps_json "@nestjs/core" "@nestjs/common" "@nestjs/platform-express" "rxjs" "typescript")

# --- Vue ---
elif [ -f "package.json" ] && grep -q "\"vue\"" package.json 2>/dev/null; then
  FRAMEWORK="vue"
  CURRENT_VERSION=$(get_pkg_version "vue")
  RELATED_DEPS=$(build_deps_json "vue" "vue-router" "pinia" "vuex" "vue-i18n" "typescript" "vite")

# --- React (generic) ---
elif [ -f "package.json" ] && grep -q "\"react\"" package.json 2>/dev/null; then
  FRAMEWORK="react"
  CURRENT_VERSION=$(get_pkg_version "react")
  RELATED_DEPS=$(build_deps_json "react" "react-dom" "react-router" "react-router-dom" "typescript" "vite" "@vitejs/plugin-react")

# --- Flutter ---
elif [ -f "pubspec.yaml" ]; then
  FRAMEWORK="flutter"
  CURRENT_VERSION=$(grep -E '^\s*sdk:\s*flutter' pubspec.yaml 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$CURRENT_VERSION" ] && command -v flutter &>/dev/null; then
    CURRENT_VERSION=$(flutter --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  DART_VERSION=""
  if command -v dart &>/dev/null; then
    DART_VERSION=$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  RELATED_DEPS="{\"flutter\": \"$CURRENT_VERSION\", \"dart\": \"$DART_VERSION\"}"

# --- Django ---
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
  RELATED_DEPS="{\"django\": \"$CURRENT_VERSION\", \"python\": \"$PYTHON_VERSION\"}"

# --- Rails ---
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
  RELATED_DEPS="{\"rails\": \"$CURRENT_VERSION\", \"ruby\": \"$RUBY_VERSION\"}"

# --- Express ---
elif [ -f "package.json" ] && grep -q "\"express\"" package.json 2>/dev/null; then
  FRAMEWORK="express"
  CURRENT_VERSION=$(get_pkg_version "express")
  RELATED_DEPS=$(build_deps_json "express" "typescript" "cors" "helmet" "morgan")
fi

# --- Output JSON ---
cat <<EOF
{
  "framework": "$FRAMEWORK",
  "currentVersion": "$CURRENT_VERSION",
  "latestVersion": "",
  "relatedDeps": $RELATED_DEPS,
  "nodeVersion": "$NODE_VERSION",
  "packageManager": "$PACKAGE_MANAGER",
  "hasTests": $HAS_TESTS,
  "hasCi": $HAS_CI,
  "projectSize": {
    "files": $PROJECT_SIZE_FILES,
    "components": $PROJECT_SIZE_COMPONENTS,
    "services": $PROJECT_SIZE_SERVICES
  }
}
EOF
