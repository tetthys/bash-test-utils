# 🧩 Bash Test Utils

> A **minimal Jest-style testing framework for Bash 4+** — pure functions, no DSLs, no heredocs, no eval.

---

## 🚀 Features

* Works safely with `set -euo pipefail` — no premature exits
* `describe / it / expect / not / to_equal` syntax inspired by Jest
* Colored, human-readable output
* Built-in matchers for strings, regex, numbers, truthiness
* Fully **snake_case API**
* Extensible: add your own matchers with `register_matcher`

---

## 🧱 Quick Start

### 1. Include the framework

```bash
#!/usr/bin/env bash
set -euo pipefail
source "./test-utils.sh"
```

### 2. Write a suite

```bash
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
```

### 3. Run

```bash
bash sample.sh
```

### 4. See results

```
Suite: Math Suite
  ✓ adds numbers [2 asserts]
  ✓ greater-than works [2 asserts]

Summary
  Total 2, Passed 2, Failed 0, Skipped 0
  Asserts 4
```

---

## 🧩 Core Concepts

### `describe "<suite_name>" <function_name>`

Defines and runs a test suite.

```bash
describe "Math Suite" suite_math
```

---

### `it "<test_name>" <function_name>`

Defines a single test case.

```bash
it "adds correctly" test_add
```

---

### `xit "<test_name>" [reason]`

Skips a test case.

```bash
xit "network test" "requires Docker"
```

---

### `expect <value>`

Starts an assertion chain.
The following matcher compares this value.

```bash
expect "foo"; to_equal "foo"
```

---

### `not`

Negates the next matcher.

```bash
expect "bar"; not; to_equal "foo"
```

---

## 🧮 Built-in Matchers

| Matcher              | Description                       | Example                                      |
| -------------------- | --------------------------------- | -------------------------------------------- |
| `to_equal`           | exact string equality             | `expect "$x"; to_equal "abc"`                |
| `to_not_equal`       | opposite of `to_equal`            | `expect "$x"; to_not_equal "xyz"`            |
| `to_match`           | matches regex                     | `expect "abc123"; to_match "^[a-z]+[0-9]+$"` |
| `to_contain`         | substring containment             | `expect "hello world"; to_contain "world"`   |
| `to_be_truthy`       | non-empty, not `"0"` or `"false"` | `expect "yes"; to_be_truthy`                 |
| `to_be_falsy`        | empty string, `"0"` or `"false"`  | `expect ""; to_be_falsy`                     |
| `to_be_greater_than` | numeric greater-than              | `expect "5"; to_be_greater_than "3"`         |
| `to_be_less_than`    | numeric less-than                 | `expect "2"; to_be_less_than "5"`            |

All matchers can be negated:

```bash
expect "5"; not; to_be_less_than "3"
```

---

## 🧰 Custom Matchers

### Define

A matcher function must:

* Take `actual` and `expected` arguments
* Return `0` for success, non-zero for failure

```bash
starts_with() {
  [[ "$1" == "$2"* ]]
}
```

### Register

```bash
register_matcher "to_start_with" starts_with
```

### Use

```bash
expect "hello"; to_start_with "he"
```

---

## 🧾 Output Summary

At exit, a summary is printed automatically:

```
Summary
  Total 4, Passed 3, Failed 1, Skipped 0
  Asserts 12
```

* **Exit code 0** → all tests passed
* **Exit code 1** → one or more tests failed
  (useful for CI/CD pipelines)

---

## ⚙️ Recommended Layout

```
bash-test-utils/
├── test-utils.sh
└── tests/
    ├── math_tests.sh
    └── string_tests.sh
```

Each test file:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "../test-utils.sh"

suite_string() {
  it "checks substring" test_substring
}

test_substring() {
  expect "abcdef"; to_contain "bcd"
}

describe "String Suite" suite_string
```

Run with:

```bash
bash tests/string_tests.sh
```

---

## 🧩 Design Notes

| Feature                         | Explanation                                      |
| ------------------------------- | ------------------------------------------------ |
| **No subshells**                | Tests run in the same shell, preserving counters |
| **Safe with set -euo pipefail** | Options temporarily relaxed inside test bodies   |
| **Automatic summary**           | Hooked via `trap _tu_summary EXIT`               |
| **Extensible**                  | `register_matcher` lets you add any assertion    |

---

## 🧠 Example CI Integration

```bash
#!/usr/bin/env bash
set -euo pipefail
for f in tests/*.sh; do
  bash "$f" || exit 1
done
```