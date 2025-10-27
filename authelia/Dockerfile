FROM authelia/authelia:4.39

LABEL maintainer="seaside <531773730@qq.com>"

# 复制配置文件
COPY configuration.yml /config/configuration.yml
COPY users_database.yml /config/users_database.yml
# 创建通知文件
RUN touch /config/notification.txt
# 暴露端口
EXPOSE 9091