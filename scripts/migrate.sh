#!/usr/bin/env bash
set -euo pipefail
docker compose exec -T app php artisan migrate --force
