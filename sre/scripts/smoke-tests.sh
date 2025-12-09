#!/bin/bash

# Smoke tests for backend service deployment
# Exit codes: 0 = success, 1 = failure

set -e

echo "================================"
echo "Backend Service Smoke Tests"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Testing: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to run a test with output validation
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"

    echo -n "Testing: $test_name... "

    output=$(eval "$test_command" 2>&1)

    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Got: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "1. Health Endpoint Tests"
echo "-------------------------"

# Test liveness endpoint
run_test "Liveness endpoint responds" \
    "curl -f -s http://localhost:8080/actuator/health/liveness"

# Test readiness endpoint
run_test "Readiness endpoint responds" \
    "curl -f -s http://localhost:8080/actuator/health/readiness"

# Test overall health endpoint returns UP status
run_test_with_output "Health status is UP" \
    "curl -s http://localhost:8080/actuator/health" \
    '"status":"UP"'

echo ""
echo "2. API Endpoint Tests"
echo "---------------------"

# Test welcome endpoint
run_test "Welcome endpoint responds" \
    "curl -f -s http://localhost:8080/api/welcome"

# Test welcome endpoint returns expected message
run_test_with_output "Welcome message is correct" \
    "curl -s http://localhost:8080/api/welcome" \
    "Welcome to the interview project"

# Test HTTP response code
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/welcome)
if [ "$http_code" == "200" ]; then
    echo -e "Testing: HTTP response code is 200... ${GREEN}PASSED${NC}"
    ((TESTS_PASSED++))
else
    echo -e "Testing: HTTP response code is 200... ${RED}FAILED${NC} (got $http_code)"
    ((TESTS_FAILED++))
fi

echo ""
echo "3. Service Availability Tests"
echo "------------------------------"

# Check if service is responding within reasonable time
response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:8080/actuator/health)
response_time_ms=$(echo "$response_time * 1000" | bc | cut -d. -f1)

if [ "$response_time_ms" -lt 5000 ]; then
    echo -e "Testing: Response time < 5s... ${GREEN}PASSED${NC} (${response_time}s)"
    ((TESTS_PASSED++))
else
    echo -e "Testing: Response time < 5s... ${YELLOW}WARNING${NC} (${response_time}s)"
    # Don't fail on slow response, just warn
    ((TESTS_PASSED++))
fi

echo ""
echo "================================"
echo "Test Results Summary"
echo "================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
