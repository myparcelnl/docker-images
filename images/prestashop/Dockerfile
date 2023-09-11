ARG PHP_VERSION="8.1"

##########
# Prestashop
##########
FROM ghcr.io/myparcelnl/php-xd:${PHP_VERSION}-fpm-alpine AS prestashop

ARG PS_VERSION="8.0.4"
ARG YARN_VERSION="berry"

ARG ROOT_DIR=/var/www/html

WORKDIR ${ROOT_DIR}

RUN PHP_VERSION="$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;")" && \
    apk update && \
    # Install dependencies
    apk add --no-cache \
      # gd
      freetype-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      # intl
      icu-dev \
      libzip-dev \
      gnu-libiconv \
      # Used in enable-modules.sh
      sudo \
      # needed for wait-for-it
      bash \
      # needed to build themes \
      nodejs \
      npm \
      # For parsing and editing json
      jq \
      # For cloning prestashop
      git \
      $PHPIZE_DEPS \
    && \
    # Configure php extensions \
    # if php version < 74 \
    if [ "${PHP_VERSION}" -lt "74" ]; then \
      docker-php-ext-configure gd \
        --with-jpeg-dir=/usr/include/ \
        --with-freetype-dir=/usr/include/; \
    else \
      docker-php-ext-configure gd \
      --with-jpeg \
      --with-freetype; \
    fi && \
    # Install php extensions
    docker-php-ext-install \
      gd \
      intl \
      mysqli \
      pdo_mysql \
      zip \
    && \
    # Install apcu
    pecl install apcu && \
    docker-php-ext-enable apcu && \
    # Install wait-for-it
    curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/local/bin/wait-for-it && \
    chmod +x /usr/local/bin/wait-for-it && \
    # Create log directory
    mkdir -p /var/log/php-fpm && \
    # Install envsubst \
    curl "https://raw.githubusercontent.com/EdieLemoine/envsubst/main/install.sh" -o /tmp/install-envsubst.sh && \
    sh /tmp/install-envsubst.sh v1.4.0 /usr/local/bin/envsubst && \
    # Clone PrestaShop repository
    git clone --branch "${PS_VERSION}" --depth 1 --single-branch https://github.com/prestashop/prestashop.git . && \
    rm -rf vendor && \
    # Set composer cache location
    composer config --global cache-dir /tmp/.cache/composer && \
    # Set up Yarn
    npm i -g yarn && \
    yarn set version ${YARN_VERSION} && \
    yarn config set --home enableTelemetry 0 && \
    yarn config set enableGlobalCache true && \
    yarn config set globalFolder /tmp/.cache/yarn && \
    yarn config set logFilters --json '[ {"code":"YN0060","level":"discard"}, {"code":"YN0002","level":"discard"} ]' && \
    yarn config set nodeLinker node-modules && \
    yarn plugin import workspace-tools && \
    # Reset permissions
    chown -R www-data . && \
    # Clear cache and unnecessary dependencies
    npm cache clean --force && \
    yarn cache clean && \
    composer clear-cache && \
    apk del git

COPY ./config/php-fpm /usr/local/etc/php-fpm.d
COPY ./config/php     /usr/local/etc/php
COPY ./scripts/       /tmp/scripts

ENV PS_VERSION=${PS_VERSION}
ENV YARN_VERSION=${YARN_VERSION}

ENV ROOT_DIR=${ROOT_DIR}


###
# Core
###
ENV BASE_URL=prestashop.dev.myparcel.nl
ENV FULL_URL=https://${BASE_URL}
ENV ROOT_DIR=/var/www/html

###
# Database
###
ENV DB_HOST=db
ENV DB_PORT=3306
ENV DB_USER=prestashop
ENV DB_PASSWORD=prestashop
ENV DB_NAME=prestashop
ENV DB_PREFIX=ps_

###
# PrestaShop
###
ENV PS_DEV_MODE=1
ENV PS_DOMAIN=${BASE_URL}
ENV PS_ALL_LANGUAGES=0
ENV PS_DB_CLEAR=1
ENV PS_DB_CREATE=1
ENV PS_ENABLE_SSL=1
ENV PS_COUNTRY=NL
ENV PS_LANGUAGE=en
ENV PS_FOLDER_ADMIN=admin1

# Admin credentials
ENV PS_ADMIN_MAIL=admin@${BASE_URL}
ENV PS_ADMIN_PASSWORD=admin


###
# Production
###
FROM prestashop AS prod

CMD ["/tmp/scripts/entrypoint.sh"]


###
# Development
###
FROM prestashop AS dev

COPY ["./config/.zshrc", "/root/.zshrc"]

# Add development tools
RUN apk add --no-cache \
      vim \
      zsh \
      # Needed for oh-my-zsh
      git \
    && \
    # Install oh-my-zsh \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended && \
    # Restore .zshrc
    mv /root/.zshrc.pre-oh-my-zsh /root/.zshrc

    # Add blackfire
RUN version="$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;")" && \
    architecture="$(uname -m)" && \
    mkdir -p /tmp/blackfire && \
	# Install Blackfire client
    curl -A "Docker" -L "https://blackfire.io/api/v1/releases/cli/linux/$architecture" | tar zxp -C /tmp/blackfire && \
    mv /tmp/blackfire/blackfire /usr/bin/blackfire && \
    # Install Blackfire probe
    curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s "https://blackfire.io/api/v1/releases/probe/php/linux/$architecture/$version" && \
    tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire && \
    mv /tmp/blackfire/blackfire-*.so "$(php -r "echo ini_get ('extension_dir');")/blackfire.so" && \
    printf "blackfire.agent_socket=tcp://blackfire:8307\n" > "$PHP_INI_DIR/conf.d/blackfire.ini" && \
    rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

ENV XDEBUG_MODE=debug

SHELL ["/bin/zsh", "-c"]

CMD ["/tmp/scripts/entrypoint.sh"]

