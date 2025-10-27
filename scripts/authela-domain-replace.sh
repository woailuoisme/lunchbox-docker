#!/bin/bash

# 域名替换脚本
# 用于将配置文件中的指定域名替换为另一个域名，并保持Linux LF换行符格式
# 使用方法: 1. 修改下方变量 2. 运行脚本: ./domain-replace.sh

# 文件路径 - 要进行替换的文件路径
# 支持相对路径或绝对路径
# 相对路径会以脚本所在目录为基准
FILE_PATH="../authelia/configuration.yml"

# ========== 变量配置区域 (用户需要修改这里) ==========
# 源域名 - 要被替换的域名
# 从 Authelia 配置文件中自动获取第一个域名
SOURCE_DOMAIN=$(grep -E "domain: '[^']+'" "$FILE_PATH" 2>/dev/null | head -1 | sed "s/.*domain: '\([^']*\)'.*/\1/" || echo "jso.lo")

# 目标域名 - 替换成的新域名
# 优先从 .env 文件获取，如果没有则使用默认值
TARGET_DOMAIN=$(grep -E "^DOMAIN=" ../.env 2>/dev/null | cut -d'=' -f2 | tr -d '\r\n' || echo "jso.lol")

# ========== 以下代码无需修改 ==========

# 显示域名来源信息
echo "域名配置信息:"
echo "源域名: $SOURCE_DOMAIN (从 Authelia 配置获取)"
echo "目标域名: $TARGET_DOMAIN (从 .env 文件获取)"
echo "---------------------------------------"

# 获取脚本所在的绝对目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 转换FILE_PATH为绝对路径（如果是相对路径）
if [[ ! "$FILE_PATH" = /* ]]; then
    FILE_PATH="$SCRIPT_DIR/$FILE_PATH"
fi

# 检查文件是否存在
check_file_exists() {
    local file_path=$1
    if [ ! -f "$file_path" ]; then
        echo "错误: 文件 $file_path 不存在"
        echo "请检查配置的FILE_PATH变量是否正确"
        exit 1
    fi
}

# 检查并转换文件为LF换行符格式
ensure_lf_format() {
    local file_path=$1

    # 检查当前文件的换行符格式
    if [[ "$(file "$file_path")" == *"with CRLF line terminators"* ]]; then
        echo "检测到CRLF换行符，将转换为LF格式"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS 系统
            tr -d '\r' < "$file_path" > "$file_path.tmp"
            mv "$file_path.tmp" "$file_path"
        else
            # Linux 系统
            sed -i 's/\r$//' "$file_path"
        fi
    else
        echo "文件已保持为Linux LF换行符格式"
    fi
}

# 验证Authelia配置文件
validate_authelia_config() {
    local config_path=$1

    echo "---------------------------------------"
    echo "开始验证Authelia配置文件..."

    # 检查authelia命令是否存在
    if command -v authelia &> /dev/null; then
        # 如果authelia命令存在，直接使用
        authelia validate "$config_path"
    elif command -v docker &> /dev/null; then
        # 如果docker存在，使用docker运行authelia验证
        echo "本地未找到authelia命令，尝试使用Docker运行验证..."
        # 调整命令格式以确保在容器内正确执行验证
        docker run --rm -v "$config_path":"/config/configuration.yml" authelia/authelia:4.39 authelia validate-config
    else
        echo "警告: 未找到authelia命令或Docker，无法验证配置文件!"
        echo "请手动安装authelia或Docker后运行 'authelia validate $config_path' 进行验证"
        return 1
    fi

    # 检查验证结果
    if [ $? -eq 0 ]; then
        echo "Authelia配置文件验证成功!"
    else
        echo "错误: Authelia配置文件验证失败!"
        echo "请检查配置文件并修复问题"
        echo "如果需要，可以恢复备份文件: $config_path.bak"
        return 1
    fi

    return 0
}

# 执行域名替换操作
do_replace() {
    local source_domain=$1
    local target_domain=$2
    local file_path=$3

    # 显示替换信息
    echo "即将执行域名替换操作..."
    echo "源域名: $source_domain"
    echo "目标域名: $target_domain"
    echo "文件路径: $file_path"
    echo "---------------------------------------"

    # 创建备份文件
    local backup_file="$file_path.bak"
    cp "$file_path" "$backup_file"
    echo "已创建备份文件: $backup_file"

    # 确保文件使用LF换行符格式
    ensure_lf_format "$file_path"

    # 执行替换 (使用sed命令，适合macOS和Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 版本的sed
        sed -i '' "s/$source_domain/$target_domain/g" "$file_path"
        # 再次确保LF格式
        ensure_lf_format "$file_path"
    else
        # Linux 版本的sed
        sed -i "s/$source_domain/$target_domain/g" "$file_path"
    fi

    echo "---------------------------------------"
    echo "替换完成!"
    echo "源域名 '$source_domain' 已成功替换为 '$target_domain'"
    echo "文件位置: $file_path"
    echo "备份文件: $backup_file"
    echo "提示: 文件已保持为Linux LF换行符格式"

    # 验证Authelia配置文件
    validate_authelia_config "$file_path"
}

# 主函数
main() {
    check_file_exists "$FILE_PATH"
    do_replace "$SOURCE_DOMAIN" "$TARGET_DOMAIN" "$FILE_PATH"
}

# 调用主函数
main
