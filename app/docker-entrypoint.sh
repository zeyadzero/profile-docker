#!/bin/bash
set -euo pipefail

TEMPLATE="/usr/local/tomcat/application.properties.template"
TARGET="/tmp/application.properties"

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:?DB_PORT is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASS:?DB_PASS is required}"
: "${MC_HOST:?MC_HOST is required}"
: "${MQ_HOST:?MQ_HOST is required}"

# Always regenerate from the template so a container restart never
# double-substitutes or leaks a previous run's values.
sed \
  -e "s#__DB_HOST__#${DB_HOST}#g" \
  -e "s#__DB_PORT__#${DB_PORT}#g" \
  -e "s#__DB_NAME__#${DB_NAME}#g" \
  -e "s#__DB_USER__#${DB_USER}#g" \
  -e "s#__DB_PASS__#${DB_PASS}#g" \
  -e "s#__MC_HOST__#${MC_HOST}#g" \
  -e "s#__MQ_HOST__#${MQ_HOST}#g" \
  "$TEMPLATE" > "$TARGET"

exec "$@"
