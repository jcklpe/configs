#!/usr/bin/env python3
"""Validate bounded Excel commands, fingerprint previews, and verify Graph readback."""
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from urllib.parse import quote

MAX_CELLS = 10000
RANGE_FIELDS = ("address", "rowCount", "columnCount", "values", "formulas", "numberFormat")
TABLE_FIELDS = ("id", "name", "style", "showHeaders", "showTotals", "showBandedRows", "showBandedColumns", "highlightFirstColumn", "highlightLastColumn")
FORMATS = {
    "format": {"columnWidth", "rowHeight", "horizontalAlignment", "verticalAlignment", "wrapText"},
    "font": {"bold", "italic", "size", "color", "name", "underline"},
    "fill": {"color"},
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    require(Path(path).stat().st_size <= 8 * 1024 * 1024, "JSON exceeds the 8 MiB response limit")
    return json.loads(Path(path).read_text(), parse_constant=lambda x: (_ for _ in ()).throw(ValueError("Non-finite JSON number")))


def segment(value):
    require(isinstance(value, str) and value and value not in (".", "..") and not any(c in value for c in "\r\n/\\"), "Invalid worksheet/table identifier")
    return quote(value, safe="")


def bounds(address):
    match = re.fullmatch(r"\$?([A-Za-z]{1,3})\$?([1-9][0-9]*)(?::\$?([A-Za-z]{1,3})\$?([1-9][0-9]*))?", address)
    require(match, "Use a finite A1 range such as A1:D20, without a sheet prefix, name or whole column")
    a, r1, b, r2 = match.groups()
    b, r2 = b or a, r2 or r1
    col = lambda s: sum((ord(c) - 64) * 26 ** i for i, c in enumerate(reversed(s.upper())))
    c1, c2, r1, r2 = col(a), col(b), int(r1), int(r2)
    require(c1 <= c2 <= 16384 and r1 <= r2 <= 1048576, "Range is reversed or exceeds Excel bounds")
    require((c2 - c1 + 1) * (r2 - r1 + 1) <= MAX_CELLS, "Range exceeds 10,000 cells; split the operation")
    return f"{a.upper()}{r1}:{b.upper()}{r2}", r2 - r1 + 1, c2 - c1 + 1


def matrix(value, rows=None, cols=None, strings=False, nulls=True):
    require(isinstance(value, list) and value and all(isinstance(r, list) and r for r in value), "Expected a nonempty rectangular matrix")
    width = len(value[0])
    require(all(len(r) == width for r in value) and len(value) * width <= MAX_CELLS, "Matrix must be rectangular and at most 10,000 cells")
    require(rows is None or (len(value) == rows and width == cols), "Matrix dimensions must match the exact target range")
    for row in value:
        for cell in row:
            if cell is None and nulls:
                continue
            require(isinstance(cell, (str, int, float, bool)) and (not strings or isinstance(cell, str)), "Invalid matrix cell type")
            require(not isinstance(cell, float) or math.isfinite(cell), "Non-finite number")
            require(not isinstance(cell, str) or len(cell) <= 32767, "Cell text exceeds Excel's limit")


def payload(path):
    require(path and Path(path).is_file(), "This command requires --file JSON_FILE")
    require(Path(path).stat().st_size <= 1024 * 1024, "Payload exceeds 1 MiB")
    value = load(path)
    require(isinstance(value, dict) and value, "Payload must be a nonempty JSON object")
    return value


def make_plan(args):
    op, sheet, address, table, part, file, name = args
    plan = {"op": op, "method": "GET", "body": {}, "reads": {}}
    read_ops = {"sheets", "tables", "read-range", "table-range"}
    allowed = {
        "sheets": set(), "tables": {"sheet"}, "read-range": {"sheet", "range"},
        "table-range": {"table"}, "write-range": {"sheet", "range", "file"},
        "format-range": {"sheet", "range", "file", "part"}, "add-sheet": {"name"},
        "add-table": {"sheet", "range"}, "update-table": {"table", "file"},
        "append-rows": {"table", "file"},
    }
    require(op in allowed, f"Unknown Excel command: {op}")
    for key, value in {"sheet": sheet, "range": address, "table": table, "part": part, "file": file, "name": name}.items():
        require(not value or key in allowed[op], f"--{key} is not supported by {op}")
    sheet_url = f"/worksheets/{segment(sheet)}" if sheet else ""
    table_url = f"/tables/{segment(table)}" if table else ""
    if op in {"read-range", "write-range", "format-range", "add-table"}:
        require(sheet and address, "This command requires --sheet and --range")
        address, rows, cols = bounds(address)
        range_url = sheet_url + f"/range(address='{address}')"
        plan.update(address=address, rows=rows, cols=cols)
    if op == "sheets":
        plan["reads"] = {"target": "/worksheets"}
    elif op == "tables":
        plan["reads"] = {"target": sheet_url + "/tables"}
    elif op == "read-range":
        plan["reads"] = {"target": range_url}
    elif op in {"table-range", "append-rows", "update-table"}:
        require(table, "This command requires --table")
        plan["reads"] = {"target": table_url}
        if op != "update-table":
            plan["reads"]["range"] = table_url + "/range"
        if op == "update-table":
            body = payload(file)
            require(set(body) <= set(TABLE_FIELDS) - {"id"}, "Unsupported table property")
            for key, value in body.items():
                if key == "name":
                    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,254}", value) and value.lower() not in {"r", "c"} and not re.fullmatch(r"[A-Za-z]{1,3}[0-9]+|R[0-9]+C[0-9]+", value, re.I), "Use an Excel table name, not a cell reference")
                elif key == "style":
                    require(isinstance(value, str) and re.fullmatch(r"TableStyle(?:Light|Medium|Dark)[1-9][0-9]?", value), "Use a built-in TableStyle name")
                else:
                    require(type(value) is bool, f"{key} must be boolean")
            plan.update(method="PATCH", suffix=table_url, body=body)
        elif op == "append-rows":
            body = payload(file)
            require(set(body) == {"values"}, "Row append accepts only a values matrix")
            matrix(body["values"], nulls=False)
            plan.update(method="POST", suffix=table_url + "/rows/add", body={"values": body["values"], "index": None})
    elif op == "write-range":
        body = payload(file)
        require(set(body) <= {"values", "formulas", "numberFormat"}, "Only values, formulas and numberFormat are supported")
        for key, value in body.items():
            matrix(value, rows, cols, strings=key != "values")
        for r in range(rows):
            for c in range(cols):
                require(not (body.get("values", [[None] * cols] * rows)[r][c] is not None and body.get("formulas", [[None] * cols] * rows)[r][c] is not None), "Do not supply both a value and a formula for the same cell")
        plan.update(method="PATCH", suffix=range_url, reads={"target": range_url}, body=body)
    elif op == "format-range":
        part = part or "format"
        require(part in FORMATS, "--part must be format, font or fill")
        body = payload(file)
        require(set(body) <= FORMATS[part], "Unsupported format property")
        for key, value in body.items():
            if key in {"bold", "italic", "wrapText"}:
                require(type(value) is bool, f"{key} must be boolean")
            elif key in {"rowHeight", "columnWidth", "size"}:
                require(type(value) in (float, int) and 0 < value <= 409, f"{key} must be a positive size at most 409")
            elif key == "color":
                require(isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", value), "Use a #RRGGBB color")
            elif key == "horizontalAlignment":
                require(value in {"General", "Left", "Center", "Right", "Fill", "Justify", "CenterAcrossSelection", "Distributed"}, "Invalid horizontal alignment")
            elif key == "verticalAlignment":
                require(value in {"Top", "Center", "Bottom", "Justify", "Distributed"}, "Invalid vertical alignment")
            elif key == "underline":
                require(value in {"None", "Single", "Double", "SingleAccountant", "DoubleAccountant"}, "Invalid underline style")
            else:
                require(isinstance(value, str) and 0 < len(value) <= 100, "Invalid font name")
        suffix = range_url + "/format" + ("/" + part if part != "format" else "")
        plan.update(method="PATCH", suffix=suffix, reads={"target": suffix}, body=body, part=part)
    elif op == "add-sheet":
        require(name and len(name) <= 31 and not any(c in name for c in "[]:*?/\\\r\n") and not name.startswith("'") and not name.endswith("'"), "Invalid worksheet name")
        plan.update(method="POST", suffix="/worksheets/add", reads={"target": "/worksheets"}, body={"name": name})
    elif op == "add-table":
        plan.update(method="POST", suffix=sheet_url + "/tables/add", reads={"target": sheet_url + "/tables", "range": range_url}, body={"address": address, "hasHeaders": True})
    plan["write"] = op not in read_ops
    return plan


def validate_range(data):
    require(type(data.get("rowCount")) is int and type(data.get("columnCount")) is int, "Incomplete range response")
    require(0 < data["rowCount"] * data["columnCount"] <= MAX_CELLS, "Range exceeds 10,000 cells or is empty")
    for key in ("values", "formulas", "numberFormat"):
        require(key in data, f"Incomplete range response: missing {key}")
        matrix(data[key], data["rowCount"], data["columnCount"])


def before_check(plan, item, data):
    require(item.get("file") is not None and str(item.get("name", "")).lower().endswith(".xlsx"), "Excel operations currently require an .xlsx file")
    require(item.get("id") and item.get("eTag"), "File identity/eTag missing")
    for value in data.values():
        require(isinstance(value, dict) and not value.get("error"), "Invalid Graph response")
        require(not value.get("@odata.nextLink"), "Collection is paginated; refusing an incomplete view")
        if "rowCount" in value:
            validate_range(value)
    op = plan["op"]
    if op in {"sheets", "tables", "add-sheet", "add-table"}:
        require(isinstance(data["target"].get("value"), list), "Missing collection response")
        require(all(x.get("id") and x.get("name") for x in data["target"]["value"]), "Incomplete collection item")
    if op in {"read-range", "write-range"}:
        validate_range(data["target"])
        require((data["target"]["rowCount"], data["target"]["columnCount"]) == (plan["rows"], plan["cols"]), "Returned range dimensions differ from request")
    if op in {"table-range", "append-rows", "update-table"}:
        require(data["target"].get("id") and data["target"].get("name"), "Incomplete table metadata")
    if op in {"format-range", "update-table"}:
        require(set(plan["body"]) <= set(data["target"]), "Current properties missing from Graph response; refusing an incomplete preview")
    if op == "add-sheet":
        require(all(x["name"].casefold() != plan["body"]["name"].casefold() for x in data["target"]["value"]), "Worksheet name already exists")
    if op == "add-table":
        validate_range(data["range"])
        require((data["range"]["rowCount"], data["range"]["columnCount"]) == (plan["rows"], plan["cols"]), "Table source dimensions differ from request")
        headers = data["range"]["values"][0]
        require(all(isinstance(h, str) and h.strip() for h in headers) and len({h.casefold() for h in headers}) == len(headers), "Table headers must already be nonempty, unique text")
    if op == "append-rows":
        validate_range(data["range"])
        require(data["target"].get("showTotals") is False and data["target"].get("showHeaders") is True, "Append requires visible headers and no totals row")
        require(len(plan["body"]["values"][0]) == data["range"]["columnCount"], "Append width differs from table")
        require((data["range"]["rowCount"] + len(plan["body"]["values"])) * data["range"]["columnCount"] <= MAX_CELLS, "Resulting table exceeds 10,000 cells")


def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items() if not k.startswith("@odata")}
    if isinstance(value, list):
        return [clean(x) for x in value]
    return value


