ARG NODE_VERSION="20"

##########
# Node
##########
FROM node:${NODE_VERSION}-alpine AS node

ARG YARN_VERSION="4"

ENV NODE_VERSION=${NODE_VERSION}
ENV YARN_VERSION=${YARN_VERSION}
ENV YARN_CACHE_FOLDER=/tmp/.cache/yarn
ENV YARN_IGNORE_NODE=1

WORKDIR /app

RUN NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d. -f1) && \
    YARN_MAJOR_VERSION=$(echo "$YARN_VERSION" | cut -d. -f1) && \
    # if node version is 18 and up, use corepack
    if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then \
      if [ "$YARN_MAJOR_VERSION" -gt 1 ]; then \
        # If yarn 1 nothing needs to be done here.
        # expand YARN_VERSION to the full version number with #.x
        if [[ "$YARN_VERSION" =~ ^[0-9]+$ ]]; then \
          YARN_VERSION="${YARN_VERSION}.x"; \
        fi && \
        yarn policies set-version stable && \
        yarn set version $YARN_VERSION && \
        chmod +x ./.yarn/releases/yarn-*.cjs && \
        # replace the default yarn in bin with the new version in .yarn/releases/yarn-x.x.x.cjs \
        cp ./.yarn/releases/yarn-*.cjs "$(which yarn)"; \
      fi \
    else \
      # If node version is 18 and up, use corepack
      corepack enable && \
      corepack prepare "yarn@${YARN_VERSION}" --activate; \
    fi && \
    if [ "$YARN_MAJOR_VERSION" == "1" ]; then \
        # Yarn 1.x
        yarn config set cache-folder "$YARN_CACHE_FOLDER"; \
    else \
        # Yarn 2+
        if [ "$YARN_MAJOR_VERSION" == "2" ]; then \
            # Yarn 2 can't run config set without a package.json or yarn.lock file
            echo "{}" > package.json ; \
        fi; \
        yarn config set --home enableTelemetry   0 && \
        yarn config set --home enableGlobalCache false && \
        yarn config set --home cacheFolder       "$YARN_CACHE_FOLDER"; \
    fi

LABEL org.opencontainers.image.description="Node.js ${NODE_VERSION} with Yarn ${YARN_VERSION} installed"

CMD ["node"]
