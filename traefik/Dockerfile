FROM traefik:3.5.4

# 环境变量
ENV ENABLE_HTTPS=true
ENV TZ=Asia/Shanghai

# 创建必要的目录
RUN mkdir -p /config/certs

# 复制配置文件
COPY traefik-http.yml /etc/traefik/traefik-http.yml
COPY traefik-https.yml /etc/traefik/traefik-https.yml
COPY users.yml /etc/traefik/users.yml

# 复制动态配置
COPY config/ /config/

# 设置工作目录
WORKDIR /etc/traefik

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -q -O- http://localhost:80/ping || exit 1

# 暴露端口
EXPOSE 80 443 8080 5432 6379

# 启动命令 - 使用 --configfile 参数加载配置文件
CMD ["traefik", \
    "--configfile=/etc/traefik/traefik-${ENABLE_HTTPS:-true}.yml", \
    "--log.level=INFO"]
