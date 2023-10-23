#!/usr/bin/env bash

# Some super hacky changes needed to be able to compile the scss of admin-dev/themes/new-theme with sass^1 :(
fix-files() {
  sed -i 's/@extend a:hover;/@extend a, :hover;/' './admin-dev/themes/new-theme/node_modules/prestakit/scss/_breadcrumb.scss' || true
  sed -i 's/@extend .btn-primary:disabled;/@extend .btn-primary, :disabled;/' './admin-dev/themes/new-theme/node_modules/prestakit/scss/_custom-forms.scss' || true
  sed -i 's/ - 2;/;/' './admin-dev/themes/new-theme/node_modules/select2-bootstrap-theme/src/select2-bootstrap.scss' || true
}

build-themes() {
  h2 "Building themes..."


  if major-version-is 1; then
    yarn set version berry

    yarn config set --home enableTelemetry 0

    yarn config set enableGlobalCache true
    yarn config set globalFolder /tmp/.cache/yarn
    yarn config set logFilters --json '[ {"code":"YN0060","level":"discard"}, {"code":"YN0002","level":"discard"} ]'
    yarn config set nodeLinker node-modules

    yarn plugin import workspace-tools

    npm pkg set name=root
    npm pkg delete workspaces
    npm pkg set \
      "workspaces[]=admin-dev/**" \
      "workspaces[]=themes" \
      "workspaces[]=themes/**"

    yarn config set nmHoistingLimits workspaces

    # Replace node-sass with sass in all workspaces
    yarn remove -A node-sass
    yarn workspaces foreach -pv --exclude root exec npm pkg set devDependencies.sass=^1

    yarn install

    fix-files

    yarn workspaces foreach -pv exec npm pkg set "scripts.build:dev=NODE_ENV=development webpack --mode development"
    yarn workspaces foreach -pv run build:dev

    if [ "$?" -eq 0 ]; then
      h2 "Built themes."
    else
      h2 "One or more themes failed to build."
    fi
  fi

  if major-version-is 8; then
    workspaces=$(find themes admin-dev -type f -name package.json -not -path "*/node_modules/*" -not -path "*/vendor/*" -exec dirname {} \;)

    for workspace in $workspaces; do
      cd "$workspace" || exit 1
      h2 "Building $workspace..."

      npm pkg delete devDependencies.node-sass
      npm pkg delete dependencies.node-sass
      npm pkg set devDependencies.sass=^1

      npm install --legacy-peer-deps

      fix-files

      npm run build

      if [ "$?" -ne 0 ]; then
        h2 "Failed to build $workspace."
      else
        h2 "Done building $workspace."
      fi

      cd - || exit 1
    done
  fi
}
