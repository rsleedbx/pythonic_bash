#!/usr/bin/env bash
#
# Test Suite for pythonic_bash.sh
#

set -e

# Load library
PYTHONIC_BASH_QUIET=1 source pythonic_bash.sh

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helper
run_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: $test_name ... "
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS${NC}"
}

fail_test() {
    local message="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Error: $message"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Value mismatch}"
    
    if [ "$expected" != "$actual" ]; then
        fail_test "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
    return 0
}

echo "================================================"
echo "Pythonic Bash Test Suite"
echo "================================================"
echo ""

# Test 1: Basic JSON read
run_test "Basic JSON read"
cat > /tmp/test1.json <<'EOF'
{
  "name": "test",
  "value": "123"
}
EOF

declare -A test1
json_to_associative_array test1 "/tmp/test1.json"

if assert_equals "test" "${test1[name]}" && \
   assert_equals "123" "${test1[value]}"; then
    pass_test
fi
rm -f /tmp/test1.json

# Test 2: Nested JSON read
run_test "Nested JSON structure"
cat > /tmp/test2.json <<'EOF'
{
  "database": {
    "host": "localhost",
    "port": 5432,
    "credentials": {
      "user": "admin",
      "password": "secret"
    }
  }
}
EOF

declare -A test2
json_to_associative_array test2 "/tmp/test2.json"

if assert_equals "localhost" "${test2[database__host]}" && \
   assert_equals "5432" "${test2[database__port]}" && \
   assert_equals "admin" "${test2[database__credentials__user]}" && \
   assert_equals "secret" "${test2[database__credentials__password]}"; then
    pass_test
fi
rm -f /tmp/test2.json

# Test 3: Special characters
run_test "Special characters handling"
declare -A test3
test3[quote_test]='value with "quotes"'
test3[dollar_test]='value with $dollar signs'
test3[space_test]='value with   multiple   spaces'
test3[newline_test]='line1
line2'

associative_array_to_json_file test3 "/tmp/test3.json"

declare -A test3_verify
json_to_associative_array test3_verify "/tmp/test3.json"

if assert_equals "${test3[quote_test]}" "${test3_verify[quote_test]}" && \
   assert_equals "${test3[dollar_test]}" "${test3_verify[dollar_test]}" && \
   assert_equals "${test3[space_test]}" "${test3_verify[space_test]}"; then
    pass_test
fi
rm -f /tmp/test3.json

# Test 4: Round-trip test
run_test "Round-trip (write then read)"
declare -A test4_orig
test4_orig[string]="hello world"
test4_orig[number]="42"
test4_orig[nested__key]="nested value"
test4_orig[another__deep__key]="very nested"

associative_array_to_json_file test4_orig "/tmp/test4.json"

declare -A test4_restored
json_to_associative_array test4_restored "/tmp/test4.json"

all_match=true
for key in "${!test4_orig[@]}"; do
    if [ "${test4_orig[$key]}" != "${test4_restored[$key]}" ]; then
        all_match=false
        break
    fi
done

if $all_match; then
    pass_test
else
    fail_test "Round-trip data mismatch"
fi
rm -f /tmp/test4.json

# Test 5: Empty array
run_test "Empty array handling"
declare -A test5
associative_array_to_json_file test5 "/tmp/test5.json"

content=$(cat /tmp/test5.json)
if assert_equals "{}" "$content"; then
    pass_test
fi
rm -f /tmp/test5.json

# Test 6: Array merge
run_test "Array merging"
declare -A test6_base test6_override
test6_base[key1]="value1"
test6_base[key2]="value2"
test6_override[key2]="overridden"
test6_override[key3]="value3"

merge_associative_arrays test6_base test6_override

if assert_equals "value1" "${test6_base[key1]}" && \
   assert_equals "overridden" "${test6_base[key2]}" && \
   assert_equals "value3" "${test6_base[key3]}"; then
    pass_test
fi

# Test 7: Validation - all present
run_test "Validation (all keys present)"
declare -A test7
test7[required1]="value1"
test7[required2]="value2"
test7[required3]="value3"

if validate_required_keys test7 "required1" "required2" "required3" 2>/dev/null; then
    pass_test
else
    fail_test "Validation should pass"
fi

# Test 8: Validation - missing key
run_test "Validation (missing key detection)"
declare -A test8
test8[present]="value"

if validate_required_keys test8 "present" "missing" 2>/dev/null; then
    fail_test "Should detect missing key"
else
    pass_test
fi

# Test 9: YAML output
run_test "YAML file generation"
declare -A test9
test9[app]="myapp"
test9[database__host]="localhost"
test9[database__port]="5432"

associative_array_to_yaml_file test9 "/tmp/test9.yaml"

if [ -f "/tmp/test9.yaml" ] && grep -q "database:" "/tmp/test9.yaml"; then
    pass_test
else
    fail_test "YAML file not generated correctly"
fi
rm -f /tmp/test9.yaml

# Test 10: Stdin input
run_test "Read from stdin"
declare -A test10
# Use process substitution instead of pipe to avoid subshell issues
json_to_associative_array test10 < <(echo '{"stdin_key": "stdin_value"}')

set +u  # Temporarily disable for safe key access check
if [ -n "${test10[stdin_key]:-}" ] && assert_equals "stdin_value" "${test10[stdin_key]}"; then
    set -u
    pass_test
else
    set -u
    fail_test "Stdin read failed or key not found"
fi

# Test 11: Deeply nested structure
run_test "Deeply nested structure (5 levels)"
cat > /tmp/test11.json <<'EOF'
{
  "level1": {
    "level2": {
      "level3": {
        "level4": {
          "level5": "deep value"
        }
      }
    }
  }
}
EOF

declare -A test11
json_to_associative_array test11 "/tmp/test11.json"

if assert_equals "deep value" "${test11[level1__level2__level3__level4__level5]}"; then
    pass_test
fi
rm -f /tmp/test11.json

# Test 12: Large config (performance test)
run_test "Large configuration (100 keys)"
declare -A test12
for i in {1..100}; do
    test12[key_$i]="value_$i"
done

start_time=$(date +%s%N)
associative_array_to_json_file test12 "/tmp/test12.json"
declare -A test12_verify
json_to_associative_array test12_verify "/tmp/test12.json"
end_time=$(date +%s%N)

elapsed_ms=$(( (end_time - start_time) / 1000000 ))

if [ ${#test12_verify[@]} -eq 100 ]; then
    pass_test
    echo "    (Performance: ${elapsed_ms}ms for 100 keys)"
else
    fail_test "Key count mismatch"
fi
rm -f /tmp/test12.json

echo ""
echo "================================================"
echo "Test Results"
echo "================================================"
echo ""
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
