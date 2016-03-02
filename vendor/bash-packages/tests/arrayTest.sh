#!/usr/bin/env bash
set -o errexit -o pipefail -o errtrace
source ../testing.sh
source ../array.sh

# Default entries
declare -r TEST_ARRAY_FROM_STRING="first second third fourth"
declare -r TEST_ARRAY_FROM_STRING_PLUS="first second third fourth fifth sixth seventh"
declare -r TEST_ARRAY_FROM_STRING_MINUS="first second"
declare -r TEST_ARRAY_FROM_STRING_SURROUND="(first second third fourth)"
declare -r TEST_ARRAY_NUMERIC_INDEX="([0]=\"first\" [1]=\"second\" [2]=\"third\" [3]=\"fourth\")"
declare -r TEST_ARRAY_ASSOCIATIVE_INDEX="([\"one\"]=\"first\" [\"two\"]=\"second\" [\"three\"]=\"third\" [\"four\"]=\"fourth\")"
declare -r TEST_ARRAY_ASSOCIATIVE_INDEX_DIFF="([four]=\"fourth\" [three]=\"third\" )"
declare -r TEST_ARRAY_DECLARE_ASSOCIATIVE_INDEX="declare -A rv='${TEST_ARRAY_ASSOCIATIVE_INDEX}'"
declare -r TEST_ARRAY_DECLARE_NUMERIC_INDEX="declare -a RV='${TEST_ARRAY_NUMERIC_INDEX}'"
declare -r TEST_ARRAY_NUMERIC_INDEX_DIFF="([2]=\"third\" [3]=\"fourth\")"

readonly TEST_ARRAY_ARRAY_DIFF="-01-01-01-01-01"

function test_arrayDiff ()
{
    local test

    # Check nothing
    test=$(arrayDiff)
    echo -n "-$?"
    [[ "$test" == "()" ]] && echo -n 1

    # Check with only first parameter
    test=$(arrayDiff "${TEST_ARRAY_FROM_STRING_SURROUND}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_NUMERIC_INDEX}" ]] && echo -n 1

    # Check with arrays with no difference
    test=$(arrayDiff "${TEST_ARRAY_NUMERIC_INDEX}" "${TEST_ARRAY_FROM_STRING_SURROUND}")
    echo -n "-$?"
    [[ "$test" == "()" ]] && echo -n 1

    # Check with associative array with differences
    test=$(arrayDiff "${TEST_ARRAY_ASSOCIATIVE_INDEX}" "${TEST_ARRAY_FROM_STRING_MINUS}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_ASSOCIATIVE_INDEX_DIFF}" ]] && echo -n 1

    # Check with numeric indexed arrays with differences
    test=$(arrayDiff "${TEST_ARRAY_NUMERIC_INDEX}" "${TEST_ARRAY_FROM_STRING_MINUS}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_NUMERIC_INDEX_DIFF}" ]] && echo -n 1
}


readonly TEST_ARRAY_ARRAY_SEARCH="-11-11-11-01-01-01"

function test_arraySearch ()
{
    local test

    # Check nothing
    test=$(arraySearch)
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Check with empty needle
    test=$(arraySearch "" "${TEST_ARRAY_FROM_STRING}")
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Check with empty haystack
    test=$(arraySearch "third" "")
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Check in basic array
    test=$(arraySearch "third" "${TEST_ARRAY_FROM_STRING}")
    echo -n "-$?"
    [[ "$test" -eq 2 ]] && echo -n 1

    # Check in numeric indexed array
    test=$(arraySearch "third" "${TEST_ARRAY_NUMERIC_INDEX}")
    echo -n "-$?"
    [[ "$test" -eq 2 ]] && echo -n 1

    # Check in associative array
    test=$(arraySearch "third" "${TEST_ARRAY_ASSOCIATIVE_INDEX}")
    echo -n "-$?"
    [[ "$test" == "three" ]] && echo -n 1
}


readonly TEST_ARRAY_ARRAY_TO_STRING="-01-01-01-01"

function test_arrayToString ()
{
    local test

    # Check nothing
    test=$(arrayToString)
    echo -n "-$?"
    [[ "$test" == "()" ]] && echo -n 1

    # Simple string
    test=$(arrayToString "${TEST_ARRAY_FROM_STRING}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_FROM_STRING_SURROUND}" ]] && echo -n 1

    # Associative declared associative array
    test=$(arrayToString "${TEST_ARRAY_DECLARE_ASSOCIATIVE_INDEX}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_ASSOCIATIVE_INDEX}" ]] && echo -n 1

    # Associative declared indexed array
    test=$(arrayToString "${TEST_ARRAY_DECLARE_NUMERIC_INDEX}")
    echo -n "-$?"
    [[ "$test" == "${TEST_ARRAY_NUMERIC_INDEX}" ]] && echo -n 1
}


readonly TEST_ARRAY_COUNT="-01-01-01-01-01-01-01"

function test_count ()
{
    local test

    # Check nothing
    test=$(count)
    echo -n "-$?"
    [[ "$test" -eq 0 ]] && echo -n 1

    # Check empty array
    test=$(count "()")
    echo -n "-$?"
    [[ "$test" -eq 0 ]] && echo -n 1

    # Check empty array with only space inside
    test=$(count "( )")
    echo -n "-$?"
    [[ "$test" -eq 0 ]] && echo -n 1

    # Check associative array with values
    test=$(count "${TEST_ARRAY_ASSOCIATIVE_INDEX}")
    echo -n "-$?"
    [[ "$test" -eq 4 ]] && echo -n 1

    # Check array with values between parentheses
    test=$(count "${TEST_ARRAY_FROM_STRING_SURROUND}")
    echo -n "-$?"
    [[ "$test" -eq 4 ]] && echo -n 1

    # Check basic array with values
    test=$(count "${TEST_ARRAY_FROM_STRING}")
    echo -n "-$?"
    [[ "$test" -eq 4 ]] && echo -n 1

    # Check indexed array with values
    test=$(count "${TEST_ARRAY_NUMERIC_INDEX}")
    echo -n "-$?"
    [[ "$test" -eq 4 ]] && echo -n 1
}


readonly TEST_ARRAY_IN_ARRAY="-11-11-01-01-01"

function test_inArray ()
{
    local test

    # Check nothing
    test=$(inArray)
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Search in basic array a unexisting value
    test=$(inArray "fifth" "${TEST_ARRAY_FROM_STRING}" )
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Search in basic array an existing value
    test=$(inArray "second" "${TEST_ARRAY_FROM_STRING}")
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Search in indexed array an existing value
    test=$(inArray "second" "${TEST_ARRAY_NUMERIC_INDEX}")
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1

    # Search in associative array an existing value
    test=$(inArray "second" "${TEST_ARRAY_ASSOCIATIVE_INDEX}")
    echo -n "-$?"
    [[ -z "$test" ]] && echo -n 1
}


# Launch all functional tests
bashUnit "arrayDiff" "${TEST_ARRAY_ARRAY_DIFF}" "$(test_arrayDiff)"
bashUnit "arraySearch" "${TEST_ARRAY_ARRAY_SEARCH}" "$(test_arraySearch)"
bashUnit "arrayToString" "${TEST_ARRAY_ARRAY_TO_STRING}" "$(test_arrayToString)"
bashUnit "count" "${TEST_ARRAY_COUNT}" "$(test_count)"
bashUnit "inArray" "${TEST_ARRAY_IN_ARRAY}" "$(test_inArray)"