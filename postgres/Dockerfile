ARG POSTGRES_VERSION=17.6-alpine
ARG TIMEZONE=Asia/Shanghai
FROM postgres:${POSTGRES_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"
# 设置时区
RUN apk add --no-cache tzdata \
    && ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && apk del tzdata

# 复制优化后的配置文件
COPY postgresql.conf /etc/postgresql/postgresql.conf

# 设置 PostgreSQL 使用自定义配置
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf

# 创建配置目录并设置权限
RUN mkdir -p /etc/postgresql && \
    chown -R postgres:postgres /etc/postgresql

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432
