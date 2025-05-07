FROM nginx:1.25-alpine

ENV DOMAIN1="api.knmholdings.vn"
ENV PROXY_PASS_HOST1="knm-asterisk-service"
ENV PROXY_PASS_PORT1="3000"

ENV DOMAIN2="devapi.knmholdings.vn"
ENV PROXY_PASS_HOST2="knm-asterisk-service-dev"
ENV PROXY_PASS_PORT2="3000"

ENV LETSENCRYPT_EMAIL="hieuhpcf@gmail.com"
ENV STAGING="false" 

RUN apk add --no-cache certbot certbot-nginx openssl bash curl supervisor

RUN mkdir -p /etc/letsencrypt /var/www/certbot /etc/nginx/snippets

COPY entrypoint.sh /entrypoint.sh

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /entrypoint.sh

VOLUME ["/etc/letsencrypt", "/var/log/nginx"]

EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]