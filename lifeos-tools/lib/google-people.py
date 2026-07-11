#!/usr/bin/env python3
"""Resolve attendee names to emails via the Google People API for lifeos.sh.

Read-only contact lookup used when inviting people to calendar events. Given a
name fragment (e.g. "lindsey"), returns candidate {name, email} matches so the
shell can decide: 0 -> error, 1 -> use it, many -> ask the user to disambiguate.

Saved contacts come from people/me/connections; people you've emailed but never
saved come from otherContacts:search. Stdlib only, no Google client libraries.
"""

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

CONNECTIONS_URL = "https://people.googleapis.com/v1/people/me/connections"
OTHER_SEARCH_URL = "https://people.googleapis.com/v1/otherContacts:search"


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def api_get(url, token, params):
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(
        f"{url}?{query}",
        headers={"Authorization": f"Bearer {token}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        if exc.code == 403:
            raise RuntimeError(
                "People API returned 403. Enable the People API for this Google "
                "project (https://console.cloud.google.com/apis/library/people.googleapis.com) "
                "and re-run `lifeos calendar auth` to grant contacts scopes.\n"
                f"{detail}"
            )
        raise RuntimeError(f"People API error {exc.code}: {detail}")


def person_emails(person):
    return [
        addr["value"]
        for addr in person.get("emailAddresses", [])
        if addr.get("value")
    ]


def person_name(person):
    names = person.get("names", [])
    if names and names[0].get("displayName"):
        return names[0]["displayName"]
    emails = person_emails(person)
    return emails[0] if emails else "(unknown)"


def matches(query, person):
    needle = query.lower()
    name = person_name(person).lower()
    if needle in name:
        return True
    return any(needle in email.lower() for email in person_emails(person))


def collect(query, candidates, seen, person):
    for email in person_emails(person):
        key = email.lower()
        if key in seen:
            continue
        seen.add(key)
        candidates.append({"name": person_name(person), "email": email})


def search_connections(token, query, candidates, seen):
    page_token = None
    while True:
        params = {
            "personFields": "names,emailAddresses",
            "pageSize": "1000",
        }
        if page_token:
            params["pageToken"] = page_token
        data = api_get(CONNECTIONS_URL, token, params)
        for person in data.get("connections", []):
            if matches(query, person):
                collect(query, candidates, seen, person)
        page_token = data.get("nextPageToken")
        if not page_token:
            break


def search_other_contacts(token, query, candidates, seen):
    # otherContacts:search needs the read mask passed as readMask and benefits
    # from a warmup call; a single query is usually enough for a CLI one-shot.
    params = {"query": query, "readMask": "names,emailAddresses", "pageSize": "20"}
    data = api_get(OTHER_SEARCH_URL, token, params)
    for result in data.get("results", []):
        person = result.get("person", {})
        if person_emails(person):
            collect(query, candidates, seen, person)


def resolve(token, query):
    query = query.strip()
    if not query:
        return fail("resolve requires a non-empty QUERY")
    candidates = []
    seen = set()
    search_connections(token, query, candidates, seen)
    if not candidates:
        search_other_contacts(token, query, candidates, seen)
    print(json.dumps(candidates))
    return 0


def main(argv):
    if len(argv) < 2:
        return fail("Usage: google-people.py resolve ACCESS_TOKEN QUERY")
    command = argv[1]
    try:
        if command == "resolve":
            if len(argv) != 4:
                return fail("Usage: google-people.py resolve ACCESS_TOKEN QUERY")
            return resolve(argv[2], argv[3])
    except Exception as exc:
        return fail(str(exc))
    return fail(f"Unknown command: {command}")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
