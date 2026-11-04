#!/usr/bin/env python3
"""Make xlkit's example workbooks and its test workbooks with openpyxl.

    python3 tools/make-examples.py

writes inst/extdata/*.xlsx (the workbooks xlkit_example() returns, which
docs/r.md describes) and tests/testthat/fixtures/*.xlsx (edge cases the
tests read). Every value is made up here. The files are reproducible:
the document dates and zip timestamps are fixed, so running the script
again changes nothing unless the script changed.

Needs openpyxl (tested with 3.1.5).
"""

import datetime as dt
import io
import os
import re
import sys
import zipfile

import openpyxl
from openpyxl.chart import BarChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils.datetime import CALENDAR_MAC_1904
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.worksheet.table import Table, TableStyleInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTDATA = os.path.join(ROOT, "inst", "extdata")
FIXTURES = os.path.join(ROOT, "tests", "testthat", "fixtures")
FIXED = dt.datetime(2024, 1, 1, 0, 0, 0)


def save(wb, path):
    """Save `wb` to `path` with fixed dates, so the bytes are reproducible."""
    wb.properties.creator = "xlkit tools/make-examples.py"
    wb.properties.created = FIXED
    wb.properties.modified = FIXED
    buf = io.BytesIO()
    wb.save(buf)
    src = zipfile.ZipFile(io.BytesIO(buf.getvalue()))
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as out:
        for info in src.infolist():
            data = src.read(info.filename)
            if info.filename == "docProps/core.xml":
                # openpyxl stamps the save time into dcterms:modified.
                data = re.sub(
                    rb"(<dcterms:modified[^>]*>)[^<]*(</dcterms:modified>)",
                    rb"\g<1>2024-01-01T00:00:00Z\g<2>",
                    data,
                )
            fixed = zipfile.ZipInfo(info.filename, date_time=(2024, 1, 1, 0, 0, 0))
            fixed.compress_type = zipfile.ZIP_DEFLATED
            out.writestr(fixed, data)
    print("wrote", os.path.relpath(path, ROOT))


def header(ws, row, col, names, bold=True):
    for j, name in enumerate(names):
        cell = ws.cell(row=row, column=col + j, value=name)
        if bold:
            cell.font = Font(bold=True)


# --- report.xlsx -----------------------------------------------------------

def report():
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Scores"
    header(ws, 1, 1, ["id", "name", "score", "passed", "joined"])
    rows = [
        (1, "Ana", 91.5, True, dt.date(2024, 1, 15)),
        (2, "Ben", 78, False, dt.date(2024, 2, 3)),
        (3, "Chen", 85.2, True, dt.date(2024, 2, 20)),
        (4, "Dee", None, None, dt.date(2024, 3, 1)),
    ]
    for i, row in enumerate(rows, start=2):
        for j, value in enumerate(row, start=1):
            cell = ws.cell(row=i, column=j, value=value)
            if j == 5:
                cell.number_format = "yyyy-mm-dd"
    save(wb, os.path.join(EXTDATA, "report.xlsx"))


# --- sales.xlsx ------------------------------------------------------------

REGIONS = ["North", "South", "East", "West", "Central"]
PRODUCTS = ["Apples", "Pears", "Plums", "Cherries", "Grapes", "Figs", "Dates"]
PRICES = [1.25, 1.5, 2.0, 4.75, 3.2, 5.5, 6.25]


def sales_sheet(wb, year, table_name):
    ws = wb.create_sheet(f"Sales {year}")
    ws["B1"] = f"Sales by region, {year}"
    ws["B1"].font = Font(bold=True, size=14)
    ws["B2"] = "Amounts in US dollars. Made-up data for xlkit's examples."
    ws["B2"].font = Font(italic=True)
    header(ws, 5, 2, ["region", "product", "units", "amount", "share"])
    rows = []
    for r, region in enumerate(REGIONS):
        for p, product in enumerate(PRODUCTS):
            units = 40 + (r * 37 + p * 53 + year * 7) % 260
            rows.append((region, product, units, round(units * PRICES[p], 2)))
    total = sum(row[3] for row in rows)
    for i, (region, product, units, amount) in enumerate(rows, start=6):
        ws.cell(row=i, column=2, value=region)
        ws.cell(row=i, column=3, value=product)
        ws.cell(row=i, column=4, value=units)
        ws.cell(row=i, column=5, value=amount).number_format = "#,##0"
        ws.cell(row=i, column=6, value=amount / total).number_format = "0.0%"
    assert i == 40
    table = Table(displayName=table_name, ref="B5:F40")
    table.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws.add_table(table)
    ws.column_dimensions["B"].width = 12
    return total, sum(row[2] for row in rows)


