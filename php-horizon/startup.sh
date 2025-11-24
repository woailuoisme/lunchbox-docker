#!/bin/bash

# Laravel Horizon 启动脚本
# 直接运行 php artisan horizon 命令

# 健康检查函数 - 检测 Horizon 进程是否运行
health_check() {
    # 检查 Horizon 进程是否在运行
    if pgrep -f "php.*artisan.*horizon" > /dev/null; then
        return 0
    else
        return 1
    fi
}

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
readonly APP_PATH=${APP_PATH:-/var/www/lunchbox}
readonly APP_ENV=${APP_ENV:-docker}

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

# 检查 Horizon 配置
check_horizon_config() {
    log_info "检查 Laravel Horizon 配置..."

    # 检查 horizon 配置文件
    if [ ! -f "${APP_PATH}/config/horizon.php" ]; then
        log_warning "Horizon 配置文件不存在，将使用默认配置"
    else
        log_success "Horizon 配置文件存在"
    fi

    # 检查是否安装了 horizon
    log_info "执行 Horizon 状态检查..."
    if ! php "${APP_PATH}/artisan" horizon:status > /dev/null 2>&1; then
        log_error "Laravel Horizon 未正确安装或配置"
        log_info "请确保已运行: composer require laravel/horizon"
        log_info "检查 vendor 目录中是否有 horizon 包..."
        if [ -d "${APP_PATH}/vendor/laravel/horizon" ]; then
            log_success "Horizon 包已安装"
            log_info "检查 Horizon 配置文件..."
            if [ -f "${APP_PATH}/config/horizon.php" ]; then
                log_success "Horizon 配置文件存在"
                log_info "检查 artisan 命令是否可用..."
                if php "${APP_PATH}/artisan" --version > /dev/null 2>&1; then
                    log_success "artisan 命令可用"
                    log_info "尝试手动执行 horizon:status 命令获取详细错误..."
                    php "${APP_PATH}/artisan" horizon:status
                else
                    log_error "artisan 命令不可用"
                fi
            else
                log_error "Horizon 配置文件不存在"
            fi
        else
            log_error "Horizon 包未安装，请运行: composer require laravel/horizon"
        fi
        exit 1
    fi

    log_success "Laravel Horizon 配置检查通过"
}

# 显示启动配置
show_config() {
    log_info "=== Laravel Horizon 启动配置 ==="
    log_info "应用路径: ${APP_PATH}"
    log_info "运行环境: ${APP_ENV}"
    log_info "启动命令: php artisan horizon"
    log_info "=================================="
}

# 启动 Laravel Horizon
start_horizon() {
    log_info "启动 Laravel Horizon..."

    # 切换到应用目录
    cd "${APP_PATH}"
    log_info "切换到应用目录: $(pwd)"

    # 显示 Horizon 状态
    log_info "检查当前 Horizon 状态..."
    php artisan horizon:status

    # 启动 Horizon
    log_info "执行命令: php artisan horizon"
    log_info "Horizon 将在前台运行，按 Ctrl+C 停止"

    # 在前台启动 Horizon
    exec php artisan horizon
}

# 健康检查入口点
if [ "$1" = "healthcheck" ]; then
    if health_check; then
        echo "Horizon is running"
        exit 0
    else
        echo "Horizon is not running"
        exit 1
    fi
fi

# 主函数
main() {
    log_info "启动 Laravel Horizon 服务..."

    # 显示配置
    show_config

    # 检查应用目录
    check_app_directory

    # 检查 Horizon 配置
    check_horizon_config

    # 启动 Horizon
    start_horizon
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Horizon..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
