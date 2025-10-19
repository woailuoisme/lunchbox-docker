FROM minio/minio
LABEL maintainer="seaside <seaside@qq.com>"
# 安装 yq (YAML 处理器)
RUN curl -sSL https://github.com/mikefarah/yq/releases/download/v4.47.2/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# 复制配置文件和初始化脚本
COPY buckets.yml /etc/minio/buckets.yml
COPY init_minio.sh /usr/local/bin/init_minio.sh
RUN chmod +x /usr/local/bin/init_minio.sh

# 设置环境变量（使用默认值，可在运行时覆盖）
ENV MINIO_ENDPOINT=http://localhost:9000
ENV CONFIG_FILE=/etc/minio/buckets.yml

EXPOSE 9000 9001

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/minio/health/live || exit 1

# 启动命令 - 使用标准 MinIO 启动方式
CMD ["minio", "server", "/data", "--console-address", ":9001"]