def sales():
    wb = openpyxl.Workbook()
    summary = wb.active
    summary.title = "Summary"
    t23, u23 = sales_sheet(wb, 2023, "Sales2023")
    t24, u24 = sales_sheet(wb, 2024, "SalesTable")
    header(summary, 1, 1, ["year", "units", "amount"])
    for i, (year, units, amount) in enumerate([(2023, u23, t23), (2024, u24, t24)], start=2):
        summary.cell(row=i, column=1, value=year)
        summary.cell(row=i, column=2, value=units)
        summary.cell(row=i, column=3, value=round(amount, 2)).number_format = "#,##0.00"

    regions = wb.create_sheet("Regions")
    header(regions, 1, 1, ["region", "manager", "office"])
    for i, (region, manager, office) in enumerate(
        zip(REGIONS, ["Ana", "Ben", "Chen", "Dee", "Eve"], ["Oslo", "Lima", "Pune", "Accra", "Kyiv"]),
        start=2,
    ):
        regions.cell(row=i, column=1, value=region)
        regions.cell(row=i, column=2, value=manager)
        regions.cell(row=i, column=3, value=office)
    wb.defined_names["RegionList"] = DefinedName("RegionList", attr_text="Regions!$A$1:$C$6")

    notes = wb.create_sheet("Notes")
    notes["A1"] = "note"
    notes["A1"].font = Font(bold=True)
    notes["A2"] = "Every number in this workbook is made up."
    notes["A3"] = "Sales 2023 and Sales 2024 have the same layout: a title, a note, and a table in B5:F40."
    save(wb, os.path.join(EXTDATA, "sales.xlsx"))


# --- messy.xlsx ------------------------------------------------------------

def messy():
    wb = openpyxl.Workbook()

    ws = wb.active
    ws.title = "Headers"
    for col, name in zip("ABCE", ["Region", "Total", "Total", "Share %"]):
        ws[f"{col}1"] = name
    for i, (region, t1, t2, d, share) in enumerate(
        [("North", 120, 118, 3, 0.25), ("South", 95, 97, 1, 0.2), ("East", 210, 205, 4, 0.44),
         ("West", 52, 50, 2, 0.11)],
        start=2,
    ):
        ws[f"A{i}"] = region
        ws[f"B{i}"] = t1
        ws[f"C{i}"] = t2
        ws[f"D{i}"] = d
        ws[f"E{i}"] = share
        ws[f"E{i}"].number_format = "0%"

    ws = wb.create_sheet("Two-row header")
    ws["A1"] = "Household income by region"
    ws["A1"].font = Font(bold=True)
    ws["A2"] = "Thousands of dollars"
    ws["A4"] = "Region"
    ws.merge_cells("A4:A5")
    ws["B4"] = "Income"
    ws.merge_cells("B4:D4")
    ws["B4"].alignment = Alignment(horizontal="center")
    for col, year in zip("BCD", [2020, 2021, 2022]):
        ws[f"{col}5"] = year
    for i, (region, a, b, c) in enumerate(
        [("North", 61.2, 63.0, 64.8), ("South", 48.5, 49.9, 52.1), ("East", 70.4, 71.0, 73.6),
         ("West", 55.0, 56.3, 58.9)],
        start=6,
    ):
        ws[f"A{i}"] = region
        ws[f"B{i}"] = a
        ws[f"C{i}"] = b
        ws[f"D{i}"] = c

    ws = wb.create_sheet("Types")
    header(ws, 1, 1, ["id", "zip", "amount"], bold=False)
    zips = [2139, 10001, 60614, 94110, 98101, 1002, 30303]
    for i in range(2, 2005):
        ws.cell(row=i, column=1, value=i - 1)
        z = ws.cell(row=i, column=2, value=zips[i % len(zips)])
        z.number_format = "00000"
        if i == 2003:
            amount = "n/a"
        elif i == 2004:
            amount = "12,5"
        else:
            amount = round(((i * 7919) % 100000) / 100, 2)
        ws.cell(row=i, column=3, value=amount)

    ws = wb.create_sheet("Missing")
    header(ws, 1, 1, ["id", "name", "score", "rate"], bold=False)
    rows = [
        (1, "Ana", 12, 0.5),
        (2, "Ben", "NA", 0.25),
        (3, "Chen", 7, "#N/A"),
        (4, "Dee", ".", 0.75),
        (5, "Eve", -1, 0.1),
        (6, "Fay", "-", 0.3),
        (7, "Gus", 9, 0.45),
        (8, "Hal", 11, "#DIV/0!"),
        (9, "Ida", " NA ", 0.6),
    ]
    for i, row in enumerate(rows, start=2):
        for j, value in enumerate(row, start=1):
            # openpyxl stores the strings "#N/A" and "#DIV/0!" as error cells.
            ws.cell(row=i, column=j, value=value)
    assert ws["D4"].data_type == "e" and ws["D9"].data_type == "e"
    save(wb, os.path.join(EXTDATA, "messy.xlsx"))


