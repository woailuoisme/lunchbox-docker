#!/bin/bash

# setup-github-secrets.sh
# Script to help configure GitHub secrets for Docker image build workflow

set -e

echo "🚀 GitHub Secrets Setup Script for Lunchbox Docker Builds"
echo "=========================================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Please install it first: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Please authenticate with GitHub CLI first:"
    echo "   gh auth login"
    exit 1
fi

# Get repository info
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO_NAME=$(gh repo view --json name --jq '.name')
echo "📦 Repository: $REPO_OWNER/$REPO_NAME"
echo ""

# Function to set secret with confirmation
set_secret() {
    local secret_name=$1
    local description=$2
    local is_token=$3

    echo "🔐 Setting secret: $secret_name"
    echo "   Description: $description"

    if [ "$is_token" = "true" ]; then
        echo "   💡 This should be an access token, not a password"
    fi

    read -p "   Enter value for $secret_name: " -s secret_value
    echo ""

    if [ -z "$secret_value" ]; then
        echo "   ⚠️  Skipping $secret_name (empty value)"
        return
    fi

    read -p "   Confirm setting $secret_name? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "$secret_value" | gh secret set "$secret_name"
        echo "   ✅ $secret_name set successfully"
    else
        echo "   ❌ $secret_name not set"
    fi
    echo ""
}

# Docker Hub secrets
echo "🐳 Docker Hub Configuration"
echo "---------------------------"
set_secret "DOCKERHUB_USERNAME" "Your Docker Hub username" false
set_secret "DOCKERHUB_TOKEN" "Docker Hub access token" true

# Tencent Cloud secrets
echo "☁️  Tencent Cloud Configuration"
echo "-------------------------------"
set_secret "TENCENT_NAMESPACE" "Tencent Cloud namespace (e.g., your-company)" false
set_secret "TENCENT_USERNAME" "Tencent Cloud username" false
set_secret "TENCENT_PASSWORD" "Tencent Cloud password" false

# Red Hat Registry secrets
echo "🔴 Red Hat Registry Configuration"
echo "---------------------------------"
set_secret "REDHAT_NAMESPACE" "Red Hat namespace" false
set_secret "REDHAT_USERNAME" "Red Hat username" false
set_secret "REDHAT_TOKEN" "Red Hat access token" true

# Optional secrets
echo "🔔 Optional Configuration"
echo "-------------------------"
read -p "Configure Slack notifications? (y/N): " slack_confirm
if [[ $slack_confirm =~ ^[Yy]$ ]]; then
    set_secret "SLACK_WEBHOOK_URL" "Slack webhook URL for build notifications" false
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Summary of configured secrets:"
gh secret list

echo ""
echo "🚀 Next steps:"
echo "   1. Push your code to trigger the workflow"
echo "   2. Check GitHub Actions tab for build status"
echo "   3. Verify images are pushed to your registries"
echo ""
echo "💡 For manual testing:"
echo "   - Go to GitHub Actions → 'Build and Push Docker Images' → 'Run workflow'"
echo ""
echo "🔧 Troubleshooting:"
echo "   - Check workflow logs for detailed error information"
echo "   - Verify all required secrets are set"
echo "   - Ensure registry permissions are correct"
