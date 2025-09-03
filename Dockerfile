# Dockerfile (ECS-ready: Nginx + PHP-FPM + Supervisor)
FROM php:8.2-fpm-alpine

# Install system deps: nginx, supervisor, build tools, and PHP extensions
RUN apk add --no-cache nginx supervisor curl git bash icu-dev libzip-dev oniguruma-dev \
    && docker-php-ext-install intl pdo pdo_mysql mbstring zip opcache

# Create web root
WORKDIR /var/www/html

# Copy app (Docker ignores .git by default if .dockerignore present; fine if not)
COPY src/ /var/www/html/

# Nginx config
COPY nginx/default.conf /etc/nginx/http.d/default.conf

# Supervisor config
COPY .docker/supervisord.conf /etc/supervisord.conf

# Permissions
RUN chown -R www-data:www-data /var/www/html \
    && mkdir -p /run/nginx

# Expose HTTP
EXPOSE 80

# Healthcheck (optional, hit the Laravel route)
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD curl -fsS http://localhost/api/health/ready || exit 1

# Start both processes
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]