def fingerprint(plan, item, data, alias, drive, item_id):
    before_check(plan, item, data)
    obj = [alias, drive, item_id, plan, item["eTag"], clean(data)]
    return hashlib.sha256(json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def readback_plan(plan, result):
    if plan["op"] == "update-table":
        return {"target": "/tables/" + segment(result.get("id"))}
    if plan["op"] in {"add-sheet", "add-table"}:
        identity = segment(result.get("id"))
        path = ("/worksheets/" if plan["op"] == "add-sheet" else "/tables/") + identity
        reads = {"target": path}
        if plan["op"] == "add-table":
            reads["range"] = path + "/range"
        return reads
    return plan["reads"]


def verify(plan, before, after):
    op, body = plan["op"], plan["body"]
    target = after["target"]
    if op == "write-range":
        validate_range(target)
        require((target["rowCount"], target["columnCount"]) == (plan["rows"], plan["cols"]), "Readback range dimensions changed")
        for key, rows in body.items():
            for r, row in enumerate(rows):
                for c, cell in enumerate(row):
                    if cell is not None:
                        require(target[key][r][c] == cell and (type(target[key][r][c]) is bool) == (type(cell) is bool), f"Readback mismatch: {key} row {r + 1}, column {c + 1}")
        # Untargeted formulas/values must survive. Formula results can recalculate, so compare formulas for formula cells.
        old = before["target"]
        for r in range(plan["rows"]):
            for c in range(plan["cols"]):
                changed = any(body.get(k, [[None] * plan["cols"]] * plan["rows"])[r][c] is not None for k in ("values", "formulas"))
                if not changed:
                    key = "formulas" if isinstance(old["formulas"][r][c], str) and old["formulas"][r][c].startswith("=") else "values"
                    require(target[key][r][c] == old[key][r][c], "Untargeted cell changed during write")
    elif op in {"format-range", "update-table", "add-sheet"}:
        for key, value in body.items():
            actual = target.get(key)
            if key == "color" and isinstance(actual, str):
                actual, value = actual.lower(), value.lower()
            require(actual == value, f"Readback mismatch: {key}")
    elif op == "add-table":
        validate_range(after["range"])
        require(target.get("id") and target.get("showHeaders") is True, "Created table missing or headers differ")
        for key in ("address", "rowCount", "columnCount", "values", "formulas"):
            require(after["range"][key] == before["range"][key], f"Created table source changed: {key}")
    elif op == "append-rows":
        validate_range(after["range"])
        old, new = before["range"], after["range"]
        require(new["rowCount"] == old["rowCount"] + len(body["values"]) and new["columnCount"] == old["columnCount"], "Appended table dimensions differ")
        require(new["values"][old["rowCount"]:] == body["values"], "Appended rows differ")
        for r, row in enumerate(old["values"]):
            for c, value in enumerate(row):
                key = "formulas" if isinstance(old["formulas"][r][c], str) and old["formulas"][r][c].startswith("=") else "values"
                require(new[key][r][c] == old[key][r][c], "Existing table cell changed during append")


def main():
    action, *args = sys.argv[1:]
    if action == "plan":
        result = make_plan(args)
    elif action == "fingerprint":
        result = fingerprint(load(args[0]), load(args[1]), load(args[2]), *args[3:])
    elif action == "readback":
        result = readback_plan(load(args[0]), load(args[1]))
    elif action == "verify":
        verify(load(args[0]), load(args[1]), load(args[2]))
        result = {"verified": True}
    else:
        raise ValueError("Unknown helper action")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, IndexError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