# --- dates.xlsx and dates1904.xlsx ---------------------------------------------

def dates(epoch1904):
    wb = openpyxl.Workbook()
    if epoch1904:
        wb.epoch = CALENDAR_MAC_1904
    ws = wb.active
    ws.title = "Dates"
    header(ws, 1, 1, ["day", "stamp", "clock"])
    rows = [
        (dt.date(2024, 1, 15), dt.datetime(2024, 1, 15, 8, 30, 0), dt.time(8, 30, 0)),
        (dt.date(2024, 2, 29), dt.datetime(2024, 2, 29, 17, 5, 30), dt.time(17, 5, 30)),
        (dt.date(2024, 12, 31), dt.datetime(2024, 12, 31, 23, 59, 59), dt.time(23, 59, 59)),
    ]
    for i, (day, stamp, clock) in enumerate(rows, start=2):
        ws.cell(row=i, column=1, value=day).number_format = "yyyy-mm-dd"
        ws.cell(row=i, column=2, value=stamp).number_format = "yyyy-mm-dd hh:mm:ss"
        ws.cell(row=i, column=3, value=clock).number_format = "hh:mm"
    name = "dates1904.xlsx" if epoch1904 else "dates.xlsx"
    save(wb, os.path.join(EXTDATA, name))


# --- template.xlsx ---------------------------------------------------------

def template():
    wb = openpyxl.Workbook()
    cover = wb.active
    cover.title = "Cover"
    cover["B2"] = "Monthly report"
    cover["B2"].font = Font(bold=True, size=14, color="1F4E79")
    thin = Side(style="thin", color="808080")
    box = Border(top=thin, bottom=thin, left=thin, right=thin)
    fill = PatternFill("solid", fgColor="DDEBF7")
    for row, label in [(4, "Total"), (5, "As of")]:
        cover[f"B{row}"] = label
        cover[f"B{row}"].font = Font(bold=True)
        cover[f"C{row}"].border = box
        cover[f"C{row}"].fill = fill
    cover["C4"] = 0
    cover["C4"].number_format = "#,##0"
    cover["C5"].number_format = "d mmm yyyy"
    cover.column_dimensions["B"].width = 18
    cover.column_dimensions["C"].width = 16
    cover.sheet_properties.tabColor = "1F4E79"

    chart_sheet = wb.create_chartsheet("Chart")

    data = wb.create_sheet("Data")
    header(data, 1, 1, ["month", "value"])
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    for i, month in enumerate(months, start=2):
        data.cell(row=i, column=1, value=month)
        data.cell(row=i, column=2, value=100 + (i * 37) % 60)
    data.freeze_panes = "A2"

    chart = BarChart()
    chart.title = "Value by month"
    chart.add_data(Reference(data, min_col=2, min_row=1, max_row=13), titles_from_data=True)
    chart.set_categories(Reference(data, min_col=1, min_row=2, max_row=13))
    chart_sheet.add_chart(chart)
    save(wb, os.path.join(EXTDATA, "template.xlsx"))


