#!/usr/bin/env bash
# test-utils.sh - Jest-like testing for Bash (snake_case matchers only)
# - Works under `set -euo pipefail` without abnormal exits
# - Counts asserts/tests correctly (no subshell state loss)
# - No heredoc/DSL; pure function calls: describe/it/expect/not/to_xxx
# -----------------------------------------------------------------------------

# ===== Colors (ANSI) ==========================================================
_tu_color() {
  local c="$1" msg="$2" code=""
  case "$c" in
    green)  code="32";;
    red)    code="31";;
    yellow) code="33";;
    cyan)   code="36";;
    bold)   code="1";;
    dim)    code="2";;
    *)      code="0";;
  esac
  printf "\033[%sm%s\033[0m" "$code" "$msg"
}

# ===== Global state ===========================================================
declare -gA _TU_MATCHERS=()  # name -> function
declare -g  _TU_SUITE="" _TU_TEST=""
declare -g  _TU_TOTAL=0 _TU_PASS=0 _TU_FAIL=0 _TU_SKIP=0 _TU_ASSERTS=0
declare -g  _TU_CUR_ASSERTS=0 _TU_NEGATE=0 _TU_ACTUAL=""
declare -g  _TU_TEST_FAILED=0

# ===== Run code with relaxed options in the SAME shell ========================
# Saves current `set -o` state, disables -e/-u/pipefail for the duration,
# runs "$@", restores options, and returns the command's RC.
_tu_inplace_try() {
  # snapshot current shell options (portable in bash)
  local _saved; _saved="$(set +o)"
  # relax safety for test body to prevent immediate aborts on non-zero
  set +e
  set +u
  set +o pipefail
  "$@"
  local rc=$?
  # restore original shell options
  eval "$_saved"
  return "$rc"
}

# ===== Matchers registry ======================================================
register_matcher() {
  local name="${1:?matcher name}" fn="${2:?function name}"
  _TU_MATCHERS["$name"]="$fn"
}

# ===== Public API: describe / it / xit =======================================
describe() {
  local name="${1:?suite name}" fn="${2:?suite function name}"
  _TU_SUITE="$name"
  echo ""
  echo "$(_tu_color bold "Suite:") $(_tu_color cyan "$_TU_SUITE")"
  _tu_inplace_try "$fn"
  _TU_SUITE=""
}

it() {
  local name="${1:?test name}" fn="${2:?test function name}"
  ((_TU_TOTAL++))
  _TU_TEST="$name"
  _TU_CUR_ASSERTS=0
  _TU_TEST_FAILED=0

  # Run test body in the same shell (no subshell), with relaxed options.
  _tu_inplace_try "$fn" >/dev/null 2>&1
  local rc=$?

  # If any assertion failed, mark test failed regardless of body rc.
  if (( _TU_TEST_FAILED != 0 )); then rc=1; fi

  if (( rc == 0 )); then
    ((_TU_PASS++))
    printf "  %s %s %s\n" "$(_tu_color green "✓")" "$name" "$(_tu_color dim "[${_TU_CUR_ASSERTS} asserts]")"
  else
    ((_TU_FAIL++))
    printf "  %s %s %s\n" "$(_tu_color red "✗")" "$name" "$(_tu_color dim "[${_TU_CUR_ASSERTS} asserts]")"
  fi
  _TU_TEST=""
}

xit() {
  local name="${1:?test name}" reason="${2:-skipped}"
  ((_TU_TOTAL++))
  ((_TU_SKIP++))
  printf "  %s %s %s\n" "$(_tu_color yellow "-")" "$name" "$(_tu_color dim "($reason)")"
}

# ===== Expect core ============================================================
expect() { _TU_ACTUAL="$1"; _TU_NEGATE=0; }
not()    { _TU_NEGATE=1; }

_tu_run_matcher() {
  local name="${1:?matcher name}"; shift
  local fn="${_TU_MATCHERS[$name]}"
  if [[ -z "$fn" ]] || ! command -v "$fn" >/dev/null 2>&1; then
    echo "    $(_tu_color red "Unknown matcher:") $name" >&2
    _TU_TEST_FAILED=1
    return 1
  fi

  "$fn" "$_TU_ACTUAL" "$@"
  local ok=$?
  ((_TU_ASSERTS++))
  ((_TU_CUR_ASSERTS++))

  if (( _TU_NEGATE )); then
    if (( ok == 0 )); then
      echo "    $(_tu_color red "Assertion failed:") not ${name}" >&2
      _TU_TEST_FAILED=1
      return 1
    fi
    return 0
  else
    if (( ok == 0 )); then
      return 0
    fi
    echo "    $(_tu_color red "Assertion failed:") ${name}" >&2
    echo "    $(_tu_color dim "actual:") $_TU_ACTUAL" >&2
    echo "    $(_tu_color dim "expected:") $*" >&2
    _TU_TEST_FAILED=1
    return 1
  fi
}

# ===== Built-in matchers (snake_case) =========================================
_tu_eq()        { [[ "$1" == "$2" ]]; }
_tu_ne()        { [[ "$1" != "$2" ]]; }
_tu_match()     { [[ "$1" =~ $2 ]]; }
_tu_contain()   { [[ "$1" == *"$2"* ]]; }
_tu_truthy()    { [[ -n "$1" && "$1" != "0" && "$1" != "false" ]]; }
_tu_falsy()     { [[ -z "$1" || "$1" == "0" || "$1" == "false" ]]; }
_tu_gt()        { (( $1 > $2 )); }
_tu_lt()        { (( $1 < $2 )); }

register_matcher "to_equal"           _tu_eq
register_matcher "to_not_equal"       _tu_ne
register_matcher "to_match"           _tu_match
register_matcher "to_contain"         _tu_contain
register_matcher "to_be_truthy"       _tu_truthy
register_matcher "to_be_falsy"        _tu_falsy
register_matcher "to_be_greater_than" _tu_gt
register_matcher "to_be_less_than"    _tu_lt

# Shortcuts
to_equal()           { _tu_run_matcher "to_equal" "$@"; }
to_not_equal()       { _tu_run_matcher "to_not_equal" "$@"; }
to_match()           { _tu_run_matcher "to_match" "$@"; }
to_contain()         { _tu_run_matcher "to_contain" "$@"; }
to_be_truthy()       { _tu_run_matcher "to_be_truthy" "$@"; }
to_be_falsy()        { _tu_run_matcher "to_be_falsy" "$@"; }
to_be_greater_than() { _tu_run_matcher "to_be_greater_than" "$@"; }
to_be_less_than()    { _tu_run_matcher "to_be_less_than" "$@"; }

# ===== Summary ================================================================
_tu_summary() {
  echo ""
  echo "$(_tu_color bold "Summary")"
  printf "  %s %s, %s %s, %s %s, %s %s\n" \
    "$(_tu_color bold "Total")" "$_TU_TOTAL" \
    "$(_tu_color green "Passed")" "$_TU_PASS" \
    "$(_tu_color red "Failed")" "$_TU_FAIL" \
    "$(_tu_color yellow "Skipped")" "$_TU_SKIP"
  printf "  %s %s\n" "$(_tu_color dim "Asserts")" "$_TU_ASSERTS"
  # exit non-zero if any failed (useful for CI)
  if (( _TU_FAIL > 0 )); then return 1; fi
  return 0
}

trap _tu_summary EXIT