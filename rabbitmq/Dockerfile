# management-alpine includes the web UI on 15672, useful for local
# debugging. Drop the -management suffix for a smaller attack surface
# once you don't need the UI anymore.
FROM rabbitmq:3.13-management-alpine

# No default guest/guest login is used - RABBITMQ_DEFAULT_USER/PASS are
# supplied via environment variables at container start (docker-compose.yml).
# The image already runs as the unprivileged `rabbitmq` user by default.

EXPOSE 5672 15672
