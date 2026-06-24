#!/usr/bin/env bash
##- LifeOS helper CLI
##- Pulls read-only source data into the private LifeOS vault.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="${CONFIGS:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
ENV_FILE="${SCRIPT_DIR}/.env"

LIFEOS_DAYS_BACK="${LIFEOS_DAYS_BACK:-14}"
LIFEOS_DAYS_AHEAD="${LIFEOS_DAYS_AHEAD:-30}"

_usage() {
    cat <<'EOF'
LifeOS helper

Usage:
  ./lifeos.sh help
  ./lifeos.sh doctor
  ./lifeos.sh open
  ./lifeos.sh context
  ./lifeos.sh trello list-boards
  ./lifeos.sh trello list-lists [board_id]
  ./lifeos.sh trello sync [--qa | --output FILE]
  ./lifeos.sh trello add-card --list LIST --name NAME [--board BOARD_ID] [--desc TEXT | --desc-file FILE]
  ./lifeos.sh trello move-card --card CARD_ID_OR_URL --list LIST [--board BOARD_ID]
  ./lifeos.sh trello rename-card --card CARD_ID_OR_URL --name NAME
  ./lifeos.sh trello set-desc --card CARD_ID_OR_URL --file FILE
  ./lifeos.sh trello comment --card CARD_ID_OR_URL (--text TEXT | --file FILE)
  ./lifeos.sh calendar auth
  ./lifeos.sh calendar list-calendars
  ./lifeos.sh calendar sync [--qa | --output FILE]
  ./lifeos.sh calendar create-event --title TITLE --start DATE_OR_DATETIME [--end ...] [--calendar CALENDAR_ID] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh calendar update-event --event EVENT_ID [--series | --instance] [--calendar CALENDAR_ID] [--title TEXT] [--start ...] [--end ...] [--tz ZONE] [--location TEXT] [--desc TEXT | --desc-file FILE] [--attendee NAME_OR_EMAIL]... [--replace-attendees] [--recurrence RRULE]... [--notify] [--execute]
  ./lifeos.sh people resolve NAME [--json]
  ./lifeos.sh people list-aliases
  ./lifeos.sh people add-alias NAME EMAIL
  ./lifeos.sh google accounts
  ./lifeos.sh google auth ALIAS [--no-browser]
  ./lifeos.sh gmail sync ALIAS [--qa | --output FILE]
  ./lifeos.sh gmail sync --all [--qa]
  ./lifeos.sh drive accounts
  ./lifeos.sh drive search ALIAS QUERY [--json]
  ./lifeos.sh drive list ALIAS FOLDER_ID [--json]
  ./lifeos.sh drive meta ALIAS FILE_URL_OR_ID [--json]
  ./lifeos.sh drive read ALIAS FILE_URL_OR_ID [--range RANGE]
  ./lifeos.sh open-austin-org path
  ./lifeos.sh open-austin-org sync [--qa | --output DIR]
  ./lifeos.sh open-austin-org create-issue --title TITLE [--body TEXT | --body-file FILE] [--label LABEL] [--assign-me | --assignee LOGIN] [--repo OWNER/REPO] [--execute] [--no-sync]
  ./lifeos.sh sync

Real config lives in .env, copied from .env.example.
EOF
}

_say() {
    printf '%s\n' "$*"
}

_warn() {
    printf 'WARN: %s\n' "$*" >&2
}

_err() {
    printf 'ERROR: %s\n' "$*" >&2
}

_trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_load_env() {
    local line key value is_set

    [ -f "$ENV_FILE" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
            export\ *) line="${line#export }" ;;
        esac

        case "$line" in
            *=*) ;;
            *) continue ;;
        esac

        key="$(_trim "${line%%=*}")"
        value="${line#*=}"

        case "$key" in
            ''|*[!A-Za-z0-9_]*) continue ;;
        esac

        eval "is_set=\${${key}+x}"
        if [ -z "$is_set" ]; then
            eval "export ${key}=${value}"
        fi
    done < "$ENV_FILE"

    LIFEOS_DAYS_BACK="${LIFEOS_DAYS_BACK:-14}"
    LIFEOS_DAYS_AHEAD="${LIFEOS_DAYS_AHEAD:-30}"
    export LIFEOS_DAYS_BACK LIFEOS_DAYS_AHEAD
}

_var_is_set() {
    local value
    eval "value=\${$1:-}"
    [ -n "$value" ]
}

_require_var() {
    if ! _var_is_set "$1"; then
        _err "$1 is not set"
        return 1
    fi
    return 0
}

_redacted_status() {
    if _var_is_set "$1"; then
        _say "OK: $1 is set (redacted)"
    else
        _say "MISSING: $1"
        return 1
    fi
}

_path_value() {
    local value
    eval "value=\${$1:-}"
    printf '%s\n' "$value"
}

_real_dir() {
    [ -d "$1" ] || return 1
    (cd "$1" && pwd -P)
}

_vault_path() {
    _path_value LIFEOS_VAULT_PATH
}

