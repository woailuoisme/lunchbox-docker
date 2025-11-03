FROM jiaoio/php-base-cli
ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=docker \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

# 使用简单的 while 循环每分钟执行 Laravel 调度器
CMD ["/bin/sh", "-c", "while true; do /usr/local/bin/php /var/www/lunchbox/artisan schedule:run; sleep 60; done"]
