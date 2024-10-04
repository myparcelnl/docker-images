#!/usr/bin/env sh

cd "${ROOT_DIR}" || exit 1

# Some super hacky changes needed to be able to compile the scss of admin-dev/themes/new-theme with sass^1 :(
sed -i 's/@extend a:hover;/@extend a, :hover;/'                             './admin-dev/themes/new-theme/node_modules/prestakit/scss/_breadcrumb.scss' || true
sed -i 's/@extend .btn-primary:disabled;/@extend .btn-primary, :disabled;/' './admin-dev/themes/new-theme/node_modules/prestakit/scss/_custom-forms.scss' || true
sed -i 's/ - 2;/;/'                                                         './admin-dev/themes/new-theme/node_modules/select2-bootstrap-theme/src/select2-bootstrap.scss' || true
