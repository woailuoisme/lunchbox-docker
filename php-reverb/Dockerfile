FROM jiaoio/php-base-cli
ENV APP_PATH=/var/www/lunchbox \
    APP_PORT=8001 \
    APP_ENV=docker \
    PYTHONWARNINGS="ignore:pkg_resources is deprecated"

CMD APP_ENV=${APP_ENV} php ${APP_PATH}/artisan reverb:start
