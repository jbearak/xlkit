"""Build the blinded judging prompts described in rubric.md.

    python docs/judging/bundle.py OTHERS OUT SEED

OTHERS holds the pinned sources listed in sources.md (one directory per
library, plus `_web/` with the pinned web pages saved as HTML). OUT
receives one prompt per group and `letters.json` with the seeded letter
assignments. Needs R (for Rd to text) and a checkout of xlkit at the
commit being judged.
"""

import glob
import html
import html.parser
import json
import os
import random
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))

# Each item: ("file", path), ("lines", path, first, last), ("rd", glob),
# ("web", file in _web, element id or None), ("jldoc", glob).
LIBRARIES = {
    "readxl + writexl": {
        "names": {"readxl": "Library {L} (reader)", "writexl": "Library {L} (writer)",
                  "libxlsxwriter": "the underlying C library"},
        "items": [("file", f"readxl/{p}") for p in [
            "README.md", "vignettes/cell-and-column-types.Rmd", "vignettes/sheet-geometry.Rmd",
            "vignettes/articles/column-names.Rmd", "vignettes/articles/multiple-header-rows.Rmd",
            "vignettes/articles/readxl-workflows.Rmd"]]
        + [("rd", f"readxl/man/{p}") for p in ["read_excel.Rd", "excel_sheets.Rd", "cell-specification.Rd"]]
        + [("file", f"writexl/{p}") for p in [
            "README.md", "vignettes/a-getting-started.Rmd", "vignettes/b-formatting.Rmd",
            "vignettes/c-worksheets-workbooks.Rmd", "vignettes/e-formulas-and-more.Rmd"]]
        + [("rd", f"writexl/man/{p}.Rd") for p in [
            "write_xlsx", "xl_sheet", "xl_colrow_spec", "xl_format", "xl_format_groups", "xl_properties",
            "xl_merge", "xl_filter", "xl_table", "xl_cell_general"]],
    },
    "openxlsx2": {
        "names": {"openxlsx2": "Library {L}", "openxlsx": "the predecessor library"},
        "items": [("file", f"openxlsx2/{p}") for p in [
            "README.md", "vignettes/openxlsx2.Rmd", "vignettes/openxlsx2_read_to_df.Rmd",
            "vignettes/openxlsx2_style_manual.Rmd", "vignettes/Update-from-openxlsx.Rmd"]]
        + [("rd", f"openxlsx2/man/{p}.Rd") for p in [
            "wb_to_df", "write_xlsx", "wb_load", "wb_save", "wb_workbook", "wb_add_worksheet",
            "wb_remove_worksheet", "sheet_names-wb", "wb_add_data", "wb_add_data_table", "wb_dims",
            "wb_add_numfmt", "wb_add_font", "wb_add_cell_style", "col_widths-wb", "wb_freeze_pane",
            "filter-wb", "wb_merge_cells", "wb_clean_sheet"]],
    },
    "pandas": {
        "names": {"pandas": "Library {L}"},
        "items": [
            ("file", "pandas/README.md"),
            ("web", "pandas_install.html", "excel-files"),
            ("lines", "pandas/doc/source/user_guide/io.rst", 3338, 3889),
            ("web", "pandas_style.html", "Export-to-Excel"),
            ("lines", "pandas/pandas/io/excel/_base.py", 197, 505),
            ("lines", "pandas/pandas/io/excel/_base.py", 991, 1184),
            ("lines", "pandas/pandas/io/excel/_base.py", 1569, 1642),
            ("lines", "pandas/pandas/core/generic.py", 2127, 2248),
            ("lines", "pandas/pandas/io/formats/style.py", 537, 660),
        ],
    },
    "openpyxl": {
        "names": {"openpyxl": "Library {L}"},
        "items": [("file", "openpyxl/openpyxl-3.1.5/README.rst")]
        + [("web", f"openpyxl_{p}.html", None) for p in [
            "tutorial", "usage", "optimized", "editing_worksheets", "pandas", "datetime", "styles", "filters",
            "worksheet_tables", "worksheet_properties", "validation", "api_openpyxl.reader.excel",
            "api_openpyxl.worksheet.worksheet", "api_openpyxl.cell.cell", "api_openpyxl.workbook.workbook"]],
    },
    "polars": {
        "names": {"polars": "Library {L}", "Polars": "Library {L}"},
        "items": [
            ("file", "polars/README.md"),
            ("file", "polars/docs/source/user-guide/io/excel.md"),
            ("lines", "polars/py-polars/src/polars/io/spreadsheet/functions.py", 255, 410),
            ("lines", "polars/py-polars/src/polars/dataframe/frame.py", 3383, 3794),
            ("file", "fastexcel/README.md"),
            ("lines", "fastexcel/python/fastexcel/__init__.py", 286, 400),
            ("file", "XlsxWriter/dev/docs/source/format.rst"),
            ("file", "XlsxWriter/dev/docs/source/working_with_tables.rst"),
        ],
    },
    "XLSX.jl": {
        "names": {"XLSX.jl": "Library {L}", "JuliaData/XLSX": "Library {L}", "felipenoris/XLSX": "Library {L}"},
        # The package itself is `XLSX`. Replace it in `using`/`import` lines (also in lists) and as the
        # string "XLSX" (Pkg.add), not in qualified names like `XLSX.readxlsx`.
        "patterns": [("julia-imports", None), (r'"XLSX"', '"Library{L}"'), (r"(\]\s*add\s+)XLSX\b", r"\1Library{L}")],
        "items": [("file", f"XLSX.jl/{p}") for p in [
            "README.md", "docs/src/index.md", "docs/src/tutorial/XLSXtutorial.md",
            "docs/src/tutorial/FileIOtutorial.md", "docs/src/migration.md",
            "docs/src/formatting/cellFormatting.md", "docs/src/formatting/widthAndHeight.md",
            "docs/src/formatting/mergedCells.md", "docs/src/formatting/freezeAndSplitPanes.md",
            "docs/src/tables/excelTables.md"]]
        + [("jldoc", f"XLSX.jl/src/{p}") for p in [
            "read.jl", "table.jl", "write.jl", "tables_interface.jl", "cell.jl", "panes.jl", "cellformats/*.jl"]],
    },
    "SheetJS CE": {
        "names": {"SheetJS": "Library {L}", "sheetjs": "library-{L}"},
        # The npm package is `xlsx`; replace it in imports, not in file names like `out.xlsx`.
        "patterns": [(r"""(require\(\s*|from\s+|import\(\s*)(["'])xlsx((?:/[\w.-]+)*)\2""", r"\1\2library-{L}\3\2")],
        "items": [("file", f"sheetjs-docs/docz/docs/{p}") for p in [
            "02-getting-started/01-installation/03-nodejs.md", "08-api/index.md", "08-api/03-parse-options.md",
            "08-api/05-write-options.md", "08-api/07-utilities/01-array.md", "08-api/07-utilities/08-wb.md",
            "07-csf/01-general.md", "07-csf/02-cell.md", "07-csf/03-sheet.md", "07-csf/04-book.md",
            "07-csf/07-features/01-dates.md", "07-csf/07-features/06-nf.md",
            "07-csf/07-features/09-colprops.md", "07-csf/07-features/11-merges.md",
            "02-getting-started/02-examples/02-export.md", "02-getting-started/02-examples/04-import.md",
            "06-solutions/03-processing.md"]],
    },
    "ExcelJS": {
        "names": {"ExcelJS": "Library {L}", "exceljs": "library-{L}", "Exceljs": "Library {L}"},
        "items": [("lines", "exceljs/README.md", 1, 1466), ("lines", "exceljs/README.md", 2137, 2192),
                  ("lines", "exceljs/README.md", 2543, 2802), ("file", "exceljs/index.d.ts")],
    },
}

