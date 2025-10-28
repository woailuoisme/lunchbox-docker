ARG REDIS_VERSION=7.4-alpine
ARG TIMEZONE=Asia/Shanghai

FROM redis:${REDIS_VERSION}
LABEL maintainer="seaside <531773730@qq.com>"


## For security settings uncomment, make the dir, copy conf, and also start with the conf, to use it
RUN mkdir -p /usr/local/etc/redis
COPY redis.conf /usr/local/etc/redis/redis.conf

VOLUME /data

EXPOSE 6379

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
#CMD ["redis-server"]
