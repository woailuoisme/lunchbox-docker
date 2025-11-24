ARG CADDY_VERSION=2.10.2-alpine
FROM caddy:${CADDY_VERSION}
ARG CHANGE_SOURCE=true
ARG TIMEZONE=Asia/Shanghai

LABEL maintainer="seaside <531773730@qq.com>"
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi && \
    apk add --no-cache nss-tools tzdata curl && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

RUN caddy add-package github.com/caddyserver/transform-encoder && \
    caddy add-package github.com/caddy-dns/cloudflare && \
    caddy add-package github.com/caddy-dns/alidns \

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
