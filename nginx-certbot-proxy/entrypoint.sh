#!/bin/bash
set -e

create_initial_nginx_config() {
    local domain="$1"
    local proxy_host="$2"
    local proxy_port="$3"
    local prefix="$4"
    local swagger="apis"
    local config_file="/etc/nginx/conf.d/${domain}.conf"

    echo "Creating initial Nginx config for ${domain} at ${config_file}"
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name ${domain};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location /${prefix} {
        proxy_pass http://${proxy_host}:${proxy_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /${swagger} {
        proxy_pass http://${proxy_host}:${proxy_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF
}

request_or_renew_cert() {
    local domain="$1"
    local email="$2"
    local staging_arg=""

    if [ "$STAGING" = "true" ]; then
        staging_arg="--staging"
        echo "INFO: Using Let's Encrypt staging server for ${domain}."
    fi

    if [ -d "/etc/letsencrypt/live/${domain}" ]; then
        echo "Certificate for ${domain} already exists. Attempting renewal (if needed)."
        certbot renew --quiet --nginx --deploy-hook "nginx -s reload"
    else
        echo "Requesting new certificate for ${domain}..."
        
        if ! pgrep -x "nginx" > /dev/null; then
            echo "Starting Nginx temporarily for Certbot..."
            nginx -g "daemon on;"
            sleep 5
        fi

        certbot --nginx -d "${domain}" --email "${email}" --agree-tos --no-eff-email --non-interactive --redirect ${staging_arg}
    fi
}

echo ">>> Docker Entrypoint Script Started <<<"

if [ -z "$DOMAIN1" ] || [ -z "$PROXY_PASS_HOST1" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo "ERROR: DOMAIN1, PROXY_PASS_HOST1, and LETSENCRYPT_EMAIL environment variables are required."
    exit 1
fi
if [ -z "$DOMAIN2" ] || [ -z "$PROXY_PASS_HOST2" ]; then
    echo "ERROR: DOMAIN2 and PROXY_PASS_HOST2 environment variables are required."
    exit 1
fi


mkdir -p /var/www/certbot

rm -f /etc/nginx/conf.d/*.conf

create_initial_nginx_config "$DOMAIN1" "$PROXY_PASS_HOST1" "$PROXY_PASS_PORT1" "$CORE_PREFIX"
create_initial_nginx_config "$DOMAIN2" "$PROXY_PASS_HOST2" "$PROXY_PASS_PORT2" "$CORE_PREFIX"

echo "Validating initial Nginx configuration..."
nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Initial Nginx configuration is invalid. Exiting."
  exit 1
fi

request_or_renew_cert "$DOMAIN1" "$LETSENCRYPT_EMAIL"
request_or_renew_cert "$DOMAIN2" "$LETSENCRYPT_EMAIL"

echo "Validating Nginx configuration after Certbot..."
nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration after Certbot is invalid. Exiting."
  exit 1
fi

echo "Nginx and Certbot setup complete. Starting Supervisor..."

exec "$@"