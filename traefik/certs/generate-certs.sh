#!/bin/bash

# Traefik TLS 证书管理脚本
# 支持本地 mkcert 和 Let's Encrypt 两种证书源

set -e

# 配置
CERT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$CERT_DIR/../.." && pwd)"
CONFIG_DIR="$CERT_DIR/../config"
CERT_TARGET_DIR="$CONFIG_DIR/certs"
TLS_MODE_FILE="$CONFIG_DIR/tls-mode"

# 支持的域名列表
LOCAL_DOMAINS=(
    "*.local"
    "localhost"
    "127.0.0.1"
    "::1"
    "app.local"
    "www.app.local"
    "traefik.local"
    "search.local"
    "portainer.local"
    "logs.local"
    "minio.local"
    "error.local"
    "registry.local"
    "watchtower.local"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 获取当前 TLS 模式
get_tls_mode() {
    if [ -f "$TLS_MODE_FILE" ]; then
        cat "$TLS_MODE_FILE"
    else
        echo "local"
    fi
}

# 设置 TLS 模式
set_tls_mode() {
    local mode="$1"
    echo "$mode" > "$TLS_MODE_FILE"
    log_success "TLS 模式已设置为: $mode"
}

# 显示当前 TLS 模式
show_tls_mode() {
    local current_mode=$(get_tls_mode)
    echo ""
    log_info "当前 TLS 模式: $current_mode"
    case "$current_mode" in
        local)
            echo "   🏠 使用本地 mkcert 证书"
            echo "   🌐 适用于: 开发环境"
            echo "   📍 域名: *.local"
            ;;
        letsencrypt)
            echo "   🔐 使用 Let's Encrypt 证书"
            echo "   🌐 适用于: 生产环境"
            echo "   📍 域名: 真实域名"
            ;;
    esac
}

# 检查 mkcert 是否安装
check_mkcert() {
    if ! command -v mkcert >/dev/null 2>&1; then
        log_error "mkcert 未安装"
        echo "请先安装 mkcert:"
        echo "  macOS: brew install mkcert"
        exit 1
    fi
}

# 安装本地 CA
install_local_ca() {
    if [ ! -f "$(mkcert -CAROOT)/rootCA.pem" ]; then
        log_info "安装本地 CA..."
        mkcert -install
        log_success "本地 CA 已安装"
    else
        log_success "本地 CA 已存在"
    fi
}

# 创建目标目录
create_target_dirs() {
    mkdir -p "$CERT_TARGET_DIR"
    log_success "证书目录已创建: $CERT_TARGET_DIR"
}

# 生成本地证书
generate_local_certificates() {
    log_info "生成本地证书..."
    cd "$CERT_DIR"
    mkcert "${LOCAL_DOMAINS[@]}"

    # 重命名证书文件
    local cert_file=$(ls | grep -E ".*\.pem$" | grep -v key | head -1)
    local key_file=$(ls | grep -E ".*-key\.pem$" | head -1)

    if [ -n "$cert_file" ] && [ -n "$key_file" ]; then
        mv "$cert_file" "localhost.crt"
        mv "$key_file" "localhost.key"
        log_success "本地证书文件已生成"
    else
        log_error "无法找到生成的证书文件"
        exit 1
    fi
}

# 复制证书到 Traefik 配置目录
copy_certificates() {
    log_info "复制证书到 Traefik 配置目录..."
    cp "$CERT_DIR/localhost.crt" "$CERT_TARGET_DIR/"
    cp "$CERT_DIR/localhost.key" "$CERT_TARGET_DIR/"
    chmod 644 "$CERT_TARGET_DIR/localhost.crt"
    chmod 600 "$CERT_TARGET_DIR/localhost.key"
    log_success "证书已复制到: $CERT_TARGET_DIR"
}

# 清理旧的证书文件
cleanup_old_certs() {
    log_info "清理旧的证书文件..."
    rm -f "$CERT_DIR/ca.crt" "$CERT_DIR/ca.key" "$CERT_DIR/openssl.cnf" "$CERT_DIR/"*.pem
    log_success "旧证书文件已清理"
}

