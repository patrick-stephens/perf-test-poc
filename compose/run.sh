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
                          "fluentbit_output_proc_records_total"
                          "fluentbit_output_dropped_records_total"
                          "fluentbit_output_errors_total"
)

if [[ ! -x "helpers/promplot" ]]; then
    curl --fail --silent -L https://github.com/qvl/promplot/releases/download/v0.17.0/promplot_0.17.0_linux_64bit.tar.gz| tar -xz
    chmod +x ./promplot
    mkdir -p helpers
    mv -fv ./promplot helpers/promplot
fi

# cleanup
./stop.sh
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# start
if [[ -n "${SKIP_REBUILD:-}" ]]; then
    $DOCKER_COMPOSE_CMD build
fi
$DOCKER_COMPOSE_CMD up --force-recreate -d

while [ $SECONDS -lt $END ]; do
    if [ -z "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")" ] || [ -z "$(docker ps -q --no-trunc | grep "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")")" ]; then
        echo "Container has failed after $SECONDS seconds"
        $DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"
        $DOCKER_COMPOSE_CMD logs "$SERVICE_TO_MONITOR" &> "$OUTPUT_DIR/failed.log"
        exit 1
    fi
    sleep 10
done

# Dump logs and metrics
$DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"

for METRIC in "${QUERY_METRICS[@]}"; do
    helpers/promplot -query "$METRIC" -range "$QUERY_RANGE" -url "$PROM_URL" -file "$OUTPUT_DIR/$METRIC.png"
    curl --fail --silent "${PROM_URL}/api/v1/query?query=$METRIC" | jq > "$OUTPUT_DIR/$METRIC.json"
done

if curl -XPOST "${PROM_URL}/api/v1/admin/tsdb/snapshot"; then
    $DOCKER_COMPOSE_CMD exec prometheus /bin/sh -c "tar -czvf /tmp/prom-data.tgz -C /prometheus/snapshots/ ."
    PROM_CONTAINER_ID=$($DOCKER_COMPOSE_CMD ps -q prometheus)
    if [[ -n "$PROM_CONTAINER_ID" ]]; then
        docker cp "$PROM_CONTAINER_ID":/tmp/prom-data.tgz "$OUTPUT_DIR"/
        echo "Copied snapshot to $OUTPUT_DIR/prom-data.tgz"
    fi
else
    echo "Unable to trigger snapshot on Prometheus"
fi

if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
    ./stop.sh
fi
