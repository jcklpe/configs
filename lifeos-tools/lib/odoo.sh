#!/usr/bin/env bash
# Compatibility route: implementations belong to the independent Odoo skills.
# Keep legacy configuration paths for existing callers while they migrate provider configuration.
ODOO_AUTH_DIR="$(cd "${LIB_DIR}/../../agent-hands/skills/authorize-odoo" && pwd)" || return 1
. "${ODOO_AUTH_DIR}/scripts/client.sh"
. "${ODOO_AUTH_DIR}/../use-odoo-projects/scripts/operations.sh"

_odoo_accounts_path() {
    if _var_is_set ODOO_ACCOUNTS_PATH; then
        _path_value ODOO_ACCOUNTS_PATH
    else
        printf '%s/odoo-accounts.json\n' "$SECRETS_DIR"
    fi
}

_odoo_request_state_path() {
    if _var_is_set ODOO_REQUEST_STATE_PATH; then
        _path_value ODOO_REQUEST_STATE_PATH
    else
        printf '%s/cache/odoo-last-request\n' "$SECRETS_DIR"
    fi
}
