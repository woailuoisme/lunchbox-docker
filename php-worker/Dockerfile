#FROM ccr.ccs.tencentyun.com/jiaoio/php-base-simple-cli
FROM jiaoio/php-base-simple-cli
ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=docker \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"



CMD APP_ENV=${APP_ENV} php ${APP_PATH}/artisan queue:work

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD ps aux | grep -q "[p]hp.*artisan queue:work" || exit 1
