#!/usr/bin/env python3
"""Compatibility entry; portable Slack implementations live in Agent Hands."""
import os
from pathlib import Path
import sys


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    skills = Path(__file__).resolve().parents[2] / "agent-hands" / "skills"
    domain = "lists" if argv and argv[0] in {"lists", "sync"} else "messages"
    sys.path.insert(0, str(skills / f"use-slack-{domain}" / "scripts"))
    if "SLACK_ACCOUNTS_PATH" not in os.environ:
        os.environ["SLACK_ACCOUNTS_PATH"] = str((Path(os.environ.get("SECRETS_DIR", ".")) / "slack-accounts.json").resolve())
    elif os.environ["SLACK_ACCOUNTS_PATH"]:
        os.environ["SLACK_ACCOUNTS_PATH"] = str(Path(os.environ["SLACK_ACCOUNTS_PATH"]).resolve())
    if domain == "lists":
        import slack_lists as capability
    else:
        import slack_messages as capability
    if not argv or argv == ["--help"]:
        print("Legacy Slack: messaging commands below; use 'lists --help' or 'sync --help' for Lists.")
    return capability.main(argv, load_config=False)


if __name__ == "__main__":
    raise SystemExit(main())
