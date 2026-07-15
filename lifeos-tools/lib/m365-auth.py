#!/usr/bin/env python3
"""Microsoft identity helper for delegated LifeOS Microsoft 365 accounts."""

import os
import sys

try:
    import msal
except ImportError:
    print("ERROR: MSAL is not installed. Run `lifeos setup` and try again.", file=sys.stderr)
    raise SystemExit(1)


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def authority_for(tenant):
    if tenant.startswith("https://"):
        return tenant.rstrip("/")
    return f"https://login.microsoftonline.com/{tenant.strip('/')}"


def load_cache(path):
    cache = msal.SerializableTokenCache()
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as handle:
            cache.deserialize(handle.read())
    return cache


def save_cache(path, cache):
    if not cache.has_state_changed:
        return
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(cache.serialize())
        handle.write("\n")
    os.replace(tmp, path)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def build_app(client_id, tenant, token_path):
    cache = load_cache(token_path)
    app = msal.PublicClientApplication(client_id, authority=authority_for(tenant), token_cache=cache)
    return app, cache


def result_error(result):
    if not result:
        return "Microsoft authentication returned no result"
    message = result.get("error_description") or result.get("error") or "Microsoft authentication failed"
    correlation = result.get("correlation_id")
    if correlation:
        message = f"{message} (correlation ID: {correlation})"
    return message


def auth(client_id, tenant, token_path, scopes, no_browser=False):
    app, cache = build_app(client_id, tenant, token_path)
    if no_browser:
        flow = app.initiate_device_flow(scopes=scopes)
        if "user_code" not in flow:
            raise RuntimeError(result_error(flow))
        print(flow.get("message") or "Complete Microsoft device authorization in your browser.", flush=True)
        result = app.acquire_token_by_device_flow(flow)
    else:
        print("Opening Microsoft authorization in your browser...", flush=True)
        result = app.acquire_token_interactive(scopes=scopes, port=0, prompt="select_account")
    save_cache(token_path, cache)
    if "access_token" not in result:
        raise RuntimeError(result_error(result))
    claims = result.get("id_token_claims") or {}
    username = claims.get("preferred_username") or claims.get("email") or claims.get("name") or "Microsoft account"
    print(f"Authorized {username}", flush=True)
    print(f"Wrote Microsoft token cache: {token_path}", flush=True)
    return 0


def access_token(client_id, tenant, token_path, scopes):
    app, cache = build_app(client_id, tenant, token_path)
    accounts = app.get_accounts()
    if not accounts:
        raise ValueError("No authorized Microsoft account is cached. Run `lifeos m365 auth ALIAS` first.")
    if len(accounts) > 1:
        usernames = ", ".join(account.get("username") or "unknown" for account in accounts)
        raise ValueError(f"Token cache contains multiple Microsoft accounts ({usernames}); use one token cache per alias.")
    result = app.acquire_token_silent(scopes, account=accounts[0])
    save_cache(token_path, cache)
    if not result or "access_token" not in result:
        raise RuntimeError(result_error(result))
    print(result["access_token"])
    return 0


def main(argv):
    if len(argv) < 2:
        return fail("Usage: m365-auth.py auth|access-token CLIENT_ID TENANT TOKEN_PATH SCOPE... [--no-browser]")
    command = argv[1]
    if len(argv) < 6:
        return fail("Usage: m365-auth.py auth|access-token CLIENT_ID TENANT TOKEN_PATH SCOPE... [--no-browser]")
    client_id, tenant, token_path = argv[2:5]
    no_browser = "--no-browser" in argv[5:]
    scopes = [value for value in argv[5:] if value != "--no-browser"]
    if not scopes:
        return fail("At least one Microsoft Graph scope is required")
    try:
        if command == "auth":
            return auth(client_id, tenant, token_path, scopes, no_browser=no_browser)
        if command == "access-token":
            if no_browser:
                return fail("--no-browser applies only to auth")
            return access_token(client_id, tenant, token_path, scopes)
    except Exception as exc:
        return fail(str(exc))
    return fail(f"Unknown command: {command}")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
