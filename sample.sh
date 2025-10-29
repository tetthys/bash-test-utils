#!/usr/bin/env bash
set -euo pipefail
source "./test-utils.sh"

suite_math() {
  it "adds numbers" test_add
  it "greater-than works" test_gt
}

test_add() {
  local x=$((1+1))
  expect "$x"; to_equal "2"
  expect "$x"; not; to_equal "3"
}

test_gt() {
  expect "5"; to_be_greater_than "3"
  expect "2"; not; to_be_greater_than "3"
}

describe "Math Suite" suite_math
