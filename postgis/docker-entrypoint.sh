#!/bin/bash
set -e

echo "=== PostGIS Container Startup ==="
echo "1. Checking PostGIS installation..."

# 验证 PostGIS 安装
echo "   - Checking PostGIS extension files..."
ls -la /usr/share/postgresql17/extension/postgis* | head -3
echo "   - Checking PostGIS library files..."
ls -la /usr/lib/postgresql17/postgis*.so
echo "   - Checking PostGIS binary..."
which postgis
echo "   [OK] PostGIS installation verified successfully!"

# 验证配置文件
echo "2. Checking PostgreSQL configuration..."
if [ -f "/etc/postgresql/postgresql.conf" ]; then
    echo "   [OK] Custom configuration file found: /etc/postgresql/postgresql.conf"
    echo "   - Configuration parameters:"
    grep -E "^(max_connections|shared_buffers|work_mem|timezone)" /etc/postgresql/postgresql.conf | head -4
else
    echo "   [WARN] Custom configuration file not found, using default configuration"
fi

# 检查数据目录
echo "3. Checking data directory..."
if [ -d "/var/lib/postgresql/data" ]; then
    echo "   [OK] Data directory exists"
    if [ -z "$(ls -A /var/lib/postgresql/data)" ]; then
        echo "   [INFO] Data directory is empty, initializing database..."
        # 初始化数据库
        gosu postgres initdb -D /var/lib/postgresql/data
        echo "   [OK] Database initialized successfully"
    else
        echo "   [INFO] Data directory contains existing database"
    fi
else
    echo "   [ERROR] Data directory not found"
    exit 1
fi

# 设置权限（如果需要）
echo "4. Setting up permissions..."
#chown -R postgres:postgres /var/lib/postgresql/data
#chown -R postgres:postgres /etc/postgresql
#chmod 700 /var/lib/postgresql/data

# 切换到 postgres 用户启动 PostgreSQL
echo "5. Starting PostgreSQL with custom configuration..."
echo "   - Config file: /etc/postgresql/postgresql.conf"
echo "   - Command: postgres -c config_file=/etc/postgresql/postgresql.conf"
echo "=== Starting PostgreSQL Server ==="

exec gosu postgres postgres -c config_file=/etc/postgresql/postgresql.conf
