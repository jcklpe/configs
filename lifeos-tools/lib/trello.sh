#!/usr/bin/env bash
##- lifeos Trello feature: board/list/card reads and writes, task-chain supersede/chain, and the Trello source-snapshot sync.
##- Sourced by lifeos.sh; depends on lib/common.sh and the bootstrap vars. _read_file and _card_ref are Trello-local helpers.

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

##- Task chains: supersede (link predecessor <-> successor) and chain traversal.
##- Links live in labeled comments ("Continues in:" / "Continues from:"); see
##- docs/archive/lifeos-tools-v2.md "Active Theme: Trello Task Chains".

# Most-recent comment text on a card whose text contains the given label, or empty.
_trello_link_comment() {
    local card="$1" label="$2"
    _trello_get "/cards/${card}/actions" \
        --data-urlencode "filter=commentCard" \
        --data-urlencode "limit=1000" 2>/dev/null |
        jq -r --arg label "$label" '
            [ .[] | select((.data.text // "") | contains($label)) ]
            | sort_by(.date) | reverse | (.[0].data.text // "")'
}

# Card id referenced by the most-recent labeled link comment on a card, or empty.
_trello_link_target() {
    local card="$1" label="$2" text rest
    text="$(_trello_link_comment "$card" "$label")" || return 1
    [ -n "$text" ] || return 0
    rest="${text#*"$label"}"
    rest="$(_trim "$rest")"
    [ -n "$rest" ] || return 0
    _card_ref "$rest"
}

# Append a link comment unless an equivalent one already targets the counterpart.
# Args: card_id label target_id target_url
_trello_write_link() {
    local card="$1" label="$2" target_id="$3" target_url="$4" existing
    existing="$(_trello_link_comment "$card" "$label")"
    if [ -n "$existing" ] && printf '%s' "$existing" | grep -qF "$target_id"; then
        _say "  link already present on ${card}: ${label} ${target_url} (skipped)"
        return 0
    fi
    _trello_write POST "/cards/${card}/actions/comments" \
        --data-urlencode "text=🔗 ${label} ${target_url}" >/dev/null
}

_trello_supersede() {
    local from="" to="" do_create="" board="" list_ref="" name="" desc="" desc_file=""
    local from_json from_url to_json to_url created list_id

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --from) from="$(_card_ref "$2")"; shift 2 ;;
            --to) to="$(_card_ref "$2")"; shift 2 ;;
            --create) do_create=1; shift ;;
            --board) board="$2"; shift 2 ;;
            --list) list_ref="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --desc) desc="$2"; shift 2 ;;
            --desc-file) desc_file="$2"; shift 2 ;;
            *) _err "Unknown supersede option: $1"; return 1 ;;
        esac
    done

    _trello_write_ready || return 1
    [ -n "$from" ] || { _err "supersede requires --from"; return 1; }

    if [ -n "$do_create" ]; then
        [ -z "$to" ] || { _err "--create builds the successor; do not also pass --to"; return 1; }
        [ -n "$list_ref" ] || { _err "supersede --create requires --list"; return 1; }
        [ -n "$name" ] || { _err "supersede --create requires --name"; return 1; }
        if [ -n "$desc" ] && [ -n "$desc_file" ]; then
            _err "Use either --desc or --desc-file, not both"; return 1
        fi
        if [ -n "$desc_file" ]; then
            desc="$(_read_file "$desc_file")" || return 1
        fi
    else
        [ -n "$to" ] || { _err "supersede requires --to (or use --create to make the successor)"; return 1; }
        if [ -n "$list_ref" ] || [ -n "$name" ] || [ -n "$desc" ] || [ -n "$desc_file" ]; then
            _err "--list/--name/--desc/--desc-file only apply with --create"; return 1
        fi
    fi

    # Pre-flight the predecessor before any write, so a typo'd ref fails clean.
    from_json="$(_trello_get "/cards/${from}" --data-urlencode "fields=name,url")" \
        || { _err "Could not read --from card '${from}' (check the id/url and read token)"; return 1; }
    from_url="$(printf '%s' "$from_json" | jq -r '.url // empty')"
    [ -n "$from_url" ] || { _err "--from card '${from}' not found"; return 1; }

    if [ -n "$do_create" ]; then
        list_id="$(_trello_resolve_list_id "$board" "$list_ref")" || return 1
        created="$(_trello_write POST "/cards" \
            --data-urlencode "idList=${list_id}" \
            --data-urlencode "name=${name}" \
            --data-urlencode "desc=${desc}")" \
            || { _err "Failed to create successor card; nothing linked"; return 1; }
        to="$(printf '%s' "$created" | jq -r '.id // empty')"
        to_url="$(printf '%s' "$created" | jq -r '.url // empty')"
        [ -n "$to" ] || { _err "Successor created but response had no id; aborting link"; return 1; }
        _say "Created successor: $(printf '%s' "$created" | jq -r '.name // "Untitled card"') | ${to_url}"
    else
        to_json="$(_trello_get "/cards/${to}" --data-urlencode "fields=name,url")" \
            || { _err "Could not read --to card '${to}' (check the id/url and read token)"; return 1; }
        to_url="$(printf '%s' "$to_json" | jq -r '.url // empty')"
        [ -n "$to_url" ] || { _err "--to card '${to}' not found"; return 1; }
    fi

    if [ "$from" = "$to" ]; then
        _err "--from and --to refer to the same card; nothing to link"; return 1
    fi

    # Successor back-link first, predecessor forward-link second (see design notes).
    _say "Linking chain ${from_url} -> ${to_url}"
    if ! _trello_write_link "$to" "Continues from:" "$from" "$from_url"; then
        _err "Failed to write the back-link on the successor; predecessor left untouched. Re-run when the write token works."
        return 1
    fi
    if ! _trello_write_link "$from" "Continues in:" "$to" "$to_url"; then
        _err "PARTIAL: the successor (${to_url}) now points back to the predecessor, but writing the forward link on the predecessor (${from_url}) FAILED."
        _err "Re-run the same command (idempotent: it only adds the missing forward link), or add manually on ${from_url}:  Continues in: ${to_url}"
        return 1
    fi
    _say "Superseded: ${from_url}  ->  ${to_url}"
}

