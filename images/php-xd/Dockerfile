ARG PHP_VERSION="7.2"
ARG ALPINE_VERSION=""
ARG TYPE=""

FROM php:${PHP_VERSION}${TYPE}-alpine${ALPINE_VERSION} AS base

LABEL org.opencontainers.image.description='Alpine image with php, composer 2, XDebug and pcov.'

RUN if [ $(php -r "echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;") = "71" ]; then \
        export COMPOSER_VERSION="2.2.0"; \
        export XDEBUG_VERSION="2.9.8"; \
    else \
        export COMPOSER_VERSION="2.5.3"; \
        export XDEBUG_VERSION=""; \
        if [ $(php -r "echo PHP_MAJOR_VERSION;") = "7" ]; then \
            export XDEBUG_VERSION="3.1.6"; \
        fi \
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
    touch /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
    # Configure XDebug
    if [ "${XDEBUG_VERSION:0:1}" = "2" ]; then \
        echo 'xdebug.remote_enable = 0' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.remote_autostart = 0' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini && \
        echo 'xdebug.remote_host = host.docker.internal' >> /usr/local/etc/php/conf.d/zzz-xdebug.ini; \
    else \
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
