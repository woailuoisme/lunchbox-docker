FROM jiaoio/php-base-cli
ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=docker \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 复制 supercronic 配置和启动脚本
COPY laravel-cron /usr/local/etc/laravel-cron

CMD APP_ENV=${APP_ENV} php ${APP_PATH}/artisan queue:work
