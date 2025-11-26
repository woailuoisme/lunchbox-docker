FROM ghcr.io/roadrunner-server/roadrunner:2025.X.X AS roadrunner
FROM jiaoio/php-base-cli

RUN apk add --no-cache --virtual .swoole-build openssl-dev \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && apk del .swoole-build \
    && rm -rf /tmp/pear

COPY --from=roadrunner /usr/bin/rr /usr/local/bin/rr
COPY download-frankenphp.sh /usr/local/bin/download-frankenphp.sh
RUN chmod +x /usr/local/bin/download-frankenphp.sh \
    && /usr/local/bin/download-frankenphp.sh \
    && frankenphp --version
