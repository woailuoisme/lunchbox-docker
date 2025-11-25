ARG POSTGIS_VERSION=17-3.6-alpine
FROM postgis/postgis:${POSTGIS_VERSION}

LABEL maintainer="seaside <531773730@qq.com>"

ARG TIMEZONE=Asia/Shanghai
ENV POSTGRES_CONFIG_FILE=/etc/postgresql/postgresql.conf
COPY postgresql.conf /etc/postgresql/postgresql.conf

RUN mkdir -p /etc/postgresql && \
    chown -R postgres:postgres /etc/postgresql

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

HEALTHCHECK --interval=60s --timeout=10s --retries=5 --start-period=60s \
    CMD pg_isready -d ${POSTGRES_DB:-postgres} -U ${POSTGRES_USER:-postgres}

EXPOSE 5432