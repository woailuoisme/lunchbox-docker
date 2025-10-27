#!/bin/bash

# setup-github-secrets.sh
# GitHub 机密配置脚本 - 用于 Docker 镜像构建工作流
# 作用：自动化配置 GitHub Actions 工作流所需的机密信息

set -e

echo "🚀 GitHub 机密配置脚本 - Lunchbox Docker 构建"
echo "================================================"
echo ""

# 检查是否安装了 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) 未安装。"
    echo "请先安装: https://cli.github.com/"
    exit 1
fi

# 检查用户是否已认证
if ! gh auth status &> /dev/null; then
    echo "❌ 请先使用 GitHub CLI 进行认证:"
    echo "   gh auth login"
    exit 1
fi

# 获取仓库信息
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO_NAME=$(gh repo view --json name --jq '.name')
echo "📦 仓库: $REPO_OWNER/$REPO_NAME"
echo ""

# 设置机密的函数（带确认）
set_secret() {
    local secret_name=$1
    local description=$2
    local is_token=$3

    echo "🔐 设置机密: $secret_name"
    echo "   描述: $description"

    if [ "$is_token" = "true" ]; then
        echo "   💡 这应该是一个访问令牌，不是密码"
    fi

    read -p "   输入 $secret_name 的值: " -s secret_value
    echo ""

    if [ -z "$secret_value" ]; then
        echo "   ⚠️  跳过 $secret_name (空值)"
        return
    fi

    read -p "   确认设置 $secret_name? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "$secret_value" | gh secret set "$secret_name"
        echo "   ✅ $secret_name 设置成功"
    else
        echo "   ❌ $secret_name 未设置"
    fi
    echo ""
}

# Docker Hub 机密配置
echo "🐳 Docker Hub 配置"
echo "-------------------"
set_secret "DOCKERHUB_USERNAME" "您的 Docker Hub 用户名" false
set_secret "DOCKERHUB_TOKEN" "Docker Hub 访问令牌" true

# 腾讯云机密配置
echo "☁️  腾讯云配置"
echo "---------------"
set_secret "TENCENT_NAMESPACE" "腾讯云命名空间 (例如: your-company)" false
set_secret "TENCENT_USERNAME" "腾讯云用户名" false
set_secret "TENCENT_PASSWORD" "腾讯云密码" false

# Red Hat Registry 机密配置
echo "🔴 Red Hat Registry 配置"
echo "-------------------------"
set_secret "REDHAT_NAMESPACE" "Red Hat 命名空间" false
set_secret "REDHAT_USERNAME" "Red Hat 用户名" false
set_secret "REDHAT_TOKEN" "Red Hat 访问令牌" true

# 可选配置
echo "🔔 可选配置"
echo "-----------"
read -p "配置 Slack 通知? (y/N): " slack_confirm
if [[ $slack_confirm =~ ^[Yy]$ ]]; then
    set_secret "SLACK_WEBHOOK_URL" "Slack webhook URL 用于构建通知" false
fi

echo ""
echo "✅ 设置完成!"
echo ""
echo "📋 已配置的机密摘要:"
gh secret list

echo ""
echo "🚀 后续步骤:"
echo "   1. 推送代码以触发工作流"
echo "   2. 检查 GitHub Actions 标签页查看构建状态"
echo "   3. 验证镜像是否推送到您的注册表"
echo ""
echo "💡 手动测试:"
echo "   - 前往 GitHub Actions → 'Build and Push Docker Images' → 'Run workflow'"
echo ""
echo "🔧 故障排除:"
echo "   - 检查工作流日志获取详细错误信息"
echo "   - 验证所有必需的机密都已设置"
echo "   - 确保注册表权限正确"