OURS = {"xlkit": "Library {L}", "jbearak/xlkit": "Library {L}"}
OUR_FILES = ["README.md", *sorted(glob.glob(os.path.join(REPO, "docs/guide/*.md"))), "docs/r.md", "docs/stata.md"]

GROUPS = {
    "R": ["readxl + writexl", "openxlsx2"],
    "Python": ["pandas", "openpyxl", "polars"],
    "Julia": ["XLSX.jl"],
    "TypeScript": ["SheetJS CE", "ExcelJS"],
    "Stata": [],
}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class Text(html.parser.HTMLParser):
    """Visible text of an HTML page, or of the element with one id."""

    SKIP = {"script", "style", "nav", "header", "footer", "noscript", "svg"}
    BLOCK = {"p", "div", "section", "li", "tr", "pre", "h1", "h2", "h3", "h4", "h5", "dt", "dd", "br", "table"}

    def __init__(self, element_id):
        super().__init__(convert_charrefs=True)
        self.want, self.depth, self.skip, self.out = element_id, 0 if element_id else 1, 0, []
        self.stack = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if self.depth == 0 and self.want and a.get("id") == self.want:
            self.depth = 1
            self.stack = [tag]
            return
        if self.depth and self.want:
            self.stack.append(tag)
        if tag in self.SKIP:
            self.skip += 1
        if self.depth and tag in self.BLOCK:
            self.out.append("\n")
        if self.depth and tag in ("h1", "h2", "h3", "h4"):
            self.out.append("#" * int(tag[1]) + " ")

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if self.depth and self.want and self.stack:
            self.stack.pop()
            if not self.stack:
                self.depth = 0
                self.want = "\0done"

    def handle_data(self, data):
        if self.depth and not self.skip:
            self.out.append(data)


