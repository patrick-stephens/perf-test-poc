#!/bin/bash
set -eu

SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}

./stop.sh

end=$((SECONDS+60))

DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose -f fluent-delta-stack.yml -f monitoring-stack.yml}
$DOCKER_COMPOSE_CMD up --force-recreate -d

while [ $SECONDS -lt $end ]; do
    if [ -z "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")" ] || [ -z "$(docker ps -q --no-trunc | grep "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")")" ]; then
        echo "Container has failed after $SECONDS seconds"
        exit 1
    fi
    sleep 10
done

if [[ ! -x "helpers/promplot" ]]; then
    curl --fail --silent -L https://github.com/qvl/promplot/releases/download/v0.17.0/promplot_0.17.0_linux_64bit.tar.gz| tar -xz
    chmod +x ./promplot
    mkdir -p helpers
    mv -fv ./promplot helpers/promplot
fi

PROM_URL="https://localhost:9090"
helpers/promplot -title "FB Input Records Total" -query "fluentbit_input_records_total" -range "5m" -url $"$PROM_URL" -file "ir-total.png"

./stop.sh