# --- test fixtures -----------------------------------------------------------

def edge():
    """Edge cases for tests/testthat: one sheet per topic."""
    wb = openpyxl.Workbook()

    # Serial numbers around Excel's 1900 leap-day bug, formatted as dates.
    ws = wb.active
    ws.title = "Early"
    ws["A1"] = "day"
    for i, serial in enumerate([1, 59, 60, 61, 0], start=2):
        ws.cell(row=i, column=1, value=serial).number_format = "yyyy-mm-dd"

    # Every Excel error, beside numbers.
    ws = wb.create_sheet("Errors")
    ws["A1"] = "x"
    ws["B1"] = "y"
    errors = ["#N/A", "#DIV/0!", "#VALUE!", "#REF!", "#NAME?", "#NUM!", "#NULL!"]
    for i, err in enumerate(errors, start=2):
        ws.cell(row=i, column=1, value=err)
        ws.cell(row=i, column=2, value=i)

    # Columns whose cells mix types.
    ws = wb.create_sheet("Mixed")
    cols = {
        "num_text": [1, 2, "three", 4],
        "bool_num": [True, 1, False, 0],
        "date_num": [dt.date(2024, 1, 1), 5, None, None],
        "big": [1, 2, 3000000000, 4],
        "whole": [1, 2.0, 3, 4],
        "frac": [1, 2.5, 3, 4],
        "lgl": [True, False, None, True],
        "empty": [None, None, None, None],
        "spaces": ["a", "   ", "b", None],
        "neg": [-2147483647, 2147483647, 0, -5],
        "date_dttm": [dt.date(2024, 1, 1), dt.datetime(2024, 1, 2, 12, 0), None, None],
    }
    for j, (name, values) in enumerate(cols.items(), start=1):
        ws.cell(row=1, column=j, value=name)
        for i, value in enumerate(values, start=2):
            cell = ws.cell(row=i, column=j, value=value)
            if isinstance(value, dt.datetime):
                cell.number_format = "yyyy-mm-dd hh:mm"
            elif isinstance(value, dt.date):
                cell.number_format = "yyyy-mm-dd"

    # Number formats and how each reads.
    ws = wb.create_sheet("Formats")
    formats = [
        ("percent", "0.0%", 0.256),
        ("duration", "[h]:mm", 1.5),
        ("red", "[Red]0.00", 3.25),
        ("minsec", "mm:ss", 0.0010416666666666667),
        ("locale_date", "[$-409]d-mmm-yy;@", 45306),
        ("thousands", "#,##0", 1234567),
        ("zip", "00000", 2139),
        ("general", "General", 0.1),
        ("ampm", "h:mm AM/PM", 0.75),
        ("dttm", "yyyy-mm-dd hh:mm", 45306.5),
        ("quoted", '"Day "0', 7),
        ("daymonth", "d-mmm", 45306),
        ("builtin14", "mm-dd-yy", 45306),
        ("elapsed_s", "[ss]", 0.5),
        ("escaped", "0\\h", 12),
        ("sci", "0.00E+00", 12345.678),
    ]
    for j, (name, fmt, value) in enumerate(formats, start=1):
        ws.cell(row=1, column=j, value=name)
        ws.cell(row=2, column=j, value=value).number_format = fmt

    # A block with gaps, for range forms: data in B3:D8, a stray value in F10.
    ws = wb.create_sheet("Ranges")
    header(ws, 3, 2, ["a", "b", "c"], bold=False)
    for i in range(4, 9):
        ws.cell(row=i, column=2, value=i)
        ws.cell(row=i, column=3, value=f"r{i}")
        if i != 6:
            ws.cell(row=i, column=4, value=i * 1.5)
    ws["F10"] = "stray"
    wb.defined_names["Block"] = DefinedName("Block", attr_text="Ranges!$B$3:$D$8")

    # Header names: repeats, blanks, long text, odd characters.
    ws = wb.create_sheet("Names")
    names = ["Age at first birth", "Total", "total", None, "Share %", "2020", "#", "if", "Region"]
    for j, name in enumerate(names, start=1):
        if name is not None:
            ws.cell(row=1, column=j, value=name)
        ws.cell(row=2, column=j, value=j)
    ws.cell(row=1, column=10, value="Region")
    ws.cell(row=2, column=10, value=10)

    # An empty worksheet.
    wb.create_sheet("Empty")

    # A chart sheet plotting the Ranges block.
    cs = wb.create_chartsheet("Plot")
    chart = BarChart()
    chart.add_data(Reference(wb["Ranges"], min_col=2, min_row=3, max_row=8), titles_from_data=True)
    cs.add_chart(chart)

    # Typed-in text for the types = conversions.
    ws = wb.create_sheet("Text")
    header(ws, 1, 1, ["num", "int", "lgl", "date", "dttm", "time"], bold=False)
    rows = [
        (" 42 ", "7", "TRUE", "2024-03-01", "2024-03-01 14:30:00", "14:30"),
        ("1e3", "7.5", "false", "01/03/2024", "2024-03-01", "14:30:15"),
        ("12,5", "x", "yes", "2024-02-30", "soon", "noon"),
        (2.5, 3, 0, 45306, 45306.25, 0.5),
    ]
    for i, row in enumerate(rows, start=2):
        for j, value in enumerate(row, start=1):
            ws.cell(row=i, column=j, value=value)

    save(wb, os.path.join(FIXTURES, "edge.xlsx"))


