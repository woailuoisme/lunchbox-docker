#!/bin/bash
set -e

# 如果存在自定义配置，则使用自定义配置
if [ -f "$POSTGRES_CONFIG_FILE" ]; then
    echo "Using custom PostgreSQL configuration: $POSTGRES_CONFIG_FILE"
    POSTGRES_ARGS="$POSTGRES_ARGS -c config_file=$POSTGRES_CONFIG_FILE"
fi

# 调用原始的 PostgreSQL 入口点脚本
exec docker-entrypoint.sh postgres $POSTGRES_ARGS "$@"