_vault_ready() {
    local vault repo

    _require_var LIFEOS_VAULT_PATH || return 1
    vault="$(_vault_path)"

    if [ ! -d "$vault" ]; then
        _err "LIFEOS_VAULT_PATH does not exist: $vault"
        return 1
    fi

    vault="$(_real_dir "$vault")" || return 1
    repo="$(_real_dir "$CONFIGS")" || return 1

    case "$vault" in
        "$repo"|"$repo"/*)
            _err "LIFEOS_VAULT_PATH points inside this configs repo: $vault"
            return 1
            ;;
    esac

    return 0
}

_sources_dir() {
    printf '%s/sources\n' "$(_vault_path)"
}

_ensure_sources_dir() {
    local dir
    dir="$(_sources_dir)"
    [ -d "$dir" ] || mkdir -p "$dir"
}

_ensure_parent_dir() {
    local dir
    dir="$(dirname "$1")"
    [ -d "$dir" ] || mkdir -p "$dir"
}

_check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        _say "OK: command '$1' found"
        return 0
    fi
    _say "MISSING: command '$1'"
    return 1
}

_doctor_file() {
    if [ -f "$1" ]; then
        _say "OK: $1"
        return 0
    fi
    _say "MISSING: $1"
    return 1
}

_doctor() {
    local issues=0 vault sources file google_accounts google_aliases google_alias google_token

    if [ -f "$ENV_FILE" ]; then
        _say "OK: ${ENV_FILE}"
    else
        _say "MISSING: ${ENV_FILE}"
        _say "NEXT: cp ${SCRIPT_DIR}/.env.example ${ENV_FILE}"
        issues=$((issues + 1))
    fi

    _check_command curl || issues=$((issues + 1))
    _check_command jq || issues=$((issues + 1))
    _check_command python3 || issues=$((issues + 1))

    if _var_is_set LIFEOS_VAULT_PATH; then
        vault="$(_vault_path)"
        _say "OK: LIFEOS_VAULT_PATH is set: $vault"
        if _vault_ready; then
            sources="$(_sources_dir)"
            if [ -d "$sources" ]; then
                _say "OK: ${sources}"
            else
                _say "MISSING: ${sources}"
                _say "NEXT: sync commands will create ${sources}"
            fi

            for file in README.md now.md weekly-review.md; do
                _doctor_file "$vault/$file" || issues=$((issues + 1))
            done
        else
            issues=$((issues + 1))
        fi
    else
        _say "MISSING: LIFEOS_VAULT_PATH"
        issues=$((issues + 1))
    fi

    _redacted_status TRELLO_API_KEY || issues=$((issues + 1))
    _redacted_status TRELLO_TOKEN || issues=$((issues + 1))
    if _var_is_set TRELLO_WRITE_TOKEN; then
        _say "OK: TRELLO_WRITE_TOKEN is set (redacted)"
    else
        _say "OPTIONAL: TRELLO_WRITE_TOKEN is not set; Trello write commands will be disabled"
    fi
    if _var_is_set TRELLO_BOARD_IDS; then
        _say "OK: TRELLO_BOARD_IDS is set"
    else
        _say "MISSING: TRELLO_BOARD_IDS"
        _say "NEXT: run './lifeos.sh trello list-boards' after Trello auth is configured"
    fi

    if _var_is_set GOOGLE_CALENDAR_CREDENTIALS_PATH; then
        _say "OK: GOOGLE_CALENDAR_CREDENTIALS_PATH is configured"
        if [ -f "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" ]; then
            _say "OK: Google Calendar credentials file exists"
        else
            _say "MISSING: Google Calendar credentials file"
        fi
    else
        _say "MISSING: GOOGLE_CALENDAR_CREDENTIALS_PATH"
    fi

    if _var_is_set GOOGLE_CALENDAR_TOKEN_PATH; then
        _say "OK: GOOGLE_CALENDAR_TOKEN_PATH is configured"
        if [ -f "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)" ]; then
            _say "OK: Google Calendar token file exists"
        else
            _say "MISSING: Google Calendar token file"
            _say "NEXT: run './lifeos.sh calendar auth'"
        fi
    else
        _say "MISSING: GOOGLE_CALENDAR_TOKEN_PATH"
    fi

    google_accounts="$(_google_accounts_path)"
    if [ -f "$google_accounts" ]; then
        if jq -e '.accounts | type == "array"' "$google_accounts" >/dev/null 2>&1; then
            _say "OK: Google account alias config exists"
            google_aliases="$(jq -r '(.accounts // [])[] | select((.gmail.enabled // false) == true or (.drive.enabled // false) == true) | .alias' "$google_accounts")"
            for google_alias in $google_aliases; do
                google_token="$(_google_account_path "$google_alias" '.token_path')" || google_token=""
                if [ -n "$google_token" ] && [ -f "$google_token" ]; then
                    _say "OK: Google token exists for alias '$google_alias'"
                else
                    _say "MISSING: Google token for alias '$google_alias'"
                    _say "NEXT: run './lifeos.sh google auth $google_alias'"
                fi
            done
        else
            _say "MISSING: Google account alias config is not valid JSON shape"
        fi
    else
        _say "OPTIONAL: Google account alias config is not set up for Gmail/Drive"
        _say "NEXT: cp ${SCRIPT_DIR}/google-accounts.example.json $google_accounts"
    fi

    if [ "$issues" -eq 0 ]; then
        _say "OK: doctor found no blocking issues for the implemented commands"
        return 0
    fi

    _say "Doctor found $issues issue(s)"
    return 1
}

_open_vault() {
    _vault_ready || return 1
    if command -v code >/dev/null 2>&1; then
        code "$(_vault_path)"
    else
        _say "$(_vault_path)"
    fi
}

_context() {
    local vault
    _require_var LIFEOS_VAULT_PATH || return 1
    vault="$(_vault_path)"
    cat <<EOF
Recommended LifeOS context files:

$vault/README.md
$vault/now.md
$vault/weekly-review.md
$vault/sources/trello.md
$vault/sources/calendar.md
$vault/sources/gmail/

For Open Austin GitHub/org work, also read:

$vault/open-austin/repo.md
$vault/sources/open-austin-org/issues.md
$vault/sources/open-austin-org/board-org-kanban.md

Then add the relevant focus-thread file, such as:

$vault/open-austin/index.open-austin.md
EOF
}

_trello_ready() {
    _require_var TRELLO_API_KEY || return 1
    _require_var TRELLO_TOKEN || return 1
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    return 0
}

_trello_get() {
    local endpoint="$1"
    shift
    curl -fsS --get "https://api.trello.com/1${endpoint}" \
        --data-urlencode "key=${TRELLO_API_KEY}" \
        --data-urlencode "token=${TRELLO_TOKEN}" \
        "$@"
}

_trello_write_ready() {
    _require_var TRELLO_API_KEY || return 1
    _require_var TRELLO_WRITE_TOKEN || return 1
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    return 0
}

_trello_write() {
    local method="$1"
    local endpoint="$2"
    shift 2
    curl -fsS -X "$method" "https://api.trello.com/1${endpoint}" \
        --data-urlencode "key=${TRELLO_API_KEY}" \
        --data-urlencode "token=${TRELLO_WRITE_TOKEN}" \
        "$@"
}

_first_board_id() {
    local first
    first="${TRELLO_BOARD_IDS%%,*}"
    _trim "$first"
}

_looks_like_trello_id() {
    case "$1" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
            return 0
            ;;
    esac
    return 1
}

_card_ref() {
    local ref="$1"
    case "$ref" in
        *trello.com/c/*)
            ref="${ref#*trello.com/c/}"
            ref="${ref%%/*}"
            ;;
    esac
    printf '%s\n' "$ref"
}

_read_file() {
    if [ ! -f "$1" ]; then
        _err "File does not exist: $1"
        return 1
    fi
    cat "$1"
}

_trello_list_boards() {
    _trello_ready || return 1
    _trello_get "/members/me/boards" \
        --data-urlencode "fields=name,url,closed" |
        jq -r '.[] | "- " + (.name // "Untitled board") + " | id: " + .id + " | closed: " + (.closed | tostring) + " | " + (.url // "")'
}

_trello_list_lists() {
    local board_id="${1:-}"

    _trello_ready || return 1
    if [ -z "$board_id" ]; then
        board_id="$(_first_board_id)"
    fi
    if [ -z "$board_id" ]; then
        _err "Pass a board ID or set TRELLO_BOARD_IDS"
        return 1
    fi

    _trello_get "/boards/${board_id}/lists" \
        --data-urlencode "filter=all" \
        --data-urlencode "fields=name,closed" |
        jq -r '.[] | "- " + (.name // "Untitled list") + " | id: " + .id + " | closed: " + (.closed | tostring)'
}

_trello_resolve_list_id() {
    local board_id="$1"
    local list_ref="$2"
    local matches

    if [ -z "$list_ref" ]; then
        _err "Missing list"
        return 1
    fi

    if _looks_like_trello_id "$list_ref"; then
        printf '%s\n' "$list_ref"
        return 0
    fi

    if [ -z "$board_id" ]; then
        board_id="$(_first_board_id)"
    fi
    if [ -z "$board_id" ]; then
        _err "List names require --board or TRELLO_BOARD_IDS"
        return 1
    fi

    matches="$(
        _trello_get "/boards/${board_id}/lists" \
            --data-urlencode "filter=open" \
            --data-urlencode "fields=name" |
            jq -r --arg name "$list_ref" '.[] | select(.name == $name) | .id'
    )" || return 1

    if [ -z "$matches" ]; then
        _err "No open list named '$list_ref' found on board $board_id"
        return 1
    fi

    if [ "$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')" != "1" ]; then
        _err "Multiple open lists named '$list_ref' found on board $board_id; use the list ID"
        return 1
    fi

    printf '%s\n' "$matches"
}

_trello_add_card() {
    local board_id="" list_ref="" name="" desc="" desc_file="" list_id

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --board) board_id="$2"; shift 2 ;;
            --list) list_ref="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --desc) desc="$2"; shift 2 ;;
            --desc-file) desc_file="$2"; shift 2 ;;
            *) _err "Unknown add-card option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$list_ref" ] || { _err "add-card requires --list"; return 1; }
    [ -n "$name" ] || { _err "add-card requires --name"; return 1; }
    if [ -n "$desc" ] && [ -n "$desc_file" ]; then
        _err "Use either --desc or --desc-file, not both"
        return 1
    fi
    if [ -n "$desc_file" ]; then
        desc="$(_read_file "$desc_file")" || return 1
    fi

    list_id="$(_trello_resolve_list_id "$board_id" "$list_ref")" || return 1
    _trello_write POST "/cards" \
        --data-urlencode "idList=${list_id}" \
        --data-urlencode "name=${name}" \
        --data-urlencode "desc=${desc}" |
        jq -r '"Created card: " + (.name // "Untitled card") + " | " + (.url // .id)'
}

_trello_move_card() {
    local board_id="" card="" list_ref="" list_id

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --board) board_id="$2"; shift 2 ;;
            --card) card="$(_card_ref "$2")"; shift 2 ;;
            --list) list_ref="$2"; shift 2 ;;
            *) _err "Unknown move-card option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$card" ] || { _err "move-card requires --card"; return 1; }
    [ -n "$list_ref" ] || { _err "move-card requires --list"; return 1; }

    list_id="$(_trello_resolve_list_id "$board_id" "$list_ref")" || return 1
    _trello_write PUT "/cards/${card}" \
        --data-urlencode "idList=${list_id}" |
        jq -r '"Moved card: " + (.name // "Untitled card") + " | " + (.url // .id)'
}

_trello_rename_card() {
    local card="" name=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --card) card="$(_card_ref "$2")"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            *) _err "Unknown rename-card option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$card" ] || { _err "rename-card requires --card"; return 1; }
    [ -n "$name" ] || { _err "rename-card requires --name"; return 1; }

    _trello_write PUT "/cards/${card}" \
        --data-urlencode "name=${name}" |
        jq -r '"Renamed card: " + (.name // "Untitled card") + " | " + (.url // .id)'
}

_trello_set_desc() {
    local card="" file="" desc

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --card) card="$(_card_ref "$2")"; shift 2 ;;
            --file) file="$2"; shift 2 ;;
            *) _err "Unknown set-desc option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$card" ] || { _err "set-desc requires --card"; return 1; }
    [ -n "$file" ] || { _err "set-desc requires --file"; return 1; }
    desc="$(_read_file "$file")" || return 1

    _trello_write PUT "/cards/${card}" \
        --data-urlencode "desc=${desc}" |
        jq -r '"Updated description: " + (.name // "Untitled card") + " | " + (.url // .id)'
}

_trello_comment() {
    local card="" text="" file=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --card) card="$(_card_ref "$2")"; shift 2 ;;
            --text) text="$2"; shift 2 ;;
            --file) file="$2"; shift 2 ;;
            *) _err "Unknown comment option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$card" ] || { _err "comment requires --card"; return 1; }
    if [ -n "$text" ] && [ -n "$file" ]; then
        _err "Use either --text or --file, not both"
        return 1
    fi
    if [ -n "$file" ]; then
        text="$(_read_file "$file")" || return 1
    fi
    [ -n "$text" ] || { _err "comment requires --text or --file"; return 1; }

    _trello_write POST "/cards/${card}/actions/comments" \
        --data-urlencode "text=${text}" |
        jq -r '"Added comment at " + (.date // "unknown date")'
}

_trello_render_cards() {
    local lists_file="$1"
    local cards_file="$2"

    jq -r --slurpfile lists "$lists_file" '
      def list_name($id):
        (($lists[0][] | select(.id == $id) | .name) // "Unknown list");
      def open_list_cards:
        map(select(.idList as $list_id | any($lists[0][]; .id == $list_id)));
      def quote_lines($indent):
        gsub("\r"; "") | split("\n") | map($indent + "> " + .) | join("\n");
      def labels:
        ((.labels // []) | map(.name // "") | map(select(. != "")) | join(", "));
      def checklist_progress:
        ((.checklists // []) |
          map((.name // "Checklist") + " " +
            (((.checkItems // []) | map(select(.state == "complete")) | length) | tostring) +
            "/" +
            (((.checkItems // []) | length) | tostring)
          ) |
          join(", "));
      def description:
        if ((.desc // "") | length) > 0 then
          "\n  - Description:\n" + ((.desc // "") | quote_lines("    "))
        else "" end;
      def comment_text:
        (.data.text // .display.entities.comment.text // "");
      def comments:
        ((.actions // []) |
          map(select(.type == "commentCard" and ((comment_text | length) > 0))) |
          sort_by(.date)
        ) as $comments |
        if ($comments | length) > 0 then
          "\n  - Comments:\n" +
          ($comments |
            map(
              "    - " + (.date // "unknown date") +
              " by " + (.memberCreator.fullName // .memberCreator.username // "Unknown") + ":\n" +
              (comment_text | quote_lines("      "))
            ) |
            join("\n")
          )
        else "" end;
      open_list_cards as $cards |
      if ($cards | length) == 0 then
        "_No open cards._\n"
      else
        $cards |
        sort_by(.idList) |
        group_by(.idList)[] |
        "### " + list_name(.[0].idList) + "\n\n" +
        (map(
          "- [" + (.name // "Untitled card") + "](" + (.url // "") + ")" +
          (if (.due // "") != "" then " | due: " + .due else "" end) +
          (if (labels | length) > 0 then " | labels: " + labels else "" end) +
          (if (checklist_progress | length) > 0 then " | checklists: " + checklist_progress else "" end) +
          description +
          comments
        ) | join("\n")) + "\n"
      end
    ' "$cards_file"
}

_trello_sync() {
    local out tmp_out board_ids board_id board_file lists_file cards_file
    local board_name board_url refreshed
    local custom_out=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/trello-qa.md"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown trello sync option: $1"; return 1 ;;
        esac
    done

    _trello_ready || return 1
    _require_var TRELLO_BOARD_IDS || {
        _err "TRELLO_BOARD_IDS is required for sync"
        _say "NEXT: run './lifeos.sh trello list-boards' and add desired IDs to .env"
        return 1
    }

    if [ -n "$custom_out" ]; then
        out="$custom_out"
        _ensure_parent_dir "$out" || return 1
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/trello.md"
    fi

    tmp_out="$(mktemp "${out}.XXXXXX")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    {
        printf '# Trello\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf 'Synced board IDs: `%s`\n\n' "$TRELLO_BOARD_IDS"
    } > "$tmp_out"

    board_ids="$(printf '%s' "$TRELLO_BOARD_IDS" | tr ',' ' ')"
    for board_id in $board_ids; do
        board_id="$(_trim "$board_id")"
        [ -n "$board_id" ] || continue

        board_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-board.XXXXXX")" || return 1
        lists_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-lists.XXXXXX")" || return 1
        cards_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-cards.XXXXXX")" || return 1

        if ! _trello_get "/boards/${board_id}" --data-urlencode "fields=name,url" > "$board_file"; then
            {
                printf '## Board `%s`\n\n' "$board_id"
                printf 'Could not fetch board metadata.\n\n'
            } >> "$tmp_out"
            continue
        fi

        _trello_get "/boards/${board_id}/lists" \
            --data-urlencode "filter=open" \
            --data-urlencode "fields=name" > "$lists_file" || return 1

        _trello_get "/boards/${board_id}/cards/open" \
            --data-urlencode "fields=name,idList,due,url,labels,desc" \
            --data-urlencode "checklists=all" \
            --data-urlencode "actions=commentCard" \
            --data-urlencode "actions_limit=1000" \
            --data-urlencode "action_fields=data,date,type" \
            --data-urlencode "action_memberCreator_fields=fullName,username" > "$cards_file" || return 1

        board_name="$(jq -r '.name // "Untitled board"' "$board_file")"
        board_url="$(jq -r '.url // ""' "$board_file")"

        {
            printf '## %s\n\n' "$board_name"
            [ -n "$board_url" ] && printf '%s\n\n' "$board_url"
            _trello_render_cards "$lists_file" "$cards_file"
            printf '\n'
        } >> "$tmp_out"
    done

    mv "$tmp_out" "$out"
    _say "Updated $out"
}

_calendar_helper() {
    python3 "${SCRIPT_DIR}/google-calendar-auth.py" "$@"
}

_calendar_render_helper() {
    python3 "${SCRIPT_DIR}/google-calendar-render.py" "$@"
}

_calendar_ready() {
    _require_var GOOGLE_CALENDAR_CREDENTIALS_PATH || return 1
    _require_var GOOGLE_CALENDAR_TOKEN_PATH || return 1
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    _check_command python3 >/dev/null || { _err "python3 is required"; return 1; }
    if [ ! -f "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" ]; then
        _err "Google Calendar credentials file does not exist: $(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)"
        return 1
    fi
    return 0
}

_calendar_token_ready() {
    _calendar_ready || return 1
    if [ ! -f "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)" ]; then
        _err "Google Calendar token file does not exist: $(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
        _say "NEXT: run './lifeos.sh calendar auth'"
        return 1
    fi
    return 0
}

_calendar_auth() {
    _calendar_ready || return 1
    _calendar_helper auth "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
}

_calendar_access_token() {
    _calendar_token_ready || return 1
    _calendar_helper access-token "$(_path_value GOOGLE_CALENDAR_CREDENTIALS_PATH)" "$(_path_value GOOGLE_CALENDAR_TOKEN_PATH)"
}

_calendar_get() {
    local endpoint="$1"
    local token
    shift
    token="$(_calendar_access_token)" || return 1
    curl -fsS --get "https://www.googleapis.com/calendar/v3${endpoint}" \
        -H "Authorization: Bearer ${token}" \
        "$@"
}

_calendar_write() {
    local method="$1" endpoint="$2" body="$3"
    local token
    shift 3
    token="$(_calendar_access_token)" || return 1
    curl -fsS -X "$method" "https://www.googleapis.com/calendar/v3${endpoint}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$body" \
        "$@"
}

_people_helper() {
    python3 "${SCRIPT_DIR}/google-people.py" "$@"
}

_calendar_write_helper() {
    python3 "${SCRIPT_DIR}/google-calendar-write.py" "$@"
}

_urlencode() {
    jq -rn --arg value "$1" '$value | @uri'
}

_google_accounts_path() {
    if _var_is_set GOOGLE_ACCOUNTS_PATH; then
        _path_value GOOGLE_ACCOUNTS_PATH
    else
        printf '%s/google-accounts.json\n' "$SCRIPT_DIR"
    fi
}

_tool_path() {
    local value="$1"
    case "$value" in
        '') return 1 ;;
        /*) printf '%s\n' "$value" ;;
        ~/*) printf '%s/%s\n' "$HOME" "${value#~/}" ;;
        \$CONFIGS/*) printf '%s/%s\n' "$CONFIGS" "${value#\$CONFIGS/}" ;;
        \$HOME/*) printf '%s/%s\n' "$HOME" "${value#\$HOME/}" ;;
        *) printf '%s/%s\n' "$SCRIPT_DIR" "$value" ;;
    esac
}

_google_accounts_ready() {
    local config
    config="$(_google_accounts_path)"
    _check_command curl >/dev/null || { _err "curl is required"; return 1; }
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    _check_command python3 >/dev/null || { _err "python3 is required"; return 1; }
    if [ ! -f "$config" ]; then
        _err "Google account config does not exist: $config"
        _say "NEXT: cp ${SCRIPT_DIR}/google-accounts.example.json $config"
        return 1
    fi
    return 0
}

_google_account_exists() {
    local alias="$1"
    _google_accounts_ready || return 1
    jq -e --arg alias "$alias" 'any(.accounts[]?; .alias == $alias)' "$(_google_accounts_path)" >/dev/null
}

_google_account_value() {
    local alias="$1"
    local filter="$2"
    jq -er --arg alias "$alias" "(.accounts[]? | select(.alias == \$alias) | ${filter}) // empty" "$(_google_accounts_path)"
}

_google_account_path() {
    local alias="$1"
    local filter="$2"
    local value
    value="$(_google_account_value "$alias" "$filter")" || return 1
    _tool_path "$value"
}

_google_account_email() {
    local alias="$1"
    _google_account_value "$alias" '.email // ""' 2>/dev/null || printf ''
}

_google_accounts_list() {
    _google_accounts_ready || return 1
    jq -r '
      (.accounts // [])[] |
      "- " + (.alias // "missing-alias") +
      " | email: " + (.email // "") +
      " | gmail: " + (((.gmail.enabled // false) == true) | tostring) +
      " | drive: " + (((.drive.enabled // false) == true) | tostring)
    ' "$(_google_accounts_path)"
}

_google_enabled_aliases() {
    local service="$1"
    _google_accounts_ready || return 1
    jq -r --arg service "$service" '
      (.accounts // [])[] |
      select((.[$service].enabled // false) == true) |
      .alias
    ' "$(_google_accounts_path)"
}

_google_account_scopes() {
    local alias="$1"
    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    jq -r --arg alias "$alias" '
      (.accounts[]? | select(.alias == $alias)) as $account |
      [
        (if (($account.gmail.enabled // false) == true) then
          "https://www.googleapis.com/auth/gmail.readonly"
        else empty end),
        (if (($account.drive.enabled // false) == true) then
          "https://www.googleapis.com/auth/drive.metadata.readonly",
          "https://www.googleapis.com/auth/drive.readonly",
          "https://www.googleapis.com/auth/spreadsheets.readonly"
        else empty end)
      ] | .[]
    ' "$(_google_accounts_path)"
}

_google_oauth_helper() {
    python3 "${SCRIPT_DIR}/google-oauth.py" "$@"
}

_google_auth() {
    local alias="${1:-}" credentials_path token_path no_browser=""
    local scopes=() scope

    [ -n "$alias" ] || { _err "google auth requires ALIAS"; return 1; }
    shift || true
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-browser) no_browser="--no-browser"; shift ;;
            *) _err "Unknown google auth option: $1"; return 1 ;;
        esac
    done

    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    credentials_path="$(_google_account_path "$alias" '.credentials_path // "google-credentials.json"')" || return 1
    token_path="$(_google_account_path "$alias" '.token_path')" || { _err "Google account '$alias' needs token_path"; return 1; }
    if [ ! -f "$credentials_path" ]; then
        _err "Google credentials file does not exist: $credentials_path"
        return 1
    fi

    while IFS= read -r scope || [ -n "$scope" ]; do
        [ -n "$scope" ] || continue
        scopes+=( "$scope" )
    done <<EOF
$(_google_account_scopes "$alias")
EOF

    if [ "${#scopes[@]}" -eq 0 ]; then
        _err "Google account '$alias' has no enabled Gmail or Drive scopes"
        return 1
    fi

    if [ -n "$no_browser" ]; then
        _google_oauth_helper auth "$credentials_path" "$token_path" "${scopes[@]}" "$no_browser"
    else
        _google_oauth_helper auth "$credentials_path" "$token_path" "${scopes[@]}"
    fi
}

_google_access_token() {
    local alias="$1" credentials_path token_path
    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    credentials_path="$(_google_account_path "$alias" '.credentials_path // "google-credentials.json"')" || return 1
    token_path="$(_google_account_path "$alias" '.token_path')" || { _err "Google account '$alias' needs token_path"; return 1; }
    if [ ! -f "$token_path" ]; then
        _err "Google token file does not exist for alias '$alias': $token_path"
        _say "NEXT: run './lifeos.sh google auth $alias'" >&2
        return 1
    fi
    _google_oauth_helper access-token "$credentials_path" "$token_path"
}

_google_get_url() {
    local alias="$1"
    local url="$2"
    local token
    shift 2
    token="$(_google_access_token "$alias")" || return 1
    curl -fsS --get "$url" \
        -H "Authorization: Bearer ${token}" \
        "$@"
}

_gmail_query() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.query // "in:inbox newer_than:30d -label:Newsletters"' 2>/dev/null || printf 'in:inbox newer_than:30d -label:Newsletters'
}

_gmail_max_results() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.max_results // 150' 2>/dev/null || printf '150'
}

_gmail_body_limit() {
    local alias="$1"
    _google_account_value "$alias" '.gmail.body_character_limit // 8000' 2>/dev/null || printf '8000'
}

_gmail_sources_dir() {
    printf '%s/gmail\n' "$(_sources_dir)"
}

_gmail_output_for_alias() {
    local alias="$1"
    local qa="$2"
    if [ "$qa" = "1" ]; then
        printf '%s/gmail-qa/%s.md\n' "$SCRIPT_DIR" "$alias"
    else
        printf '%s/%s.md\n' "$(_gmail_sources_dir)" "$alias"
    fi
}

_gmail_render_helper() {
    python3 "${SCRIPT_DIR}/google-gmail-render.py" "$@"
}

_gmail_sync_alias() {
    local alias="$1"
    local out="$2"
    local query max_results body_limit email_address refreshed
    local list_file msg_dir messages_file message_id message_file count

    _google_account_exists "$alias" || { _err "Unknown Google account alias: $alias"; return 1; }
    query="$(_gmail_query "$alias")"
    max_results="$(_gmail_max_results "$alias")"
    body_limit="$(_gmail_body_limit "$alias")"
    email_address="$(_google_account_email "$alias")"
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    _ensure_parent_dir "$out" || return 1
    list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-list.XXXXXX")" || return 1
    msg_dir="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-gmail-messages.XXXXXX")" || return 1
    messages_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-gmail-render.XXXXXX")" || return 1

    _say "Syncing Gmail: ${alias}" >&2
    _google_get_url "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages" \
        --data-urlencode "q=${query}" \
        --data-urlencode "maxResults=${max_results}" > "$list_file" || return 1

    count=0
    for message_id in $(jq -r '.messages[]?.id' "$list_file"); do
        message_file="${msg_dir}/${count}.json"
        _google_get_url "$alias" "https://gmail.googleapis.com/gmail/v1/users/me/messages/${message_id}" \
            --data-urlencode "format=full" > "$message_file" || return 1
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        jq -n '{messages: []}' > "$messages_file"
    else
        jq -s '{messages: .}' "${msg_dir}"/*.json > "$messages_file"
    fi

    _gmail_render_helper "$alias" "$email_address" "$query" "$max_results" "$body_limit" "$refreshed" "$messages_file" > "$out" || return 1
    _say "Updated $out"
}

_gmail_write_index() {
    local dir="$1"
    local refreshed="$2"
    shift 2
    {
        printf '# Gmail\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf '## Account Snapshots\n\n'
        for alias in "$@"; do
            printf -- '- [%s](%s.md)\n' "$alias" "$alias"
        done
    } > "${dir}/index.md"
}

_gmail_sync() {
    local all=0 qa=0 custom_out="" alias aliases="" out dir refreshed

    case "${1:-}" in
        --all) all=1; shift ;;
        '') _err "gmail sync requires ALIAS or --all"; return 1 ;;
        *) alias="$1"; shift ;;
    esac

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa) qa=1; shift ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown gmail sync option: $1"; return 1 ;;
        esac
    done

    if [ "$all" -eq 1 ]; then
        [ -z "$custom_out" ] || { _err "gmail sync --all does not support --output"; return 1; }
        aliases="$(_google_enabled_aliases gmail)" || return 1
        [ -n "$aliases" ] || { _err "No Gmail-enabled Google aliases configured"; return 1; }
        if [ "$qa" -eq 1 ]; then
            dir="${SCRIPT_DIR}/gmail-qa"
        else
            _vault_ready || return 1
            _ensure_sources_dir || return 1
            dir="$(_gmail_sources_dir)"
        fi
        [ -d "$dir" ] || mkdir -p "$dir"
        for alias in $aliases; do
            _gmail_sync_alias "$alias" "${dir}/${alias}.md" || return 1
        done
        refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        _gmail_write_index "$dir" "$refreshed" $aliases
        _say "Updated ${dir}/index.md"
        return 0
    fi

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    elif [ "$qa" -eq 1 ]; then
        out="$(_gmail_output_for_alias "$alias" 1)"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_gmail_output_for_alias "$alias" 0)"
    fi
    _gmail_sync_alias "$alias" "$out"
}

_drive_accounts() {
    _google_accounts_ready || return 1
    jq -r '
      (.accounts // [])[] |
      select((.drive.enabled // false) == true) |
      "- " + (.alias // "missing-alias") + " | email: " + (.email // "")
    ' "$(_google_accounts_path)"
}

_drive_page_size() {
    local alias="$1"
    _google_account_value "$alias" '.drive.search_page_size // 20' 2>/dev/null || printf '20'
}

_drive_read_limit() {
    local alias="$1"
    _google_account_value "$alias" '.drive.read_character_limit // 20000' 2>/dev/null || printf '20000'
}

_drive_sheet_row_limit() {
    local alias="$1"
    _google_account_value "$alias" '.drive.sheet_row_limit // 200' 2>/dev/null || printf '200'
}

_drive_query_escape() {
    printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g"
}

_drive_file_id() {
    local ref="$1"
    case "$ref" in
        *'/d/'*)
            ref="${ref#*/d/}"
            ref="${ref%%/*}"
            ;;
        *'id='*)
            ref="${ref#*id=}"
            ref="${ref%%&*}"
            ;;
    esac
    printf '%s\n' "$ref"
}

