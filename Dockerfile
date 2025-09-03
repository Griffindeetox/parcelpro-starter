# ---- Runtime image for local dev (no app code copied at build) ----
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# system deps + php extensions for Laravel
RUN apk add --no-cache bash icu-dev libzip-dev oniguruma-dev git zip unzip curl \
    && docker-php-ext-install pdo_mysql opcache intl

# install Composer globally
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm /tmp/composer-setup.php

# create non-root user that matches container usage
RUN adduser -D -H app && chown -R app:app /var/www/html
USER app

# php-fpm in foreground
CMD ["php-fpm", "-F"]
