#!/usr/bin/env bash
set -e
docker compose -f docker-compose/docker-compose.dev.yml up -d --build

