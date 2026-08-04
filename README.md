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

PHP images based on `php:<version>-fpm-alpine`, with Composer 2.5 and pcov installed, and XDebug enabled. Based on the fpm variant of the official PHP images, so you can use it for both CLI and web applications.

### PHP versions

- 7.4 (XDebug 3.1.6)
- 8.0 (latest XDebug 3)
- 8.1 (latest XDebug 3)
- 8.2 (latest XDebug 3)
- 8.3 (latest XDebug 3)
- 8.4 (latest XDebug 3)

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