_drive_files_human() {
    jq -r '
      (.files // [])[] |
      "- " + (.name // "Untitled") +
      " | id: " + (.id // "") +
      " | type: " + (.mimeType // "") +
      " | modified: " + (.modifiedTime // "") +
      " | owner: " + (((.owners // []) | map(.emailAddress // .displayName // "") | map(select(. != "")) | join(", "))) +
      " | " + (.webViewLink // "")
    '
}

_drive_meta_human() {
    jq -r '
      "Name: " + (.name // "Untitled") + "\n" +
      "ID: " + (.id // "") + "\n" +
      "MIME type: " + (.mimeType // "") + "\n" +
      "Modified: " + (.modifiedTime // "") + "\n" +
      "Owners: " + (((.owners // []) | map(.emailAddress // .displayName // "") | map(select(. != "")) | join(", "))) + "\n" +
      "Parents: " + (((.parents // []) | join(", "))) + "\n" +
      "Drive ID: " + (.driveId // "") + "\n" +
      "URL: " + (.webViewLink // "")
    '
}

_drive_fetch_meta() {
    local alias="$1"
    local file_id="$2"
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files/${file_id}" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "fields=id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId,size"
}

_drive_search() {
    local alias="${1:-}" query="${2:-}" json=0 page_size escaped q
    local result_file
    [ -n "$alias" ] || { _err "drive search requires ALIAS"; return 1; }
    [ -n "$query" ] || { _err "drive search requires QUERY"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive search option: $1"; return 1 ;;
        esac
    done
    page_size="$(_drive_page_size "$alias")"
    escaped="$(_drive_query_escape "$query")"
    q="trashed = false and (name contains '${escaped}' or fullText contains '${escaped}')"
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-search.XXXXXX")" || return 1
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files" \
        --data-urlencode "q=${q}" \
        --data-urlencode "pageSize=${page_size}" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "includeItemsFromAllDrives=true" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId),nextPageToken" > "$result_file" || return 1

    if [ "$json" -eq 1 ]; then
        cat "$result_file"
    else
        _drive_files_human < "$result_file"
    fi
}

_drive_list() {
    local alias="${1:-}" folder_id="${2:-}" json=0 q
    local result_file
    [ -n "$alias" ] || { _err "drive list requires ALIAS"; return 1; }
    [ -n "$folder_id" ] || { _err "drive list requires FOLDER_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive list option: $1"; return 1 ;;
        esac
    done
    q="'$(_drive_query_escape "$folder_id")' in parents and trashed = false"
    result_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-list.XXXXXX")" || return 1
    _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files" \
        --data-urlencode "q=${q}" \
        --data-urlencode "pageSize=$(_drive_page_size "$alias")" \
        --data-urlencode "supportsAllDrives=true" \
        --data-urlencode "includeItemsFromAllDrives=true" \
        --data-urlencode "fields=files(id,name,mimeType,modifiedTime,webViewLink,owners(displayName,emailAddress),parents,driveId),nextPageToken" > "$result_file" || return 1

    if [ "$json" -eq 1 ]; then
        cat "$result_file"
    else
        _drive_files_human < "$result_file"
    fi
}

_drive_meta() {
    local alias="${1:-}" ref="${2:-}" json=0 file_id
    [ -n "$alias" ] || { _err "drive meta requires ALIAS"; return 1; }
    [ -n "$ref" ] || { _err "drive meta requires FILE_URL_OR_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            *) _err "Unknown drive meta option: $1"; return 1 ;;
        esac
    done
    file_id="$(_drive_file_id "$ref")"
    if [ "$json" -eq 1 ]; then
        _drive_fetch_meta "$alias" "$file_id"
    else
        _drive_fetch_meta "$alias" "$file_id" | _drive_meta_human
    fi
}

_single_quote_sheet_name() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

_text_cap_file() {
    python3 -c 'import sys
limit = int(sys.argv[1])
data = sys.stdin.read()
if len(data) <= limit:
    print(data, end="")
else:
    print(data[:limit].rstrip(), end="")
    print("\n\n[content truncated]")' "$1"
}

_drive_read() {
    local alias="${1:-}" ref="${2:-}" range="" file_id meta_file mime name limit content_file
    local sheet_meta_file values_file sheet_title escaped_title encoded_range
    [ -n "$alias" ] || { _err "drive read requires ALIAS"; return 1; }
    [ -n "$ref" ] || { _err "drive read requires FILE_URL_OR_ID"; return 1; }
    shift 2
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --range) [ -n "${2:-}" ] || { _err "--range requires RANGE"; return 1; }; range="$2"; shift 2 ;;
            *) _err "Unknown drive read option: $1"; return 1 ;;
        esac
    done

    file_id="$(_drive_file_id "$ref")"
    meta_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-meta.XXXXXX")" || return 1
    _drive_fetch_meta "$alias" "$file_id" > "$meta_file" || return 1
    mime="$(jq -r '.mimeType // ""' "$meta_file")"
    name="$(jq -r '.name // "Untitled"' "$meta_file")"

    case "$mime" in
        application/vnd.google-apps.document)
            content_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-drive-doc.XXXXXX")" || return 1
            _google_get_url "$alias" "https://www.googleapis.com/drive/v3/files/${file_id}/export" \
                --data-urlencode "mimeType=text/plain" > "$content_file" || return 1
            limit="$(_drive_read_limit "$alias")"
            printf '# Google Doc - %s\n\n' "$name"
            printf 'Account alias: `%s`\n\n' "$alias"
            printf 'File ID: `%s`\n\n' "$file_id"
            _text_cap_file "$limit" < "$content_file"
            ;;
        application/vnd.google-apps.spreadsheet)
            sheet_meta_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-sheet-meta.XXXXXX")" || return 1
            values_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-sheet-values.XXXXXX")" || return 1
            _google_get_url "$alias" "https://sheets.googleapis.com/v4/spreadsheets/${file_id}" \
                --data-urlencode "fields=properties(title),sheets(properties(sheetId,title,gridProperties(rowCount,columnCount)))" > "$sheet_meta_file" || return 1
            if [ -z "$range" ]; then
                sheet_title="$(jq -r '.sheets[0].properties.title // "Sheet1"' "$sheet_meta_file")"
                escaped_title="$(_single_quote_sheet_name "$sheet_title")"
                range="${escaped_title}!A1:Z$(_drive_sheet_row_limit "$alias")"
            fi
            encoded_range="$(_urlencode "$range")" || return 1
            _google_get_url "$alias" "https://sheets.googleapis.com/v4/spreadsheets/${file_id}/values/${encoded_range}" > "$values_file" || return 1
            python3 "${SCRIPT_DIR}/google-sheets-render.py" "$alias" "$file_id" "$sheet_meta_file" "$values_file"
            ;;
        *)
            _warn "Drive read supports Google Docs and Google Sheets for now. Showing metadata only."
            _drive_meta_human < "$meta_file"
            ;;
    esac
}

_calendar_ids() {
    if _var_is_set GOOGLE_CALENDAR_IDS; then
        printf '%s' "$GOOGLE_CALENDAR_IDS"
    else
        printf 'primary'
    fi
}

_calendar_writable_ids() {
    if _var_is_set LIFEOS_CALENDAR_WRITABLE_IDS; then
        printf '%s' "$LIFEOS_CALENDAR_WRITABLE_IDS"
    else
        printf 'primary'
    fi
}

_calendar_is_writable() {
    local target="$1" id
    for id in $(printf '%s' "$(_calendar_writable_ids)" | tr ',' ' '); do
        id="$(_trim "$id")"
        [ -n "$id" ] || continue
        [ "$id" = "$target" ] && return 0
    done
    return 1
}

_people_aliases_path() {
    if _var_is_set LIFEOS_PEOPLE_ALIASES_PATH; then
        _path_value LIFEOS_PEOPLE_ALIASES_PATH
    else
        printf '%s/people-aliases.json\n' "$SCRIPT_DIR"
    fi
}

# Look up a short name in the local alias map (case-insensitive). Prints the
# mapped email on a hit; non-zero with no output on a miss or missing file.
_people_alias_lookup() {
    local raw="$1" path lower email
    path="$(_people_aliases_path)"
    [ -f "$path" ] || return 1
    lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    email="$(jq -r --arg k "$lower" '
        (.aliases // {}) | to_entries[]
        | select((.key | ascii_downcase) == $k) | .value
    ' "$path" 2>/dev/null | head -n 1)"
    [ -n "$email" ] || return 1
    printf '%s' "$email"
}

# Resolve an attendee token to an email. Resolution order:
#   1. A value containing "@" is treated as a literal email.
#   2. The local alias map (people-aliases.json) is checked next, so frequent
#      invitees resolve deterministically regardless of Google Contacts.
#   3. Otherwise it is looked up in Google contacts via the People API: 0 or >1
#      matches is an error (caller must disambiguate), exactly 1 prints the email.
_people_resolve_attendee() {
    local raw="$1" token results count alias_email
    case "$raw" in
        *@*) printf '%s' "$raw"; return 0 ;;
    esac
    if alias_email="$(_people_alias_lookup "$raw")"; then
        printf '%s' "$alias_email"
        return 0
    fi
    token="$(_calendar_access_token)" || return 1
    results="$(_people_helper resolve "$token" "$raw")" || return 1
    count="$(printf '%s' "$results" | jq 'length')" || return 1
    if [ "$count" -eq 0 ]; then
        _err "No contact matched '$raw'. Pass a full email address instead."
        return 1
    fi
    if [ "$count" -gt 1 ]; then
        _err "Ambiguous contact '$raw'. Candidates:"
        printf '%s' "$results" | jq -r '.[] | "  - " + .name + " <" + .email + ">"' >&2
        _err "Re-run --attendee with the chosen email, or 'lifeos people add-alias $raw EMAIL' to remember it."
        return 1
    fi
    printf '%s' "$results" | jq -r '.[0].email'
}

_people_aliases_ready() {
    _check_command jq >/dev/null || { _err "jq is required"; return 1; }
    return 0
}

# Preview how a name resolves, for interactive disambiguation. Prints the alias
# or literal email when one applies, otherwise the People API candidate list.
# With --json, always emits a JSON array so an agent can parse and choose.
_people_resolve() {
    local name="" json=0 token results count alias_email
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --json) json=1; shift ;;
            -*) _err "Unknown people resolve option: $1"; return 1 ;;
            *) if [ -z "$name" ]; then name="$1"; shift; else _err "Unexpected argument: $1"; return 1; fi ;;
        esac
    done
    [ -n "$name" ] || { _err "people resolve requires NAME"; return 1; }
    _people_aliases_ready || return 1

    case "$name" in
        *@*)
            if [ "$json" -eq 1 ]; then
                jq -cn --arg e "$name" '[{name:"(literal)",email:$e,source:"literal"}]'
            else
                _say "$name (literal email)"
            fi
            return 0
            ;;
    esac

    if alias_email="$(_people_alias_lookup "$name")"; then
        if [ "$json" -eq 1 ]; then
            jq -cn --arg n "$name" --arg e "$alias_email" '[{name:$n,email:$e,source:"alias"}]'
        else
            _say "$name -> $alias_email (alias)"
        fi
        return 0
    fi

    _calendar_token_ready || return 1
    token="$(_calendar_access_token)" || return 1
    results="$(_people_helper resolve "$token" "$name")" || return 1
    if [ "$json" -eq 1 ]; then
        printf '%s\n' "$results"
        return 0
    fi
    count="$(printf '%s' "$results" | jq 'length')" || return 1
    if [ "$count" -eq 0 ]; then
        _say "No contact matched '$name'."
        return 0
    fi
    printf '%s' "$results" | jq -r '.[] | "  - " + .name + " <" + .email + ">"'
}

_people_list_aliases() {
    local path
    _people_aliases_ready || return 1
    path="$(_people_aliases_path)"
    if [ ! -f "$path" ]; then
        _say "No alias file yet: $path"
        _say "NEXT: cp ${SCRIPT_DIR}/people-aliases.example.json $path"
        return 0
    fi
    jq -r '(.aliases // {}) | to_entries[] | "  " + .key + " -> " + .value' "$path"
}

_people_add_alias() {
    local name="${1:-}" email="${2:-}" path tmp
    [ -n "$name" ] || { _err "add-alias requires NAME"; return 1; }
    [ -n "$email" ] || { _err "add-alias requires EMAIL"; return 1; }
    case "$email" in *@*) ;; *) _err "EMAIL must look like an address: $email"; return 1 ;; esac
    _people_aliases_ready || return 1
    path="$(_people_aliases_path)"
    if [ ! -f "$path" ]; then
        printf '{\n  "aliases": {}\n}\n' > "$path" || { _err "Could not create alias file: $path"; return 1; }
        chmod 600 "$path" 2>/dev/null || true
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/lifeos-aliases.XXXXXX")" || return 1
    if jq --arg k "$name" --arg v "$email" '.aliases = ((.aliases // {}) + {($k): $v})' "$path" > "$tmp"; then
        mv "$tmp" "$path"
        _say "Saved alias: $name -> $email ($path)"
    else
        rm -f "$tmp"
        _err "Failed to update alias file: $path"
        return 1
    fi
}

# Default time zone for timed events: explicit override wins, else the target
# calendar's own time zone, else the system zone.
_calendar_default_tz() {
    local calendar_id="$1" encoded tz
    encoded="$(_urlencode "$calendar_id")" || return 1
    tz="$(_calendar_get "/calendars/${encoded}" --data-urlencode "fields=timeZone" 2>/dev/null | jq -r '.timeZone // empty')"
    if [ -n "$tz" ]; then
        printf '%s' "$tz"
        return 0
    fi
    if [ -f /etc/timezone ]; then
        _trim "$(cat /etc/timezone)"
        return 0
    fi
    printf 'UTC'
}

_calendar_list_calendars() {
    _calendar_token_ready || return 1
    _calendar_get "/users/me/calendarList" \
        --data-urlencode "fields=items(id,summary,primary,selected,hidden,accessRole)" |
        jq -r '
          (.items // [])[] |
          "- " + (.summary // "Untitled calendar") +
          " | id: " + (.id // "") +
          " | primary: " + ((.primary // false) | tostring) +
          " | selected: " + ((.selected // false) | tostring) +
          " | access: " + (.accessRole // "unknown")
        '
}

_calendar_window() {
    _calendar_helper date-window "$LIFEOS_DAYS_BACK" "$LIFEOS_DAYS_AHEAD"
}

_calendar_render_events() {
    _calendar_render_helper "$@"
}

_calendar_write_metadata() {
    local calendar_list_file="$1"
    local requested_id="$2"
    local out="$3"

    if ! jq -e --arg id "$requested_id" '
      if $id == "primary" then
        ((.items // []) | map(select(.primary == true)) | .[0])
      else
        ((.items // []) | map(select(.id == $id)) | .[0])
      end |
      select(. != null) |
      {
        id: (if $id == "primary" then "primary" else .id end),
        actualId: (.id // ""),
        summary: (.summary // $id),
        timeZone: (.timeZone // ""),
        primary: (.primary // false),
        selected: (.selected // false),
        accessRole: (.accessRole // "")
      }
    ' "$calendar_list_file" > "$out"; then
        jq -n --arg id "$requested_id" '{id: $id, actualId: $id, summary: $id}' > "$out"
    fi
}

_calendar_sync() {
    local out tmp_out calendar_ids calendar_id encoded_id calendar_file events_file calendar_list_file
    local refreshed window time_min time_max today calendar_name custom_out=""
    local render_args=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/calendar-qa.md"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires FILE"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown calendar sync option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1

    if [ -n "$custom_out" ]; then
        out="$custom_out"
        _ensure_parent_dir "$out" || return 1
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/calendar.md"
    fi

    tmp_out="$(mktemp "${out}.XXXXXX")" || return 1
    refreshed="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    window="$(_calendar_window)" || return 1
    time_min="$(printf '%s\n' "$window" | sed -n '1p')"
    time_max="$(printf '%s\n' "$window" | sed -n '2p')"
    today="$(printf '%s\n' "$window" | sed -n '3p')"

    {
        printf '# Google Calendar\n\n'
        printf 'Last refreshed: %s\n\n' "$refreshed"
        printf 'Today: %s\n\n' "$today"
        printf 'Window: %s to %s\n\n' "$time_min" "$time_max"
        printf 'Calendar IDs: `%s`\n\n' "$(_calendar_ids)"
    } > "$tmp_out"

    calendar_list_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar-list.XXXXXX")" || return 1
    _calendar_get "/users/me/calendarList" \
        --data-urlencode "fields=items(id,summary,primary,selected,hidden,accessRole,timeZone)" > "$calendar_list_file" || return 1

    calendar_ids="$(printf '%s' "$(_calendar_ids)" | tr ',' ' ')"
    for calendar_id in $calendar_ids; do
        calendar_id="$(_trim "$calendar_id")"
        [ -n "$calendar_id" ] || continue
        encoded_id="$(_urlencode "$calendar_id")" || return 1
        calendar_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-calendar.XXXXXX")" || return 1
        events_file="$(mktemp "${TMPDIR:-/tmp}/lifeos-events.XXXXXX")" || return 1

        _calendar_write_metadata "$calendar_list_file" "$calendar_id" "$calendar_file"

        calendar_name="$(jq -r '.summary // .id // "Calendar"' "$calendar_file")"
        _say "Syncing calendar: ${calendar_name}" >&2

        _calendar_get "/calendars/${encoded_id}/events" \
            --data-urlencode "singleEvents=true" \
            --data-urlencode "orderBy=startTime" \
            --data-urlencode "showDeleted=false" \
            --data-urlencode "timeMin=${time_min}" \
            --data-urlencode "timeMax=${time_max}" \
            --data-urlencode "maxResults=2500" \
            --data-urlencode "fields=items(id,status,summary,description,location,htmlLink,hangoutLink,conferenceData(entryPoints(entryPointType,label,uri)),start,end)" > "$events_file" || return 1

        render_args+=( "$calendar_file" "$events_file" )
    done

    if [ "${#render_args[@]}" -eq 0 ]; then
        _warn "No Google Calendar IDs were configured."
    else
        _calendar_render_events "${render_args[@]}" >> "$tmp_out" || return 1
    fi

    mv "$tmp_out" "$out"
    _say "Updated $out"
}

# Shared attendee resolution: turns the raw --attendee tokens (names or emails)
# into resolved emails, populating two parallel arrays by name convention:
#   _RESOLVED_EMAILS  – emails to send to the API
#   _RESOLVED_DISPLAY – "raw -> email" lines for the dry-run plan
_calendar_resolve_attendees() {
    local raw email
    _RESOLVED_EMAILS=()
    _RESOLVED_DISPLAY=()
    for raw in "$@"; do
        email="$(_people_resolve_attendee "$raw")" || return 1
        _RESOLVED_EMAILS+=("$email")
        if [ "$raw" = "$email" ]; then
            _RESOLVED_DISPLAY+=("$email")
        else
            _RESOLVED_DISPLAY+=("$raw -> $email")
        fi
    done
    return 0
}

_calendar_create_event() {
    local calendar_id="primary" title="" start="" end="" tz="" location="" desc="" desc_file=""
    local notify=0 execute=0 encoded body send_updates created
    local attendees_raw=() build_args=() recurrence_rules=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; shift 2 ;;
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires CALENDAR_ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --recurrence) [ -n "${2:-}" ] || { _err "--recurrence requires an RRULE line"; return 1; }; recurrence_rules+=("$2"); shift 2 ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown calendar create-event option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1
    [ -n "$title" ] || { _err "create-event requires --title"; return 1; }
    [ -n "$start" ] || { _err "create-event requires --start"; return 1; }
    if ! _calendar_is_writable "$calendar_id"; then
        _err "Calendar '$calendar_id' is not writable. Allowed: $(_calendar_writable_ids)"
        _say "NEXT: add it to LIFEOS_CALENDAR_WRITABLE_IDS in .env if you intend to write there."
        return 1
    fi
    if [ -n "$desc_file" ]; then
        [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }
        desc="$(cat "$desc_file")"
    fi

    # Timed events (start contains a time component) need a time zone.
    case "$start" in
        *T*) [ -n "$tz" ] || tz="$(_calendar_default_tz "$calendar_id")" || return 1 ;;
    esac

    if [ "${#attendees_raw[@]}" -gt 0 ]; then
        _calendar_resolve_attendees "${attendees_raw[@]}" || return 1
    else
        _RESOLVED_EMAILS=()
        _RESOLVED_DISPLAY=()
    fi

    build_args=(build-event --title "$title" --start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ -n "$location" ] && build_args+=(--location "$location")
    [ -n "$desc" ] && build_args+=(--description "$desc")
    local email rule
    for email in "${_RESOLVED_EMAILS[@]}"; do
        build_args+=(--attendee "$email")
    done
    for rule in "${recurrence_rules[@]}"; do
        build_args+=(--recurrence "$rule")
    done

    body="$(_calendar_write_helper "${build_args[@]}")" || return 1

    if [ "$notify" -eq 1 ]; then send_updates="all"; else send_updates="none"; fi

    _say "Calendar event create plan:"
    _say "Calendar: $calendar_id"
    _say "Title: $title"
    _say "Start: $start"
    _say "End: ${end:-<default>}"
    [ -n "$tz" ] && _say "Time zone: $tz"
    _say "Location: ${location:-<none>}"
    if [ "${#recurrence_rules[@]}" -gt 0 ]; then
        _say "Recurrence: ${recurrence_rules[*]}"
    fi
    if [ "${#_RESOLVED_DISPLAY[@]}" -gt 0 ]; then
        _say "Attendees: ${_RESOLVED_DISPLAY[*]}"
    else
        _say "Attendees: <none>"
    fi
    _say "Notify attendees: $([ "$notify" -eq 1 ] && echo "YES (email invites)" || echo "no")"

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no event was created. Re-run with --execute to create it."
        return 0
    fi

    encoded="$(_urlencode "$calendar_id")" || return 1
    created="$(_calendar_write POST "/calendars/${encoded}/events?sendUpdates=${send_updates}" "$body")" || return 1
    _say "Created event: $(printf '%s' "$created" | jq -r '.htmlLink // .id // "(unknown)"')"
}

_calendar_update_event() {
    local calendar_id="primary" event_id="" title="" start="" end="" tz="" location="" desc="" desc_file=""
    local notify=0 execute=0 replace_attendees=0 set_title=0 set_location=0 set_desc=0 scope_series=0
    local encoded event_encoded target_id target_encoded body send_updates current scope_label updated
    local attendees_raw=() build_args=() final_emails=() recurrence_rules=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --event) [ -n "${2:-}" ] || { _err "--event requires EVENT_ID"; return 1; }; event_id="$2"; shift 2 ;;
            --calendar) [ -n "${2:-}" ] || { _err "--calendar requires CALENDAR_ID"; return 1; }; calendar_id="$2"; shift 2 ;;
            --title) [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }; title="$2"; set_title=1; shift 2 ;;
            --start) [ -n "${2:-}" ] || { _err "--start requires DATE or DATETIME"; return 1; }; start="$2"; shift 2 ;;
            --end) [ -n "${2:-}" ] || { _err "--end requires DATE or DATETIME"; return 1; }; end="$2"; shift 2 ;;
            --tz) [ -n "${2:-}" ] || { _err "--tz requires ZONE"; return 1; }; tz="$2"; shift 2 ;;
            --location) [ -n "${2+x}" ] || { _err "--location requires TEXT"; return 1; }; location="$2"; set_location=1; shift 2 ;;
            --desc) [ -n "${2+x}" ] || { _err "--desc requires TEXT"; return 1; }; desc="$2"; set_desc=1; shift 2 ;;
            --desc-file) [ -n "${2:-}" ] || { _err "--desc-file requires FILE"; return 1; }; desc_file="$2"; set_desc=1; shift 2 ;;
            --attendee) [ -n "${2:-}" ] || { _err "--attendee requires NAME or EMAIL"; return 1; }; attendees_raw+=("$2"); shift 2 ;;
            --recurrence) [ -n "${2:-}" ] || { _err "--recurrence requires an RRULE line"; return 1; }; recurrence_rules+=("$2"); shift 2 ;;
            --replace-attendees) replace_attendees=1; shift ;;
            --series) scope_series=1; shift ;;
            --instance) scope_series=0; shift ;;
            --notify) notify=1; shift ;;
            --execute) execute=1; shift ;;
            --dry-run) execute=0; shift ;;
            *) _err "Unknown calendar update-event option: $1"; return 1 ;;
        esac
    done

    _calendar_token_ready || return 1
    [ -n "$event_id" ] || { _err "update-event requires --event"; return 1; }
    if ! _calendar_is_writable "$calendar_id"; then
        _err "Calendar '$calendar_id' is not writable. Allowed: $(_calendar_writable_ids)"
        return 1
    fi
    if [ "${#recurrence_rules[@]}" -gt 0 ] && [ "$scope_series" -ne 1 ]; then
        _err "--recurrence changes the recurrence rule, which only applies to the series. Re-run with --series."
        return 1
    fi
    if [ -n "$desc_file" ]; then
        [ -f "$desc_file" ] || { _err "Description file does not exist: $desc_file"; return 1; }
        desc="$(cat "$desc_file")"
    fi

    encoded="$(_urlencode "$calendar_id")" || return 1
    event_encoded="$(_urlencode "$event_id")" || return 1
    current="$(_calendar_get "/calendars/${encoded}/events/${event_encoded}")" || {
        _err "Could not fetch event '$event_id' on calendar '$calendar_id'."
        return 1
    }

    # Default target is the event ID as passed (a single instance for recurring
    # events). --series retargets the parent series master so the edit applies to
    # every occurrence; re-fetch it so the plan and attendee merge use its state.
    if [ "$scope_series" -eq 1 ]; then
        target_id="$(printf '%s' "$current" | jq -r '.recurringEventId // .id')"
        target_encoded="$(_urlencode "$target_id")" || return 1
        if [ "$target_id" != "$event_id" ]; then
            current="$(_calendar_get "/calendars/${encoded}/events/${target_encoded}")" || {
                _err "Could not fetch series master '$target_id'."
                return 1
            }
        fi
        scope_label="entire series ($target_id)"
    else
        target_id="$event_id"
        target_encoded="$event_encoded"
        if printf '%s' "$current" | jq -e '.recurringEventId' >/dev/null 2>&1; then
            scope_label="single occurrence (pass --series to edit all)"
        else
            scope_label="single event"
        fi
    fi

    case "$start" in
        *T*) [ -n "$tz" ] || tz="$(_calendar_default_tz "$calendar_id")" || return 1 ;;
    esac

    # Attendee handling: PATCH replaces the whole attendees array, so to ADD we
    # merge the existing list with the new one unless --replace-attendees is set.
    if [ "${#attendees_raw[@]}" -gt 0 ] || [ "$replace_attendees" -eq 1 ]; then
        if [ "${#attendees_raw[@]}" -gt 0 ]; then
            _calendar_resolve_attendees "${attendees_raw[@]}" || return 1
        else
            _RESOLVED_EMAILS=()
            _RESOLVED_DISPLAY=()
        fi
        if [ "$replace_attendees" -eq 1 ]; then
            final_emails=("${_RESOLVED_EMAILS[@]}")
        else
            local existing
            while IFS= read -r existing || [ -n "$existing" ]; do
                [ -n "$existing" ] || continue
                final_emails+=("$existing")
            done <<EOF
$(printf '%s' "$current" | jq -r '(.attendees // [])[] | .email // empty')
EOF
            final_emails+=("${_RESOLVED_EMAILS[@]}")
        fi
    fi

    build_args=(build-event)
    [ "$set_title" -eq 1 ] && build_args+=(--title "$title")
    [ -n "$start" ] && build_args+=(--start "$start")
    [ -n "$end" ] && build_args+=(--end "$end")
    [ -n "$tz" ] && build_args+=(--tz "$tz")
    [ "$set_location" -eq 1 ] && build_args+=(--location "$location")
    [ "$set_desc" -eq 1 ] && build_args+=(--description "$desc")
    local email rule
    for email in "${final_emails[@]}"; do
        build_args+=(--attendee "$email")
    done
    for rule in "${recurrence_rules[@]}"; do
        build_args+=(--recurrence "$rule")
    done

    body="$(_calendar_write_helper "${build_args[@]}")" || return 1

    if [ "$notify" -eq 1 ]; then send_updates="all"; else send_updates="none"; fi

    _say "Calendar event update plan:"
    _say "Calendar: $calendar_id"
    _say "Event: $event_id"
    _say "Scope: $scope_label"
    _say "Current title: $(printf '%s' "$current" | jq -r '.summary // "(none)"')"
    _say "Changes:"
    printf '%s' "$body" | jq .
    if [ "${#final_emails[@]}" -gt 0 ]; then
        _say "Final attendees: ${final_emails[*]}"
    fi
    _say "Notify attendees: $([ "$notify" -eq 1 ] && echo "YES (email invites)" || echo "no")"

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no event was updated. Re-run with --execute to apply."
        return 0
    fi

    updated="$(_calendar_write PATCH "/calendars/${encoded}/events/${target_encoded}?sendUpdates=${send_updates}" "$body")" || return 1
    _say "Updated event: $(printf '%s' "$updated" | jq -r '.htmlLink // .id // "(unknown)"')"
}


_open_austin_org_repo_path() {
    if _var_is_set OPEN_AUSTIN_ORG_REPO_PATH; then
        _path_value OPEN_AUSTIN_ORG_REPO_PATH
    else
        printf "%s/work/org\n" "$HOME"
    fi
}

_open_austin_org_snapshot_dir() {
    printf "%s/snapshot\n" "$(_open_austin_org_repo_path)"
}

_open_austin_org_ready() {
    local repo run
    repo="$(_open_austin_org_repo_path)"
    run="${repo}/tools/sync/run.sh"

    if [ ! -d "$repo" ]; then
        _err "OPEN_AUSTIN_ORG_REPO_PATH does not exist: $repo"
        return 1
    fi
    if [ ! -x "$run" ]; then
        _err "Open Austin org sync script is missing or not executable: $run"
        return 1
    fi
    return 0
}

_open_austin_org_path() {
    local repo snapshot
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"
    _say "Repo: $repo"
    _say "Snapshot: $snapshot"
    if _vault_ready >/dev/null 2>&1; then
        _say "LifeOS output: $(_sources_dir)/open-austin-org"
    fi
}

_copy_open_austin_org_snapshot() {
    local src="$1" dest="$2" name

    [ -d "$src" ] || { _err "Snapshot directory does not exist: $src"; return 1; }
    mkdir -p "$dest" || return 1

    find "$dest" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

    for name in issues.md labels.md board-org-kanban.md board-open-roles.md weekly-summary.md; do
        if [ -f "$src/$name" ]; then
            cp "$src/$name" "$dest/$name" || return 1
        fi
    done

    if [ -d "$src/issues" ]; then
        mkdir -p "$dest/issues" || return 1
        find "$src/issues" -maxdepth 1 -type f -name "*.md" -exec cp {} "$dest/issues/" \;
    fi
}

_open_austin_org_sync() {
    local custom_out="" repo snapshot out

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --qa)
                custom_out="${SCRIPT_DIR}/open-austin-org-qa"
                shift
                ;;
            --output)
                [ -n "${2:-}" ] || { _err "--output requires DIR"; return 1; }
                custom_out="$2"
                shift 2
                ;;
            *) _err "Unknown open-austin-org sync option: $1"; return 1 ;;
        esac
    done

    _open_austin_org_ready || return 1
    repo="$(_open_austin_org_repo_path)"
    snapshot="$(_open_austin_org_snapshot_dir)"

    _say "Refreshing Open Austin org snapshot from $repo" >&2
    (cd "$repo" && tools/sync/run.sh) || return 1

    if [ -n "$custom_out" ]; then
        out="$custom_out"
    else
        _vault_ready || return 1
        _ensure_sources_dir || return 1
        out="$(_sources_dir)/open-austin-org"
    fi

    _copy_open_austin_org_snapshot "$snapshot" "$out" || return 1

    _say "Updated $out"
    [ -f "$out/issues.md" ] && _say "- $out/issues.md"
    [ -f "$out/board-org-kanban.md" ] && _say "- $out/board-org-kanban.md"
    [ -f "$out/board-open-roles.md" ] && _say "- $out/board-open-roles.md"
    [ -f "$out/weekly-summary.md" ] && _say "- $out/weekly-summary.md"
}


_open_austin_org_github_repo() {
    if _var_is_set OPEN_AUSTIN_ORG_GITHUB_REPO; then
        _path_value OPEN_AUSTIN_ORG_GITHUB_REPO
    else
        printf 'open-austin/org\n'
    fi
}

_open_austin_org_gh_ready() {
    _check_command gh >/dev/null || { _err "gh is required"; return 1; }
    return 0
}

_open_austin_org_create_issue() {
    local repo title="" body="" body_file="" execute=0 sync_after=1 assign_me=0 login="" created_url=""
    local labels=() assignees=() cmd=()

    repo="$(_open_austin_org_github_repo)"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --title)
                [ -n "${2:-}" ] || { _err "--title requires TEXT"; return 1; }
                title="$2"
                shift 2
                ;;
            --body)
                [ -n "${2+x}" ] || { _err "--body requires TEXT"; return 1; }
                body="$2"
                shift 2
                ;;
            --body-file)
                [ -n "${2:-}" ] || { _err "--body-file requires FILE"; return 1; }
                body_file="$2"
                shift 2
                ;;
            --label)
                [ -n "${2:-}" ] || { _err "--label requires LABEL"; return 1; }
                labels+=("$2")
                shift 2
                ;;
            --assignee|--assign)
                [ -n "${2:-}" ] || { _err "$1 requires LOGIN"; return 1; }
                assignees+=("$2")
                shift 2
                ;;
            --assign-me)
                assign_me=1
                shift
                ;;
            --repo)
                [ -n "${2:-}" ] || { _err "--repo requires OWNER/REPO"; return 1; }
                repo="$2"
                shift 2
                ;;
            --execute)
                execute=1
                shift
                ;;
            --dry-run)
                execute=0
                shift
                ;;
            --no-sync)
                sync_after=0
                shift
                ;;
            *) _err "Unknown open-austin-org create-issue option: $1"; return 1 ;;
        esac
    done

    [ -n "$title" ] || { _err "create-issue requires --title"; return 1; }
    if [ -n "$body_file" ] && [ ! -f "$body_file" ]; then
        _err "Body file does not exist: $body_file"
        return 1
    fi

    if [ "$assign_me" -eq 1 ] && [ "$execute" -eq 1 ]; then
        _open_austin_org_gh_ready || return 1
        login="$(gh api user --jq .login)" || return 1
        assignees+=("$login")
    elif [ "$assign_me" -eq 1 ]; then
        assignees+=("@me")
    fi

    _say "GitHub issue create plan:"
    _say "Repo: $repo"
    _say "Title: $title"
    if [ -n "$body_file" ]; then
        _say "Body file: $body_file"
    elif [ -n "$body" ]; then
        _say "Body:"
        printf '%s\n' "$body"
    else
        _say "Body: <empty>"
    fi
    if [ "${#labels[@]}" -gt 0 ]; then
        _say "Labels: ${labels[*]}"
    else
        _say "Labels: <none>"
    fi
    if [ "${#assignees[@]}" -gt 0 ]; then
        _say "Assignees: ${assignees[*]}"
    else
        _say "Assignees: <none>"
    fi

    if [ "$execute" -ne 1 ]; then
        _say "DRY RUN: no GitHub issue was created. Re-run with --execute to create it."
        return 0
    fi

    _open_austin_org_gh_ready || return 1

    cmd=(gh issue create --repo "$repo" --title "$title")
    if [ -n "$body_file" ]; then
        cmd+=(--body-file "$body_file")
    else
        cmd+=(--body "$body")
    fi
    for label in "${labels[@]}"; do
        cmd+=(--label "$label")
    done
    for login in "${assignees[@]}"; do
        cmd+=(--assignee "$login")
    done

    created_url="$("${cmd[@]}")" || return 1
    _say "Created issue: $created_url"

    if [ "$sync_after" -eq 1 ]; then
        _open_austin_org_sync || return 1
    fi
}

