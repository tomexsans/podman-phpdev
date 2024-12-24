#!/bin/bash

# Set pod name
POD_NAME=php-dev-env-pod

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
        fastcgi_pass dev-php-fpm:9000;  # Name of the PHP-FPM container and port (inside the pod)
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    error_page 404 /404.html;
    location = /404.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Create custom PHP configuration file (custom.ini and php-fpm.conf)
touch ./php/config/custom.ini
touch ./php/config/php-fpm.conf

# Create a simple HTML page in src/html/index.html
cat <<EOF > ./src/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello</title>
</head>
<body>
    <h1>Hello From the Other Side</h1>
</body>
</html>
EOF

# Create a simple PHP page in src/html/index.php
cat <<EOF > ./src/html/index.php
<?php
phpinfo();
EOF

# Create the Pod with the PORTS
podman pod create --name ${POD_NAME} -p 80:80 -p 8080:8080 -p 5432:5432 -p 9000:9000 -p 11211:11211

# In case of an error (Rootless Podman and ports < 1024)
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

# Create PostgreSQL Container
podman run -d --pod ${POD_NAME} --name dev-php-postgres \
    -v ./postgres/data:/var/lib/postgresql/data \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=pass \
    -e POSTGRES_DB=mydatabasedatabase \
    bitnami/postgresql

# Create Nginx Container
podman run -d --pod ${POD_NAME} --name dev-php-nginx \
    -v ./nginx/config:/etc/nginx/conf.d \
    -v ./src/html:/usr/share/nginx/html \
    -v ./src:/var/www \
    nginx

# Create PHP-FPM Container
podman run -d --pod ${POD_NAME} --name dev-php-fpm \
    -v ./src:/var/www \
    -v ./php/config/custom.ini:/opt/bitnami/php/etc/conf.d/custom.ini \
    bitnami/php-fpm

# Create Memcached Container
podman run -d --pod ${POD_NAME} --name dev-php-memcached memcached