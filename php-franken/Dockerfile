FROM ccr.ccs.tencentyun.com/jiaoio/php-base-franken

EXPOSE 8001 2019
WORKDIR /var/www
CMD ["php", "/var/www/lunchbox/artisan", "octane:start", "--server=frankenphp", "--port=8001", "--watch", "--env=local "]