def web_text(path, element_id):
    p = Text(element_id)
    p.feed(read(path))
    text = re.sub(r"[ \t]+", " ", "".join(p.out))
    return re.sub(r"\n\s*\n+", "\n\n", text).strip()


def rd_text(path):
    out = subprocess.run(["R", "CMD", "Rdconv", "-t", "txt", path], capture_output=True, text=True, check=True)
    return out.stdout


def jl_docstrings(pattern):
    parts = []
    for path in sorted(glob.glob(pattern)):
        for m in re.finditer(r'^"""\n(.*?)\n"""\n([^\n]*)', read(path), re.S | re.M):
            parts.append(f"### {m.group(2).strip()}\n\n{m.group(1)}\n")
    return "\n".join(parts)


def expand_code_blocks(others, name, text):
    """Polars' guide includes its examples with {{code_block('path','section',...)}}; put them in."""
    if not name.startswith("polars/docs/"):
        return text

    def one(m):
        src = read(os.path.join(others, "polars/docs/source/src/python", m.group(1) + ".py"))
        body = re.search(rf"# --8<-- \[start:{m.group(2)}\]\n(.*?)# --8<-- \[end:{m.group(2)}\]", src, re.S)
        return "```python\n" + body.group(1) + "```"

    return re.sub(r"\{\{code_block\('([^']+)','([^']+)'[^}]*\}\}", one, text)


def item_text(others, item):
    kind, path = item[0], os.path.join(others, item[1])
    if kind == "file":
        return item[1], expand_code_blocks(others, item[1], read(path))
    if kind == "lines":
        lines = read(path).splitlines()[item[2] - 1:item[3]]
        return f"{item[1]} lines {item[2]}-{item[3]}", "\n".join(lines)
    if kind == "rd":
        return item[1], rd_text(path)
    if kind == "web":
        return item[1], web_text(os.path.join(others, "_web", item[1]), item[2])
    if kind == "jldoc":
        return item[1], jl_docstrings(path)
    raise ValueError(kind)


def group_patterns(letters):
    """Context-dependent replacements (package names that are also common words)."""
    out = []
    for lib, letter in letters.items():
        if lib != "xlkit":
            for pat, rep in LIBRARIES[lib].get("patterns", []):
                if pat == "julia-imports":
                    label = f"Library{letter}"
                    out.append((re.compile(r"^([ \t]*(?:using|import)\b[^\n]*)$", re.M),
                                lambda m, label=label: re.sub(r"\bXLSX\b(?!\.)", label, m.group(1))))
                else:
                    out.append((pat, rep.replace("{L}", letter)))
    return out


def group_names(letters):
    """Every member's names, each mapped to its own letter, for use in every bundle."""
    out = {}
    for lib, letter in letters.items():
        for name, label in (OURS if lib == "xlkit" else LIBRARIES[lib]["names"]).items():
            out[name] = label.format(L=letter)
    return out


URL = re.compile(r"https?://[^\s)\]>\"'`]+")


def blind(text, names, title=False, patterns=()):
    """Replace each library name by its label: in links (dropped), titles (anywhere) and prose."""
    for pat, rep in patterns:
        text = re.sub(pat, rep, text)
    lowered = [n.lower() for n in names]
    text = URL.sub(lambda m: "[link]" if any(n in m.group(0).lower() for n in lowered) else m.group(0), text)
    # Longest names first, so "openxlsx2" is replaced before "openxlsx".
    for name in sorted(names, key=len, reverse=True):
        pattern = re.escape(name) if title else rf"(?<![\w-]){re.escape(name)}(?![\w-])"
        text = re.sub(pattern, names[name], text, flags=re.I)
    return text


