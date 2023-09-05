# MyParcel Docker Images

Docker images we use in our open source projects.

## Contents

## php-xd

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/php-xd)

PHP images based on `php:<version>-alpine`, with Composer 2.5 and XDebug.

### Platforms

- linux/amd64
- linux/arm64

### PHP versions

- 7.1 (XDebug 2.9.8)
- 7.2 (XDebug 3.1.6)
- 7.3 (XDebug 3.1.6)
- 7.4 (XDebug 3.1.6)
- 8.0 (latest XDebug 3)
- 8.1 (latest XDebug 3)
- 8.2 (latest XDebug 3)

## wordpress

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/wordpress)

WordPress images based on `php-xd`.

### Platforms

- linux/amd64
- linux/arm64

### WordPress versions

All versions returned by [the WordPress API](https://api.wordpress.org/core/version-check/1.7/).

### PHP versions

- 8.2
- 7.4
