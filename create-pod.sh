# Create the Pod with the PORTS
podman pod create --name php-dev-pod -p 80:80 -p 8080:8080 -p 5432:5432 -p 9000:9000 -p 11211:11211


# In case of an error (Rootless Podman and ports < 1024)
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

# Create PostgreSQL Container
podman run -d --pod php-dev-pod --name dev-php-postgres \
    -v ./postgres/data:/var/lib/postgresql/data \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=pass \
    -e POSTGRES_DB=mydatabasedatabase \
    bitnami/postgresql

# Create Nginx Container
podman run -d --pod php-dev-pod --name dev-php-nginx \
    -v ./nginx/config:/etc/nginx/conf.d \
    -v ./src/html:/usr/share/nginx/html \
    -v ./src:/var/www \
    nginx

# Create PHP-FPM Container
#   -v ./php/config/php-fpm.conf:/opt/bitnami/php/etc/php-fpm.conf \
podman run -d --pod php-dev-pod --name dev-php-fpm \
    -v ./src:/var/www \
    -v ./php/config/custom.ini:/opt/bitnami/php/etc/conf.d/custom.ini \
    bitnami/php-fpm

# Create Memcached Container
podman run -d --pod php-dev-pod --name dev-php-memcached memcached


