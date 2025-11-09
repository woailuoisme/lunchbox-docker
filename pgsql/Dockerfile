# =========================================================
# PostgreSQL with PostGIS and pgvector
# =========================================================
ARG POSTGRES_VERSION=17.6-alpine
FROM postgres:${POSTGRES_VERSION}

# 设置环境变量
ENV POSTGRES_DB=postgres
ARG CHANGE_SOURCE=false

# 切换为中国源（如果启用）
RUN if [ "${CHANGE_SOURCE}" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 安装编译和运行所需的依赖包
RUN apk update && \
    apk add --no-cache \
    build-base \
    git \
    clang \
    llvm \
    postgresql-dev \
    postgis \
    geos \
    proj

# 编译安装 pgvector
WORKDIR /tmp
RUN git clone --branch v0.8.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" && \
    make install && \
    cd .. && \
    rm -rf pgvector

# 清理构建工具以减小镜像大小
RUN apk del --purge build-base git clang llvm && \
    rm -rf /var/cache/apk/*

# 复制初始化脚本
COPY ./initdb.d/ /docker-entrypoint-initdb.d/

# 设置脚本执行权限
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pg_isready -U postgres

# 设置工作目录
WORKDIR /var/lib/postgresql

# 暴露端口
EXPOSE 5432
