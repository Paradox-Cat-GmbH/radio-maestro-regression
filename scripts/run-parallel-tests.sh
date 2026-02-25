#!/usr/bin/env bash
set -euo pipefail

DEVICE_A="${1:-}"
DEVICE_B="${2:-}"
TEST_A="${3:-Test1.yaml}"
TEST_B="${4:-Test2.yaml}"

if [[ -z "$DEVICE_A" || -z "$DEVICE_B" ]]; then
  echo "Usage: ./scripts/run-parallel-tests.sh <DEVICE_A> <DEVICE_B> [TEST_A] [TEST_B]"
  exit 1
fi

echo "Checking connected devices..."
maestro devices

echo "Starting tests in parallel..."
maestro --device "$DEVICE_A" test "$TEST_A" &
PID1=$!

maestro --device "$DEVICE_B" test "$TEST_B" &
PID2=$!

wait $PID1
wait $PID2

echo "Both tests finished."
