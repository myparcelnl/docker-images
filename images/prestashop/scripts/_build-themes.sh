#!/usr/bin/env bash

build-themes() {
  h2 "Building themes..."

  # Remove legacy node-sass and replace with dart-sass (sass)
  find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/vendor/*' \) -exec \
    sed -i 's/"node-sass": ".*"/"sass": "^1"/g' {} \;

  # If using sass-embedded, must update to >=1.77.0 to work on ARM
  find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/vendor/*' \) -exec \
    sed -i 's/"sass-embedded": ".*"/"sass-embedded": "^1.77.0"/g' {} \;

  # npm install is run through via make install, so add postinstall hooks to modify files in node_modules after npm install
  # shellcheck disable=SC2038
  find . -type f -name 'package.json' -not \( -path '*/node_modules/*' -o -path '*/vendor/*' \) -exec \
    dirname {} \; | xargs -I {} sh -c 'cd {}; npm pkg set "scripts.postinstall=sh /tmp/scripts/fix-sass.sh"'

  if major-version-is 1; then
    yarn config set logFilters --json '[ {"code":"YN0060","level":"discard"}, {"code":"YN0002","level":"discard"} ]'
    yarn config set nodeLinker node-modules
    yarn config set nmHoistingLimits workspaces

    yarn plugin import workspace-tools

    npm pkg set name=root
    npm pkg delete workspaces
    npm pkg set \
      "workspaces[]=admin-dev/**" \
      "workspaces[]=themes" \
      "workspaces[]=themes/**"

    yarn install

    yarn workspaces foreach -pv --exclude root exec npm pkg set "scripts.build:dev=NODE_ENV=development webpack --mode development"
    yarn workspaces foreach -pv --exclude root run build:dev
  fi

  if major-version-is 8; then
    make install
  fi

  if [ "$?" -eq 0 ]; then
    h2 "Built themes."
  else
    h2 "One or more themes failed to build."
  fi
}
