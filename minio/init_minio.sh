#!/bin/bash

# ============================================================================
# MinIO 初始化脚本
# 通过 Dockerfile ARG 参数获取配置并从 YAML 文件读取 bucket 配置
# ============================================================================

set -e

# 配置变量（通过环境变量传递，使用默认值）
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin123}"
CONFIG_FILE="${CONFIG_FILE:-/var/www/minio/buckets.yml}"

# 颜色输出
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# 检查环境变量配置
check_config() {
    log_info "使用配置: MINIO_ENDPOINT=$MINIO_ENDPOINT"
    log_info "使用配置: MINIO_ROOT_USER=$MINIO_ROOT_USER"
}

# 检查 YAML 配置文件
check_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    log_info "使用配置文件: $CONFIG_FILE"
}

# 解析 YAML 配置文件
parse_yaml_config() {
    log_info "解析 YAML 配置文件..."

    # 使用 yq 解析 YAML 文件
    if command -v yq &> /dev/null; then
        # 如果有 yq 工具，使用它来解析
        BUCKET_COUNT=$(yq e '.buckets | length' "$CONFIG_FILE")
        log_info "找到 $BUCKET_COUNT 个 bucket 配置"

        for i in $(seq 0 $((BUCKET_COUNT - 1))); do
            name=$(yq e ".buckets[$i].name" "$CONFIG_FILE")
            description=$(yq e ".buckets[$i].description" "$CONFIG_FILE")
            access_type=$(yq e ".buckets[$i].access_type" "$CONFIG_FILE")

            if [ "$name" != "null" ] && [ "$access_type" != "null" ]; then
                log_info "配置 bucket: $name ($description) - $access_type"
                BUCKETS+=("$name:$access_type")
            fi
        done
    else
        # 如果没有 yq，使用简单的 grep 和 sed 解析
        log_info "未找到 yq 工具，使用基础解析"
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"([^\"]*)\" ]]; then
                name="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*access_type:[[:space:]]*\"([^\"]*)\" ]]; then
                access_type="${BASH_REMATCH[1]}"
                if [ -n "$name" ] && [ -n "$access_type" ]; then
                    log_info "配置 bucket: $name - $access_type"
                    BUCKETS+=("$name:$access_type")
                    name=""
                    access_type=""
                fi
            fi
        done < "$CONFIG_FILE"
    fi

    if [ ${#BUCKETS[@]} -eq 0 ]; then
        log_error "未在配置文件中找到有效的 bucket 配置"
        exit 1
    fi
}

# 等待 MinIO 服务就绪
wait_for_minio() {
    log_info "等待 MinIO 服务启动..."

    for i in {1..30}; do
        if curl -s "$MINIO_ENDPOINT/minio/health/live" > /dev/null 2>&1; then
            log_info "MinIO 服务已就绪"
            return 0
        fi
        sleep 2
    done

    log_error "MinIO 服务启动超时"
    exit 1
}

# 设置 MinIO 客户端别名
setup_mc() {
    log_info "设置 MinIO 客户端别名..."

    if mc alias set local "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; then
        log_info "MinIO 客户端别名设置成功"
    else
        log_error "MinIO 客户端别名设置失败"
        exit 1
    fi
}

# 创建 bucket
create_buckets() {
    log_info "创建 bucket..."

    for bucket_config in "${BUCKETS[@]}"; do
        bucket=$(echo "$bucket_config" | cut -d':' -f1)
        access_type=$(echo "$bucket_config" | cut -d':' -f2)

        # 检查是否已存在
        if mc ls local/"$bucket" > /dev/null 2>&1; then
            log_info "bucket '$bucket' 已存在，跳过"
            continue
        fi

        # 创建 bucket
        if mc mb local/"$bucket"; then
            log_info "bucket '$bucket' 创建成功"

            # 设置权限
            case "$access_type" in
                "public"|"download")
                    mc anonymous set download local/"$bucket"
                    log_info "设置 bucket '$bucket' 为下载权限"
                    ;;
                "private")
                    mc anonymous set none local/"$bucket"
                    log_info "设置 bucket '$bucket' 为私有权限"
                    ;;
                *)
                    log_error "未知的访问类型: $access_type，跳过权限设置"
                    ;;
            esac
        else
            log_error "bucket '$bucket' 创建失败"
        fi
    done
}

# 主函数
main() {
    log_info "开始 MinIO 初始化..."

    check_config
    check_config_file
    parse_yaml_config
    wait_for_minio
    setup_mc
    create_buckets

    log_info "MinIO 初始化完成!"

    # 显示 bucket 列表
    log_info "当前 bucket:"
    mc ls local/
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
