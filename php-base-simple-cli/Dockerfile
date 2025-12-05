# ============================================================================
# PHP 基础镜像构建文件（使用 docker-php-extension-installer 优化版）
# ============================================================================

FROM php:8.4.14-cli-alpine3.22
LABEL maintainer="seaside <531773730@qq.com>"

# ============================================================================
# 构建参数配置
# ============================================================================

ARG CHANGE_SOURCE=true
ARG TIMEZONE=Asia/Shanghai
ARG WWWUSER=33
ARG WWWGROUP=33

# 可选功能开关
ARG WITH_PG=true
ARG WITH_AMQP=true
ARG WITH_UV=true
ARG WITH_LDAP=false
ARG WITH_SWOOLE=false
ARG SUPERCRONIC_VERSION=0.2.39

# ============================================================================
# 系统基础配置
# ============================================================================

RUN set -eux; \
    # 配置镜像源
    if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi; \
    # 安装基础工具
    apk add --no-cache \
    bash \
    curl \
    git \
    tzdata \
    gettext \
    postgresql17-client \
    libzip \
    libxml2 \
    oniguruma \
    zlib \
    icu-libs \
    freetype \
    libjpeg-turbo \
    libpng \
    libwebp \
    libavif \
    libffi \
    ; \
    # 安装可选运行时依赖
    if [ "$WITH_PG" = "true" ]; then apk add --no-cache libpq; fi; \
    if [ "$WITH_LDAP" = "true" ]; then apk add --no-cache openldap; fi; \
    if [ "$WITH_AMQP" = "true" ]; then apk add --no-cache rabbitmq-c; fi; \
    if [ "$WITH_SWOOLE" = "true" ]; then apk add --no-cache openssl; fi; \
    if [ "$WITH_UV" = "true" ]; then apk add --no-cache libuv; fi; \
    # 设置时区
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime; \
    echo "${TIMEZONE}" > /etc/timezone

# ============================================================================
# 安装 docker-php-extension-installer
# ============================================================================

COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

# ============================================================================
# 安装 PHP 扩展（使用 install-php-extensions）
# ============================================================================

RUN set -eux; \
    # 安装核心扩展
    install-php-extensions \
    @composer \
    pdo_mysql \
    mysqli \
    gd \
    mbstring \
    xml \
    simplexml \
    zip \
    intl \
    bcmath \
    pcntl \
    sockets \
    exif \
    ffi \
    opcache \
    ; \
    # 安装可选扩展
    if [ "$WITH_PG" = "true" ]; then \
    install-php-extensions pdo_pgsql pgsql; \
    fi; \
    if [ "$WITH_LDAP" = "true" ]; then \
    install-php-extensions ldap; \
    fi; \
    # 安装 PECL 扩展
    install-php-extensions redis; \
    if [ "$WITH_AMQP" = "true" ]; then \
    install-php-extensions amqp; \
    fi; \
    if [ "$WITH_SWOOLE" = "true" ]; then \
    install-php-extensions swoole; \
    fi; \
    if [ "$WITH_UV" = "true" ]; then \
    install-php-extensions uv; \
    fi

# ============================================================================
# 清理和优化
# ============================================================================

RUN set -eux; \
    # 清理 APK 缓存
    rm -rf /var/cache/apk/*; \
    # 清理 PHP 扩展构建文件
    find /usr/local/lib/php -name "*.a" -delete 2>/dev/null || true; \
    find /usr/local/lib/php -name "*.la" -delete 2>/dev/null || true; \
    # 清理头文件
    { find /usr/include -type f \( -name "*.h" -o -name "*.hpp" \) -delete 2>/dev/null || true; } && true; \
    { find /usr/local/include -type f \( -name "*.h" -o -name "*.hpp" \) -delete 2>/dev/null || true; } && true; \
    # 清理文档
    { find /usr/share/man -type f -delete 2>/dev/null || true; } && true; \
    { find /usr/share/doc -type f -delete 2>/dev/null || true; } && true; \
    { find /usr/share/info -type f -delete 2>/dev/null || true; } && true; \
    # 清理临时文件
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true; \
    # 清理 composer 缓存
    rm -rf /root/.composer/cache 2>/dev/null || true; \
    # 清理 PHP 测试文件
    { find /usr/local/lib/php -name "test" -type d -exec rm -rf {} + 2>/dev/null || true; } && true; \
    # 清理 PHP 文档
    { find /usr/local/lib/php -name "*.md" -delete 2>/dev/null || true; } && true; \
    { find /usr/local/lib/php -name "*.txt" -delete 2>/dev/null || true; } && true; \
    # 保留必要的目录结构
    mkdir -p /usr/include /usr/local/include /usr/share/info 2>/dev/null || true

# ============================================================================
# 安装额外工具
# ============================================================================

RUN set -eux; \
    # 安装 Supercronic
    curl -sSL -o /usr/local/bin/supercronic \
    https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64; \
    chmod +x /usr/local/bin/supercronic; \
    # 清理 curl 下载的临时文件
    rm -rf /root/.curl

# ============================================================================
# 用户、目录和权限配置
# ============================================================================

RUN set -eux; \
    # 删除默认用户
    deluser www-data 2>/dev/null || true; \
    delgroup www-data 2>/dev/null || true; \
    # 创建新用户和组
    addgroup -g ${WWWGROUP} www-data; \
    adduser -u ${WWWUSER} -D -H -G www-data www-data; \
    # 创建目录
    mkdir -p /var/www /tmp /var/log/php /var/run/php /usr/local/etc/php/conf.d; \
    # 设置权限
    chown -R www-data:www-data /var/www /tmp /var/log/php /var/run/php /usr/local/etc/php/conf.d; \
    # 创建日志文件
    touch /var/log/php/error.log /var/log/php/slow.log; \
    chmod 644 /var/log/php/error.log /var/log/php/slow.log; \
    chmod 755 /var/log/php /var/run/php; \
    # 验证扩展
    php -m | grep -i ffi || echo "FFI extension not loaded"

# ============================================================================
# 最终清理
# ============================================================================

RUN set -eux; \
    # 清理所有缓存
    rm -rf /var/cache/*; \
    # 清空日志文件
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true; \
    # 清理 bash 历史
    rm -f /root/.bash_history; \
    # 显示 PHP 信息（用于调试）
    php --version; \
    composer --version

# ============================================================================
# 工作目录设置
# ============================================================================

WORKDIR /var/www

# ============================================================================
# 默认用户
# ============================================================================

USER www-data

# ============================================================================
# 默认命令
# ============================================================================

CMD ["php", "-a"]