def bundle(name, letter, others, names, patterns=()):
    if name == "xlkit":
        parts = [(f, read(os.path.join(REPO, f))) for f in OUR_FILES]
    else:
        parts = [item_text(others, it) for it in LIBRARIES[name]["items"]]
    body = "\n\n".join(f"===== {blind(title, names, title=True)} =====\n{blind(text, names, patterns=patterns)}" for title, text in parts)
    return f"########## Library {letter} ##########\n\n{body}\n"


def rubric_sections():
    text = read(os.path.join(HERE, "rubric.md"))
    tasks = re.search(r"## The thirteen tasks\n(.*?)\n## Common", text, re.S).group(1)
    scores = re.search(r"## Scores\n(.*?)\n## Pass rule", text, re.S).group(1)
    return tasks.strip(), scores.strip()


def support():
    """Common tasks per library, from the support table in sources.md."""
    text = read(os.path.join(HERE, "sources.md"))
    table = re.search(r"\| Task \|(.*?)\n\n", text, re.S).group(0).strip().splitlines()
    libs = [c.strip() for c in table[0].strip("|").split("|")][1:]
    common = {lib: [] for lib in libs}
    for row in table[2:]:
        cells = [c.strip() for c in row.strip("|").split("|")]
        task = int(cells[0].split()[0])
        for lib, cell in zip(libs, cells[1:]):
            if cell in ("yes", "limited"):
                common[lib].append(task)
    return common


def prompt(group, letters, others, common):
    tasks, scores = rubric_sections()
    libs = sorted(letters, key=letters.get)
    lines = ["| library | tasks it supports (common with Library " + letters["xlkit"] + ") |", "|---|---|"]
    for lib in libs:
        if lib != "xlkit":
            lines.append(f"| Library {letters[lib]} | {', '.join(map(str, common[lib]))} |")
    stata = group == "Stata"
    head = f"""You are judging the design and documentation of xlsx libraries for a fixed set of tasks.

Rules:
- Use only this file. Do not open other files, browse, or run code, and do not use what you may know
  about any library you think you recognise, except where this prompt asks for your knowledge of Stata.
- Library {letters['xlkit']} is an R package. {'The other libraries are in other languages; ' if group not in ('R', 'Stata') else ''}judge each
  library on the code its own user writes for each scenario, and on its own documentation.
- Work through every task for every library before scoring.
- Library names have been replaced by "Library A", "Library B" and so on, also inside install commands,
  imports and file paths. Such a replacement is not an error in the documentation; read it as the real name.

## The thirteen tasks

{tasks}

## Scores

{scores}
"""
    if stata:
        head += f"""
## This session

You score two things: Library {letters['xlkit']} from its documentation below, and Stata's `import excel`,
`export excel` and `putexcel` commands from your own knowledge of them. For Stata give only the two design
scores (Ergonomics and Failure behavior). For each task, write out the Stata code you scored. Task 1
(install) does not apply to Stata: give Stata no scores for it. Where a task needs more than one command or
a loop in Stata, score what Stata needs.
"""
    else:
        head += "\n## Which tasks are common\n\n" + "\n".join(lines) + "\n\nScore every library on every task anyway.\n"
    head += f"""
## What to return

For each library and task: the code you would write (at most a few lines), the six scores (two for Stata),
and one or two sentences of reason for each score below 3. Then end with one JSON block:

```json
{{"{letters['xlkit']}": {{"1": [ergonomics, failure, findability, correctness, completeness, clarity], "2": [...], ... "13": [...]}},
  "<other letter or Stata>": {{...}}}}
```

Use integers 0 to 3, in that order. {'For Stata use two numbers per task, for tasks 2 to 13.' if stata else ''}
"""
    # The Stata session is not blinded (rubric.md, "Stata").
    names = {} if stata else group_names(letters)
    patterns = () if stata else group_patterns(letters)
    body = "\n".join(bundle(lib, letters[lib], others, names, patterns) for lib in libs)
    return head + "\n" + body


def main(others, out, seed):
    os.makedirs(out, exist_ok=True)
    rng = random.Random(seed)
    common = support()
    record = {"seed": seed, "groups": {}}
    for group, libs in GROUPS.items():
        members = ["xlkit", *libs]
        order = members[:]
        rng.shuffle(order)
        letters = {lib: "ABCD"[i] for i, lib in enumerate(order)}
        record["groups"][group] = letters
        text = prompt(group, letters, others, common)
        with open(os.path.join(out, f"{group.lower()}.md"), "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{group}: {len(text.split()):,} words, letters {letters}")
    with open(os.path.join(out, "letters.json"), "w", encoding="utf-8") as f:
        json.dump(record, f, indent=2)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]))
