#!/bin/sh

# 设置错误处理
set -e

# 环境变量默认值
DNS_PROVIDER=${DNS_PROVIDER:-cloudflare}
DOMAIN=${DOMAIN:-example.com}
EMAIL=${EMAIL:-admin@example.com}
RENEW_INTERVAL=${RENEW_INTERVAL:-43200}  # 12小时

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 验证必要的环境变量和文件
validate_config() {
    case $DNS_PROVIDER in
        "cloudflare")
            if [ ! -f "/etc/letsencrypt/cloudflare.ini" ]; then
                log "错误: Cloudflare 凭据文件不存在: /etc/letsencrypt/cloudflare.ini"
                exit 1
            fi
            ;;
        "aliyun")
            if [ ! -f "/etc/letsencrypt/aliyun.ini" ]; then
                log "错误: 阿里云凭据文件不存在: /etc/letsencrypt/aliyun.ini"
                exit 1
            fi
            ;;
        *)
            log "错误: 不支持的 DNS 提供商: $DNS_PROVIDER (支持: cloudflare, aliyun)"
            exit 1
            ;;
    esac
}

# 获取证书函数
obtain_certificate() {
    log "开始为域名 $DOMAIN 申请证书，使用 $DNS_PROVIDER DNS 验证"

    case $DNS_PROVIDER in
        "cloudflare")
            certbot certonly \
                --non-interactive \
                --authenticator dns-cloudflare \
                --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
                --dns-cloudflare-propagation-seconds 60 \
                --email "$EMAIL" \
                --agree-tos \
                --no-eff-email \
                --expand \
                --domains "$DOMAIN" \
                --domains "*.$DOMAIN"
            ;;
        "aliyun")
            certbot certonly \
                --non-interactive \
                --authenticator dns-aliyun \
                --dns-aliyun-credentials /etc/letsencrypt/aliyun.ini \
                --dns-aliyun-propagation-seconds 60 \
                --email "$EMAIL" \
                --agree-tos \
                --no-eff-email \
                --expand \
                --domains "$DOMAIN" \
                --domains "*.$DOMAIN"
            ;;
    esac

    if [ $? -eq 0 ]; then
        log "证书申请成功"
    else
        log "证书申请失败"
        exit 1
    fi
}

# 续签证书函数
renew_certificates() {
    log "检查证书续签"

    # 使用 --quiet 进行静默续签检查
    # 移除已弃用的 --no-self-upgrade 选项（仅适用于 certbot-auto）
    certbot renew --quiet

    if [ $? -eq 0 ]; then
        log "证书续签检查完成"
    else
        log "证书续签失败"
    fi
}

# 主函数
main() {
    log "Certbot 容器启动，DNS 提供商: $DNS_PROVIDER，域名: $DOMAIN"

    # 验证配置
    validate_config

    # 检查是否已有证书
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        log "发现已存在的证书，跳过初始申请"
    else
        # 首次申请证书
        obtain_certificate
    fi

    # 设置信号处理
    trap 'log "收到终止信号，正在退出..."; exit 0' TERM INT

    # 进入续签循环
    log "开始证书自动续签循环，检查间隔: ${RENEW_INTERVAL}秒"

    while true; do
        sleep "$RENEW_INTERVAL" &
        wait $!

        renew_certificates
    done
}

# 调用主函数
main "$@"
