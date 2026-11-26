# MyParcel Docker Images

Docker images we use in our open source projects. All images have `linux/amd64` and `linux/arm64` variants.

## Usage

To build the images using the provided root `docker-compose.yml`, first create `.env`:

```bash
cp .env.template .env
```

You can change the variables in the `.env` file to change which versions of the images are built.

After that, use Docker compose to build the images:

```bash
docker compose build
```

This builds all images, also `magento`, which takes many minutes and some GB. To build one image, give its service name, for example `docker compose build wordpress`.

## Contents

## php-xd

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/php-xd)

PHP images on Ubuntu 24.04 with php-fpm and php-cli from [Ondřej Surý's PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php), Composer 2 and pcov installed, and XDebug enabled. Use them for both CLI and web applications. `php-fpm` listens on port 9000.

Every image uses the same base, so switching PHP versions only means switching the tag: `ghcr.io/myparcelnl/php-xd:<version>`.

The images are rebuilt every week. PHP versions that are end of life (7.4, 8.0, 8.1) only get the security fixes that the PPA backports.

The `wordpress` images in this repo follow every successful `php-xd` build through a `workflow_run` trigger in their workflow; a new image that builds on `php-xd` needs the same trigger. Every Monday `cleanup-ghcr.yml` deletes the untagged versions and the tags no workflow builds anymore from the `php-xd`, `wordpress` and `magento` packages. Images built outside this repo (for example in `docker-shopware` and `pdk`) only pick up a new `php-xd` when you build them with `docker compose build --pull`.

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

WordPress images based on `php-xd`, with pnpm 12 to build the JS of a plugin. The images have no Node.js: pnpm downloads the version from `devEngines.runtime` in the `package.json` of the plugin.

Before November 2026 the `wordpress` images had Node.js and Yarn. Docker keeps using a local image until you pull a new one. After that, a plugin branch that is still on Yarn fails with `ERR_PNPM_OTHER_PM_EXPECTED`. Rebase that branch onto `main`, which brings pnpm. When that is not possible, build the JS with Yarn on your own machine. The weekly cleanup deletes the older images, so you cannot pin one.

> Example: `ghcr.io/myparcelnl/wordpress:6.2.2-php7.4`

### WordPress versions

All versions returned by [the WordPress API](https://api.wordpress.org/core/version-check/1.7/), excluding end-of-life 4.x releases (support floor: 5.2+; CI builds 5.0+).

### PHP versions

- 7.4
- 8.2
- 8.3
- 8.4

## magento

[View on GitHub Container Registry 📦](https://ghcr.io/myparcelnl/magento)

The php container of a Magento Open Source shop with the MyParcel plugin. The image has php-fpm on port 9000, Composer and a Magento that is compiled for production mode. It contains the latest plugin release, the MyParcel seed module and a language pack for each plugin locale. nginx, MariaDB and OpenSearch run in their own containers. The `docker-magento` repository starts the full shop.

Give Docker 4 GB of memory or more. MariaDB, OpenSearch and the first install need it.

### Tags

- `ghcr.io/myparcelnl/magento:<magento>-php<php>`, for example `2.4.8-p5-php8.3`.
- `ghcr.io/myparcelnl/magento:<minor>-php<php>`, for example `2.4.8-php8.3`. This tag moves to the new patch release when `versions.json` gets it.
- A run on a branch pushes only `<branch>-<magento>-php<php>`, for example `feat-magento-image-2.4.8-p5-php8.3`. It does not change the two tags above.

`build-magento.yml` builds the images every Monday, after a change in `images/magento` and when you start it manually. Each build installs the latest plugin release. The labels `nl.myparcel.plugin.version` and `nl.myparcel.sdk.version` show the installed versions. After the build, CI starts each image with `tests/smoke.sh run`. One extra run on 2.4.8-p5 with PHP 8.3 uses `WITH_SEED=0`.

On `main`, the build pushes only a run tag (`ci-<run id>-<magento>-php<php>`). The two tags above move to the new image only when all smoke tests of that pair pass. When a smoke test fails, the tags stay on the previous image. The weekly GHCR clean-up removes run tags and untagged images after one day, and branch tags after two weeks.

To build and test an image on your machine:

```bash
images/magento/tests/smoke.sh build 2.4.8-p5 8.3
images/magento/tests/smoke.sh run 2.4.8-p5 8.3
```

### Versions

`images/magento/versions.json` holds the matrix. CI reads it. MariaDB and OpenSearch are the versions that the shop uses with that Magento version.

| Magento   | PHP      | MariaDB | OpenSearch |
| --------- | -------- | ------- | ---------- |
| 2.4.6-p15 | 8.2      | 10.11   | 3.10.0     |
| 2.4.7-p10 | 8.2, 8.3 | 11.8    | 3.10.0     |
| 2.4.8-p5  | 8.3, 8.4 | 11.8    | 3.10.0     |
| 2.4.9     | 8.4, 8.5 | 12.3    | 3.10.0     |

> [!WARNING]
> Adobe does not support Magento 2.4.6 since 2026-08-11. The image keeps 2.4.6 only because merchants still run it.
>
> The 2.4.6-p15 build fails in `setup:di:compile` until a plugin release contains myparcelnl/magento PR #1050 (INT-2362). `"allow_failure": true` in `versions.json` keeps CI green until then. Remove the flag after that release.

### Accepted security advisories

Composer does not install a package that has a known security advisory. For each Magento version, `accepted_advisories` in `versions.json` lists the advisory IDs that Composer accepts. A new advisory still stops the build. The Composer audit and `block-insecure` stay on.

| ID                  | Package           | Severity   | Magento              | Reason                                                                                                                                | Accepted   |
| ------------------- | ----------------- | ---------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| PKSA-w9tt-7782-78jx | league/flysystem  | low        | 2.4.6-p15, 2.4.7-p10 | Magento 2.4.6 and 2.4.7 require `^2.4`. No 2.x release has the fix.                                                                   | 2026-11-24 |
| PKSA-kbc7-dq62-pt7d | spomky-labs/otphp | high       | 2.4.6-p15            | Only `Magento_TwoFactorAuth` uses this package, and the image disables that module. Magento 2.4.6 requires `^10.0`, which has no fix. | 2026-11-24 |
| PKSA-qv5y-crcz-9nxw | spomky-labs/otphp | medium     | 2.4.6-p15            | Same as PKSA-kbc7-dq62-pt7d.                                                                                                          | 2026-11-24 |
| PKSA-t85t-2sdq-9qvz | spomky-labs/otphp | none given | 2.4.6-p15            | Same as PKSA-kbc7-dq62-pt7d.                                                                                                          | 2026-11-24 |

### Temporary plugin patch

Plugin 5.11.0 fails `setup:di:compile` on PHP 8.4 and 8.5, because it has implicitly nullable parameters. The build applies the diff of myparcelnl/magento PR #1015 (`patches/plugin-php84-nullable.patch`) to the plugin on all images. The plugin label then ends in `+php84-patch`. When a plugin release contains the fix, the build log tells you to remove the patch. When the patch does not apply anymore, the build fails. The patch does not apply to a branch or a local checkout: on PHP 8.4 and 8.5, use a branch that contains PR #1015.

### Environment variables

| Variable                                                        | Default                                           | Meaning                                                                                 |
| --------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `BASE_URL`                                                      | `localhost`                                       | Host name, without scheme                                                               |
| `FULL_URL`                                                      | `https://${BASE_URL}`                             | Base URL that Magento uses. Localhost mode sets `http://`                               |
| `PLUGIN_VERSION`                                                | (empty)                                           | Composer constraint, for example `dev-INT-1234`. Empty: keep the release from the build |
| `SDK_VERSION`                                                   | (empty)                                           | Same, for the SDK                                                                       |
| `PLUGIN_PATH` / `SDK_PATH` / `HYVA_MODULE_PATH`                 | (empty)                                           | Path of a mounted checkout. Empty: the checkout in `plugins/<name>`, if one is mounted  |
| `MAGENTO_MODE`                                                  | `production`                                      | `production` or `developer`                                                             |
| `ADMIN_USER` / `ADMIN_PASSWORD`                                 | `admin` / `admin123`                              | Admin login that the install creates. The log hides a password that is not the default  |
| `WITH_SEED`                                                     | `1`                                               | Run the seed module on the first install                                                |
| `WITH_HYVA`                                                     | `0`                                               | Hook for the Hyvä add-on. Does nothing in the first version                             |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD`   | `db` / `3306` / `magento` / `magento` / `magento` | Database connection                                                                     |
| `OPENSEARCH_HOST` / `OPENSEARCH_PORT`                           | `opensearch` / `9200`                             | Search engine                                                                           |
| `OPENSEARCH_SCHEME` / `OPENSEARCH_USER` / `OPENSEARCH_PASSWORD` | `http` / (empty) / (empty)                        | For a managed OpenSearch with login                                                     |
| `OPENSEARCH_INDEX_PREFIX`                                       | `magento`                                         | Lets more than one shop use the same OpenSearch                                         |
| `MAGENTO_CRYPT_KEY`                                             | (empty)                                           | Fixed crypt key. Necessary when the database stays but `app/etc/env.php` does not       |
| `SMTP_HOST`                                                     | (empty)                                           | Mail goes to `$SMTP_HOST:1025` when you set it. Otherwise Magento discards the mail     |

### Notes

- The image disables two-factor authentication (`Magento_TwoFactorAuth`, `Magento_AdminAdobeImsTwoFactorAuth`) and all PayPal Braintree modules (`PayPal_Braintree*`). The Braintree admin script needs Prototype.js, which the Magento admin does not load. It stops the JavaScript on every configuration page, also the MyParcel settings. A shop that has the old image gets these modules disabled on its first start with the new image.
- When `PLUGIN_VERSION` is empty and the plugin requires one exact SDK version, `SDK_VERSION=dev-main` gets an alias to that version (`dev-main as <version>`). Otherwise, write the alias yourself. A value that already has `as` stays as it is.
- A container does not pull a branch again when it restarts. To get the new commits, remove `/var/www/html/.plugin-modes-applied` and restart the php container.
- A branch can have a higher `setup_version` than the release. To go back to the release after such a branch, remove the volumes with `docker compose down -v`.
- With `WITH_SEED=0` the start disables the seed module. After each image update, the start disables it again and compiles DI again, so that start takes longer.
- The start uses a checkout at `/var/www/html/plugins/magento`, `/var/www/html/plugins/sdk` or `/var/www/html/plugins/hyva-checkout` when the matching `*_PATH` is empty. It looks for `composer.json`, so an empty folder is not a checkout. A set `*_PATH` wins. A set `PLUGIN_VERSION` or `SDK_VERSION` also wins: the start then does not use that checkout and logs this. `PLUGIN_VERSION` together with `PLUGIN_PATH` stops the start (the same for the SDK).
- Mount a local checkout at `/var/www/html/plugins/<name>`, inside the Magento root. Magento deploys static files relative to its root, so a module outside the root fails. The code sync from the image does not touch `plugins/`.
- `setup:di:compile` loads all PHP files in a local checkout, also its own `vendor/`. Mount a tmpfs over the `vendor/` of the checkout in the php container, for example `tmpfs: [/var/www/html/plugins/magento/vendor]`. If you do not, the start stops with an error for the plugin and the Hyvä module. The SDK is not a Magento module and does not need it.

## Contributing

Requirements:

- Node.js 24, version 24.21 or later
- pnpm 12, version 12.11 or later
- No Volta on your machine. Its `yarn` does not go through corepack, so the `packageManager` field in `package.json` does not stop it.

Install the dependencies with `pnpm install`.
