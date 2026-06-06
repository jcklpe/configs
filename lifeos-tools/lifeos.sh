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
    local issues=0 vault sources file

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

            for file in README.md CURRENT.md now.md weekly-review.md; do
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
$vault/CURRENT.md
$vault/now.md
$vault/weekly-review.md
$vault/sources/trello.md
$vault/sources/calendar.md

Then add one relevant project file from:

$vault/projects/
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

_urlencode() {
    jq -rn --arg value "$1" '$value | @uri'
}

_calendar_ids() {
    if _var_is_set GOOGLE_CALENDAR_IDS; then
        printf '%s' "$GOOGLE_CALENDAR_IDS"
    else
        printf 'primary'
    fi
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
    local calendar_file="$1"
    local events_file="$2"

    _calendar_render_helper "$calendar_file" "$events_file"
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
            --data-urlencode "fields=items(id,status,summary,description,location,htmlLink,start,end)" > "$events_file" || return 1

        {
            _calendar_render_events "$calendar_file" "$events_file"
            printf '\n'
        } >> "$tmp_out"
    done

    mv "$tmp_out" "$out"
    _say "Updated $out"
}

_calendar_pending() {
    _warn "Google Calendar commands are pending the OAuth implementation."
    _warn "Trello and local vault commands are available now."
    return 2
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
            *) _err "Unknown Calendar command: ${2:-}"; _usage; exit 1 ;;
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
