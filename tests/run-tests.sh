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
run_test() {
  local fixture_name="$1"
  local expected_framework="$2"
  local expected_version="$3"
  local expected_pm="$4"
  local label="$5"

  TOTAL=$((TOTAL + 1))

  local fixture_dir="$FIXTURES_DIR/$fixture_name"
  if [ ! -d "$fixture_dir" ]; then
    echo "  FAIL $label: fixture directory not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Run detection from fixture directory
  local output
  output=$(cd "$fixture_dir" && bash "$DETECT_SCRIPT" 2>/dev/null)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "  FAIL $label: detect-stack.sh exited with code $exit_code"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return
  fi

  # Validate JSON output
  if ! echo "$output" | jq . &>/dev/null; then
    echo "  FAIL $label: invalid JSON output"
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

  # Check related deps is not empty
  if [ "$related_deps_count" -eq 0 ] 2>/dev/null; then
    errors="${errors}relatedDeps is empty; "
  fi

  # Report result
  if [ -z "$errors" ]; then
    local version_display=""
    if [ -n "$actual_version" ] && [ "$actual_version" != "null" ] && [ "$actual_version" != "" ]; then
      version_display=" version=$actual_version"
    fi
    printf "  PASS %-20s framework=%s%s\n" "$label:" "$actual_framework" "$version_display"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf "  FAIL %-20s %s\n" "$label:" "$errors"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo ""
echo "  migrate-kit Test Suite"
echo "  =========================="
echo ""

# Run all tests
#                fixture dir             framework   version     pm        label
run_test         "angular-17"            "angular"   "17.3.2"    "npm"     "angular-17"
run_test         "react-18"             "react"     "18.2.0"    "npm"     "react-18"
run_test         "nextjs-15"            "nextjs"    "15.0.0"    "npm"     "nextjs-15"
run_test         "vue-3"                "vue"       "3.4.0"     "npm"     "vue-3"
run_test         "flutter"              "flutter"   ""          "pub"     "flutter"
run_test         "django"               "django"    "5.1.2"     "unknown" "django"
run_test         "nextjs-16-turbopack"  "nextjs"    "16.0.0"    "npm"     "nextjs-16"
run_test         "monorepo-npm"         "react"     "19.0.0"    "npm"     "monorepo-npm"

echo ""
echo "  Results: $PASS_COUNT/$TOTAL passed"

if [ $FAIL_COUNT -gt 0 ]; then
  echo "  $FAIL_COUNT test(s) failed."
  exit 1
else
  echo "  All tests passed."
  exit 0
fi
