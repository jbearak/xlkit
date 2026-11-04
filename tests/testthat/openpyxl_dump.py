# What openpyxl sees in a workbook, for the tests' oracle (helper.R,
# `openpyxl()`): one tab-separated line per sheet, column width, merged
# range and cell. R's readers cannot see number formats, fonts, fills,
# borders, widths, frozen panes, filters or merged ranges.
#
#   python3 -I openpyxl_dump.py workbook.xlsx

import sys

import openpyxl


def clean(x):
    if x is None:
        return ""
    return repr(x) if isinstance(x, str) else str(x)


def color(c):
    if c is None or c.type != "rgb" or c.rgb is None:
        return ""
    return str(c.rgb)[-6:]


def main(path):
    wb = openpyxl.load_workbook(path)
    out = []
    for ws in wb.worksheets:
        name = ws.title
        out.append(["sheet", name, clean(ws.freeze_panes), clean(ws.auto_filter.ref)])
        for letter, dim in sorted(ws.column_dimensions.items()):
            if dim.width is not None and dim.customWidth:
                out.append(["width", name, letter, str(dim.width)])
        for rng in ws.merged_cells.ranges:
            out.append(["merged", name, str(rng)])
        for row in ws.iter_rows():
            for c in row:
                if c.value is None and not c.has_style:
                    continue
                f = c.font
                fill = color(c.fill.fgColor) if c.fill.fill_type == "solid" else ""
                b = c.border
                out.append([
                    "cell", name, c.coordinate, c.data_type, clean(c.value), c.number_format,
                    str(bool(f.b)), str(bool(f.i)), clean(f.u), clean(f.sz), clean(f.name),
                    color(f.color), fill,
                    clean(b.top.style), clean(b.right.style), clean(b.bottom.style), clean(b.left.style),
                    clean(c.alignment.horizontal), clean(c.alignment.vertical),
                    str(bool(c.alignment.wrap_text)), clean(c.alignment.indent),
                ])
    text = "".join("\t".join(r) + "\n" for r in out)
    sys.stdout.buffer.write(text.encode("utf-8"))


if __name__ == "__main__":
    main(sys.argv[1])
