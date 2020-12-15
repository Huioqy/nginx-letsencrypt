#!/bin/bash

##------------------------- Variable Checks ---------------------##
if [ -z "${DOMAIN_OR_PUBLIC_IP}" ]; then
  printf "\n  =======¡ERROR!======="
  printf "\n  Variable 'DOMAIN_OR_PUBLIC_IP' it's necessary\n"
  exit 0
fi

if [ -z "${CERTIFICATE_TYPE}" ]; then 
  printf "\n  =======¡ERROR!======="
  printf "\n  Variable 'CERTIFICATE_TYPE' it's necessary\n"
  exit 0
fi

if [[ "${CERTIFICATE_TYPE}" == "letsencrypt" && \
      "${LETSENCRYPT_EMAIL}" == "user@example.com" ]]; then
  printf "\n  =======¡ERROR!======="
  printf "\n  If your use LetsEncrypt mode it's necessary a correct email in 'LETSENCRYPT_EMAIL' variable\n"
  exit 0
fi

if [[ "${CERTIFICATE_TYPE}" == "letsencrypt" && \
      -z "${LETSENCRYPT_EMAIL}" ]]; then
  printf "\n  =======¡ERROR!======="
  printf "\n  If your use LetsEncrypt mode it's necessary a correct email in 'LETSENCRYPT_EMAIL' variable\n"
  exit 0
fi

##-------------------------Global variables ---------------------##

CERTIFICATES_FOLDER=/etc/letsencrypt/live
CERTIFICATES_CONF="${CERTIFICATES_FOLDER}/certificates.conf"

[ ! -d "${CERTIFICATES_FOLDER}" ] && mkdir -p "${CERTIFICATES_FOLDER}"
[ ! -f "${CERTIFICATES_CONF}" ] && touch "${CERTIFICATES_CONF}"
[ -z "${PROXY_HTTP_PORT}" ] && export PROXY_HTTP_PORT=80
[ -z "${PROXY_HTTPS_PORT}" ] && export PROXY_HTTPS_PORT=443
[ -z "${CONF_MODIFICATION}" ] && export CONF_MODIFICATION=false

# Start with default certbot conf
sed -i "s/{http_port}/${PROXY_HTTP_PORT}/" /etc/nginx/conf.d/default.conf
nginx -g "daemon on;"

##---------------------Show input enviroment variables---------------------##
printf "\n  ======================================="
printf "\n  =          INPUT VARIABLES            ="
printf "\n  ======================================="
printf "\n"

printf "\n  Config NGINX:"
printf "\n    - Http Port: %s" "${PROXY_HTTP_PORT}"
printf "\n    - Https Port: %s" "${PROXY_HTTPS_PORT}"
printf "\n    - Domain name: %s" "${DOMAIN_OR_PUBLIC_IP}"
printf "\n    - Certificated: %s" "${CERTIFICATE_TYPE}"
printf "\n    - Letsencrypt Email: %s" "${LETSENCRYPT_EMAIL}"

printf "\n"
printf "\n  ======================================="
printf "\n  =       CONFIGURATION NGINX           ="
printf "\n  ======================================="
printf "\n"

printf "\n  Configure %s domain..." "${DOMAIN_OR_PUBLIC_IP}"
CERTIFICATED_OLD_CONFIG=$(grep "${DOMAIN_OR_PUBLIC_IP}" "${CERTIFICATES_CONF}" | cut -f2 -d$'\t')

printf "\n    - New configuration: %s" "${CERTIFICATE_TYPE}"

if [ -z "${CERTIFICATED_OLD_CONFIG}" ]; then
  printf "\n    - Old configuration: none"
else
  printf "\n    - Old configuration: %s" "${CERTIFICATED_OLD_CONFIG}"

  if [ "${CERTIFICATED_OLD_CONFIG}" != "${CERTIFICATE_TYPE}" ]; then
    printf "\n    - Restarting configuration... Removing old certificated..."

    rm -rf "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/"*
  fi
fi

# Save actual conf
sed -i "/${DOMAIN_OR_PUBLIC_IP}/d" "${CERTIFICATES_CONF}"
echo -e "${DOMAIN_OR_PUBLIC_IP}\t${CERTIFICATE_TYPE}" >> "${CERTIFICATES_CONF}"

