#!/bin/bash

# Laravel Octane with FrankenPHP 启动脚本
# 使用环境变量配置启动参数

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${BLUE}[${timestamp}] [INFO]${NC} $1"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} $1"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${YELLOW}[${timestamp}] [WARNING]${NC} $1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo -e "${RED}[${timestamp}] [ERROR]${NC} $1"
}

# 全局变量
readonly WWWUSER=${WWWUSER:-33}
readonly WWWGROUP=${WWWGROUP:-33}
readonly ENABLE_SUPERVISOR=${ENABLE_SUPERVISOR:-true}
# 安全执行函数，避免ptrace问题
safe_exec() {
    # 使用exec -c来清除环境变量，减少潜在冲突
    if [ "$(id -u)" = "0" ]; then
        exec -c "$@"
    else
        exec -c gosu www-data "$@"
    fi
}

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

# 启动 supervisord（后台进程）
start_supervisord_background() {
    log_info "启动 supervisord（后台模式）..."

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
        log_info "supervisord 启动成功，PID: $supervisord_pid"
        return 0
    else
        log_info "WARNING: supervisord 启动失败"
        return 1
    fi
}

# 显示启动配置
show_config() {
    log_info "=== Laravel Octane 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "服务器: frankenphp"
    log_info "端口: ${APP_PORT}"
    log_info "监听地址: ${OCTANE_HOST}"
    log_info "工作进程数: ${OCTANE_WORKERS}"
    log_info "管理端口: ${OCTANE_ADMIN_PORT}"
    log_info "最大请求数: ${OCTANE_MAX_REQUESTS}"
    log_info "文件监听: ${WATCH}"
    log_info "网络轮询: ${OCTANE_POLL}"
    log_info "HTTPS: ${OCTANE_HTTPS}"
    log_info "HTTP重定向: ${OCTANE_HTTP_REDIRECT}"
    log_info "日志级别: ${OCTANE_LOG_LEVEL}"
    log_info "================================="
}

# 检查应用目录
check_app_directory() {
    if [ ! -d "${APP_PATH}" ]; then
        log_error "应用目录不存在: ${APP_PATH}"
        exit 1
    fi

    if [ ! -f "${APP_PATH}/artisan" ]; then
        log_error "artisan 文件不存在: ${APP_PATH}/artisan"
        exit 1
    fi

    log_success "应用目录检查通过"
}

# 构建启动命令字符串（仅用于显示）
build_start_command_display() {
    local command="php artisan octane:frankenphp"

    # 基本参数
    command="${command} --port=${APP_PORT}"
    command="${command} --host=${OCTANE_HOST}"
    command="${command} --workers=${OCTANE_WORKERS}"
    command="${command} --admin-port=${OCTANE_ADMIN_PORT}"
    command="${command} --max-requests=${OCTANE_MAX_REQUESTS}"
    command="${command} --env=${APP_ENV}"
    command="${command} --log-level=${OCTANE_LOG_LEVEL}"

    # 条件参数
    if [ "${WATCH}" = "true" ]; then
        command="${command} --watch"
        log_info "启用文件监听模式"
    fi

    if [ "${OCTANE_POLL}" = "true" ]; then
        command="${command} --poll"
        log_info "启用网络文件轮询模式"
    fi

    if [ "${OCTANE_HTTPS}" = "true" ]; then
        command="${command} --https"
        log_info "启用 HTTPS/HTTP2/HTTP3"
    fi

    if [ "${OCTANE_HTTP_REDIRECT}" = "true" ]; then
        command="${command} --http-redirect"
        log_info "启用 HTTP 到 HTTPS 重定向"
    fi

    echo "${command}"
}

# 主函数
main() {
    # 检查是否有supervisord配置，如果ENABLE_SUPERVISOR为true且有配置则在后台启动supervisord
    if [ "$ENABLE_SUPERVISOR" = "true" ] && has_supervisord_config; then
          log_info "启动supervisord管理后台进程..."
          start_supervisord_background
    fi
    log_info "启动 Laravel Octane with Franken PHP..."
    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 切换到应用目录
    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"


    # 显示执行的命令
    local display_command=$(build_start_command_display)
    log_info "执行命令: ${display_command}"

    # 执行启动命令（直接在exec中构建，避免变量污染）
    log_info "启用详细日志模式..."
    log_info "在前台模式运行 FrankenPHP..."
    exec php artisan octane:frankenphp \
        --port="${APP_PORT}" \
        --host="${OCTANE_HOST}" \
        --workers="${OCTANE_WORKERS}" \
        --admin-port="${OCTANE_ADMIN_PORT}" \
        --max-requests="${OCTANE_MAX_REQUESTS}" \
        --env="${APP_ENV}" \
        --log-level="${OCTANE_LOG_LEVEL}" \
        $([ "${WATCH}" = "true" ] && echo "--watch") \
        $([ "${OCTANE_POLL}" = "true" ] && echo "--poll") \
        $([ "${OCTANE_HTTPS}" = "true" ] && echo "--https") \
        $([ "${OCTANE_HTTP_REDIRECT}" = "true" ] && echo "--http-redirect")


}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止服务..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
