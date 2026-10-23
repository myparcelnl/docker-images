# MyParcel Docker Images

Docker images we use in our open source projects. All images have `linux/amd64` and `linux/arm64` variants.

## Usage

To build the images using the provided root `docker-compose.yml`, first create `.env`:

```bash
cp .env.example .env
```

You can change the variables in the `.env` file to change which versions of the images are built.

After that, use Docker compose to build the images:

```bash
docker compose build
```

## Contents

## php-xd

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/php-xd)

PHP images on Ubuntu 24.04 with php-fpm and php-cli from [Ondřej Surý's PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php), Composer 2 and pcov installed, and XDebug enabled. Use them for both CLI and web applications. `php-fpm` listens on port 9000.

Every image uses the same base, so switching PHP versions only means switching the tag: `ghcr.io/myparcelnl/php-xd:<version>`.

The images are rebuilt every week. PHP versions that are end of life (7.4, 8.0, 8.1) only get the security fixes that the PPA backports.

Images built outside this repo (for example in `docker-shopware` and `pdk`) only pick up a new `php-xd` when you build them with `docker compose build --pull`.

Before October 2026 the images were Alpine based. The `<version>-alpine<alpine version>`, `<version>-fpm-alpine` and `<version>-cli-alpine` tags are not rebuilt anymore and do not get security fixes. A Dockerfile that builds on `php-xd` and uses `apk`, `docker-php-ext-install` or `pecl` needs the `apt-get` commands below instead.

### PHP versions

- 7.4 (XDebug 3.1.6)
- 8.0 (latest XDebug 3)
- 8.1 (latest XDebug 3)
- 8.2 (latest XDebug 3)
- 8.3 (latest XDebug 3)
- 8.4 (latest XDebug 3)
- 8.5 (latest XDebug 3)

### Adding extensions in a downstream image

Install the PPA package for the extension. `PHP_VERSION` and `PHP_INI_DIR` (`/etc/php/<version>`) are set in the image.

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends php${PHP_VERSION}-zip && \
    rm -rf /var/lib/apt/lists/*
```

To add PHP settings, put an ini file in `${PHP_INI_DIR}/mods-available` and enable it for cli and fpm with `phpenmod`:

```dockerfile
RUN echo 'memory_limit = 512M' > ${PHP_INI_DIR}/mods-available/memory-limit.ini && \
    phpenmod memory-limit
```

## wordpress

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/wordpress)

WordPress images based on `php-xd`.

> Example: `ghrc.io/myparcelnl/wordpress:6.2.2-php7.4`

### WordPress versions

All versions returned by [the WordPress API](https://api.wordpress.org/core/version-check/1.7/), excluding end-of-life 4.x releases (support floor: 5.2+; CI builds 5.0+).

### PHP versions

- 7.4
- 8.2
- 8.3
- 8.4
