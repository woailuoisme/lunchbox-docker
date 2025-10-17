#!/bin/bash

# 检测操作系统和架构
detect_system() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    # 处理架构名称映射
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            echo "不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    # 检查操作系统支持
    if [[ $OS != "linux" && $OS != "darwin" ]]; then
        echo "不支持的操作系统: $OS"
        exit 1
    fi

    echo "检测到系统: $OS-$ARCH"
}

# 下载并安装 mc
install_mc() {
    # 最新版 mc 下载地址
    BASE_URL="https://dl.min.io/client/mc/release"
    DOWNLOAD_URL="$BASE_URL/$OS-$ARCH/mc"

    # 临时下载路径
    TEMP_FILE=$(mktemp)

    echo "正在下载 mc: $DOWNLOAD_URL"
    if ! curl -sSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
        echo "下载失败，请检查网络连接"
        rm -f "$TEMP_FILE"
        exit 1
    fi

    # 赋予执行权限
    chmod +x "$TEMP_FILE"

    # 移动到系统可执行目录
    if [[ -w /usr/local/bin ]]; then
        DEST="/usr/local/bin/mc"
    else
        DEST="$HOME/.local/bin/mc"
        mkdir -p "$(dirname "$DEST")"
    fi

    echo "安装到: $DEST"
    mv "$TEMP_FILE" "$DEST"

    # 验证安装
    if command -v mc &> /dev/null; then
        echo "安装成功！mc 版本:"
        mc --version
    else
        echo "安装失败，请将 $DEST 所在目录添加到 PATH"
        exit 1
    fi
}

# 主流程
main() {
    detect_system
    install_mc
}

main