# 重启 Traefik 服务
restart_traefik() {
    log_info "重启 Traefik 服务..."
    if docker-compose ps traefik >/dev/null 2>&1; then
        cd "$PROJECT_ROOT"
        docker-compose restart traefik && log_success "Traefik 服务已重启" || log_warning "Traefik 重启失败"
    else
        log_warning "Traefik 容器未运行"
    fi
}

# 验证证书配置
verify_certificates() {
    log_info "验证证书配置..."
    if [ -f "$CERT_TARGET_DIR/localhost.crt" ] && [ -f "$CERT_TARGET_DIR/localhost.key" ]; then
        log_success "证书文件存在且可访问"
    else
        log_warning "证书文件不存在"
    fi
}

# 显示证书信息
show_cert_info() {
    local current_mode=$(get_tls_mode)

    echo ""
    log_info "证书信息 (模式: $current_mode):"

    case "$current_mode" in
        local)
            echo "   📄 证书文件: $CERT_TARGET_DIR/localhost.crt"
            echo "   🔑 私钥文件: $CERT_TARGET_DIR/localhost.key"
            echo "   🏠 CA 根证书: $(mkcert -CAROOT)/rootCA.pem"

            if command -v openssl >/dev/null 2>&1 && [ -f "$CERT_TARGET_DIR/localhost.crt" ]; then
                echo "📋 证书包含的域名:"
                openssl x509 -in "$CERT_TARGET_DIR/localhost.crt" -noout -text | \
                    grep -A1 "Subject Alternative Name" | tail -1 | \
                    tr ',' '\n' | sed 's/DNS://g' | sed 's/^/   - /'
            fi
            ;;
        letsencrypt)
            echo "   🔐 Let's Encrypt 证书"
            echo "   💾 存储文件: $CONFIG_DIR/acme.json"
            echo "   🌐 适用域名: 配置的真实域名"
            echo ""
            echo "💡 提示:"
            echo "   - 需要在 Traefik 路由中配置 certResolver: letsencrypt"
            echo "   - 确保域名 DNS 解析正确"
            echo "   - 需要公网可访问的服务器"
            ;;
    esac
}

# 测试 HTTPS 连接
test_https() {
    local current_mode=$(get_tls_mode)
    local test_urls=()

    case "$current_mode" in
        local)
            test_urls=(
                "https://app.local"
                "https://traefik.local"
                "https://logs.local"
                "https://minio.local"
                "https://search.local"
                "https://portainer.local"
            )
            ;;
        letsencrypt)
            log_warning "Let's Encrypt 模式需要配置真实域名进行测试"
            return
            ;;
    esac

    log_info "测试 HTTPS 连接..."
    for url in "${test_urls[@]}"; do
        if curl -k -s -o /dev/null -w "%{http_code}" "$url" | grep -q "2[0-9][0-9]\|3[0-9][0-9]"; then
            log_success "$url - 连接正常"
        else
            log_warning "$url - 连接失败"
        fi
    done
}

# 切换到本地模式
switch_to_local() {
    log_info "切换到本地 TLS 模式..."
    set_tls_mode "local"
    check_mkcert
    install_local_ca
    cleanup_old_certs
    create_target_dirs
    generate_local_certificates
    copy_certificates
    show_cert_info
}

# 切换到 Let's Encrypt 模式
switch_to_letsencrypt() {
    log_info "切换到 Let's Encrypt TLS 模式..."
    set_tls_mode "letsencrypt"

    # 创建 ACME 存储文件
    if [ ! -f "$CONFIG_DIR/acme.json" ]; then
        touch "$CONFIG_DIR/acme.json"
        chmod 600 "$CONFIG_DIR/acme.json"
        log_success "ACME 存储文件已创建: $CONFIG_DIR/acme.json"
    fi

    echo ""
    log_info "Let's Encrypt 配置说明:"
    echo "   1. 在 Traefik 路由中配置:"
    echo "      tls:"
    echo "        certResolver: letsencrypt"
    echo "   2. 确保域名 DNS 解析正确"
    echo "   3. 服务器需要公网可访问"
    echo "   4. 在 traefik.yml 中配置正确的邮箱和域名"

    show_cert_info
}

