ARG PHP_VERSION="8.4"

FROM ubuntu:24.04 AS base

ARG PHP_VERSION

LABEL org.opencontainers.image.description='Ubuntu image with php-fpm, composer 2, XDebug and pcov. PHP packages from the ppa:ondrej/php PPA.'

ENV PHP_VERSION=${PHP_VERSION}
# Config directory of the active PHP version. Downstream images put their ini files in ${PHP_INI_DIR}/mods-available and run phpenmod.
ENV PHP_INI_DIR=/etc/php/${PHP_VERSION}

# Build-time only; as ENV it would hide apt prompts in running containers too.
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=composer:2.10.2 /usr/bin/composer /usr/bin/composer

# Ondřej Surý's PPA ships every PHP version from 7.4 up, with security fixes backported to the end-of-life versions.
# It is the same source as packages.sury.org, but Launchpad builds arm64 at the same time as amd64.
# ondrej-php.gpg is the PPA signing key, fingerprint B8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6 (see the PPA page on Launchpad).
COPY ondrej-php.gpg /usr/share/keyrings/ondrej-php.gpg

RUN apt-get update && \
    apt-get upgrade -y && \
    # apt needs it to reach the PPA over https
    apt-get install -y --no-install-recommends ca-certificates && \
    echo 'deb [signed-by=/usr/share/keyrings/ondrej-php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main' > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    # The extensions the official php images compile in come as separate packages here
    apt-get install -y --no-install-recommends \
      php${PHP_VERSION}-cli \
      php${PHP_VERSION}-curl \
      php${PHP_VERSION}-fpm \
      php${PHP_VERSION}-mbstring \
      php${PHP_VERSION}-mysql \
      php${PHP_VERSION}-pcov \
      php${PHP_VERSION}-sqlite3 \
      php${PHP_VERSION}-xdebug \
      php${PHP_VERSION}-xml \
      # Composer needs it to extract packages
      unzip \
    && \
    rm -rf /var/lib/apt/lists/* && \
    # Ubuntu's php.ini changes error_reporting, display_errors, zend.assertions, memory_limit and variables_order. Without it PHP uses its built-in defaults, like the official php images.
    rm ${PHP_INI_DIR}/cli/php.ini ${PHP_INI_DIR}/fpm/php.ini && \
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
