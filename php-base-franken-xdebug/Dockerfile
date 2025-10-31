FROM jiaoio/php-base-cli-xdebug

COPY download-frankenphp.sh /usr/local/bin/download-frankenphp.sh
RUN chmod +x /usr/local/bin/download-frankenphp.sh \
    && /usr/local/bin/download-frankenphp.sh \
    && frankenphp --version
