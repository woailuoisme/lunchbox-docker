# 基于官方 Nginx 镜像，添加 HTTP/3 (QUIC) 支持
FROM nginx:1.29.4-alpine3.23 AS base

LABEL maintainer="seaside <531773730@qq.com>"
LABEL description="Official Nginx with HTTP/3 (QUIC) support via dynamic module"

# 阶段1：下载 quiche 源码
FROM alpine:3.23 AS quiche-builder

ARG QUICHE_VERSION=0.12.0

RUN apk add --no-cache git \
  && git clone --depth 1 --branch tokio-quiche-${QUICHE_VERSION} https://github.com/cloudflare/quiche.git /quiche

# 阶段2：编译 HTTP/3 动态模块
FROM nginx:1.29.4-alpine3.23 AS builder

ARG NGINX_VERSION=1.29.4

# 复制 quiche 源码
COPY --from=quiche-builder /quiche /quiche

# 安装编译依赖并编译 HTTP/3 模块
RUN apk add --no-cache \
    gcc g++ make cmake rust cargo go \
    libc-dev pcre2-dev zlib-dev linux-headers \
  && wget -qO- https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz -C /tmp \
  && cd /tmp/nginx-${NGINX_VERSION} \
  && ./configure \
    --with-compat \
    --with-http_v3_module \
    --with-stream_quic_module \
    --with-quiche=/quiche \
    --with-openssl=/quiche/deps/boringssl \
    --add-dynamic-module=/quiche/nginx \
  && make modules \
  && cp objs/ngx_http_v3_module.so /tmp/ \
  && cp objs/ngx_stream_quic_module.so /tmp/ \
  && rm -rf /tmp/nginx-${NGINX_VERSION} /quiche

# 阶段3：最终镜像（基于官方镜像）
FROM nginx:1.29.4-alpine3.23

LABEL maintainer="seaside <531773730@qq.com>"
LABEL description="Official Nginx with HTTP/3 (QUIC) support"

# 复制 HTTP/3 动态模块
COPY --from=builder /tmp/ngx_http_v3_module.so /usr/lib/nginx/modules/
COPY --from=builder /tmp/ngx_stream_quic_module.so /usr/lib/nginx/modules/

# 创建额外的配置目录
RUN mkdir -p /etc/nginx/snippets \
  && chown -R nginx:nginx /etc/nginx/snippets

# 暴露 HTTP/3 端口（UDP）
EXPOSE 443/udp

STOPSIGNAL SIGQUIT

# 使用官方镜像的默认 CMD
CMD ["nginx", "-g", "daemon off;"]