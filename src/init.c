/* The bridge between R and xlkit's Rust core (ADR 0002).
 *
 * Rust never calls R's API. Each Rust function returns an XlResult of
 * plain buffers; this file copies them into an R list and frees them.
 * While the copy runs, the result is owned by an external pointer whose
 * finalizer frees it, so an allocation error part way leaks nothing.
 * A failure comes back to R as list(status, message), and R raises the
 * error once Rust's memory is freed.
 *
 * To write, C_xl_write() points an XlPlan at R's vectors (strings
 * translated to UTF-8 into memory R frees when the call ends) and Rust
 * only reads them while xl_write() runs. C_xl_edit() does the same with an
 * XlEditPlan for xl_edit(), which writes into an existing workbook.
 */
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int32_t status;
  char *message;
  int32_t *ints;
  size_t n_ints;
  double *doubles;
  size_t n_doubles;
  unsigned char *bytes;
  size_t n_bytes;
  unsigned char *str_data;
  size_t n_str_data;
  size_t *str_offsets;
  size_t n_strings;
} XlResult;

typedef struct { const int32_t *ptr; size_t n; } XlInts;
typedef struct { const double *ptr; size_t n; } XlDoubles;
typedef struct { const char *const *ptr; size_t n; } XlStrings;

/* The same fields, in the same order, as XlPlan in src/rust/src/lib.rs. */
typedef struct {
  XlInts fmt_ints;
  XlDoubles fmt_size;
  XlStrings fmt_font;
  XlStrings fmt_numfmt;
  XlStrings sheet_names;
  XlInts sheet_ints;
  XlInts width_cols;
  XlDoubles width_vals;
  XlInts merges;
  XlInts blocks;
  XlInts kinds;
  XlInts fmts;
  XlDoubles nums;
  XlStrings strs;
} XlPlan;

/* The same fields, in the same order, as XlEditPlan in src/rust/src/lib.rs. */
typedef struct {
  XlInts fmt_ints;
  XlDoubles fmt_size;
  XlStrings fmt_font;
  XlStrings fmt_numfmt;
  XlStrings names;
  XlInts ints;
  XlInts width_cols;
  XlDoubles width_vals;
  XlInts merges;
  XlInts blocks;
  XlInts kinds;
  XlInts fmts;
  XlInts dclass;
  XlDoubles nums;
  XlStrings strs;
  XlInts pieces;
} XlEditPlan;

XlResult xl_info(const char *path);
XlResult xl_names(const char *path);
XlResult xl_read(const char *path, const char *sheet);
XlResult xl_create_new(const char *from, const char *to);
XlResult xl_write(const char *path, const XlPlan *plan);
XlResult xl_edit(const char *src, const char *dst, const XlEditPlan *plan);
void xl_result_free(XlResult *r);

static void finalize(SEXP ptr) {
  XlResult *r = (XlResult *) R_ExternalPtrAddr(ptr);
  if (r) {
    xl_result_free(r);
    free(r);
    R_ClearExternalPtr(ptr);
  }
}

/* The owner of a Rust result: an external pointer whose finalizer frees
 * it, made (and protected) before Rust runs, with space for the result.
 * Everything here that can fail does so before Rust has allocated. */
