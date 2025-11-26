# ============================================================================
# PHP Base Octane Image - Laravel Octane Support
# ============================================================================

FROM jiaoio/php-base-cli
LABEL maintainer="seaside <531773730@qq.com>"

# ============================================================================
# 构建参数配置
# ============================================================================

# 控制 APK 镜像源和可选功能
ARG CHANGE_SOURCE=false
ARG TIMEZONE=Asia/Shanghai

# ============================================================================
# 安装 Laravel Octane 所需组件
# ============================================================================
COPY download-frankenphp-docker.sh /tmp/download-frankenphp-docker.sh
RUN chmod +x /tmp/download-frankenphp.sh

RUN set -eux; \
    if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi; \
    apk add --no-cache --virtual .swoole-build openssl-dev \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del .swoole-build \
    && rm -rf /tmp/pear \
    && curl -L -o /tmp/rr.tar.gz \
    https://github.com/roadrunner-server/roadrunner/releases/download/v2025.1.5/roadrunner-2025.1.5-linux-$(uname -m).tar.gz \
    && tar -xzf /tmp/rr.tar.gz -C /tmp/ \
    && mv /tmp/roadrunner-2025.1.5-linux-$(uname -m)/rr /usr/local/bin/rr \
    && chmod +x /usr/local/bin/rr \
    && rm -rf /tmp/rr.tar.gz /tmp/roadrunner-2025.1.5-linux-$(uname -m) \
    # 下载 FrankenPHP 二进制
    && /tmp/download-frankenphp-docker.sh 1.10.1 \
    && rm -f /tmp/download-frankenphp-docker.sh

# ============================================================================
# 验证安装
# ============================================================================

RUN rr --version \
    && frankenphp --version \
    && php -m | grep swoole

# ============================================================================
# 工作目录设置
# ============================================================================

WORKDIR /var/www
