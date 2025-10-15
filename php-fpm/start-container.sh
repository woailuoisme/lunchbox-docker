#!/usr/bin/env bash
set -euo pipefail

# 全局变量
readonly WWWUSER=${WWWUSER:-33}
readonly WWWGROUP=${WWWGROUP:-33}
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-true}

log() {
    echo "[$(date '+%H:%M:%S')] $*" >&2
}
# 用户切换执行函数
exec_as_user() {
    if [ "$(id -u)" = "0" ]; then
        exec "$@"
    else
        exec gosu www-data "$@"
    fi
}

# 安全执行函数，避免ptrace问题
safe_exec() {
    # 使用exec -c来清除环境变量，减少潜在冲突
    if [ "$(id -u)" = "0" ]; then
        exec -c "$@"
    else
        exec -c gosu www-data "$@"
    fi
}

# 检查依赖和设置权限
setup_environment() {
    # 检查依赖
    command -v gosu >/dev/null || { log "ERROR: gosu not found"; exit 1; }

    # 确保用户和组ID一致性
    ensure_user_consistency

    # 确保错误日志文件存在（Dockerfile已创建目录并设置权限）
        if [ "$(id -u)" = "0" ]; then
            local log_files=(/var/log/php-fpm/error.log /var/log/php-fpm/slow.log)

            for file in "${log_files[@]}"; do
                touch "$file" 2>/dev/null || true
                chown www-data:www-data "$file" 2>/dev/null || true
                chmod 666 "$file" 2>/dev/null || true
            done
        fi

        # 确保SSH目录权限正确（如果挂载了SSH密钥）
        if [ -d "/home/www-data/.ssh" ]; then
            log "设置SSH目录权限..."
            chown -R www-data:www-data /home/www-data/.ssh 2>/dev/null || true
            chmod 700 /home/www-data/.ssh 2>/dev/null || true

            # 设置所有SSH文件的正确权限
            if [ -f "/home/www-data/.ssh/known_hosts" ]; then
                chown www-data:www-data /home/www-data/.ssh/known_hosts 2>/dev/null || true
                chmod 644 /home/www-data/.ssh/known_hosts 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/id_ed25519" ]; then
                chown www-data:www-data /home/www-data/.ssh/id_ed25519 2>/dev/null || true
                chmod 600 /home/www-data/.ssh/id_ed25519 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/id_ed25519.pub" ]; then
                chown www-data:www-data /home/www-data/.ssh/id_ed25519.pub 2>/dev/null || true
                chmod 644 /home/www-data/.ssh/id_ed25519.pub 2>/dev/null || true
            fi
            if [ -f "/home/www-data/.ssh/config" ]; then
                chown www-data:www-data /home/www-data/.ssh/config 2>/dev/null || true
                chmod 600 /home/www-data/.ssh/config 2>/dev/null || true
            fi
        fi

    log "环境设置完成"
}

# 确保用户和组ID一致性
ensure_user_consistency() {
    # 检查用户是否存在
    if id -u www-data >/dev/null 2>&1; then
        # 检查现有用户的UID/GID是否匹配环境变量
        local current_uid=$(id -u www-data)
        local current_gid=$(id -g www-data)

        if [ "$current_uid" != "$WWWUSER" ] || [ "$current_gid" != "$WWWGROUP" ]; then
            log "WARNING: www-data 用户ID不匹配 (当前: UID=$current_uid GID=$current_gid, 期望: UID=$WWWUSER GID=$WWWGROUP)"
            log "删除现有用户并重新创建以匹配配置..."

            # 删除现有用户和组
            deluser www-data 2>/dev/null || true
            delgroup www-data 2>/dev/null || true

            # 创建新的用户和组 (Alpine Linux 参数格式)
            addgroup -g "$WWWGROUP" www-data 2>/dev/null || true
            adduser -u "$WWWUSER" -D -H -G www-data www-data 2>/dev/null || true

            # 验证用户创建是否成功
            if id -u www-data >/dev/null 2>&1; then
                local new_uid=$(id -u www-data)
                local new_gid=$(id -g www-data)
                log "已重新创建 www-data 用户 (UID: $new_uid, GID: $new_gid)"
            else
                log "ERROR: 无法创建 www-data 用户"
                exit 1
            fi
        else
            log "www-data 用户ID匹配 (UID: $current_uid, GID: $current_gid)"
        fi
    else
        # 用户不存在，直接创建
        log "创建 www-data 用户 (UID: $WWWUSER, GID: $WWWGROUP)"
        addgroup -g "$WWWGROUP" www-data 2>/dev/null || true
        adduser -u "$WWWUSER" -D -H -G www-data www-data 2>/dev/null || true

        # 验证用户创建是否成功
        if ! id -u www-data >/dev/null 2>&1; then
            log "ERROR: 无法创建 www-data 用户"
            exit 1
        fi
    fi
}

