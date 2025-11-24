#!/bin/sh

# Caddy 启动脚本
# 自动格式化所有 Caddy 配置文件并启动服务

set -e

# 日志前缀定义
INFO_PREFIX="[INFO]"
SUCCESS_PREFIX="[SUCCESS]"
WARNING_PREFIX="[WARNING]"
ERROR_PREFIX="[ERROR]"

# 日志函数
log_info() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo "[${timestamp}] ${INFO_PREFIX} $1"
}

log_success() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo "[${timestamp}] ${SUCCESS_PREFIX} $1"
}

log_warning() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo "[${timestamp}] ${WARNING_PREFIX} $1"
}

log_error() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
    echo "[${timestamp}] ${ERROR_PREFIX} $1"
}

# 格式化 Caddy 配置文件
format_caddy_configs() {
    log_info "开始格式化 Caddy 配置文件..."

    config_files="
        /etc/caddy/Caddyfile
        $(find /etc/caddy/snippets -name "*.conf" 2>/dev/null || true)
        $(find /etc/caddy/templates -name "*.conf" 2>/dev/null || true)
    "

    formatted_count=0
    error_count=0

    for config_file in $config_files; do
        if [ -f "$config_file" ]; then
            log_info "格式化文件: $config_file"
            if caddy fmt --overwrite "$config_file" 2>/dev/null; then
                log_success "成功格式化: $config_file"
                formatted_count=$((formatted_count + 1))
            else
                log_warning "格式化失败或文件已是最新: $config_file"
                error_count=$((error_count + 1))
            fi
        else
            log_warning "配置文件不存在: $config_file"
        fi
    done

    log_success "格式化完成: 成功 $formatted_count 个文件, 失败/跳过 $error_count 个文件"
}

# 验证 Caddy 配置
validate_caddy_config() {
    log_info "验证 Caddy 配置..."

    if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
        log_success "Caddy 配置验证通过"
        return 0
    else
        log_error "Caddy 配置验证失败"
        return 1
    fi
}

# 显示 Caddy 模块信息
show_caddy_modules() {
    log_info "已安装的 Caddy 模块:"
    caddy list-modules | grep -E "(Standard modules|Non-standard modules|Unknown modules)" || true
}

# 显示启动配置
show_startup_config() {
    log_info "=== Caddy 启动配置 ==="
    log_info "配置文件: /etc/caddy/Caddyfile"
    log_info "适配器: caddyfile"
    log_info "工作目录: $(pwd)"
    log_info "用户: $(whoami)"
    log_info "=================================="
}

# 主函数
main() {
    log_info "启动 Caddy 服务..."

    # 显示启动配置
    show_startup_config

    # 格式化配置文件
    format_caddy_configs

    # 验证配置
    if ! validate_caddy_config; then
        log_error "配置验证失败，退出启动"
        exit 1
    fi

    # 显示模块信息
    show_caddy_modules

    log_success "Caddy 服务启动准备完成"
    log_info "启动命令: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"

    # 启动 Caddy
    exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
}

# 捕获退出信号
trap 'log_warning "接收到终止信号，正在停止 Caddy..."; exit 0' SIGTERM SIGINT

# 运行主函数
main "$@"
