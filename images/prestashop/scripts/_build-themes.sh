#!/usr/bin/env bash

build-themes() {
  h2 "Building themes..."

  npm pkg set name=root
  npm pkg delete workspaces
  npm pkg set \
    "workspaces[]=admin-dev/**" \
    "workspaces[]=themes" \
    "workspaces[]=themes/**"

  if major-version-is 1; then
    yarn config set nmHoistingLimits workspaces
  fi

  # Replace node-sass with sass in all workspaces
  yarn remove -A node-sass
  yarn workspaces foreach -pv --exclude root exec npm pkg set devDependencies.sass=^1

  yarn install

  if major-version-is 1; then
    # Some super hacky changes needed to be able to compile the scss of admin-dev/themes/new-theme with sass^1 :(
    sed -i 's/@extend a:hover;/@extend a, :hover;/' './admin-dev/themes/new-theme/node_modules/prestakit/scss/_breadcrumb.scss' || true
    sed -i 's/@extend .btn-primary:disabled;/@extend .btn-primary, :disabled;/' './admin-dev/themes/new-theme/node_modules/prestakit/scss/_custom-forms.scss' || true
    sed -i 's/ - 2;/;/' './admin-dev/themes/new-theme/node_modules/select2-bootstrap-theme/src/select2-bootstrap.scss' || true

    yarn workspaces foreach -pv exec npm pkg set "scripts.build:dev=NODE_ENV=development webpack --mode development"
    yarn workspaces foreach -pv run build:dev
  fi

  if major-version-is 8; then
    ROOT=$(echo "$ROOT_DIR" | sed 's/\//\\\//g')

    ### default
    # Replace relative node_modules paths with absolute paths
    sed -i "s/..\/node_modules\//$ROOT\/node_modules\//" './admin-dev/themes/default/js/theme.js' || true
    sed -i "s/..\/node_modules\//$ROOT\/node_modules\//" './admin-dev/themes/default/scss/modules/_variables.scss' || true
    sed -i "s/..\/node_modules\//$ROOT\/node_modules\//" './admin-dev/themes/default/css/font.css' || true
    ### /default

    ### new-theme
    # Tweak tsconfig so the new-theme can be built
    TSCONFIG='./admin-dev/themes/new-theme/tsconfig.json'
    echo "$(jq '(.compilerOptions |= . + {strict: false, noImplicitAny: false, noImplicitThis: false})' $TSCONFIG)" > $TSCONFIG
    echo "$(jq 'del(.compilerOptions.typeRoots)' $TSCONFIG)" > $TSCONFIG

    # Aadd // @ts-nocheck to the top of all ts files
    find './admin-dev/themes/new-theme' -type f -name '*.ts' -exec sed -i '1i // @ts-nocheck' {} \;
    # Add // @ts-nocheck after all script tags in .vue files
    find './admin-dev/themes/new-theme' -type f -name '*.vue' -exec sed -i 's/<script lang="ts">/<script lang="ts">\n\/\/ @ts-nocheck/' {} \;

    # Remove tsconfig path resolution to node_modules
    find './admin-dev/themes/new-theme' -type f -name '*.ts' -exec sed -i "s/'@node_modules\//'/g" {} \; || true

    # Remove deprecation warnings caused by postcss-preset-env 6
    yarn workspace new-theme exec npm pkg set "devDependencies.postcss-preset-env=^7"
    ### /new-theme

    # Build
    yarn workspaces foreach -pv --exclude root run build
  fi

  if [ "$?" -eq 0 ]; then
    h2 "Built themes."
  else
    h2 "One or more themes failed to build."
  fi
}
