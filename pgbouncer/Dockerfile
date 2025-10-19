FROM alpine:latest
LABEL maintainer="seaside <531773730@qq.com>"

ARG CHANGE_SOURCE=false

RUN if [ "$CHANGE_SOURCE" = "true" ]; then \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    fi

# 安装pgbouncer和其他必要工具
RUN apk add --no-cache pgbouncer shadow


ARG TIMEZONE=Asia/Shanghai

# 创建非root用户运行pgbouncer
RUN addgroup -S pgbouncer && adduser -S pgbouncer -G pgbouncer

# 复制配置文件到标准位置
COPY pgbouncer.ini /etc/pgbouncer/
COPY userlist.txt /etc/pgbouncer/

# 设置配置文件权限
RUN chown -R pgbouncer:pgbouncer /etc/pgbouncer/

EXPOSE 6432

# 健康检查 - 检查PgBouncer进程是否正常运行
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep pgbouncer > /dev/null || exit 1

# 切换到非root用户
USER pgbouncer

# 直接运行pgbouncer命令，使用标准配置文件路径
CMD ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
