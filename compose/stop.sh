#!/bin/bash
set -eu
docker-compose -f fluent-delta-stack.yml -f monitoring-stack.yml down --remove-orphans --volumes
