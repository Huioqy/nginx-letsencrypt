# nginx-letsencrypt


## Domain name. 
If you do not have one, the public IP of the machine. For example: 198.51.100.1, or hello.example.com

        DOMAIN_OR_PUBLIC_IP=hello.example.com

## Certificate type:
- selfsigned: Self signed certificate. Not recommended for production use.
- owncert: Valid certificate purchased in a Internet services company. Please put the certificates files inside folder ./owncert with names certificate.key and certificate.cert
- letsencrypt: Generate a new certificate using letsencrypt. Please set the required contact email for Let's Encrypt in LETSENCRYPT_EMAIL variable.
- ssldisable: Disable ssl.

        CERTIFICATE_TYPE=letsencrypt

- If CERTIFICATE_TYPE=letsencrypt, you need to configure a valid email for notifications

        LETSENCRYPT_EMAIL=user@example.com

## Proxy configuration

- Allows any request to http://DOMAIN_OR_PUBLIC_IP:HTTP_PORT/ to be automatically, redirected to https://DOMAIN_OR_PUBLIC_IP:HTTPS_PORT/.
WARNING: the default port 80 cannot be changed during the first bootif you have chosen to deploy with the option CERTIFICATE_TYPE=letsencrypt

        HTTP_PORT=80

- Changes the port of all services exposed to connect to this port

        HTTPS_PORT=443

## Nginx Conf Modification

- If want to modify the nginx conf files, set CONF_MODIFICATION=true. And then put all the nginx conf files inside the "./modified_nginx_conf" near the docker-compose.yml