_sync() {
    local status=0

    if _var_is_set TRELLO_API_KEY && _var_is_set TRELLO_TOKEN && _var_is_set TRELLO_BOARD_IDS; then
        _trello_sync || status=$?
    else
        _warn "Skipping Trello sync: Trello env values are incomplete."
    fi

    if _var_is_set GOOGLE_CALENDAR_CREDENTIALS_PATH || _var_is_set GOOGLE_CALENDAR_TOKEN_PATH; then
        _calendar_sync || status=$?
    else
        _warn "Skipping Calendar sync: Google Calendar is not configured."
    fi

    return "$status"
}

_load_env

case "${1:-help}" in
    help|-h|--help)
        _usage
        ;;
    doctor)
        _doctor
        ;;
    open)
        _open_vault
        ;;
    context)
        _context
        ;;
    trello)
        case "${2:-}" in
            list-boards) _trello_list_boards ;;
            list-lists) shift 2; _trello_list_lists "$@" ;;
            sync) shift 2; _trello_sync "$@" ;;
            add-card) shift 2; _trello_add_card "$@" ;;
            move-card) shift 2; _trello_move_card "$@" ;;
            rename-card) shift 2; _trello_rename_card "$@" ;;
            set-desc) shift 2; _trello_set_desc "$@" ;;
            comment) shift 2; _trello_comment "$@" ;;
            *) _err "Unknown Trello command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    calendar)
        case "${2:-}" in
            auth) shift 2; _calendar_auth "$@" ;;
            list-calendars) shift 2; _calendar_list_calendars "$@" ;;
            sync) shift 2; _calendar_sync "$@" ;;
            create-event) shift 2; _calendar_create_event "$@" ;;
            update-event) shift 2; _calendar_update_event "$@" ;;
            *) _err "Unknown Calendar command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    google)
        case "${2:-}" in
            accounts) shift 2; _google_accounts_list "$@" ;;
            auth) shift 2; _google_auth "$@" ;;
            *) _err "Unknown Google command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    people)
        case "${2:-}" in
            resolve) shift 2; _people_resolve "$@" ;;
            list-aliases) shift 2; _people_list_aliases "$@" ;;
            add-alias) shift 2; _people_add_alias "$@" ;;
            *) _err "Unknown People command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    gmail)
        case "${2:-}" in
            sync) shift 2; _gmail_sync "$@" ;;
            *) _err "Unknown Gmail command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    drive)
        case "${2:-}" in
            accounts) shift 2; _drive_accounts "$@" ;;
            search) shift 2; _drive_search "$@" ;;
            list) shift 2; _drive_list "$@" ;;
            meta) shift 2; _drive_meta "$@" ;;
            read) shift 2; _drive_read "$@" ;;
            *) _err "Unknown Drive command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    open-austin-org)
        case "${2:-}" in
            path) shift 2; _open_austin_org_path "$@" ;;
            sync) shift 2; _open_austin_org_sync "$@" ;;
            create-issue) shift 2; _open_austin_org_create_issue "$@" ;;
            *) _err "Unknown Open Austin org command: ${2:-}"; _usage; exit 1 ;;
        esac
        ;;
    sync)
        _sync
        ;;
    *)
        _err "Unknown command: $1"
        _usage
        exit 1
        ;;
esac
