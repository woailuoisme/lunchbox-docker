#!/bin/bash

# HTTP/3 启用脚本
# 为所有 Nginx 站点配置启用 HTTP/3 (QUIC) 支持

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NGINX_SITES_DIR="$PROJECT_ROOT/nginx/sites"
NGINX_SNIPPETS_DIR="$PROJECT_ROOT/nginx/snippets"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Nginx 是否支持 HTTP/3
check_http3_support() {
    log_info "检查 Nginx HTTP/3 支持..."

    if docker compose exec -T nginx nginx -V 2>&1 | grep -q "http_v3_module"; then
        log_success "Nginx 支持 HTTP/3"
        return 0
    else
        log_error "Nginx 不支持 HTTP/3，请使用编译了 --with-http_v3_module 的 Nginx 版本"
        return 1
    fi
}

# 检查 HTTP/3 配置片段是否存在
check_http3_config() {
    if [[ ! -f "$NGINX_SNIPPETS_DIR/http3.conf" ]]; then
        log_error "HTTP/3 配置片段不存在: $NGINX_SNIPPETS_DIR/http3.conf"
        log_info "请先创建 HTTP/3 配置片段"
        return 1
    fi
    return 0
}

# 为单个站点启用 HTTP/3
enable_http3_for_site() {
    local site_file="$1"
    local site_name=$(basename "$site_file")

    log_info "处理站点: $site_name"

    # 检查是否已经是 HTTPS 站点
    if ! grep -q "listen 443 ssl" "$site_file"; then
        log_warning "站点 $site_name 不是 HTTPS 站点，跳过"
        return 0
    fi

    # 检查是否已经启用了 HTTP/3
    if grep -q "include.*http3.conf" "$site_file"; then
        log_info "站点 $site_name 已经启用了 HTTP/3"
        return 0
    fi

    # 在 common-server.conf 包含后添加 http3.conf 包含
    if grep -q "include.*common-server.conf" "$site_file"; then
        # 使用 sed 在 common-server.conf 包含后添加 http3.conf 包含
        sed -i '/include.*common-server.conf;/a\    include /etc/nginx/snippets/http3.conf;' "$site_file"
        log_success "为站点 $site_name 启用 HTTP/3"
    else
        log_warning "站点 $site_name 没有包含 common-server.conf，跳过"
    fi
}

# 为所有站点启用 HTTP/3
enable_http3_for_all_sites() {
    log_info "开始为所有站点启用 HTTP/3..."

    local site_files=("$NGINX_SITES_DIR"/*.conf)
    local enabled_count=0
    local skipped_count=0

    for site_file in "${site_files[@]}"; do
        if [[ -f "$site_file" ]]; then
            if enable_http3_for_site "$site_file"; then
                ((enabled_count++))
            else
                ((skipped_count++))
            fi
        fi
    done

    log_success "完成！启用了 $enabled_count 个站点，跳过了 $skipped_count 个站点"
}

# 验证 Nginx 配置
validate_nginx_config() {
    log_info "验证 Nginx 配置..."

    if docker compose exec -T nginx nginx -t; then
        log_success "Nginx 配置验证通过"
        return 0
    else
        log_error "Nginx 配置验证失败"
        return 1
    fi
}

# 重新加载 Nginx 配置
reload_nginx() {
    log_info "重新加载 Nginx 配置..."

    if docker compose exec -T nginx nginx -s reload; then
        log_success "Nginx 配置重新加载成功"
        return 0
    else
        log_error "Nginx 配置重新加载失败"
        return 1
    fi
}

# 检查 HTTP/3 是否正在运行
check_http3_running() {
    log_info "检查 HTTP/3 运行状态..."

    if docker compose exec nginx netstat -tulpn 2>/dev/null | grep -q ":443.*udp"; then
        log_success "HTTP/3 (QUIC) 正在 UDP 443 端口运行"
        return 0
    else
        log_error "HTTP/3 未在 UDP 443 端口运行"
        return 1
    fi
}

# 显示使用帮助
show_usage() {
    cat << EOF
HTTP/3 启用脚本

用法: $0 [选项]

选项:
    -h, --help      显示此帮助信息
    -c, --check     仅检查 HTTP/3 支持，不进行修改
    -d, --dry-run   干运行，显示将要修改的内容但不实际修改
    -v, --validate  仅验证配置，不重新加载
    -s, --status    检查 HTTP/3 运行状态

示例:
    $0              为所有站点启用 HTTP/3 并重新加载配置
    $0 --check      仅检查 HTTP/3 支持
    $0 --dry-run    显示将要修改的站点但不实际修改
    $0 --status     检查 HTTP/3 运行状态

EOF
}

# 干运行模式
dry_run() {
    log_info "干运行模式 - 显示将要修改的站点"

    local site_files=("$NGINX_SITES_DIR"/*.conf)

    for site_file in "${site_files[@]}"; do
        if [[ -f "$site_file" ]]; then
            local site_name=$(basename "$site_file")

            if grep -q "listen 443 ssl" "$site_file" && ! grep -q "include.*http3.conf" "$site_file"; then
                if grep -q "include.*common-server.conf" "$site_file"; then
                    log_success "将会启用: $site_name"
                else
                    log_warning "无法启用 (缺少 common-server.conf): $site_name"
                fi
            else
                log_info "跳过: $site_name"
            fi
        fi
    done
}

main() {
    local action="enable"
    local validate_only=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--check)
                action="check"
                ;;
            -d|--dry-run)
                action="dry-run"
                ;;
            -v|--validate)
                validate_only=true
                ;;
            -s|--status)
                action="status"
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done

    case $action in
        check)
            check_http3_support
            ;;
        dry-run)
            dry_run
            ;;
        status)
            check_http3_running
            ;;
        enable)
            # 检查前置条件
            if ! check_http3_support; then
                exit 1
            fi

            if ! check_http3_config; then
                exit 1
            fi

            # 启用 HTTP/3
            enable_http3_for_all_sites

            # 验证配置
            if ! validate_nginx_config; then
                exit 1
            fi

            # 如果不只是验证，则重新加载配置
            if [[ "$validate_only" != "true" ]]; then
                if reload_nginx; then
                    check_http3_running
                else
                    exit 1
                fi
            fi
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
