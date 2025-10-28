ARG RABBITMQ_VERSION=4.1-management-alpine
FROM rabbitmq:${REDIS_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

# 下载并安装延迟消息交换插件（4.1.0版本）
RUN wget -O /opt/rabbitmq/plugins/rabbitmq_delayed_message_exchange-4.1.0.ez \
    https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v4.1.0/rabbitmq_delayed_message_exchange-4.1.0.ez && \
    rabbitmq-plugins enable rabbitmq_delayed_message_exchange

# 复制配置文件
COPY config/rabbitmq.conf /etc/rabbitmq/

# 设置健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD rabbitmq-diagnostics -q ping