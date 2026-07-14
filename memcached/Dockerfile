FROM memcached:1.6-alpine

# The alpine image already runs as the unprivileged `memcached` user by
# default - nothing to override there.

# -m 64        : cap memory usage at 64MB (matches mem_limit in compose)
# -c 1024      : cap max simultaneous connections
# -v           : verbose logging for visibility, not debug-level noise
CMD ["memcached", "-m", "64", "-c", "1024", "-v"]

EXPOSE 11211