_trello_chain() {
    local card="" want_json="" head prev cur guard visited seen order count
    local id meta name url current obj all idx

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --card) card="$(_card_ref "$2")"; shift 2 ;;
            --json) want_json=1; shift ;;
            *) _err "Unknown chain option: $1"; return 1 ;;
        esac
    done

    _trello_ready || return 1
    [ -n "$card" ] || { _err "chain requires --card"; return 1; }

    # Walk backward to the head of the chain (cycle/runaway guarded).
    head="$card"; visited=" "; guard=0
    while :; do
        case "$visited" in *" ${head} "*) break ;; esac
        visited="${visited}${head} "
        prev="$(_trello_link_target "$head" "Continues from:")" || break
        [ -n "$prev" ] || break
        case "$visited" in *" ${prev} "*) break ;; esac
        head="$prev"
        guard=$((guard + 1)); [ "$guard" -gt 100 ] && break
    done

    # Walk forward from the head, collecting the ordered chain.
    cur="$head"; seen=" "; order=""; guard=0
    while :; do
        case "$seen" in *" ${cur} "*) break ;; esac
        seen="${seen}${cur} "
        order="${order}${cur} "
        cur="$(_trello_link_target "$cur" "Continues in:")" || break
        [ -n "$cur" ] || break
        guard=$((guard + 1)); [ "$guard" -gt 100 ] && break
    done

    if [ -n "$want_json" ]; then
        all=""
        for id in $order; do
            meta="$(_trello_get "/cards/${id}" --data-urlencode "fields=name,url")" || meta='{}'
            obj="$(printf '%s' "$meta" | jq -c \
                --arg id "$id" \
                --argjson current "$( [ "$id" = "$card" ] && echo true || echo false )" \
                '{id: $id, name: (.name // null), url: (.url // null), current: $current}')"
            all="${all}${obj}
"
        done
        printf '%s' "$all" | jq -s '{chain: .}'
        return 0
    fi

    count="$(set -- $order; echo "$#")"
    _say "Task chain (head -> tail):"
    idx=1
    for id in $order; do
        meta="$(_trello_get "/cards/${id}" --data-urlencode "fields=name,url")" || meta=""
        name="$(printf '%s' "$meta" | jq -r '.name // "Unknown card"')"
        url="$(printf '%s' "$meta" | jq -r '.url // empty')"
        [ -n "$url" ] || url="(card ${id} unreadable)"
        if [ "$id" = "$card" ]; then current="  <-- you are here"; else current=""; fi
        printf '%d. %s%s\n     %s\n' "$idx" "$name" "$current" "$url"
        idx=$((idx + 1))
    done
    if [ "$count" -eq 1 ]; then
        _say "(no chain links found on this card)"
    fi
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
                custom_out="${QA_DIR}/trello-qa.md"
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