case ${CERTIFICATE_TYPE} in
  "selfsigned")
    if [[ ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/privkey.pem" && \
          ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/fullchain.pem" ]]; then
      printf "\n    - Generating selfsigned certificate...\n"
      
      # Delete and create certificate folder
      rm -rf "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}" | true
      mkdir -p "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}" 

      openssl req -new -nodes -x509 \
        -subj "/CN=${DOMAIN_OR_PUBLIC_IP}" -days 365 \
        -keyout "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/privkey.pem" \
        -out "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/fullchain.pem" \
        -extensions v3_ca
    else
      printf "\n    - Selfsigned certificate already exists, using them..."
    fi
    ;;

  "owncert")
    if [[ ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/privkey.pem" && \
          ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/fullchain.pem" ]]; then
      printf "\n    - Copying owmcert certificate..."

      # Delete and create certificate folder
      rm -rf "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}" | true
      mkdir -p "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}" 

      cp /owncert/privkey.pem "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/privkey.pem"
      cp /owncert/fullchain.pem "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/fullchain.pem"
    else
      printf "\n    - Owmcert certificate already exists, using them..."
    fi
    ;;

  "letsencrypt")
    # Init cron
    /usr/sbin/crond -f &
    echo '0 */12 * * * certbot renew --post-hook "nginx -s reload" >> /var/log/cron-letsencrypt.log' | crontab - # Auto renew cert

    if [[ ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/privkey.pem" && \
          ! -f "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}/fullchain.pem" ]]; then
      printf "\n    - Requesting LetsEncrypt certificate..."

      # Delete certificate folder
      rm -rf "${CERTIFICATES_FOLDER:?}/${DOMAIN_OR_PUBLIC_IP}" | true

      certbot certonly -n --webroot -w /var/www/certbot \
                                    -m "${LETSENCRYPT_EMAIL}" \
                                    --agree-tos -d "${DOMAIN_OR_PUBLIC_IP}"
    else
      printf "\n    - LetsEncrypt certificate already exists, using them..."
    fi
    ;;
esac

# All permission certificated folder
chmod -R 777 /etc/letsencrypt

##---------------------Copy nginx conf---------------------##

if [ "${CONF_MODIFICATION}" == "false" ]; then 
  # Use certificates in folder '/default_nginx_conf'
  if [[ "${CERTIFICATE_TYPE}" == "selfsigned" || \
      "${CERTIFICATE_TYPE}" == "letsencrypt" || \
      "${CERTIFICATE_TYPE}" == "owncert" ]]; then 
        mv /default_nginx_conf/ssl/default-app.conf /default_nginx_conf/default-app.conf
        mv /default_nginx_conf/ssl/default.conf /default_nginx_conf/default.conf
  fi
  if [ "${CERTIFICATE_TYPE}" == "ssldisable" ]; then 
      mv /default_nginx_conf/ssldisable/default-app.conf /default_nginx_conf/default-app.conf
      mv /default_nginx_conf/ssldisable/default.conf /default_nginx_conf/default.conf
  fi
  # Create index.html
  mkdir -p /var/www/html
  cat> /var/www/html/index.html<<EOF
  Welcome to Nginx Server
EOF
fi

if [ "${CONF_MODIFICATION}" == "true" ]; then 
  cp /modified_nginx_conf/* /default_nginx_conf/
fi

rm -rf /default_nginx_conf/ssl
rm -rf /default_nginx_conf/ssldisable

##---------------------Load nginx conf files---------------------##
rm /etc/nginx/conf.d/*
cp /default_nginx_conf/* /etc/nginx/conf.d

sed -i "s/{domain_name}/${DOMAIN_OR_PUBLIC_IP}/g" /etc/nginx/conf.d/*
sed -i "s/{http_port}/${PROXY_HTTP_PORT}/g" /etc/nginx/conf.d/*
sed -i "s/{https_port}/${PROXY_HTTPS_PORT}/g" /etc/nginx/conf.d/*

# Restart nginx service
printf "\n"
printf "\n  ======================================="
printf "\n  =         START NGINX PROXY        ="
printf "\n  ======================================="
printf "\n\n"
nginx -s reload

# nginx logs
tail -f /var/log/nginx/*.log