# 显示使用说明
show_usage() {
    echo "🚀 Traefik TLS 证书管理脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "TLS 模式管理:"
    echo "  -m, --mode [local|letsencrypt]  切换 TLS 模式"
    echo "  -s, --show-mode                 显示当前 TLS 模式"
    echo ""
    echo "证书操作:"
    echo "  -g, --generate                  生成证书（基于当前模式）"
    echo "  -gx, --generate-full            生成证书并重启 Traefik"
    echo "  -c, --cleanup                   清理旧的证书文件"
    echo "  -i, --info                      显示证书信息"
    echo "  -t, --test                      测试 HTTPS 连接"
    echo "  -r, --restart                   重启 Traefik 服务"
    echo "  -h, --help                      显示此帮助信息"
    echo ""
    echo "模式说明:"
    echo "  🏠 local        - 本地开发环境，使用 mkcert"
    echo "  🔐 letsencrypt  - 生产环境，使用 Let's Encrypt"
}

# 主函数
main() {
    local full_setup=false

    case "${1:-}" in
        -m|--mode)
            case "${2:-}" in
                local)
                    switch_to_local
                    ;;
                letsencrypt)
                    switch_to_letsencrypt
                    ;;
                *)
                    log_error "无效的 TLS 模式: $2"
                    echo "可用模式: local, letsencrypt"
                    exit 1
                    ;;
            esac
            ;;
        -s|--show-mode)
            show_tls_mode
            ;;
        -g|--generate|"")
            local current_mode=$(get_tls_mode)
            case "$current_mode" in
                local)
                    check_mkcert
                    install_local_ca
                    cleanup_old_certs
                    create_target_dirs
                    generate_local_certificates
                    copy_certificates
                    show_cert_info
                    ;;
                letsencrypt)
                    log_info "Let's Encrypt 模式无需手动生成证书"
                    show_cert_info
                    ;;
            esac
            ;;
        -gx|--generate-full)
            full_setup=true
            local current_mode=$(get_tls_mode)
            case "$current_mode" in
                local)
                    check_mkcert
                    install_local_ca
                    cleanup_old_certs
                    create_target_dirs
                    generate_local_certificates
                    copy_certificates
                    restart_traefik
                    sleep 2
                    verify_certificates
                    show_cert_info
                    test_https
                    ;;
                letsencrypt)
                    log_info "Let's Encrypt 模式证书自动管理"
                    restart_traefik
                    show_cert_info
                    ;;
            esac
            ;;
        -c|--cleanup)
            cleanup_old_certs
            ;;
        -i|--info)
            show_cert_info
            ;;
        -t|--test)
            test_https
            ;;
        -r|--restart)
            restart_traefik
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac

    # 显示完成信息
    if [ "$full_setup" = true ]; then
        local current_mode=$(get_tls_mode)
        echo ""
        log_success "🎉 完整证书设置完成！ (模式: $current_mode)"

        case "$current_mode" in
            local)
                echo "📋 现在可以访问以下 HTTPS 服务:"
                echo "   🌐 https://app.local"
                echo "   📊 https://traefik.local"
                ;;
            letsencrypt)
                echo "📋 Let's Encrypt 已配置完成"
                echo "💡 提示: 在路由中配置 certResolver: letsencrypt 启用自动证书"
                ;;
        esac
    elif [ "${1:-}" != "-s" ] && [ "${1:-}" != "-m" ]; then
        echo ""
        local current_mode=$(get_tls_mode)
        log_success "🎉 操作完成！ (当前模式: $current_mode)"
    fi
}

# 运行主函数
main "$@"
# 生成证书并重启 Traefik
# ./traefik/certs/generate-certs.sh --generate-full

# 其他可用命令
# ./traefik/certs/generate-certs.sh --help