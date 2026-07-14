# vprofile — Dockerized

The same vprofile stack (DB, cache, message queue, app server, load balancer) as the AWS/Terraform version, but fully containerized. Every service has its own Dockerfile, all tied together with a single `docker-compose.yml`. Built with security and reproducibility as first-class goals, not an afterthought.

## Architecture

```
                    Internet
                       |
                       v
              ┌─────────────────┐
              │  nginx (LB)     │  <- only service published to the host (port 80)
              └────────┬────────┘
                       |
           ┌───────────┴───────────┐
           v                       v
     ┌───────────┐           ┌───────────┐
     │   app1     │           │   app2     │   <- Tomcat, identical images
     └─────┬──────┘           └─────┬──────┘
           |                        |
   ┌───────┴────────────────────────┴───────┐
   v                    v                    v
┌──────┐          ┌────────────┐       ┌──────────┐
│  db   │          │ memcached  │       │ rabbitmq │
└──────┘          └────────────┘       └──────────┘
```

Two isolated Docker networks:
- **frontend** — nginx ↔ app1/app2
- **backend** (`internal: true`) — app1/app2 ↔ db/memcached/rabbitmq. Nothing on this network can reach the internet or be reached from outside the Docker host.

## File structure

| Path | Contents |
|---|---|
| `docker-compose.yml` | Orchestrates all 6 services, networks, volumes, healthchecks, and security options |
| `.env.example` | Template for required secrets/config — copy to `.env` (never commit `.env`) |
| `app/Dockerfile` | Multi-stage build: Maven+JDK build stage (discarded) → minimal Tomcat runtime |
| `app/docker-entrypoint.sh` | Injects real DB/cache/MQ config at **container start**, not build time |
| `db/Dockerfile` + `db/my.cnf` | MySQL with hardening config (no LOCAL INFILE, no symlinks, connection cap) |
| `memcached/Dockerfile` | Memcached with memory/connection caps |
| `rabbitmq/Dockerfile` | RabbitMQ with management UI |
| `nginx/Dockerfile` + `nginx/nginx.conf` | Load balancer with sticky sessions + security headers |

## Security measures applied

1. **Multi-stage builds** (`app/Dockerfile`) — Maven, the JDK, and the full git history/source tree exist only in the discarded build stage. The final image only has a JRE, Tomcat, and the compiled WAR contents.
2. **No secrets baked into any image** — the app's `application.properties` is built with placeholders (`__DB_HOST__`, `__DB_PASS__`, etc.), and the real values are substituted by `docker-entrypoint.sh` **at container startup**, sourced from environment variables that come from `.env` (which is git-ignored). Nothing sensitive ever lands in an image layer or in `docker history`.
3. **Non-root users everywhere** — the app's Dockerfile explicitly creates and switches to a `tomcat` system user. The official mysql/memcached/rabbitmq/nginx images already drop to unprivileged users internally; none of the custom Dockerfiles re-introduce root.
4. **`cap_drop: ["ALL"]`** on every service, with capabilities added back only where strictly required (e.g. nginx needs `NET_BIND_SERVICE` to bind port 80; mysqld needs a small set of filesystem-related caps to manage its data directory).
5. **`read_only: true` root filesystem** on nginx, the app containers, and memcached, with `tmpfs` mounts only for the specific paths each process needs to write to at runtime (e.g. Tomcat's `temp`/`work`/`logs`).
6. **`security_opt: no-new-privileges:true`** on every service — blocks privilege escalation via setuid binaries even if a container is compromised.
7. **Network segmentation** — the `backend` network is marked `internal: true`. The database, cache, and message broker are unreachable from the host or the internet; only the app containers can talk to them, and only nginx is published externally.
8. **Removed Tomcat's default webapps** (`manager`, `host-manager`, `examples`, `docs`) — these are a well-known attack surface and have no place in production.
9. **Pinned image versions** everywhere (`mysql:8.0.36`, `tomcat:9.0-jre11-temurin-jammy`, etc.) — no `:latest` tags, so builds are reproducible and you control exactly when you take an upgrade.
10. **Healthchecks on every service** — compose won't route traffic to (or start dependents on) a container that isn't actually ready.
11. **Resource limits** (`mem_limit`) — a compromised or misbehaving container can't exhaust the host's memory.
12. **`.dockerignore`** in the app build context — keeps `.git`, `.env`, and markdown files out of the build context entirely.

## Setup

1. Copy the env template and fill in real values:
   ```bash
   cp .env.example .env
   # edit .env with real passwords
   ```
2. Build and start everything:
   ```bash
   docker compose up -d --build
   ```
3. Check status:
   ```bash
   docker compose ps
   ```
   All services should show `healthy` within ~60 seconds.
4. Visit `http://localhost/login`.

## Notes / things you may want to adjust

- **Database seed data**: this compose file starts `db` empty. To seed it automatically, either mount a `.sql` file into `/docker-entrypoint-initdb.d/` on the `db` service, or run your import manually once the container is healthy:
  ```bash
  docker compose exec -T db mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" < backup.sql
  ```
- **RabbitMQ over TLS**: this local setup uses plain AMQP (5672) inside the isolated `backend` network, which is fine for local/dev use since that network isn't internet-reachable. If you deploy this compose file on a host where the network boundary is less trustworthy, put RabbitMQ behind TLS the same way the AWS/AmazonMQ version does.
- **Scaling beyond 2 app instances**: duplicate the `app1`/`app2` block (or convert to Swarm/Kubernetes for real autoscaling) and add the new instance to `nginx/nginx.conf`'s `upstream` block.
- **Image scanning**: before shipping these images anywhere, scan them — e.g. `docker scout cves vprofile/app:1.0` or `trivy image vprofile/app:1.0` — multi-stage builds reduce the attack surface but don't eliminate vulnerable dependencies inside the final base images.

## Cleanup

```bash
docker compose down          # stop and remove containers
docker compose down -v       # also remove db_data/rmq_data volumes (destroys data)
```
