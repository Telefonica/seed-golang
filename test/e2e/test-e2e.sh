#!/bin/bash -e

cd $(dirname $BASH_SOURCE)
if [ "${ENVIRONMENT}" == "pull" ]; then
    cd ../../build/bin 
    ./seed > ../seed.log &
    echo $! > ../seed.pid
    sleep 1
    kill -0 "$(cat ../seed.pid)"
    cd -
fi
lettuce
EXIT_CODE=$?
if [ "${ENVIRONMENT}" == "pull" ]; then
    cd ../../build
    kill "$(cat seed.pid)"
    rm -f seed.log seed.pid
fi
exit "${EXIT_CODE}"