static SEXP new_owner(XlResult **slot) {
  SEXP ptr = PROTECT(R_MakeExternalPtr(NULL, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ptr, finalize, TRUE);
  *slot = (XlResult *) malloc(sizeof(XlResult));
  if (!*slot) Rf_error("xlkit: out of memory");
  UNPROTECT(1);
  return ptr;
}

/* Hand Rust's result to its owner. Neither step allocates through R, so
 * from here every R error leaves the result to the finalizer. */
static void own(SEXP ptr, XlResult *slot, XlResult res) {
  *slot = res;
  R_SetExternalPtrAddr(ptr, slot);
}

/* Copy the owned result into an R list, then free it. `ptr` is protected
 * by the caller. */
static SEXP to_r(SEXP ptr) {
  XlResult *r = (XlResult *) R_ExternalPtrAddr(ptr);

  SEXP out;
  if (r->status != 0) {
    out = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("status"));
    SET_STRING_ELT(names, 1, Rf_mkChar("message"));
    SET_VECTOR_ELT(out, 0, Rf_ScalarInteger(r->status));
    SET_VECTOR_ELT(out, 1, Rf_ScalarString(Rf_mkCharCE(r->message ? r->message : "", CE_UTF8)));
    Rf_setAttrib(out, R_NamesSymbol, names);
  } else {
    out = PROTECT(Rf_allocVector(VECSXP, 4));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(names, 0, Rf_mkChar("ints"));
    SET_STRING_ELT(names, 1, Rf_mkChar("doubles"));
    SET_STRING_ELT(names, 2, Rf_mkChar("bytes"));
    SET_STRING_ELT(names, 3, Rf_mkChar("strings"));
    Rf_setAttrib(out, R_NamesSymbol, names);

    SEXP ints = Rf_allocVector(INTSXP, (R_xlen_t) r->n_ints);
    SET_VECTOR_ELT(out, 0, ints);
    if (r->n_ints) memcpy(INTEGER(ints), r->ints, r->n_ints * sizeof(int32_t));

    SEXP doubles = Rf_allocVector(REALSXP, (R_xlen_t) r->n_doubles);
    SET_VECTOR_ELT(out, 1, doubles);
    if (r->n_doubles) memcpy(REAL(doubles), r->doubles, r->n_doubles * sizeof(double));

    SEXP bytes = Rf_allocVector(RAWSXP, (R_xlen_t) r->n_bytes);
    SET_VECTOR_ELT(out, 2, bytes);
    if (r->n_bytes) memcpy(RAW(bytes), r->bytes, r->n_bytes);

    SEXP strings = Rf_allocVector(STRSXP, (R_xlen_t) r->n_strings);
    SET_VECTOR_ELT(out, 3, strings);
    for (size_t i = 0; i < r->n_strings; i++) {
      size_t from = r->str_offsets[i], to = r->str_offsets[i + 1];
      if (to == from) continue; /* already "" */
      if (to - from > INT_MAX) Rf_error("xlkit: a cell's text is too long");
      SET_STRING_ELT(strings, (R_xlen_t) i,
                     Rf_mkCharLenCE((const char *) r->str_data + from, (int) (to - from), CE_UTF8));
    }
  }
  finalize(ptr);
  UNPROTECT(2);
  return out;
}

static const char *utf8(SEXP x, const char *what) {
  if (TYPEOF(x) != STRSXP || XLENGTH(x) != 1 || STRING_ELT(x, 0) == NA_STRING)
    Rf_error("xlkit: `%s` must be one string", what);
  return Rf_translateCharUTF8(STRING_ELT(x, 0));
}

/* Each entry point converts its arguments and makes the owner before
 * calling Rust, so nothing allocates between Rust returning and R
 * owning the result. */
static SEXP C_xl_info(SEXP path) {
  const char *p = utf8(path, "path");
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_info(p));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}
static SEXP C_xl_names(SEXP path) {
  const char *p = utf8(path, "path");
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_names(p));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}
static SEXP C_xl_create_new(SEXP from, SEXP to) {
  const char *f = utf8(from, "from");
  const char *t = utf8(to, "to");
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_create_new(f, t));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}
static SEXP C_xl_read(SEXP path, SEXP sheet) {
  const char *p = utf8(path, "path");
  const char *s = utf8(sheet, "sheet");
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_read(p, s));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}

/* The parts of the plan R made (R/write_xlsx.R, `plan_parts`), in order. */
enum {
  P_FMT_INTS, P_FMT_SIZE, P_FMT_FONT, P_FMT_NUMFMT, P_SHEET_NAMES, P_SHEET_INTS,
  P_WIDTH_COLS, P_WIDTH_VALS, P_MERGES, P_BLOCKS, P_KINDS, P_FMTS, P_NUMS, P_STRS,
  P_N
};

static XlInts ints_of(SEXP plan, int i) {
  SEXP x = VECTOR_ELT(plan, i);
  if (TYPEOF(x) != INTSXP) Rf_error("xlkit: part %d of the plan must be integer", i + 1);
  XlInts out = {INTEGER(x), (size_t) XLENGTH(x)};
  return out;
}

static XlDoubles doubles_of(SEXP plan, int i) {
  SEXP x = VECTOR_ELT(plan, i);
  if (TYPEOF(x) != REALSXP) Rf_error("xlkit: part %d of the plan must be double", i + 1);
  XlDoubles out = {REAL(x), (size_t) XLENGTH(x)};
  return out;
}

/* UTF-8 copies of a character vector, NULL for NA, in memory R frees
 * when the .Call returns. */
