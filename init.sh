#!/bin/bash

# Set pod name
POD_NAME=Podman-php-devenv
CONTAINER_ALIAS=${POD_NAME}-cont-

# Define ALl Ports to be used container:host
PORTS=(
  "80:80" #Nginx
  "8080:8080" #used default by laravel app
  "5432:5432" #postgresql
  "9000:9000" # will be used as port for php-fpm latest
  "11211:11211" # memcached
  "5173:5173" #vite
  "5174:5174" #vite
)

#FILE PATHS
NGINX_CONFIG_PATH=$(pwd)/config/nginx/config
PHP_CONFIG_PATH=$(pwd)/config/php/config
POSTGRE_DATA_PATH=$(pwd)/config/postgres/data
POSTGRE_CONFIG_PATH=$(pwd)/config/postgres/config
SOURCE_PATH=../srcFiles

# Create necessary directories
mkdir -p ${NGINX_CONFIG_PATH}
mkdir -p ${PHP_CONFIG_PATH}
mkdir -p ${POSTGRE_DATA_PATH}
mkdir -p ${POSTGRE_CONFIG_PATH}
mkdir -p ${SOURCE_PATH}/html

# Create NGINX default.conf
cat <<EOF > ${NGINX_CONFIG_PATH}/default.conf
server {
    listen 80;  # Listen on port 80 for HTTP traffic
    server_name localhost;  # Server name or IP address

    root /var/www/html;  # Document root directory
    index index.php index.html index.htm;  # Default index files

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;  # This ensures NGINX tries PHP if the file doesn't exist
    }

    # PHP-FPM handling
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass ${CONTAINER_ALIAS}php-fpm:9000;  # Name of the PHP-FPM container and port (inside the pod)
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    ## Sample template to support other PHP versions multiple
    #location ~ \.php$ {
    #    include fastcgi_params;
    #    fastcgi_pass ${CONTAINER_ALIAS}php-fpm8.3:9000;  # Name of the PHP-FPM container and port (inside the pod)
    #    fastcgi_index index.php;
    #    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    #}

    error_page 404 /404.html;
    location = /404.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Create custom PHP configuration files
cat <<EOF > ${PHP_CONFIG_PATH}/custom.ini
# Disable opcache in the container, if not PHP files are cached
opcache.enable=0
opcache.enable_cli=0
# Enable other Extensions
extension=pdo_pgsql
EOF
touch ${PHP_CONFIG_PATH}/php-fpm.conf

# Create a simple HTML page in src/html/index.html
cat <<EOF > ${SOURCE_PATH}/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello</title>
</head>
<body>
    <h1>Greetings from PODMAN Container</h1>
</body>
</html>
EOF

# Create a simple PHP page in src/html/index.php
cat <<EOF > ${SOURCE_PATH}/html/index.php
<?php
echo "Greetings from PODMAN Container (PHP is Running!)";
//phpinfo();
?>
EOF

# Create the Pod with the PORTS
# Port 74784 will be used for PHP-FPM socket to parse php-8.4
# Add ports here if you plan to support multiple PHP 74783 is added also
# Create the pod with the ports
POD_CREATE_CMD="podman pod create --name ${POD_NAME}"

for PORT in "${PORTS[@]}"; do
  POD_CREATE_CMD+=" -p $PORT"
done
# Execute the command
echo "Executing: $POD_CREATE_CMD"
eval "$POD_CREATE_CMD"

# Adjust for Rootless Podman and ports < 1024
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

# Create PostgreSQL Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}postgres \
    -v ${POSTGRE_DATA_PATH}:/bitnami/postgresql \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=pass \
    -e POSTGRES_DB=mydatabase \
    bitnami/postgresql

# Create PHP-FPM Container for PHP Latest version, bind to port 9000
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}php-fpm \
    --mount type=bind,source=${SOURCE_PATH},target=/var/www,bind-propagation=rshared \
    --mount type=bind,source=${PHP_CONFIG_PATH},target=/opt/bitnami/php/etc/conf.d,bind-propagation=rshared \
    bitnami/php-fpm

## Create PHP-FPM container for a specific php version
## https://hub.docker.com/r/bitnami/php-fpm
#podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}php-fpm8.3 \
#    --mount type=bind,source=${SOURCE_PATH},target=/var/www,bind-propagation=rshared \
#    --mount type=bind,source=${PHP_CONFIG_PATH},target=/opt/bitnami/php/etc/conf.d,bind-propagation=rshared \
#    bitnami/php-fpm:8.3



# Create Nginx Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}nginx \
    -v ${NGINX_CONFIG_PATH}:/etc/nginx/conf.d \
    -v ${SOURCE_PATH}/html:/usr/share/nginx/html \
    -v ${SOURCE_PATH}:/var/www \
    nginx

# Create Node.js Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}nodejs \
    -v ${SOURCE_PATH}:/var/www \
    node:latest tail -f /dev/null

# Create Memcached Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}memcached memcached
