#!/usr/bin/env bash

#
# 多数据库初始化脚本
# 自动创建多个应用数据库并启用所有扩展
#

echo "开始创建多数据库..."

# 创建 lunchbox 数据库
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE lunchbox;
    GRANT ALL PRIVILEGES ON DATABASE lunchbox TO "$POSTGRES_USER";
EOSQL

# 为 lunchbox 数据库启用所有扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "lunchbox" <<-EOSQL
    -- PostGIS 扩展
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

    -- pgvector 扩展
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

# 创建 shop 数据库
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE shop;
    GRANT ALL PRIVILEGES ON DATABASE shop TO "$POSTGRES_USER";
EOSQL

# 为 shop 数据库启用所有扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "shop" <<-EOSQL
    -- PostGIS 扩展
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

    -- pgvector 扩展
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

# 创建 domost 数据库
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE domost;
    GRANT ALL PRIVILEGES ON DATABASE domost TO "$POSTGRES_USER";
EOSQL

# 为 domost 数据库启用所有扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "domost" <<-EOSQL
    -- PostGIS 扩展
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

    -- pgvector 扩展
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

# 创建 authelia 数据库
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE authelia;
    GRANT ALL PRIVILEGES ON DATABASE authelia TO "$POSTGRES_USER";
EOSQL

# 为 authelia 数据库启用所有扩展
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "authelia" <<-EOSQL
    -- PostGIS 扩展
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

    -- pgvector 扩展
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

# 为默认数据库启用所有扩展（如果尚未启用）
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- PostGIS 扩展
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS postgis_raster;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

    -- pgvector 扩展
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo "多数据库创建完成！"
echo "已创建的数据库："
echo "- lunchbox (午餐盒应用)"
echo "- shop (商店应用)"
echo "- domost (智能家居)"
echo "- authelia (认证服务)"
echo "- $POSTGRES_DB (默认数据库)"
