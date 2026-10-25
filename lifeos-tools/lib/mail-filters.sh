#!/usr/bin/env bash
##- LifeOS mail filters: Gmail filters and Microsoft 365 Inbox rules that file incoming mail, limited to labels or categories, skipping the Inbox, and moving to an allowed folder.
##- Never forwards, redirects, deletes, marks read, or replies. Creates and deletes are dry-run by default and need an opt-in flag per account. Decision record: docs/decisions/0009-mail-filters-and-rules.md.
##- Sourced by lifeos.sh after google.sh and m365.sh.

##- Gmail filters

# Gmail filter operations now load with the portable Gmail module through google.sh.

##- Microsoft 365 Inbox rules

_m365_mail_require_rules() {
    local alias="$1"
    if ! _m365_account_value "$alias" '(.mail.rules_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Microsoft 365 Inbox rule changes are not enabled for alias '$alias'"
        _say "NEXT: set mail.rules_enabled to true for '$alias' in $(_m365_accounts_path), then run 'lifeos m365 auth $alias' so the session requests MailboxSettings.ReadWrite" >&2
        return 1
    fi
}

_m365_mail_rules_url() {
    printf '%s/me/mailFolders/inbox/messageRules\n' "$(_m365_graph_base "$1")"
}

# Render RULES ({value: [...]}) with folder IDs shown as paths, using TREE (from _m365_mail_folder_tree) when given.
_m365_mail_rules_human() {
    local rules="$1" tree="${2:-[]}"
    jq -rn --argjson r "$rules" --argjson t "$tree" '
      ([$t[] | {key: .id, value: .path}] | from_entries) as $paths |
      ($r.value // []) | sort_by(.sequence // 0)[] |
      "- " + (.displayName // "(unnamed rule)") + " | rule_id: " + .id + " | " + (if .isEnabled then "enabled" else "disabled" end) +
      " | when: " + ([(.conditions // {}) | to_entries[] | select(.value != null and .value != [] and .value != false) |
          .key + "=" + (if (.value | type) == "array" then (.value | map(if type == "object" then (.emailAddress.address // tostring) else tostring end) | join("|")) else (.value | tostring) end)] | join(", ")) +
      " | then: " + ([(.actions // {}) | to_entries[] | select(.value != null and .value != [] and .value != false) |
          if .key == "moveToFolder" then "move to " + ($paths[.value] // .value)
          elif .key == "assignCategories" then "category " + (.value | join(", "))
          else .key + "=" + (.value | tostring) end] | join(", "))
    '
}

_m365_mail_rules() {
    local alias="${1:-}" json_mode=0 rules dir
    [ -n "$alias" ] || { _err "m365 mail rules requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json_mode=1; shift ;; *) _err "Unknown m365 mail rules option: $1"; return 1 ;; esac; done
    _m365_require_enabled "$alias" mail || return 1
    rules="$(_m365_get "$alias" "$(_m365_mail_rules_url "$alias")")" || return 1
    if [ "$json_mode" -eq 1 ]; then printf '%s\n' "$rules"; return 0; fi
    if [ "$(printf '%s' "$rules" | jq '(.value // []) | length')" -eq 0 ]; then _say "No Inbox rules."; return 0; fi
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-rules.XXXXXX")" || return 1
    _m365_mail_folder_tree "$alias" "${dir}/tree.json" || printf '[]' > "${dir}/tree.json"
    _m365_mail_rules_human "$rules" "$(cat "${dir}/tree.json")"
}

_m365_mail_create_rule() {
    local alias="${1:-}" name="" category="" folder_spec="" stop=0 delete=0 execute=0 dir folder="" existing sequence conditions actions body created readback ok
    local froms=() senders=() subjects=() recipients=()
    [ -n "$alias" ] || { _err "m365 mail create-rule requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --from) [ -n "${2:-}" ] || { _err "--from requires ADDRESS"; return 1; }; froms+=("$2"); shift 2 ;;
            --sender-contains) [ -n "${2:-}" ] || { _err "--sender-contains requires TEXT"; return 1; }; senders+=("$2"); shift 2 ;;
            --subject-contains) [ -n "${2:-}" ] || { _err "--subject-contains requires TEXT"; return 1; }; subjects+=("$2"); shift 2 ;;
            --recipient-contains) [ -n "${2:-}" ] || { _err "--recipient-contains requires TEXT"; return 1; }; recipients+=("$2"); shift 2 ;;
            --category) [ -n "${2:-}" ] || { _err "--category requires NAME"; return 1; }; category="$2"; shift 2 ;;
            --folder) [ -n "${2:-}" ] || { _err "--folder requires NAME, PATH, or ID"; return 1; }; folder_spec="$2"; shift 2 ;;
            --delete) delete=1; shift ;;
            --stop) stop=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 mail create-rule option: $1"; return 1 ;;
        esac
    done
    [ -n "$name" ] || { _err "create-rule requires --name"; return 1; }
    [ "${#froms[@]}" -gt 0 ] || [ "${#senders[@]}" -gt 0 ] || [ "${#subjects[@]}" -gt 0 ] || [ "${#recipients[@]}" -gt 0 ] || { _err "create-rule needs at least one --from, --sender-contains, --subject-contains, or --recipient-contains"; return 1; }
    [ -n "$category" ] || [ -n "$folder_spec" ] || [ "$delete" -eq 1 ] || { _err "create-rule needs --category, --folder, or --delete"; return 1; }
    if [ "$delete" -eq 1 ]; then
        [ "${#froms[@]}" -gt 0 ] && [ "${#recipients[@]}" -gt 0 ] || { _err "--delete requires both --from ADDRESS and --recipient-contains ADDRESS to scope duplicate-mail cleanup"; return 1; }
        [ -z "$category$folder_spec" ] || { _err "--delete cannot be combined with --category or --folder"; return 1; }
        local address
        for address in "${froms[@]}" "${recipients[@]}"; do
            if ! printf '%s\n' "$address" | LC_ALL=C grep -Eq '^[^[:space:]@<>]+@[^[:space:]@<>]+\.[^[:space:]@<>]+$'; then _err "--delete requires complete sender and recipient email addresses, not fragments"; return 1; fi
        done
    fi
    case "$category" in *,*) _err "Category names may not contain commas"; return 1 ;; esac
    _m365_require_enabled "$alias" mail || return 1
    dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-m365-create-rule.XXXXXX")" || return 1
    if [ -n "$folder_spec" ]; then
        _m365_mail_folder_tree "$alias" "${dir}/tree.json" || return 1
        folder="$(_m365_mail_resolve_folder "${dir}/tree.json" "$folder_spec")" || return 1
        if [ "$(printf '%s' "$folder" | jq -r '.moveTarget')" != true ]; then _err "Rules may not move mail into $(printf '%s' "$folder" | jq -r '.path')"; return 1; fi
    else
        printf '[]' > "${dir}/tree.json"
    fi
    existing="$(_m365_get "$alias" "$(_m365_mail_rules_url "$alias")")" || return 1
    if printf '%s' "$existing" | jq -e --arg n "$name" 'any((.value // [])[]; (.displayName // "" | ascii_downcase) == ($n | ascii_downcase))' >/dev/null; then _err "An Inbox rule named '$name' already exists"; return 1; fi
    sequence="$(printf '%s' "$existing" | jq '([(.value // [])[].sequence // 0] | max // 0) + 1')"
    conditions="$(jq -cn \
        --argjson froms "$(printf '%s\n' "${froms[@]+"${froms[@]}"}" | jq -R . | jq -sc 'map(select(. != ""))')" \
        --argjson senders "$(printf '%s\n' "${senders[@]+"${senders[@]}"}" | jq -R . | jq -sc 'map(select(. != ""))')" \
        --argjson subjects "$(printf '%s\n' "${subjects[@]+"${subjects[@]}"}" | jq -R . | jq -sc 'map(select(. != ""))')" \
        --argjson recipients "$(printf '%s\n' "${recipients[@]+"${recipients[@]}"}" | jq -R . | jq -sc 'map(select(. != ""))')" \
        '{} + (if ($froms | length) > 0 then {fromAddresses: [$froms[] | {emailAddress: {address: .}}]} else {} end)
            + (if ($senders | length) > 0 then {senderContains: $senders} else {} end)
            + (if ($subjects | length) > 0 then {subjectContains: $subjects} else {} end)
            + (if ($recipients | length) > 0 then {recipientContains: $recipients} else {} end)')"
    actions="$(jq -cn --arg c "$category" --arg f "$(printf '%s' "$folder" | jq -r '.id // empty' 2>/dev/null)" --argjson stop "$stop" --argjson delete "$delete" \
        '{} + (if $c != "" then {assignCategories: [$c]} else {} end) + (if $f != "" then {moveToFolder: $f} else {} end) + (if $stop == 1 then {stopProcessingRules: true} else {} end) + (if $delete == 1 then {delete: true} else {} end)')"
    body="$(jq -cn --arg n "$name" --argjson s "$sequence" --argjson c "$conditions" --argjson a "$actions" '{displayName: $n, sequence: $s, isEnabled: true, conditions: $c, actions: $a}')"
    _say "Microsoft 365 Inbox rule create plan:"
    _say "Account: $alias"
    _m365_mail_rules_human "$(jq -cn --argjson b "$body" '{value: [$b + {id: "(new)"}]}')" "$(cat "${dir}/tree.json")"
    _say "Different condition types must all match; values within one type are alternatives."
    [ "$delete" -ne 1 ] || _say "Delete means move to Outlook Deleted Items, not permanent deletion."
    _say "Applies to new mail arriving in the Inbox only; existing mail is unchanged."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no rule was created. Re-run with --execute to create it."; return 0; fi
    _m365_mail_require_rules "$alias" || return 1
    created="$(_m365_write POST "$alias" "$(_m365_mail_rules_url "$alias")" "$body")" || return 1
    readback="$(_m365_get "$alias" "$(_m365_mail_rules_url "$alias")/$(_m365_uri_encode "$(printf '%s' "$created" | jq -r '.id')")")" || return 1
    ok="$(jq -n --argjson want "$body" --argjson got "$readback" '
      def meaningful: with_entries(select(.value != null and .value != [] and .value != false and .value != {}));
      def predicates: (. // {}) | del(."@odata.type") | meaningful | with_entries(
        if (.value | type) == "array" then .value |= (map(if type == "object" and has("emailAddress") then {emailAddress: {address: (.emailAddress.address | ascii_downcase)}} elif type == "string" then ascii_downcase else . end) | sort) else . end);
      def rule_actions: (. // {}) | del(."@odata.type") | meaningful | with_entries(if (.value | type) == "array" then .value |= sort else . end);
      ($got.displayName == $want.displayName) and ($got.isEnabled == true) and (($got.hasError // false) == false) and
      ($got.sequence == $want.sequence) and
      (($got.conditions | predicates) == ($want.conditions | predicates)) and
      (($got.exceptions | predicates) == {}) and
      (($got.actions | rule_actions) == ($want.actions | rule_actions))')"
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$alias" --argjson r "$readback" --argjson ok "$ok" '{ts: $ts, service: "m365", alias: $alias, action: "create-rule", rule_id: $r.id, rule: $r.displayName, conditions: $r.conditions, rule_actions: $r.actions, verified: $ok}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    [ "$ok" = true ] || { _err "Created rule but readback did not match"; return 1; }
    _say "Created rule (confirmed by readback): $name | rule_id: $(printf '%s' "$created" | jq -r '.id')"
}

_m365_mail_delete_rule() {
    local alias="${1:-}" rule_id="" execute=0 rule url
    [ -n "$alias" ] || { _err "m365 mail delete-rule requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --rule) [ -n "${2:-}" ] || { _err "--rule requires ID"; return 1; }; rule_id="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 mail delete-rule option: $1"; return 1 ;;
        esac
    done
    [ -n "$rule_id" ] || { _err "delete-rule requires --rule ID"; return 1; }
    _m365_require_enabled "$alias" mail || return 1
    url="$(_m365_mail_rules_url "$alias")/$(_m365_uri_encode "$rule_id")"
    rule="$(_m365_get "$alias" "$url")" || { _err "No Inbox rule with ID $rule_id"; return 1; }
    _say "Microsoft 365 Inbox rule delete plan (removes the rule only; no mail is touched):"
    _say "Account: $alias"
    _m365_mail_rules_human "$(printf '%s' "$rule" | jq -c '{value: [.]}')"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: the rule was not deleted. Re-run with --execute to delete it."; return 0; fi
    _m365_mail_require_rules "$alias" || return 1
    _m365_write DELETE "$alias" "$url" "" >/dev/null || return 1
    if _m365_get "$alias" "$url" >/dev/null 2>&1; then _err "Rule $rule_id still exists after delete"; return 1; fi
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$alias" --argjson r "$rule" '{ts: $ts, service: "m365", alias: $alias, action: "delete-rule", rule_id: $r.id, rule: $r.displayName, conditions: $r.conditions, rule_actions: $r.actions, verified: true}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    _say "Deleted rule (confirmed): $rule_id"
}
