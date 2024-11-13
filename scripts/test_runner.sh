#!/bin/bash

if [ -z "$1" ]; then
  echo "test_runner.sh: no arg provided"
else
  echo "test_runner.sh: arg provided: $1"
fi
echo "test_runner.sh: writing test file to /data"
echo "test_runner.sh: $(date)" > /data/test.txt
sleep 5
echo "test_runner.sh: finished"
exit 0
