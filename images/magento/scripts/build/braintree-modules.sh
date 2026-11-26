#!/usr/bin/env bash
# Prints the installed PayPal Braintree modules, one per line. The image disables them:
# their admin system.js needs Prototype.js and breaks the JS of every config page.
# Run it in the Magento root. Prints nothing when the Magento version has no Braintree module.
set -euo pipefail

status="$(bin/magento module:status)"
grep -E '^PayPal_Braintree[A-Za-z]*$' <<<"$status" | sort -u || true
