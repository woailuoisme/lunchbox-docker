#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-franken
#FROM jiaoio/php-base-franken
FROM jiaoio/php-base-franken-xdebug
ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=docker \
    APP_DEBUG=true \
    OCTANE_SERVER=frankenphp \
    OCTANE_HOST=0.0.0.0 \
    WATCH=false \
    OCTANE_WORKERS=2 \
    OCTANE_ADMIN_PORT=2019 \
    OCTANE_MAX_REQUESTS=500 \
    OCTANE_POLL=false \
    OCTANE_HTTPS=false \
    OCTANE_HTTP_REDIRECT=false \
    OCTANE_LOG_LEVEL=info

# 复制PHP配置
#COPY config/php.ini $PHP_INI_DIR/conf.d/99-custom.ini
COPY config/*.ini /usr/local/etc/php/conf.d/

# 复制启动脚本
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# 复制健康检查脚本
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# 复制 Supervisor 配置
COPY supervisor/*.conf /usr/local/etc/supervisord.d/
COPY supervisord.conf /usr/local/etc/supervisord.conf

# 复制 supercronic 配置和启动脚本
COPY laravel-cron /usr/local/etc/laravel-cron

# 健康检测配置
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

EXPOSE ${APP_PORT} ${OCTANE_ADMIN_PORT} 9103 9201
WORKDIR $APP_PATH
CMD ["/usr/local/bin/startup.sh"]
