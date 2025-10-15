#!/usr/bin/env bash
set -euo pipefail

# 简化日志函数
log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}

# 确保Nginx缓存目录存在并具有正确的权限
ensure_cache_dirs() {
    local cache_dirs=(
        "/var/cache/nginx"
        "/var/cache/nginx/client_temp"
        "/var/cache/nginx/proxy_temp"
        "/var/cache/nginx/fastcgi_temp"
        "/var/cache/nginx/uwsgi_temp"
        "/var/cache/nginx/scgi_temp"
    )
    
    for dir in "${cache_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
        chown -R www-data:www-data "$dir"
        chmod -R 755 "$dir"
    done
    
    log "确保Nginx缓存目录权限设置完成"
}

# 初始化用户认证
init_auth() {
    if [ -f "/usr/local/bin/init-users.sh" ]; then
        log "初始化Nginx认证用户..."
        /usr/local/bin/init-users.sh || log "WARN: 用户初始化失败，继续启动"
    else
        log "WARN: 用户初始化脚本不存在，跳过认证初始化"
    fi
}

# 初始化服务
init_services() {
    crond -l 2 -b || log "crond启动失败"
    ensure_cache_dirs
    init_auth
    nginx -t >/dev/null 2>&1 || { log "ERROR: nginx配置错误"; nginx -t; exit 1; }
    log "服务初始化完成"
}

init_services

# 测试nginx配置
test_nginx() {
    nginx -t >/dev/null 2>&1 || { log "ERROR: nginx配置测试失败"; nginx -t; exit 1; }
    log "nginx配置测试通过"
}

# 主启动逻辑
test_nginx
log "启动nginx前台模式"
exec nginx
