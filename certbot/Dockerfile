FROM certbot/certbot:latest
LABEL maintainer="seaside <531773730@qq.com>"

# 安装阿里云和 Cloudflare DNS 插件
RUN pip install certbot-dns-cloudflare certbot-dns-aliyun

# 创建必要的目录
RUN mkdir -p /etc/letsencrypt

# 设置工作目录
WORKDIR /opt/certbot

# 复制启动脚本
COPY start.sh /opt/certbot/start.sh
RUN chmod +x /opt/certbot/start.sh

# 设置入口点
ENTRYPOINT ["/opt/certbot/start.sh"]