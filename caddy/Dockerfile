FROM jiaoio/caddy-base:latest

COPY sites /etc/caddy/sites
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
