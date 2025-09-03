 #!/usr/bin/env bash
set -e
URL="${1:-http://localhost:8080/health/ready}"
echo "Checking $URL ..."
curl -fsS "$URL" && echo "OK" || (echo "Healthcheck failed" && exit 1)
