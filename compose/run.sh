#!/bin/bash
set -eu

SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}
OUTPUT_DIR=${OUTPUT_DIR:-output}
PROM_URL=${PROM_URL:-http://localhost:9090}
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose -f fluent-delta-stack.yml -f monitoring-stack.yml}

# Run for 5 minutes
QUERY_RANGE=${QUERY_RANGE:-5m}
END=$((SECONDS+300))

declare -a QUERY_METRICS=("fluentbit_input_records_total"
                          "fluentbit_output_records_total"
)
./stop.sh

if [[ ! -x "helpers/promplot" ]]; then
    curl --fail --silent -L https://github.com/qvl/promplot/releases/download/v0.17.0/promplot_0.17.0_linux_64bit.tar.gz| tar -xz
    chmod +x ./promplot
    mkdir -p helpers
    mv -fv ./promplot helpers/promplot
fi


$DOCKER_COMPOSE_CMD up --force-recreate -d

while [ $SECONDS -lt $END ]; do
    if [ -z "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")" ] || [ -z "$(docker ps -q --no-trunc | grep "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")")" ]; then
        echo "Container has failed after $SECONDS seconds"
        $DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"
        exit 1
    fi
    sleep 10
done

# Dump logs and metrics
$DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"
curl -XPOST "$PROM_URL/api/v1/admin/tsdb/snapshot"

mkdir -p "$OUTPUT_DIR"
for METRIC in "${QUERY_METRICS[@]}"; do
    helpers/promplot -query "$METRIC" -range "$QUERY_RANGE" -url "$PROM_URL" -file "$OUTPUT_DIR/$METRIC.png"
done

if [[ -n "${SKIP_TEARDOWN:-}" ]]; then
    ./stop.sh
fi
