#!/bin/bash

# Set pod name
POD_NAME=phpdev3-env
CONTAINER_ALIAS=${POD_NAME}-cont-

# Create necessary directories
mkdir -p nginx/config
mkdir -p php/config
mkdir -p postgres/data
mkdir -p src/html

# Create NGINX default.conf
cat <<EOF > ./nginx/config/default.conf
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

    error_page 404 /404.html;
    location = /404.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Create custom PHP configuration files
cat <<EOF > $(pwd)/php/config/custom.ini
# Disable opcache in the container, if not PHP files are cached
opcache.enable=0
opcache.enable_cli=0
# Enable other Extensions
extension=pdo_pgsql
EOF
touch $(pwd)/php/config/php-fpm.conf

# Create a simple HTML page in src/html/index.html
cat <<EOF > $(pwd)/src/html/index.html
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
cat <<EOF > $(pwd)/src/html/index.php
<?php
echo "Greetings from PODMAN Container (PHP is Running!)";
//phpinfo();
?>
EOF

# Create the Pod with the PORTS
podman pod create --name ${POD_NAME} -p 80:80 -p 8080:8080 -p 5432:5432 \
    -p 9000:9000 -p 11211:11211 \
    -p 5173:5173 -p 5174:5174

# Adjust for Rootless Podman and ports < 1024
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

# Create PostgreSQL Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}postgres \
    -v $(pwd)/postgres/data:/var/lib/postgresql/data \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=pass \
    -e POSTGRES_DB=mydatabase \
    bitnami/postgresql

# Create PHP-FPM Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}php-fpm \
    --mount type=bind,source=$(pwd)/src,target=/var/www,bind-propagation=rshared \
    --mount type=bind,source=$(pwd)/php/config,target=/opt/bitnami/php/etc/conf.d,bind-propagation=rshared \
    bitnami/php-fpm

# Create Nginx Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}nginx \
    -v $(pwd)/nginx/config:/etc/nginx/conf.d \
    -v $(pwd)/src/html:/usr/share/nginx/html \
    -v $(pwd)/src:/var/www \
    nginx

# Create Node.js Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}nodejs \
    -v $(pwd)/src:/var/www \
    node:latest tail -f /dev/null

# Create Memcached Container
podman run -d --pod ${POD_NAME} --name ${CONTAINER_ALIAS}memcached memcached
