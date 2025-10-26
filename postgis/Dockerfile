ARG POSTGRES_VERSION=17.6-alpine
FROM postgres:${POSTGRES_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ARG CHANGE_SOURCE=true

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

RUN apk update && apk add --no-cache \
    postgis \
    geos \
    proj \
    gdal \
    && mkdir -p /usr/local/share/postgresql/extension \
    && mkdir -p /usr/local/lib/postgresql \
    && ln -sf /usr/share/postgresql17/extension/* /usr/local/share/postgresql/extension/ \
    && ln -sf /usr/lib/postgresql17/*.so /usr/local/lib/postgresql/

# 创建启动脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 设置 PostgreSQL 使用自定义配置
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
