# 阶段 1: 构建 Caddy
FROM caddy:2.10.2-builder-alpine AS builder

# 运行 xcaddy build 来构建，不需要指定核心模块，它们会自动包含。
# https://github.com/hslatman/caddy-crowdsec-bouncer
# 如果您需要添加第三方模块，可以在后面加上 --with <module_path>
RUN xcaddy build \
    --output /usr/bin/caddy \
    --with github.com/caddyserver/transform-encoder  \
    --with github.com/hslatman/caddy-crowdsec-bouncer/crowdsec \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddy-dns/alidns

# 阶段 2: 最终运行镜像
FROM caddy:2.10.2-alpine

# 安装 certutil 所需的依赖包
RUN apk add --no-cache nss-tools
# 替换官方的 caddy 可执行文件为我们构建的版本
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

COPY snippets /etc/caddy/snippets
COPY templates /etc/caddy/templates
COPY startup.sh /usr/local/bin/startup.sh
COPY Caddyfile /etc/caddy/Caddyfile
RUN chmod +x /usr/local/bin/startup.sh

CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=60s --timeout=5s --start-period=5s --retries=3 CMD [ \
    "curl", \
    "--silent", \
    "--fail", \
    "http://localhost:2019/config/" \
    ]