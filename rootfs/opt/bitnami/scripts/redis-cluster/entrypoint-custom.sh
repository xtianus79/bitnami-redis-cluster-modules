#!/bin/bash
# custom-entrypoint.sh

# Example: Add module load directives to the redis.conf directly
echo "loadmodule /opt/bitnami/redis/etc/rejson.so" >> /opt/bitnami/redis/etc/redis.conf
echo "loadmodule /opt/bitnami/redis/etc/module-oss.so OSS_GLOBAL_PASSWORD bitnami" >> /opt/bitnami/redis/etc/redis.conf

# Echo some output to indicate what's happening
echo "Custom configuration applied. Delegating to original entrypoint..."

# Call the original entrypoint script to handle default behaviors including starting Redis server
exec /opt/bitnami/scripts/redis-cluster/entrypoint.sh "$@"