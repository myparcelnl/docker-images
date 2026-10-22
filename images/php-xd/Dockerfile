ARG PHP_VERSION="8.4"

FROM ubuntu:24.04 AS base

ARG PHP_VERSION

LABEL org.opencontainers.image.description='Ubuntu image with php-fpm, composer 2, XDebug and pcov. PHP packages from packages.sury.org.'

ENV PHP_VERSION=${PHP_VERSION}
# Config directory of the active PHP version. Downstream images put their ini files in ${PHP_INI_DIR}/mods-available and run phpenmod.
ENV PHP_INI_DIR=/etc/php/${PHP_VERSION}
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=composer:2.10.2 /usr/bin/composer /usr/bin/composer

# packages.sury.org ships every PHP version from 7.4 up, with security fixes backported to the end-of-life versions.
ADD https://packages.sury.org/debsuryorg-archive-keyring.deb /tmp/debsuryorg-archive-keyring.deb

RUN apt-get update && \
    apt-get upgrade -y && \
    # apt needs it to reach packages.sury.org over https
    apt-get install -y --no-install-recommends ca-certificates && \
    dpkg -i /tmp/debsuryorg-archive-keyring.deb && \
    rm /tmp/debsuryorg-archive-keyring.deb && \
    echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ noble main' > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      php${PHP_VERSION}-cli \
      php${PHP_VERSION}-fpm \
      php${PHP_VERSION}-pcov \
      php${PHP_VERSION}-xdebug \
      # Composer needs it to extract packages
      unzip \
    && \
    rm -rf /var/lib/apt/lists/* && \
    # Same binary name as the official php images, so `php-fpm` works without the version suffix
    ln -s /usr/sbin/php-fpm${PHP_VERSION} /usr/local/sbin/php-fpm && \
    # Configure XDebug
    printf 'xdebug.mode = off\nxdebug.client_host = host.docker.internal\n' >> ${PHP_INI_DIR}/mods-available/xdebug.ini && \
    # Configure pcov
    printf 'pcov.enabled = 0\npcov.directory = /app\n' >> ${PHP_INI_DIR}/mods-available/pcov.ini

# Run php-fpm in the foreground on port 9000, like the official php images.
COPY zz-docker.conf ${PHP_INI_DIR}/fpm/pool.d/zz-docker.conf

WORKDIR /app

EXPOSE 9000

CMD ["php-fpm"]
