#!/bin/bash
set -eux

start

# Enable tracing
if command -v http; then
    until http -v 127.0.0.1:2020/api/v1/trace input=dummy.0 output=stdout prefix=trace. enable:=true params:='{"format":"json"}'; do
        sleep 10
    done
elif command -v curl; then
    until curl --fail --header 'Content-Type: application/json' --data '{"enable":true, "input": "dummy.0", "output": "stdout", "params": { "format": "json" }, "prefix": "trace."}' '127.0.0.1:2020/api/v1/trace'; do
        sleep 10
    done
else
    echo "No curl or httpie installed"
    exit 1
fi

monitor
dump
stop
