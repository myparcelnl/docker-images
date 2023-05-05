# syntax=docker/dockerfile:1.4

########################################################################################################################
# Dockerfile for Elasticsearch 6, using Ubuntu as base image.
#
# This ES image is more stable and secure than the official Dockerfile created by the vendor itself. It's designed to be
# a drop-in replacement for the official image, so all the paths and environment variables are kept identical to the
# official Dockerfile.
########################################################################################################################

ARG DISTRIB_CODENAME="focal"
ARG ES_INSTALL_DIR="/usr/share/elasticsearch"

########################################################################################################################
# Build stage.
########################################################################################################################
FROM ubuntu:${DISTRIB_CODENAME} AS build

ARG DEBIAN_FRONTEND="noninteractive"

# Install platform dependencies.
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,sharing=locked,target=/var/lib/apt set -o errexit -o xtrace; \
    apt-get --yes --quiet update; \
    apt-get --yes --quiet install --no-install-recommends ca-certificates wget

ARG ES_INSTALL_DIR
RUN mkdir --parents --verbose ${ES_INSTALL_DIR}

WORKDIR "${ES_INSTALL_DIR}"

# Install Elasticsearch.
ARG ES_VERSION
ARG ES_DOWNLOAD_URL_PATH="https://artifacts.elastic.co/downloads/elasticsearch"
ARG ES_DOWNLOAD_FILENAME="elasticsearch-${ES_VERSION}.tar.gz"
ARG ES_DOWNLOAD_DIR="/tmp/elasticsearch"

ADD [ \
    "${ES_DOWNLOAD_URL_PATH}/${ES_DOWNLOAD_FILENAME}", \
    "${ES_DOWNLOAD_URL_PATH}/${ES_DOWNLOAD_FILENAME}.sha512", \
    "${ES_DOWNLOAD_DIR}/" \
]

# Chack if the downloaded file matches the provided sha512 hash.
RUN set -o errexit -o xtrace; \
    cd ${ES_DOWNLOAD_DIR}; \
    sha512sum --check "${ES_DOWNLOAD_FILENAME}.sha512"

# Untar the downloaded Elasticsearch release.
RUN set -o errexit -o xtrace; \
    tar --extract --gzip --file "${ES_DOWNLOAD_DIR}/${ES_DOWNLOAD_FILENAME}" --strip-components 1

COPY [ "config/elasticsearch.yml", "config/log4j2.properties", "config/" ]

# Add elasticsearch user.
RUN set -o errexit -o xtrace; \
    groupadd --gid 1000 elasticsearch; \
    useradd  --gid 1000 --uid 1000 --home-dir /home/elasticsearch elasticsearch

# Create dirs and ensure they have the correct permissions set.
RUN set -o errexit -o xtrace; \
    mkdir --parents --verbose "${ES_INSTALL_DIR}/data" "${ES_INSTALL_DIR}/repo"; \
    chown --recursive root:elasticsearch "${ES_INSTALL_DIR}"; \
    chmod --recursive u+rw,g+r-w,o=      "${ES_INSTALL_DIR}"; \
    chmod --verbose g+w \
        "${ES_INSTALL_DIR}/config" \
        "${ES_INSTALL_DIR}/data" \
        "${ES_INSTALL_DIR}/logs" \
        "${ES_INSTALL_DIR}/repo"

# Disable AVX and Xpack on amd64.
ARG TARGETARCH
RUN set -o errexit -o xtrace; \
    if [ "${TARGETARCH}" != 'amd64' ]; then \
        sed --in-place '/10-:-XX:UseAVX=2/d' "${ES_INSTALL_DIR}/config/jvm.options"; \
        echo "xpack.ml.enabled: false" >> "${ES_INSTALL_DIR}/config/elasticsearch.yml"; \
    fi

# Disable Log4j Message lookup to circumvent Log4Shell vulnerability. \
RUN echo "-Dlog4j2.formatMsgNoLookups=true" >> "${ES_INSTALL_DIR}/config/jvm.options"

# Set the ES_DISTRIBUTION_TYPE to `docker` in the Elasticsearch env file.
RUN sed --in-place 's/ES_DISTRIBUTION_TYPE=tar/ES_DISTRIBUTION_TYPE=docker/' \
      /usr/share/elasticsearch/bin/elasticsearch-env


########################################################################################################################
# Final build target.
########################################################################################################################
FROM ubuntu:${DISTRIB_CODENAME}

ARG DEBIAN_FRONTEND="noninteractive"

# Install OpenJDK 8, the recommended Java Runtime for Elasticsearch according to their documentation:
# https://www.elastic.co/guide/en/elasticsearch/reference/6.8/setup.html#jvm-version
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,sharing=locked,target=/var/lib/apt set -o errexit -o xtrace; \
    apt-get --yes --quiet update; \
    apt-get --yes --quiet install --no-install-recommends curl openjdk-8-jre-headless; \
    groupadd --gid 1000 elasticsearch; \
    useradd  --gid 1000 --uid 1000 --home-dir /home/elasticsearch elasticsearch

# Copy over Elasticsearch from build stage.
ARG ES_INSTALL_DIR
COPY --from=build ${ES_INSTALL_DIR} ${ES_INSTALL_DIR}
WORKDIR ${ES_INSTALL_DIR}
VOLUME ${ES_INSTALL_DIR}/data ${ES_INSTALL_DIR}/logs

# Install entrypoint.
COPY --chown=root:elasticsearch bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod --verbose u+x,g-w+x,o= /usr/local/bin/docker-entrypoint.sh

ENV ELASTIC_CONTAINER='true' \
    JAVA_HOME="/usr/lib/jvm/java-8-openjdk-arm64" \
    PATH="/usr/share/elasticsearch/bin:${PATH}"

USER        elasticsearch
EXPOSE      9200 9300
ENTRYPOINT  ["/usr/local/bin/docker-entrypoint.sh"]
CMD         ["eswrapper"]
HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=3 \
        CMD curl -s -f http://localhost:9200/_cluster/health?wait_for_status=green || exit 1
