FROM quay.io/minio/minio
LABEL maintainer="seaside <seaside@qq.com>"

CMD ["minio", "server", "/data", "--console-address", ":9001"]

EXPOSE 9000 9001

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/minio/health/live || exit 1