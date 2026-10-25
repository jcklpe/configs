#!/usr/bin/env bash
##- Compatibility entry; workbook operations belong to use-excel-workbooks.
source "${LIB_DIR}/../../agent-hands/skills/use-excel-workbooks/scripts/operations.sh"
_m365_excel_audit_append() { _mail_audit_append; }
# Preserve this entry's historical Python selection, including direct shell consumers.
_m365_excel_python() { "${LIFEOS_PY:-python3}" "$@"; }
