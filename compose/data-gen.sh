#!/bin/bash
set -eu

LOG_DIR=${LOG_DIR:-/logs}
LOG_PREFIX=${LOG_PREFIX:-multi}
LOG_COUNT=${LOG_COUNT:-100}
LOG_RATE=${LOG_RATE:-20}
LOG_SIZE=${LOG_SIZE:-1000}

rm -vfr "${LOG_DIR:?}/$LOG_PREFIX*"

for i in $(seq "$LOG_COUNT")
do
    OUTPUT_LOGFILE="$LOG_DIR/${LOG_PREFIX}-${i}.log"
    echo "Creating $OUTPUT_LOGFILE"
    /run_log_generator.py --log-size-in-bytes "$LOG_SIZE" --log-rate "$LOG_RATE" --log-agent-input-type tail --tail-file-path "$OUTPUT_LOGFILE" &
done

wait
