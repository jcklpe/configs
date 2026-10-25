#!/usr/bin/env bash
##- Compatibility entry; portable file mechanics live with use-microsoft-files.
source "${LIB_DIR}/../../agent-hands/skills/use-microsoft-files/scripts/operations.sh"
# Existing private callers keep their established shared audit destination.
_m365_files_audit_append() { _mail_audit_append; }
