ARG PHP_VERSION=7.2

FROM php:${PHP_VERSION}-alpine AS base

LABEL org.opencontainers.image.description='Alpine image with php, composer 2 and XDebug.'

COPY --from=composer:2.3 /usr/bin/composer /usr/bin/composer

RUN apk update && \
    apk add --no-cache \
        # Dependencies needed for installing XDebug
        $PHPIZE_DEPS && \
    composer selfupdate --2 && \
    # Install XDebug
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    touch /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    echo 'xdebug.mode = coverage' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    echo 'xdebug.client_host = host.docker.internal' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini

WORKDIR /app
