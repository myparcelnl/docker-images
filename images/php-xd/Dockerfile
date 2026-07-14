ARG PHP_VERSION="7.4"
ARG ALPINE_VERSION=""

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS base

LABEL org.opencontainers.image.description='Alpine image with php-fpm, composer 2, XDebug and pcov.'

# XDebug 3.1.6 is the last release supporting PHP 7.x; PHP 8 gets the latest.
RUN export COMPOSER_VERSION="2.10.2" && \
    export XDEBUG_VERSION="" && \
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "7" ]; then \
        export XDEBUG_VERSION="3.1.6"; \
    fi && \
    apk update && \
    # Install dependencies
    apk add --no-cache --virtual .build-deps \
      make \
      linux-headers \
      $PHPIZE_DEPS \
    && \
    # Install composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} && \
    # Install xdebug
    pecl install xdebug${XDEBUG_VERSION:+-${XDEBUG_VERSION}} && \
    docker-php-ext-enable xdebug && \
    # Configure XDebug
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
