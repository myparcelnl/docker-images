# syntax=docker/dockerfile:1
# The php container of a Magento shop: php-fpm, Composer and a compiled Magento with the MyParcel plugin.
# nginx, MariaDB and OpenSearch run in their own containers. Magento is in /opt/magento; the entrypoint
# copies it into the shared web-data volume at /var/www/html, which is empty in the image.
ARG PHP_VERSION="8.3"

FROM php:${PHP_VERSION}-fpm-trixie AS base

ARG PHP_VERSION
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=composer:2.10.2 /usr/bin/composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer:2.13.1 /usr/bin/install-php-extensions /usr/local/bin/

# PHP extensions from the Adobe Open Source requirements, plus ftp (magento/framework requires it) and pcov.
# ctype, curl, dom, fileinfo, mbstring, simplexml and sodium are compiled into the official image.
RUN install-php-extensions bcmath ftp gd intl opcache pcov pdo_mysql soap sockets xsl zip && \
    for ext in bcmath ctype curl dom fileinfo ftp gd intl mbstring pcov pdo_mysql simplexml soap sockets sodium xsl zip "Zend OPcache"; do \
      php -m | grep -qixF "$ext" || { echo "PHP extension $ext is missing" >&2; exit 1; }; \
    done

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      jq \
      less \
      mariadb-client \
      msmtp \
      procps \
      rsync \
      unzip \
      vim \
      zsh \
    && \
    rm -rf /var/lib/apt/lists/*

COPY config/php/conf.d/ ${PHP_INI_DIR}/conf.d/
COPY config/php-fpm/    /usr/local/etc/php-fpm.d/
COPY config/bin/        /usr/local/bin/
COPY scripts/build/     /usr/local/lib/magento-scripts/build/
COPY patches/           /usr/local/lib/magento-patches/

RUN mkdir -p /opt/magento /var/www/html /usr/local/share/magento-image && \
    chown www-data:www-data /opt/magento /var/www /var/www/html /usr/local/share/magento-image && \
    # The official image makes it world-writable (1777)
    chmod 755 /var/www/html

##########
# Magento
##########
FROM base AS magento

ARG PHP_VERSION
ARG MAGENTO_VERSION="2.4.8-p5"
# JSON list of advisory IDs from versions.json that Composer may install anyway
ARG ACCEPTED_ADVISORIES="[]"

ENV COMPOSER_HOME=/var/www/.composer \
    COMPOSER_CACHE_DIR=/tmp/.cache/composer \
    COMPOSER_NO_INTERACTION=1 \
    MAGENTO_VERSION=${MAGENTO_VERSION}

WORKDIR /opt/magento
USER www-data

# A new value runs Composer again instead of using the cached layers. CI passes the run date, so that the
# weekly build gets the new plugin release and the dependency fixes.
ARG CACHE_BUST=""

# The cache mount keeps the Composer cache out of the image layers.
# The accepted advisories go to the global config for create-project, then to the project's composer.json.
RUN --mount=type=cache,target=/tmp/.cache/composer,uid=33,gid=33 \
    mkdir -p "$COMPOSER_HOME" && \
    jq -n --argjson ids "$ACCEPTED_ADVISORIES" '{config: {policy: {advisories: {"ignore-id": $ids}}}}' \
      > "$COMPOSER_HOME/config.json" && \
    composer create-project --repository-url=https://mirror.mage-os.org/ \
      "magento/project-community-edition:${MAGENTO_VERSION}" . && \
    rm "$COMPOSER_HOME/config.json" && \
    # Drop repo.magento.com: it needs keys
    jq --argjson ids "$ACCEPTED_ADVISORIES" \
      'del(.repositories) | if ($ids | length) > 0 then .config.policy.advisories["ignore-id"] = $ids else . end' \
      composer.json > composer.json.new && \
    mv composer.json.new composer.json && \
    composer config repositories.mage-os composer https://mirror.mage-os.org/ && \
    # The plugin releases need the SDK beta; prefer-stable keeps every other package stable
    composer config minimum-stability beta && \
    composer config prefer-stable true

RUN --mount=type=cache,target=/tmp/.cache/composer,uid=33,gid=33 \
    composer require myparcelnl/magento && \
    # Temporary until a plugin release has PR #1015 (PHP 8.4 nullable types)
    /usr/local/lib/magento-scripts/build/patch-plugin.sh && \
    # Community language packs (Magento Community Engineering, Crowdin) for the plugin locales; en_US is in core
    packs="$(/usr/local/lib/magento-scripts/build/locales.sh | grep -vx en_US | tr 'A-Z' 'a-z' | sed 's#^#community-engineering/language-#')" && \
    composer require ${packs}

COPY --chown=www-data:www-data seed/ /var/www/seed/

RUN --mount=type=cache,target=/tmp/.cache/composer,uid=33,gid=33 \
    composer config repositories.seed path /var/www/seed && \
    composer require myparcelnl/magento-dev-seed:@dev

# Writes app/etc/config.php and compiles for production mode. There is no database and no env.php.
# Braintree: see scripts/build/braintree-modules.sh
RUN bin/magento module:enable --all && \
    braintree="$(/usr/local/lib/magento-scripts/build/braintree-modules.sh)" && \
    bin/magento module:disable Magento_TwoFactorAuth Magento_AdminAdobeImsTwoFactorAuth ${braintree} && \
    bin/magento setup:di:compile && \
    # di:compile writes an env.php with only cache_types; each container must create its own on install
    rm app/etc/env.php

ARG SCD_ON_START=false

# Versions with scd_on_start in versions.json deploy static content on the first start instead
RUN if [ "${SCD_ON_START}" != true ]; then \
      /usr/local/lib/magento-scripts/build/static-content-deploy.sh; \
    fi && \
    test ! -e app/etc/env.php && \
    ! grep -q "'scopes'" app/etc/config.php

# The entrypoint syncs /opt/magento into the web-data volume when this ID differs from the one there
ARG IMAGE_ID=""
RUN printf '%s\n' "${IMAGE_ID:-${MAGENTO_VERSION}-php${PHP_VERSION}-$(date -u +%Y%m%dT%H%M%SZ)}" > .image-id

USER root
WORKDIR /var/www/html
ENV PATH="/var/www/html/bin:${PATH}"

# Last, so that a change in the start scripts does not rebuild Magento
COPY scripts/*.sh /usr/local/lib/magento-scripts/

LABEL org.opencontainers.image.source="https://github.com/myparcelnl/docker-images" \
      org.opencontainers.image.description="php container for a Magento Open Source shop with the MyParcel plugin." \
      org.opencontainers.image.version="${MAGENTO_VERSION}-php${PHP_VERSION}"

EXPOSE 9000

CMD ["/usr/local/lib/magento-scripts/entrypoint.sh"]
