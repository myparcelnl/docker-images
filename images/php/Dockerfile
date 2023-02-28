ARG PHP_VERSION="7.2"
ARG ALPINE_VERSION=""
ARG TYPE=""

FROM php:${PHP_VERSION}${TYPE}-alpine${ALPINE_VERSION} AS base

LABEL org.opencontainers.image.description='Alpine image with php, composer 2, XDebug and pcov.'

COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer

RUN XDEBUG_SUFFIX=$( [[ $(php -r "echo PHP_MAJOR_VERSION;") -lt 8 ]] && echo '-3.1.6' || echo '') && \
    apk update && \
    # Install dependencies
    apk add --no-cache --virtual .build-deps \
      make \
      linux-headers \
      $PHPIZE_DEPS \
    && \
    # Install and configure xdebug
    pecl install xdebug$XDEBUG_SUFFIX && \
    docker-php-ext-enable xdebug && \
    touch /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    echo 'xdebug.mode = off' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    echo 'xdebug.client_host = host.docker.internal' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    # Install and configure pcov
    pecl install pcov && \
    docker-php-ext-enable pcov && \
    echo 'pcov.enabled = 0' >> /usr/local/etc/php/conf.d/zzz-pcov.ini && \
    echo 'pcov.directory = /app' >> /usr/local/etc/php/conf.d/zzz-pcov.ini && \
    # Clear apk dependencies
    apk del .build-deps

WORKDIR /app
