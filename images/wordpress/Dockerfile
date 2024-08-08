ARG PHP_VERSION="7.4"

##########
# WordPress
##########
FROM ghcr.io/myparcelnl/php-xd:${PHP_VERSION}-fpm-alpine AS wordpress

ARG WP_VERSION="6.1.1"

ARG ROOT_DIR=/var/www/html

WORKDIR ${ROOT_DIR}

RUN apk update && \
    # Install dependencies
    apk add --no-cache \
      # To run in AWS
      nginx \
      # Needed for php extensions
      $PHPIZE_DEPS \
      # needed for wait-for-it
      bash \
      # Needed for wp-cli
      less \
      # For zip extension
      libzip-dev \
      # Needed for database connection
      mysql-client \
      # Needed to build JS
      npm \
      nodejs \
      # Used to not have to switch user
      sudo && \
    # Install php extensions
    docker-php-ext-install \
      mysqli \
      opcache \
      pdo_mysql \
      zip && \
    pecl install redis && \
    rm -rf /tmp/pear && \
    docker-php-ext-enable redis && \
    # Install wp-cli
    curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp && \
    # Install wait-for-it
    curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -o /usr/local/bin/wait-for-it && \
    chmod +x /usr/local/bin/wait-for-it && \
    # Create log directory
    mkdir -p /var/log/php-fpm && \
    # Set composer cache location
    composer config --global cache-dir /tmp/.cache/composer && \
    # Set up Yarn
    npm i -g yarn && \
    # Clear cache and unnecessary dependencies
    npm cache clean --force && \
    yarn cache clean && \
    composer clear-cache && \
    # Install envsubst \
    curl "https://raw.githubusercontent.com/EdieLemoine/envsubst/main/install.sh" -o /tmp/install-envsubst.sh && \
    sh /tmp/install-envsubst.sh v1.4.0 /usr/local/bin/envsubst && \
    rm /tmp/install-envsubst.sh && \
    chmod +x /usr/local/bin/envsubst && \
    # Fix folders and permissions
    mkdir -p ./wp-content/plugins && \
    mkdir -p ./wp-content/themes && \
    mkdir -p ./wp-content/upgrade && \
    mkdir -p ./wp-content/uploads && \
    # Reset permissions
    chown -R www-data .

COPY ./scripts/         /tmp/scripts
COPY ./config/php-fpm   /usr/local/etc/php-fpm.d
COPY ./config/php       /usr/local/etc/php
COPY ./config/wordpress /tmp/wordpress
# Copy nginx config
COPY ./etc/nginx/http.d/* /etc/nginx/http.d/

ENV WP_VERSION=${WP_VERSION}

ENV ROOT_DIR=${ROOT_DIR}

###
# Core
###
ENV BASE_URL=localhost:8130
ENV FULL_URL=https://${BASE_URL}
ENV ROOT_DIR=/var/www/html

###
# Database
###
ENV DB_HOST=db
ENV DB_PORT=3306
ENV DB_USER=wordpress
ENV DB_PASSWORD=wordpress
ENV DB_NAME=wordpress
ENV DB_PREFIX=wp_

###
# WordPress
###
ENV WP_LOCALE=nl_NL
ENV WP_SITE_NAME=wordpress
ENV WP_URL_REPLACE=${FULL_URL}
ENV WP_PLUGINS=woocommerce
ENV WP_THEMES=storefront
ENV WP_DEBUG=true
ENV WP_DEBUG_DISPLAY=true
ENV WP_ALTERNATE_WP_CRON=true

ENV WP_ADMIN_EMAIL=admin@${BASE_URL}
ENV WP_ADMIN_USER=admin
ENV WP_ADMIN_PASSWORD=admin

ENV WP_CUSTOMER_EMAIL=customer@${BASE_URL}
ENV WP_CUSTOMER_USER=customer
ENV WP_CUSTOMER_PASSWORD=customer


###
# Production
###
FROM wordpress AS prod

CMD ["/tmp/scripts/entrypoint.sh"]


###
# Development
###
FROM wordpress AS dev

COPY ["./config/.zshrc", "/root/.zshrc"]

# Add development tools
RUN apk add --no-cache \
      vim \
      zsh  \
      # Needed for oh-my-zsh
      git \
    && \
    # Install oh-my-zsh \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended && \
    # Restore .zshrc
    mv /root/.zshrc.pre-oh-my-zsh /root/.zshrc && \
    # Add blackfire
    version="$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;")" && \
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

