ARG PHP_VERSION="7.2"
ARG ALPINE_VERSION=""
ARG TYPE=""

FROM php:${PHP_VERSION}${TYPE}-alpine${ALPINE_VERSION} AS base

LABEL org.opencontainers.image.description='Alpine image with php, composer 2, XDebug and pcov.'

COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer

RUN apk update && \
    # Install dependencies
    apk add --no-cache --virtual .build-deps \
      make \
      linux-headers \
      $PHPIZE_DEPS \
    && \
    # Install and configure xdebug
    # php 7.1
    if [ $(php -r "echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;") = "71" ]; then \
        pecl install xdebug-2.9.8; \
        # Enable xdebug 2
        docker-php-ext-enable xdebug && \
        # Configure xdebug 2
        touch /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.remote_enable = 0' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.remote_autostart = 0' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.remote_host = host.docker.internal' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini; \
    else \
        if [ $(php -r "echo PHP_MAJOR_VERSION;") -ge "8" ]; then \
            # php 8+
            pecl install xdebug; \
        else \
            # php 7.2+
            pecl install xdebug-3.1.6; \
        fi && \
        # Enable xdebug 3
        docker-php-ext-enable xdebug && \
        # Configure xdebug 3
        touch /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.mode = off' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.client_host = host.docker.internal' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini; \
    fi && \
    # Install and configure pcov
    pecl install pcov && \
    docker-php-ext-enable pcov && \
    echo 'pcov.enabled = 0' >> /usr/local/etc/php/conf.d/zzz-pcov.ini && \
    echo 'pcov.directory = /app' >> /usr/local/etc/php/conf.d/zzz-pcov.ini && \
    # Clear apk dependencies
    apk del .build-deps

WORKDIR /app
