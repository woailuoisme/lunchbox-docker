FROM ccr.ccs.tencentyun.com/jiaoio/php-base-franken

## 设置工作目录
#WORKDIR /var/www/laravel
#
## ---------------------------------
## 环境变量 (Environment Variables)
## ---------------------------------
## 配置 PHP
## 配置 Laravel Octane
#ENV APP_ENV production
#ENV APP_PORT 8000
#ENV OCTANE_SERVER frankenphp
#ENV OCTANE_HOST 0.0.0.0
#ENV PHP_INI_DIR /usr/local/etc/php
#COPY ./docker/php.ini $PHP_INI_DIR/php.ini
# # ---------------------------------
# # Composer
# # ---------------------------------
# # 从官方镜像复制 Composer
# COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# # ---------------------------------
# # 应用代码和依赖 (Application Code & Dependencies)
# # ---------------------------------
# # 复制 composer 文件
# COPY --chown=www-data:www-data composer.json composer.lock ./

# # 以非 root 用户身份安装 Composer 依赖（更安全）
# # 这将触发 frankenphp/binary-plugin 插件下载 FrankenPHP 二进制文件
# USER www-data
# RUN composer install --no-interaction --no-dev --optimize-autoloader

# # 复制剩余的应用代码
# USER root
# COPY --chown=www-data:www-data . .

# # ---------------------------------
# # 优化和权限 (Optimization & Permissions)
# # ---------------------------------
# RUN chown -R www-data:www-data storage bootstrap/cache \
#     && chmod -R 775 storage bootstrap/cache

# # 清理缓存并生成优化文件
# USER www-data
# RUN php artisan config:cache \
#     && php artisan route:cache \
#     && php artisan view:cache

# ---------------------------------
# 运行 (Run)
# ---------------------------------
# 暴露 Octane 运行的端口
EXPOSE ${APP_PORT}

# 以 www-data 用户运行 Octane
# CMD ["php", "artisan", "octane:start", "--server=frankenphp","--workers=4","--host=0.0.0.0", "--port=${APP_PORT}"]

EXPOSE 8001 2019
WORKDIR /var/www
CMD ["php", "/var/www/lunchbox/artisan", "octane:start", "--server=frankenphp", "--port=8001", "--watch", "--env=docker "]