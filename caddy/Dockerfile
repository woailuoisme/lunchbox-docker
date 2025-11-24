ARG CADDY_VERSION=2.10.2-alpine
FROM caddy:${CADDY_VERSION}
ARG CHANGE_SOURCE=true
ARG TIMEZONE=Asia/Shanghai

# 安全标签
LABEL maintainer="seaside <531773730@qq.com>"
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories; \
    fi && \
    apk add --no-cache nss-tools tzdata curl && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

RUN caddy add-package github.com/caddyserver/transform-encoder && \
    caddy add-package github.com/caddy-dns/cloudflare && \
    caddy add-package github.com/caddy-dns/alidns


COPY snippets /etc/caddy/snippets
COPY templates /etc/caddy/templates
COPY startup.sh /usr/local/bin/startup.sh
COPY Caddyfile /etc/caddy/Caddyfile
RUN chmod +x /usr/local/bin/startup.sh

# 使用启动脚本
CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=60s --timeout=5s --start-period=5s --retries=3 CMD [ \
    "curl", \
    "--silent", \
    "--fail", \
    "http://localhost:2019/config/" \
    ]
