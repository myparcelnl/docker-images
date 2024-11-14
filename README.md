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

PHP images based on `php:<version>-alpine`, with Composer 2.5 and XDebug.

### PHP versions

- 7.1 (XDebug 2.9.8)
- 7.2 (XDebug 3.1.6)
- 7.3 (XDebug 3.1.6)
- 7.4 (XDebug 3.1.6)
- 8.0 (latest XDebug 3)
- 8.1 (latest XDebug 3)
- 8.2 (latest XDebug 3)
- 8.3 (latest XDebug 3)

## prestashop

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/prestashop)

PrestaShop images based on `php-xd`.

> Example: `ghrc.io/myparcelnl/prestashop:8.0.1-php8.2`

### PrestaShop versions

All [tags in the `prestashop/prestashop` repository](https://api.github.com/repos/PrestaShop/PrestaShop/tags).

### PHP versions

- 7.1
- 7.4
- 8.0
- 8.1
- 8.2

## shopware

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/shopware)

Shopware images based on `php-xd`.

> Example: `ghrc.io/myparcelnl/shopware:6.5-php8.2`

### Shopware versions

- 6.5 (latest)

### PHP versions

- 8.2
- 8.1

## wordpress

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/wordpress)

WordPress images based on `php-xd`.

> Example: `ghrc.io/myparcelnl/wordpress:6.2.2-php7.4`

### WordPress versions

All versions returned by [the WordPress API](https://api.wordpress.org/core/version-check/1.7/).

### PHP versions

- 7.4
- 8.2
