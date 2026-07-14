# Pin an exact version - never use `mysql:latest` in production, it makes
# builds non-reproducible and can silently pull breaking changes.
FROM mysql:8.0.36

# Custom hardening config: disable remote root login surface, disable
# symbolic-link following, require secure file privileges.
COPY my.cnf /etc/mysql/conf.d/hardening.cnf

# No password, no schema, and no seed data are baked into this image -
# they're all supplied at container start via environment variables
# (see docker-compose.yml) and a bind-mounted init script if needed.

EXPOSE 3306
