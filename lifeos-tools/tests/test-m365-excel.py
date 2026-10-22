#!/usr/bin/env python3
"""Synthetic workbook tests; no credentials, network or user workbook content."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("excel", ROOT / "lib/m365-excel.py")
excel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(excel)


def initial():
    return {
        "item": {"id": "book", "name": "example.xlsx", "eTag": "one", "file": {}},
        "sheets": [{"id": "sheet1", "name": "Inventory"}],
        "table": {"id": "table1", "name": "InventoryTable", "showHeaders": True, "showTotals": False, "style": "TableStyleMedium2"},
        "range": {"address": "Inventory!A1:B2", "rowCount": 2, "columnCount": 2, "values": [["Label", "Count"], ["Example", 4]], "formulas": [["Label", "Count"], ["Example", 4]], "numberFormat": [["General", "General"], ["General", "General"]]},
        "format": {"wrapText": False, "columnWidth": 80},
        "font": {"bold": False, "color": "#000000"},
        "fill": {"color": "#FFFFFF"},
        "writes": 0,
    }


def mock_transport():
    method, alias, url, body, *options = sys.argv[2:]
    path = Path(os.environ["EXCEL_TEST_STATE"])
    state = json.loads(path.read_text())
    fail = os.environ.get("EXCEL_TEST_FAIL", "")
    with path.with_suffix(".calls").open("a") as stream:
        stream.write(json.dumps([method, url, body]) + "\n")
    suffix = unquote(url.split("/workbook", 1)[1]) if "/workbook" in url else None
    def save():
        path.write_text(json.dumps(state))
    if method == "GET":
        if fail == "denied" and suffix is not None:
            print("AccessDenied: synthetic denial", file=sys.stderr)
            sys.exit(1)
        if fail == "readback" and state["writes"]:
            sys.exit(1)
        if suffix is None:
            if fail == "race":
                state["item"]["eTag"] += "x"
                save()
            result = state["item"]
        elif suffix == "/worksheets":
            result = {"value": state["sheets"]}
            if fail == "paged":
                result["@odata.nextLink"] = "https://example.invalid/next"
        elif suffix.endswith("/tables"):
            result = {"value": [state["table"]]}
        elif suffix.endswith("/format/font"):
            result = state["font"]
        elif suffix.endswith("/format/fill"):
            result = state["fill"]
        elif suffix.endswith("/format"):
            result = state["format"]
        elif "/range" in suffix:
            result = state["range"]
            if fail == "mismatch" and state["writes"]:
                result["values"][1][0] = "unexpected"
        elif suffix.startswith("/tables/"):
            result = state["table"]
        elif suffix.startswith("/worksheets/"):
            result = next(s for s in state["sheets"] if s["id"] == suffix.split("/")[-1])
        else:
            raise ValueError(suffix)
    else:
        data = json.loads(body)
        state["writes"] += 1
        state["item"]["eTag"] += "w"
        if fail == "timeout":
            save()
            print("Timeout after possible application", file=sys.stderr)
            sys.exit(1)
        if suffix == "/worksheets/add":
            result = {"id": "sheet2", "name": data["name"]}
            state["sheets"].append(result)
        elif suffix.endswith("/tables/add"):
            assert data["address"] == state["range"]["address"]
            state["table"]["id"] = "table2"
            result = state["table"]
        elif suffix.endswith("/rows/add"):
            assert data["index"] is None
            for row in data["values"]:
                state["range"]["values"].append(row)
                state["range"]["formulas"].append(row)
                state["range"]["numberFormat"].append(["General"] * len(row))
            state["range"]["rowCount"] += len(data["values"])
            result = {"value": [{"index": 1, "values": data["values"]}]}
        elif suffix.endswith("/format/font") or suffix.endswith("/format/fill") or suffix.endswith("/format"):
            part = suffix.split("/")[-1]
            state[part].update(data)
            result = state[part]
        elif "/range" in suffix:
            for key, rows in data.items():
                for r, row in enumerate(rows):
                    for c, value in enumerate(row):
                        if value is not None:
                            state["range"][key][r][c] = value
                            if key == "values":
                                state["range"]["formulas"][r][c] = value
            result = state["range"]
        elif suffix.startswith("/tables/"):
            state["table"].update(data)
            result = state["table"]
        else:
            raise ValueError(suffix)
        save()
    print(json.dumps(result))


class ExcelTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.state = self.dir / "state.json"
        self.state.write_text(json.dumps(initial()))
        self.patch = self.dir / "patch.json"
        self.patch.write_text(json.dumps({"values": [[None, None], ["Changed", 8]]}))
        self.env = dict(os.environ, EXCEL_TEST_STATE=str(self.state), EXCEL_TEST_SCRIPT=str(Path(__file__).resolve()), LIB_DIR=str(ROOT / "lib"))

    def cli(self, *args, fail="", enabled=True, shell="bash"):
        script = r'''
            . "$LIB_DIR/m365.sh"
            . "$LIB_DIR/m365-excel.sh"
            _err() { printf 'ERROR: %s\n' "$*" >&2; }
            _warn() { printf 'WARNING: %s\n' "$*" >&2; }
            _m365_require_enabled() { return 0; }
            _m365_files_require_write() { [ "$EXCEL_TEST_WRITE" = yes ]; }
            _m365_files_item_url() { printf 'https://graph.microsoft.com/v1.0/drives/example/items/book'; }
            _m365_http() { python3 "$EXCEL_TEST_SCRIPT" mock "$@"; }
            _mail_audit_append() { cat >> "$EXCEL_TEST_STATE.audit"; }
            _m365_dispatch excel "$@"
        '''
        env = dict(self.env, EXCEL_TEST_FAIL=fail, EXCEL_TEST_WRITE="yes" if enabled else "no")
        return subprocess.run([shell, "-c", script, "test", *args], env=env, capture_output=True, text=True)

    def args(self, op="write-range", *extra):
        return (op, "example", "book", "--sheet", "Inventory", "--range", "A1:B2", "--file", str(self.patch), *extra)

    def roundtrip(self, args):
        preview = self.cli(*args)
        self.assertEqual(preview.returncode, 0, preview.stderr)
        plan = json.loads(preview.stdout)
        self.assertEqual(json.loads(self.state.read_text())["writes"], 0)
        result = self.cli(*args, "--execute", "--expect", plan["preview_sha256"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["verified"])
        return result

    def test_range_roundtrip_preserves_nulls_and_audits(self):
        self.roundtrip(self.args())
        state = json.loads(self.state.read_text())
        self.assertEqual(state["range"]["values"], [["Label", "Count"], ["Changed", 8]])
        audit = Path(str(self.state) + ".audit").read_text()
        self.assertIn('"state":"verified"', audit)
        self.assertNotIn("Changed", audit)

    def test_zsh_range_roundtrip(self):
        args = self.args()
        result = self.cli(*args, shell="zsh")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.cli(*args, "--execute", "--expect", json.loads(result.stdout)["preview_sha256"], shell="zsh")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_formula_and_number_format(self):
        self.patch.write_text(json.dumps({"formulas": [[None, None], [None, "=2*4"]], "numberFormat": [[None, None], [None, "0.00"]]}))
        self.roundtrip(self.args())

    def test_read_commands(self):
        commands = [("sheets",), ("tables",), ("tables", "--sheet", "Inventory"), ("read-range", "--sheet", "Inventory", "--range", "A1:B2"), ("table-range", "--table", "InventoryTable")]
        for op, *options in commands:
            with self.subTest(op=op, options=options):
                result = self.cli(op, "example", "book", *options, "--json")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("target", json.loads(result.stdout))
        self.assertFalse(Path(str(self.state) + ".audit").exists())

    def test_add_sheet(self):
        self.roundtrip(("add-sheet", "example", "book", "--name", "Codebook"))

    def test_add_table_uses_resolved_address(self):
        self.roundtrip(("add-table", "example", "book", "--sheet", "Inventory", "--range", "A1:B2"))

    def test_update_table(self):
        self.patch.write_text(json.dumps({"name": "Entries", "style": "TableStyleMedium4"}))
        self.roundtrip(("update-table", "example", "book", "--table", "table1", "--file", str(self.patch)))

    def test_rename_readback_uses_stable_id(self):
        plan = {"op": "update-table", "reads": {"target": "/tables/OldName"}}
        self.assertEqual(excel.readback_plan(plan, {"id": "stable-id", "name": "NewName"}), {"target": "/tables/stable-id"})

    def test_append_rows(self):
        self.patch.write_text(json.dumps({"values": [["New", 10], ["More", 12]]}))
        self.roundtrip(("append-rows", "example", "book", "--table", "table1", "--file", str(self.patch)))

    def test_format_parts(self):
        for part, body in [("format", {"wrapText": True}), ("font", {"bold": True, "color": "#AABBCC"}), ("fill", {"color": "#FFFFFF"})]:
            with self.subTest(part=part):
                self.state.write_text(json.dumps(initial()))
                self.patch.write_text(json.dumps(body))
                self.roundtrip(self.args("format-range", "--part", part))

    def test_auth_denial_is_not_success(self):
        result = self.cli("sheets", "example", "book", fail="denied")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("AccessDenied", result.stderr)

    def test_missing_preview_and_disabled_writes(self):
        self.assertNotEqual(self.cli(*self.args(), "--execute").returncode, 0)
        self.assertNotEqual(self.cli(*self.args(), "--execute", "--expect", "0" * 64, enabled=False).returncode, 0)
        self.assertFalse(self.state.with_suffix(".calls").exists())

    def test_stale_or_changed_payload(self):
        args = self.args()
        preview = json.loads(self.cli(*args).stdout)["preview_sha256"]
        self.patch.write_text(json.dumps({"values": [[None, None], ["Different", 8]]}))
        result = self.cli(*args, "--execute", "--expect", preview)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Stale", result.stderr)
        self.assertEqual(json.loads(self.state.read_text())["writes"], 0)

    def test_race_after_initial_preview_check(self):
        args = self.args()
        state = initial()
        state["item"]["eTag"] = "onex"
        self.state.write_text(json.dumps(state))
        preview = json.loads(self.cli(*args).stdout)["preview_sha256"]
        self.state.write_text(json.dumps(initial()))
        result = self.cli(*args, "--execute", "--expect", preview, fail="race")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during preflight", result.stderr)
        self.assertEqual(json.loads(self.state.read_text())["writes"], 0)

    def test_uncertain_write_not_retried(self):
        args = self.args()
        preview = json.loads(self.cli(*args).stdout)["preview_sha256"]
        result = self.cli(*args, "--execute", "--expect", preview, fail="timeout")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncertain", result.stderr)
        self.assertEqual(json.loads(self.state.read_text())["writes"], 1)

    def test_readback_failures(self):
        for mode in ("readback", "mismatch"):
            with self.subTest(mode=mode):
                self.state.write_text(json.dumps(initial()))
                args = self.args()
                preview = json.loads(self.cli(*args).stdout)["preview_sha256"]
                result = self.cli(*args, "--execute", "--expect", preview, fail=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("verification failed", result.stderr)
                self.assertEqual(json.loads(self.state.read_text())["writes"], 1)

    def test_refuse_pagination_and_non_xlsx(self):
        self.assertNotEqual(self.cli("sheets", "example", "book", fail="paged").returncode, 0)
        data = initial()
        data["item"]["name"] = "document.docx"
        self.state.write_text(json.dumps(data))
        self.assertNotEqual(self.cli("sheets", "example", "book").returncode, 0)

    def test_duplicate_sheet_refused(self):
        self.assertNotEqual(self.cli("add-sheet", "example", "book", "--name", "inventory").returncode, 0)

    def test_range_limits_and_injection(self):
        for address in ("A:A", "A1:XFD1048576", "B2:A1", "XFE1", "A1048577", "Sheet!A1", "A1')/delete", "A0"):
            with self.subTest(address=address), self.assertRaises(ValueError):
                excel.bounds(address)
        self.assertEqual(excel.bounds("$a$1:$b$2"), ("A1:B2", 2, 2))

    def test_reject_unsupported_properties_and_shapes(self):
        for body in ({"values": [[1]]}, {"values": [[1, 2], [3]]}, {"values": [[{}, 2], [3, 4]]}, {"values": [[1, 2], [3, 4]], "delete": True}, {"values": [[1, 2], [3, 4]], "formulas": [["=1", None], [None, None]]}):
            with self.subTest(body=body):
                self.patch.write_text(json.dumps(body))
                self.assertNotEqual(self.cli(*self.args()).returncode, 0)
        self.assertFalse(self.state.with_suffix(".calls").exists())

    def test_append_totals_and_width_refused(self):
        self.patch.write_text(json.dumps({"values": [["New"]]}))
        args = ("append-rows", "example", "book", "--table", "table1", "--file", str(self.patch))
        self.assertNotEqual(self.cli(*args).returncode, 0)
        self.patch.write_text(json.dumps({"values": [["New", 1]]}))
        data = initial()
        data["table"]["showTotals"] = True
        self.state.write_text(json.dumps(data))
        self.assertNotEqual(self.cli(*args).returncode, 0)

    def test_format_rejects_invalid_types_and_properties(self):
        for body in ({"wrapText": "yes"}, {"columnWidth": -1}, {"columnWidth": True}, {"delete": True}, {"horizontalAlignment": "sideways"}):
            with self.subTest(body=body):
                self.patch.write_text(json.dumps(body))
                self.assertNotEqual(self.cli(*self.args("format-range")).returncode, 0)
        self.assertFalse(self.state.with_suffix(".calls").exists())

    def test_incomplete_range_and_duplicate_headers_refused(self):
        data = initial()
        data["range"].pop("formulas")
        self.state.write_text(json.dumps(data))
        self.assertNotEqual(self.cli(*self.args()).returncode, 0)
        data = initial()
        data["range"]["values"][0] = ["ID", "id"]
        self.state.write_text(json.dumps(data))
        self.assertNotEqual(self.cli("add-table", "example", "book", "--sheet", "Inventory", "--range", "A1:B2").returncode, 0)

    def test_invalid_read_flags_and_unknown_commands(self):
        for args in (("delete",), ("sheets", "--execute"), ("sheets", "--file", str(self.patch)), ("read-range", "--sheet", "..", "--range", "A1:B2")):
            op, *opts = args
            self.assertNotEqual(self.cli(op, "example", "book", *opts).returncode, 0)
        self.assertFalse(self.state.with_suffix(".calls").exists())


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "mock":
        mock_transport()
    else:
        unittest.main()
