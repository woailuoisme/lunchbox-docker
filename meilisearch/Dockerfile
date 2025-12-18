FROM getmeili/meilisearch:v1.30

ARG TIMEZONE=Asia/Shanghai

RUN apk add --no-cache tzdata && \
    ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo ${TIMEZONE} > /etc/timezone

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD wget --spider -q http://127.0.0.1:7700/health || exit 1