# 验证配置文件
validate_configs() {
    log "开始验证配置..."

    # 验证 PHP-FPM 配置
    if ! php-fpm -t >/dev/null 2>&1; then
        log "ERROR: PHP-FPM 配置无效"
        php-fpm -t
        exit 1
    fi

    log "配置验证完成"
}
# 优雅关闭
graceful_shutdown() {
    log "正在关闭..."
    pkill -TERM php-fpm 2>/dev/null || true
    exit 0
}

# 启动 PHP-FPM
start_php_fpm() {
    log "启动 PHP-FPM..."
    # 如果以root用户运行，使用gosu切换到www-data用户启动PHP-FPM
    if [ "$(id -u)" = "0" ]; then
        safe_exec php-fpm --nodaemonize
    else
        # 非root用户运行时，直接启动PHP-FPM（已经是www-data用户）
        php-fpm --nodaemonize
    fi
}

# 启动 supervisord（后台进程）
start_supervisord_background() {
    log "启动 supervisord（后台模式）..."

    # 如果以root用户运行，使用gosu切换到www-data用户启动supervisord
    if [ "$(id -u)" = "0" ]; then
        safe_exec supervisord -c /usr/local/etc/supervisord.conf &
    else
        # 非root用户运行时，直接启动supervisord（已经是www-data用户）
        supervisord -c /usr/local/etc/supervisord.conf &
    fi

    local supervisord_pid=$!

    # 等待supervisord启动完成
    sleep 2

    # 检查supervisord是否正常运行
    if kill -0 "$supervisord_pid" 2>/dev/null; then
        log "supervisord 启动成功，PID: $supervisord_pid"
        return 0
    else
        log "WARNING: supervisord 启动失败"
        return 1
    fi
}

## 切换到 www-data 用户（或容器内实际使用的用户）
#USER www-data
#
## 创建 .ssh 目录并添加 GitHub 主机指纹
#RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
#    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
#    chmod 644 ~/.ssh/known_hosts

# 检查是否有supervisord配置
has_supervisord_config() {
    # 检查是否有supervisord配置文件
    if [ -f "/usr/local/etc/supervisord.conf" ] && [ -d "/usr/local/etc/supervisord.d" ]; then
        local config_count=$(find /usr/local/etc/supervisord.d -name "*.conf" 2>/dev/null | wc -l)
        if [ "$config_count" -gt 0 ]; then
            return 0
        fi
    fi
    return 1
}

# 主函数
main() {
    log "容器启动中..."
    trap 'graceful_shutdown' TERM INT QUIT

    setup_environment
    validate_configs

    # 处理命令行参数
    if [ $# -gt 0 ]; then
        log "执行自定义命令: $*"
        safe_exec "$@"
    fi

    # 检查是否有supervisord配置，如果ENABLE_SUPERVISOR为true且有配置则在后台启动supervisord
    if [ "$ENABLE_SUPERVISOR" = "true" ] && has_supervisord_config; then
        log "启动supervisord管理后台进程..."
        start_supervisord_background
    fi

    # 前台启动 PHP-FPM（主进程）
    log "启动PHP-FPM服务..."
    start_php_fpm
}

main "$@"