static XlStrings strings_of(SEXP plan, int i) {
  SEXP x = VECTOR_ELT(plan, i);
  if (TYPEOF(x) != STRSXP) Rf_error("xlkit: part %d of the plan must be character", i + 1);
  R_xlen_t n = XLENGTH(x);
  const char **p = n ? (const char **) R_alloc((size_t) n, sizeof(char *)) : NULL;
  for (R_xlen_t k = 0; k < n; k++) {
    SEXP s = STRING_ELT(x, k);
    p[k] = s == NA_STRING ? NULL : Rf_translateCharUTF8(s);
  }
  XlStrings out = {p, (size_t) n};
  return out;
}

static SEXP C_xl_write(SEXP path, SEXP plan) {
  const char *p = utf8(path, "path");
  if (TYPEOF(plan) != VECSXP || XLENGTH(plan) != P_N) Rf_error("xlkit: the plan must be a list of %d parts", P_N);
  XlPlan w;
  w.fmt_ints = ints_of(plan, P_FMT_INTS);
  w.fmt_size = doubles_of(plan, P_FMT_SIZE);
  w.fmt_font = strings_of(plan, P_FMT_FONT);
  w.fmt_numfmt = strings_of(plan, P_FMT_NUMFMT);
  w.sheet_names = strings_of(plan, P_SHEET_NAMES);
  w.sheet_ints = ints_of(plan, P_SHEET_INTS);
  w.width_cols = ints_of(plan, P_WIDTH_COLS);
  w.width_vals = doubles_of(plan, P_WIDTH_VALS);
  w.merges = ints_of(plan, P_MERGES);
  w.blocks = ints_of(plan, P_BLOCKS);
  w.kinds = ints_of(plan, P_KINDS);
  w.fmts = ints_of(plan, P_FMTS);
  w.nums = doubles_of(plan, P_NUMS);
  w.strs = strings_of(plan, P_STRS);
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_write(p, &w));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}

/* The parts of an edit plan R made (R/edit.R, `edit_parts`), in order. */
enum {
  E_FMT_INTS, E_FMT_SIZE, E_FMT_FONT, E_FMT_NUMFMT, E_NAMES, E_INTS, E_WIDTH_COLS,
  E_WIDTH_VALS, E_MERGES, E_BLOCKS, E_KINDS, E_FMTS, E_DCLASS, E_NUMS, E_STRS, E_PIECES,
  E_N
};

static SEXP C_xl_edit(SEXP src, SEXP dst, SEXP plan) {
  const char *s = utf8(src, "src");
  const char *d = utf8(dst, "dst");
  if (TYPEOF(plan) != VECSXP || XLENGTH(plan) != E_N) Rf_error("xlkit: the edit plan must be a list of %d parts", E_N);
  XlEditPlan w;
  w.fmt_ints = ints_of(plan, E_FMT_INTS);
  w.fmt_size = doubles_of(plan, E_FMT_SIZE);
  w.fmt_font = strings_of(plan, E_FMT_FONT);
  w.fmt_numfmt = strings_of(plan, E_FMT_NUMFMT);
  w.names = strings_of(plan, E_NAMES);
  w.ints = ints_of(plan, E_INTS);
  w.width_cols = ints_of(plan, E_WIDTH_COLS);
  w.width_vals = doubles_of(plan, E_WIDTH_VALS);
  w.merges = ints_of(plan, E_MERGES);
  w.blocks = ints_of(plan, E_BLOCKS);
  w.kinds = ints_of(plan, E_KINDS);
  w.fmts = ints_of(plan, E_FMTS);
  w.dclass = ints_of(plan, E_DCLASS);
  w.nums = doubles_of(plan, E_NUMS);
  w.strs = strings_of(plan, E_STRS);
  w.pieces = ints_of(plan, E_PIECES);
  XlResult *slot;
  SEXP ptr = PROTECT(new_owner(&slot));
  own(ptr, slot, xl_edit(s, d, &w));
  SEXP out = to_r(ptr);
  UNPROTECT(1);
  return out;
}

static const R_CallMethodDef calls[] = {
  {"C_xl_info", (DL_FUNC) &C_xl_info, 1},
  {"C_xl_names", (DL_FUNC) &C_xl_names, 1},
  {"C_xl_read", (DL_FUNC) &C_xl_read, 2},
  {"C_xl_write", (DL_FUNC) &C_xl_write, 2},
  {"C_xl_create_new", (DL_FUNC) &C_xl_create_new, 2},
  {"C_xl_edit", (DL_FUNC) &C_xl_edit, 3},
  {NULL, NULL, 0}
};

void R_init_xlkit(DllInfo *dll) {
  R_registerRoutines(dll, NULL, calls, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