def edge1904():
    wb = openpyxl.Workbook()
    wb.epoch = CALENDAR_MAC_1904
    ws = wb.active
    ws.title = "Early"
    ws["A1"] = "day"
    # 0 is 1904-01-01; 60 is an ordinary day in the 1904 system.
    for i, serial in enumerate([0, 1, 60, 43844], start=2):
        ws.cell(row=i, column=1, value=serial).number_format = "yyyy-mm-dd"
    save(wb, os.path.join(FIXTURES, "edge1904.xlsx"))


def review():
    """Cases from the first review: tables without a header row or with only
    one, fractional seconds, conditional number formats, signed padding,
    reserved Stata words and a defined name in another script."""
    from openpyxl.workbook.defined_name import DefinedName

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Tables"
    ws["A1"] = "a title above the tables"
    ws["A2"], ws["B2"] = 1, 2
    ws["A3"], ws["B3"] = 3, 4
    ws.add_table(Table(displayName="NoHeader", ref="A2:B3", headerRowCount=0))
    ws["D2"], ws["E2"] = "left", "right"
    ws.add_table(Table(displayName="OnlyHeader", ref="D2:E2"))
    wb.defined_names["Donn\u00e9es"] = DefinedName("Donn\u00e9es", attr_text="Tables!$A$2:$B$3")

    ws = wb.create_sheet("Stamps")
    ws["A1"] = "stamp"
    ws["A2"] = dt.datetime(2024, 1, 1, 0, 0, 0, 125000)
    ws["A2"].number_format = "yyyy-mm-dd hh:mm:ss.000"
    ws["A3"] = "unknown"

    ws = wb.create_sheet("Conditional")
    ws["A1"] = "x"
    for i, v in enumerate([100, 250], start=2):
        ws.cell(row=i, column=1, value=v).number_format = "[<1]yyyy-mm-dd;0"

    ws = wb.create_sheet("Padded")
    ws["A1"] = "code"
    for i, v in enumerate([-42, 7], start=2):
        ws.cell(row=i, column=1, value=v).number_format = "00000"

    ws = wb.create_sheet("Reserved")
    ws["A1"], ws["B1"] = "IF", "FLOAT"
    ws["A2"], ws["B2"] = 1, 2

    save(wb, os.path.join(FIXTURES, "review.xlsx"))


def main():
    os.makedirs(EXTDATA, exist_ok=True)
    os.makedirs(FIXTURES, exist_ok=True)
    report()
    sales()
    messy()
    dates(False)
    dates(True)
    template()
    edge()
    edge1904()
    review()


if __name__ == "__main__":
    sys.exit(main())
