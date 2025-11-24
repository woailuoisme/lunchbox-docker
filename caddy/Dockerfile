# 阶段 1: 构建 Caddy
FROM caddy:builder AS builder

# 运行 xcaddy build 来构建，不需要指定核心模块，它们会自动包含。
# 如果您需要添加第三方模块，可以在后面加上 --with <module_path>
RUN xcaddy build \
    --output /usr/bin/caddy \
    # --with github.com/caddy-dns/cloudflare  <-- 如果您需要第三方模块才取消注释

# 阶段 2: 最终运行镜像
FROM caddy:2.10.2-alpine

# 安装 certutil 所需的依赖包
RUN apk add --no-cache nss-tools

# 替换官方的 caddy 可执行文件为我们构建的版本
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

#COPY snippets /etc/caddy/snippets
#COPY templates /etc/caddy/templates
#COPY startup.sh /usr/local/bin/startup.sh
#RUN chmod +x /usr/local/bin/startup.sh
# 复制您的 Caddyfile
COPY Caddyfile /etc/caddy/Caddyfile

# 保持 Caddy 的默认 CMD
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]