#!/usr/bin/env bash
# Compatibility route: implementations belong to the independent Odoo skills.
ODOO_AUTH_DIR="$(cd "${LIB_DIR}/../../agent-hands/skills/authorize-odoo" && pwd)" || return 1
. "${ODOO_AUTH_DIR}/scripts/client.sh"
. "${ODOO_AUTH_DIR}/../use-odoo-projects/scripts/operations.sh"
