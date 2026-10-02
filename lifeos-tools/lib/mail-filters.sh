#!/usr/bin/env bash
##- LifeOS mail filters: Gmail filters and Microsoft 365 Inbox rules that file incoming mail, limited to labels or categories, skipping the Inbox, and moving to an allowed folder.
##- Never forwards, redirects, deletes, marks read, or replies. Creates and deletes are dry-run by default and need an opt-in flag per account. Decision record: docs/decisions/0009-mail-filters-and-rules.md.
##- Sourced by lifeos.sh after google.sh and m365.sh.

##- Gmail filters

_gmail_require_filters() {
    local alias="$1"
    if ! _google_account_value "$alias" '(.gmail.filters_enabled // false) == true' 2>/dev/null | grep -qx true; then
        _err "Gmail filter changes are not enabled for alias '$alias'"
        _say "NEXT: set gmail.filters_enabled to true for '$alias' in $(_google_accounts_path), then run 'lifeos google auth $alias' to grant gmail.settings.basic" >&2
        return 1
    fi
}

_gmail_filters_fetch() {
    _google_get_url "$1" "${_GMAIL_API}/settings/filters"
}

# Render FILTERS (the API's {filter: [...]}) with label IDs shown as names, using LABELS ({labels: [...]}).
_gmail_filters_human() {
    local filters="$1" labels="$2"
    jq -rn --argjson f "$filters" --argjson l "$labels" '
      ([($l.labels // [])[] | {key: .id, value: .name}] | from_entries) as $names |
      ($f.filter // [])[] |
      "- filter_id: " + .id +
      " | when: " + ([(.criteria // {}) | to_entries[] | .key + "=" + (.value | tostring)] | join(", ")) +
      " | then: " + ([
          ((.action.addLabelIds // [])[] | "label " + ($names[.] // .)),
          ((.action.removeLabelIds // [])[] | if . == "INBOX" then "skip inbox" else "remove " + ($names[.] // .) end),
          (if .action.forward then "forward " + .action.forward else empty end)
        ] | join(", "))
    '
}

_gmail_filters() {
    local alias="${1:-}" json_mode=0 filters labels
    [ -n "$alias" ] || { _err "gmail filters requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do case "$1" in --json) json_mode=1; shift ;; *) _err "Unknown gmail filters option: $1"; return 1 ;; esac; done
    _gmail_require_enabled "$alias" || return 1
    filters="$(_gmail_filters_fetch "$alias")" || return 1
    if [ "$json_mode" -eq 1 ]; then printf '%s\n' "$filters"; return 0; fi
    if [ "$(printf '%s' "$filters" | jq '(.filter // []) | length')" -eq 0 ]; then _say "No Gmail filters."; return 0; fi
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    _gmail_filters_human "$filters" "$labels"
}

# Build the Gmail search that matches the same mail as CRITERIA, so the dry run can show what the filter would have caught.
_gmail_filter_search() {
    printf '%s' "$1" | jq -r '[
        (if .from then "from:(" + .from + ")" else empty end),
        (if .to then "to:(" + .to + ")" else empty end),
        (if .subject then "subject:(" + .subject + ")" else empty end),
        (if .query then .query else empty end)
      ] | join(" ")'
}

_gmail_create_filter() {
    local alias="${1:-}" from="" to="" subject="" query="" label_spec="" skip_inbox=0 execute=0
    local criteria action body labels label search created readback ok
    [ -n "$alias" ] || { _err "gmail create-filter requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --from) [ -n "${2:-}" ] || { _err "--from requires TEXT"; return 1; }; from="$2"; shift 2 ;;
            --to) [ -n "${2:-}" ] || { _err "--to requires TEXT"; return 1; }; to="$2"; shift 2 ;;
            --subject) [ -n "${2:-}" ] || { _err "--subject requires TEXT"; return 1; }; subject="$2"; shift 2 ;;
            --query) [ -n "${2:-}" ] || { _err "--query requires a Gmail search"; return 1; }; query="$2"; shift 2 ;;
            --label) [ -n "${2:-}" ] || { _err "--label requires NAME or ID"; return 1; }; label_spec="$2"; shift 2 ;;
            --skip-inbox) skip_inbox=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown gmail create-filter option: $1"; return 1 ;;
        esac
    done
    [ -n "$from$to$subject$query" ] || { _err "create-filter needs at least one of --from, --to, --subject, --query"; return 1; }
    [ -n "$label_spec" ] || [ "$skip_inbox" -eq 1 ] || { _err "create-filter needs --label, --skip-inbox, or both"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    criteria="$(jq -cn --arg from "$from" --arg to "$to" --arg subject "$subject" --arg query "$query" '{from: $from, to: $to, subject: $subject, query: $query} | with_entries(select(.value != ""))')"
    action='{}'
    if [ -n "$label_spec" ]; then
        labels="$(_gmail_labels_fetch "$alias")" || return 1
        label="$(_gmail_resolve_user_label "$labels" "$label_spec")" || return 1
        action="$(printf '%s' "$action" | jq -c --arg id "$(printf '%s' "$label" | jq -r '.id')" '. + {addLabelIds: [$id]}')"
    fi
    [ "$skip_inbox" -eq 1 ] && action="$(printf '%s' "$action" | jq -c '. + {removeLabelIds: ["INBOX"]}')"
    body="$(jq -cn --argjson c "$criteria" --argjson a "$action" '{criteria: $c, action: $a}')"
    search="$(_gmail_filter_search "$criteria")"
    _say "Gmail filter create plan:"
    _say "Account: $alias"
    _say "When: $(printf '%s' "$criteria" | jq -r 'to_entries | map(.key + "=" + .value) | join(", ")')"
    _say "Then: $([ -n "$label_spec" ] && printf 'label %s' "$(printf '%s' "$label" | jq -r '.name')")$([ -n "$label_spec" ] && [ "$skip_inbox" -eq 1 ] && printf ', ')$([ "$skip_inbox" -eq 1 ] && printf 'skip inbox')"
    _say "Applies to new mail only. Recent existing mail it would have matched (search: $search):"
    _gmail_list "$alias" --query "$search" --limit 5 || _warn "Could not run the preview search"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no filter was created. Re-run with --execute to create it."; return 0; fi
    _gmail_require_filters "$alias" || return 1
    created="$(_gmail_send POST "$alias" "${_GMAIL_API}/settings/filters" "$body")" || { _say "NEXT: if the token predates gmail.filters_enabled, run 'lifeos google auth $alias' to grant gmail.settings.basic" >&2; return 1; }
    readback="$(_google_get_url "$alias" "${_GMAIL_API}/settings/filters/$(printf '%s' "$created" | jq -r '.id')")" || return 1
    ok="$(jq -n --argjson want "$body" --argjson got "$readback" '($got.criteria == $want.criteria) and (($got.action.addLabelIds // []) == ($want.action.addLabelIds // [])) and (($got.action.removeLabelIds // []) == ($want.action.removeLabelIds // []))')"
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$alias" --argjson f "$readback" --argjson ok "$ok" '{ts: $ts, service: "gmail", alias: $alias, action: "create-filter", filter_id: $f.id, criteria: $f.criteria, filter_action: $f.action, verified: $ok}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    [ "$ok" = true ] || { _err "Created filter $(printf '%s' "$created" | jq -r '.id') but readback did not match"; return 1; }
    _say "Created filter (confirmed by readback): filter_id: $(printf '%s' "$created" | jq -r '.id')"
}

_gmail_delete_filter() {
    local alias="${1:-}" filter_id="" execute=0 filter labels
    [ -n "$alias" ] || { _err "gmail delete-filter requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --filter) [ -n "${2:-}" ] || { _err "--filter requires ID"; return 1; }; filter_id="$2"; shift 2 ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown gmail delete-filter option: $1"; return 1 ;;
        esac
    done
    [ -n "$filter_id" ] || { _err "delete-filter requires --filter ID"; return 1; }
    _gmail_require_enabled "$alias" || return 1
    filter="$(_google_get_url "$alias" "${_GMAIL_API}/settings/filters/$(_urlencode "$filter_id")")" || { _err "No Gmail filter with ID $filter_id"; return 1; }
    labels="$(_gmail_labels_fetch "$alias")" || return 1
    _say "Gmail filter delete plan (removes the rule only; no mail is touched):"
    _say "Account: $alias"
    _gmail_filters_human "$(printf '%s' "$filter" | jq -c '{filter: [.]}')" "$labels"
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: the filter was not deleted. Re-run with --execute to delete it."; return 0; fi
    _gmail_require_filters "$alias" || return 1
    _gmail_send DELETE "$alias" "${_GMAIL_API}/settings/filters/$(_urlencode "$filter_id")" "" >/dev/null || return 1
    if _google_get_url "$alias" "${_GMAIL_API}/settings/filters/$(_urlencode "$filter_id")" >/dev/null 2>&1; then _err "Filter $filter_id still exists after delete"; return 1; fi
    jq -nc --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg alias "$alias" --argjson f "$filter" '{ts: $ts, service: "gmail", alias: $alias, action: "delete-filter", filter_id: $f.id, criteria: $f.criteria, filter_action: $f.action, verified: true}' | _mail_audit_append || _warn "Could not append to the mail audit log: $(_mail_audit_log_path)"
    _say "Deleted filter (confirmed): $filter_id"
}

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
    local alias="${1:-}" name="" category="" folder_spec="" stop=0 execute=0 dir folder="" existing sequence conditions actions body created readback ok
    local froms=() senders=() subjects=()
    [ -n "$alias" ] || { _err "m365 mail create-rule requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --name) [ -n "${2:-}" ] || { _err "--name requires TEXT"; return 1; }; name="$2"; shift 2 ;;
            --from) [ -n "${2:-}" ] || { _err "--from requires ADDRESS"; return 1; }; froms+=("$2"); shift 2 ;;
            --sender-contains) [ -n "${2:-}" ] || { _err "--sender-contains requires TEXT"; return 1; }; senders+=("$2"); shift 2 ;;
            --subject-contains) [ -n "${2:-}" ] || { _err "--subject-contains requires TEXT"; return 1; }; subjects+=("$2"); shift 2 ;;
            --category) [ -n "${2:-}" ] || { _err "--category requires NAME"; return 1; }; category="$2"; shift 2 ;;
            --folder) [ -n "${2:-}" ] || { _err "--folder requires NAME, PATH, or ID"; return 1; }; folder_spec="$2"; shift 2 ;;
            --stop) stop=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown m365 mail create-rule option: $1"; return 1 ;;
        esac
    done
    [ -n "$name" ] || { _err "create-rule requires --name"; return 1; }
    [ "${#froms[@]}" -gt 0 ] || [ "${#senders[@]}" -gt 0 ] || [ "${#subjects[@]}" -gt 0 ] || { _err "create-rule needs at least one --from, --sender-contains, or --subject-contains"; return 1; }
    [ -n "$category" ] || [ -n "$folder_spec" ] || { _err "create-rule needs --category, --folder, or both"; return 1; }
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
        '{} + (if ($froms | length) > 0 then {fromAddresses: [$froms[] | {emailAddress: {address: .}}]} else {} end)
            + (if ($senders | length) > 0 then {senderContains: $senders} else {} end)
            + (if ($subjects | length) > 0 then {subjectContains: $subjects} else {} end)')"
    actions="$(jq -cn --arg c "$category" --arg f "$(printf '%s' "$folder" | jq -r '.id // empty' 2>/dev/null)" --argjson stop "$stop" \
        '{} + (if $c != "" then {assignCategories: [$c]} else {} end) + (if $f != "" then {moveToFolder: $f} else {} end) + (if $stop == 1 then {stopProcessingRules: true} else {} end)')"
    body="$(jq -cn --arg n "$name" --argjson s "$sequence" --argjson c "$conditions" --argjson a "$actions" '{displayName: $n, sequence: $s, isEnabled: true, conditions: $c, actions: $a}')"
    _say "Microsoft 365 Inbox rule create plan:"
    _say "Account: $alias"
    _m365_mail_rules_human "$(jq -cn --argjson b "$body" '{value: [$b + {id: "(new)"}]}')" "$(cat "${dir}/tree.json")"
    _say "Applies to new mail arriving in the Inbox only; existing mail is not moved or categorized."
    if [ "$execute" -ne 1 ]; then _say "DRY RUN: no rule was created. Re-run with --execute to create it."; return 0; fi
    _m365_mail_require_rules "$alias" || return 1
    created="$(_m365_write POST "$alias" "$(_m365_mail_rules_url "$alias")" "$body")" || return 1
    readback="$(_m365_get "$alias" "$(_m365_mail_rules_url "$alias")/$(_m365_uri_encode "$(printf '%s' "$created" | jq -r '.id')")")" || return 1
    ok="$(jq -n --argjson want "$body" --argjson got "$readback" '
      ($got.displayName == $want.displayName) and
      ((($got.actions.assignCategories // []) | sort) == (($want.actions.assignCategories // []) | sort)) and
      (($got.actions.moveToFolder // null) == ($want.actions.moveToFolder // null)) and
      (($got.actions.forwardTo // []) == []) and (($got.actions.redirectTo // []) == []) and (($got.actions.delete // false) == false)')"
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
