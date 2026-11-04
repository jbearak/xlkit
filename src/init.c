/* The bridge between R and xlkit's Rust core (ADR 0002).
 *
 * Rust never calls R's API. Each Rust function returns an XlResult of
 * plain buffers; this file copies them into an R list and frees them.
 * While the copy runs, the result is owned by an external pointer whose
 * finalizer frees it, so an allocation error part way leaks nothing.
 * A failure comes back to R as list(status, message), and R raises the
 * error once Rust's memory is freed.
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

XlResult xl_info(const char *path);
XlResult xl_names(const char *path);
XlResult xl_read(const char *path, const char *sheet);
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

static const R_CallMethodDef calls[] = {
  {"C_xl_info", (DL_FUNC) &C_xl_info, 1},
  {"C_xl_names", (DL_FUNC) &C_xl_names, 1},
  {"C_xl_read", (DL_FUNC) &C_xl_read, 2},
  {NULL, NULL, 0}
};

void R_init_xlkit(DllInfo *dll) {
  R_registerRoutines(dll, NULL, calls, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
