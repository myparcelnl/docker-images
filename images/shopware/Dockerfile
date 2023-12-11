ARG PHP_VERSION="8.1"

##########
# Shopware
##########
FROM ghcr.io/myparcelnl/php-xd:${PHP_VERSION}-fpm-alpine AS shopware

ARG NODE_VERSION="16"
ARG SW_VERSION="6.5.0.0"
ARG XDEBUG_VERSION="3.1.6"
ARG YARN_VERSION="3.3.0"

ARG ROOT_DIR=/var/www/html

WORKDIR ${ROOT_DIR}

RUN apk upgrade && \
    # Add dependencies
    apk add --no-cache \
      # ext-gd
      freetype-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      # ext-intl
      icu-dev \
      libzip-dev \
      # Used in enable-modules.sh
      sudo \
      # Includes envsubst
      gettext \
      # needed for wait-for-it
      bash \
      # used in installation
      mysql-client \
      # For building assets
      "nodejs>${NODE_VERSION}" \
      npm \
      $PHPIZE_DEPS \
    && \
    docker-php-ext-configure gd \
      --with-jpeg \
      --with-freetype  \
    && \
    # Install php extensions
    docker-php-ext-install \
      pdo_mysql \
      zip \
      gd \
      intl \
      bcmath \
    && \
    # Install apcu
    pecl install apcu && \
    docker-php-ext-enable apcu &&  \
    # Install wait-for-it
    curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/local/bin/wait-for-it && \
    chmod +x /usr/local/bin/wait-for-it && \
    # Set composer cache directory
    composer config --global cache-dir /tmp/.cache/composer && \
    # Create Shopware project \
    COMPOSER_MEMORY_LIMIT=-1 composer create-project shopware/production:${SW_VERSION} . && \
    # Remove default env files
    rm -f .env .env.dist && \
    touch .env .env.dist && \
    # Set up yarn
    npm i -g yarn && \
    yarn set version ${YARN_VERSION} && \
    # Configure yarn \
    yarn config set --home enableTelemetry 0 && \
    yarn config set enableGlobalCache true && \
    yarn config set globalFolder /tmp/.cache/yarn && \
    yarn config set logFilters --json '[ {"code":"YN0060","level":"discard"}, {"code":"YN0002","level":"discard"} ]' && \
    yarn config set nmHoistingLimits workspaces && \
    yarn config set nodeLinker node-modules && \
    yarn plugin import workspace-tools && \
    # Add workspaces
    npm pkg set \
      "workspaces[]=platform/src/Storefront/Resources/app/storefront" \
      "workspaces[]=platform/src/Administration/Resources/app/administration" && \
    # Clear caches
    npm cache clean --force && \
    rm -rf /var/cache/apk/* && \
    # Reset permissions
    find .    -not -user www-data -exec chown www-data {} \; && \
    find /tmp -not -user www-data -exec chown www-data {} \; && \
    # Remove composer.lock files to avoid issues with composer install
    find . -name "composer.lock" -delete

RUN version="$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;")" \
    architecture="$(uname -m)" && \
    mkdir -p /tmp/blackfire && \
	  # Install Blackfire client
    curl -A "Docker" -L "https://blackfire.io/api/v1/releases/cli/linux/$architecture" | tar zxp -C /tmp/blackfire && \
    mv /tmp/blackfire/blackfire /usr/bin/blackfire && \
    # Install Blackfire probe
    curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s "https://blackfire.io/api/v1/releases/probe/php/linux/$architecture/$version" && \
    tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire && \
    mv /tmp/blackfire/blackfire-*.so "$(php -r "echo ini_get ('extension_dir');")/blackfire.so" && \
    rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

# add utilities
RUN apk add --no-cache \
      vim \
      # For zipping the plugin
      zip \
      zsh

COPY ./config/.psh.yaml.override.template /tmp/.psh.yaml.override.template
COPY ./config/nginx                       /etc/nginx
COPY ./config/php                         /usr/local/etc/php
COPY ./config/root                        .
COPY ./scripts                            /tmp/scripts

ENV YARN_VERSION=${YARN_VERSION}
ENV SW_VERSION=${SW_VERSION}
ENV PHP_VERSION=${PHP_VERSION}
ENV XDEBUG_VERSION=${XDEBUG_VERSION}

ENV ROOT_DIR=${ROOT_DIR}

CMD ["/tmp/scripts/entrypoint.sh"]
