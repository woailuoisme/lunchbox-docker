#!/bin/bash

# Certbot 健康检查脚本
# 用于监控证书状态和容器运行状况

set -e

# 默认域名
DOMAIN=${DOMAIN:-haoxiaoguai.xyz}
HEALTHCHECK_PORT=${HEALTHCHECK_PORT:-8888}

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# 检查证书是否存在
check_certificate_exists() {
    local cert_dir="/etc/letsencrypt/live/$DOMAIN"

    if [ ! -d "$cert_dir" ]; then
        log "ERROR: 证书目录不存在: $cert_dir"
        return 1
    fi

    # 检查关键证书文件
    local cert_files=("cert.pem" "privkey.pem" "chain.pem" "fullchain.pem")
    for file in "${cert_files[@]}"; do
        if [ ! -f "$cert_dir/$file" ]; then
            log "ERROR: 证书文件缺失: $cert_dir/$file"
            return 1
        fi
    done

    log "INFO: 证书文件检查通过"
    return 0
}

# 检查证书有效期
check_certificate_validity() {
    local cert_file="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

    if [ ! -f "$cert_file" ]; then
        log "ERROR: 证书文件不存在: $cert_file"
        return 1
    fi

    # 获取证书过期时间
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)

    if [ $? -ne 0 ]; then
        log "ERROR: 无法读取证书信息"
        return 1
    fi

    # 转换为时间戳
    local expiry_timestamp
    expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp
    current_timestamp=$(date +%s)

    # 计算剩余天数
    local days_remaining
    days_remaining=$(( (expiry_timestamp - current_timestamp) / 86400 ))

    if [ $days_remaining -lt 0 ]; then
        log "ERROR: 证书已过期"
        return 1
    elif [ $days_remaining -lt 7 ]; then
        log "WARNING: 证书将在 $days_remaining 天后过期"
        # 证书即将过期，但仍在有效期内，返回健康状态
        return 0
    else
        log "INFO: 证书有效，剩余 $days_remaining 天"
        return 0
    fi
}

# 检查续签状态
check_renewal_status() {
    local renewal_config="/etc/letsencrypt/renewal/$DOMAIN.conf"

    if [ ! -f "$renewal_config" ]; then
        log "WARNING: 续签配置文件不存在: $renewal_config"
        return 0  # 首次运行可能没有续签配置
    fi

    # 检查最后一次续签时间
    local last_renewal
    last_renewal=$(grep -oP 'last_renewal_time\s*=\s*\K\d+' "$renewal_config" 2>/dev/null || echo "0")

    if [ "$last_renewal" -gt 0 ]; then
        local current_time
        current_time=$(date +%s)
        local days_since_renewal
        days_since_renewal=$(( (current_time - last_renewal) / 86400 ))

        if [ $days_since_renewal -gt 90 ]; then
            log "WARNING: 距离上次续签已超过 $days_since_renewal 天"
        else
            log "INFO: 距离上次续签 $days_since_renewal 天"
        fi
    fi

    return 0
}

# 检查磁盘空间
check_disk_space() {
    local letsencrypt_dir="/etc/letsencrypt"
    local available_space
    available_space=$(df "$letsencrypt_dir" | awk 'NR==2 {print $4}')

    # 如果可用空间小于 100MB，发出警告
    if [ "$available_space" -lt 102400 ]; then
        log "WARNING: 磁盘空间不足，可用空间: ${available_space}KB"
        return 1
    fi

    log "INFO: 磁盘空间充足: ${available_space}KB"
    return 0
}

# HTTP 健康检查端点（可选）
start_healthcheck_server() {
    if [ "$1" = "server" ]; then
        log "INFO: 启动健康检查服务器，端口: $HEALTHCHECK_PORT"

        while true; do
            {
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                echo '{"status": "healthy", "timestamp": "'$(date -Iseconds)'", "service": "certbot"}'
            } | nc -l -p "$HEALTHCHECK_PORT" -q 1
        done
    fi
}

# 主健康检查函数
main_healthcheck() {
    local exit_code=0

    log "INFO: 开始健康检查"

    # 执行各项检查
    if ! check_certificate_exists; then
        exit_code=1
    fi

    if ! check_certificate_validity; then
        exit_code=1
    fi

    if ! check_renewal_status; then
        # 续签状态检查失败不影响整体健康状态
        :
    fi

    if ! check_disk_space; then
        # 磁盘空间警告不影响整体健康状态
        :
    fi

    if [ $exit_code -eq 0 ]; then
        log "INFO: 健康检查通过"
        echo "HEALTHY"
    else
        log "ERROR: 健康检查失败"
        echo "UNHEALTHY"
    fi

    return $exit_code
}

# 处理命令行参数
case "${1:-}" in
    "server")
        start_healthcheck_server "$@"
        ;;
    "check")
        main_healthcheck
        exit $?
        ;;
    *)
        echo "用法: $0 {check|server}"
        echo "  check  - 执行一次性健康检查"
        echo "  server - 启动健康检查HTTP服务器"
        exit 1
        ;;
esac
