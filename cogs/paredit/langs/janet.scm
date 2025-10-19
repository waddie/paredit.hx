;; langs/janet.scm — Janet language definition.

(require "cogs/paredit/lang.scm")

(define janet-pairs-query
  "(par_tup_lit
  (sym_lit) @fn-name
  (#any-of? @fn-name
   \"let\"
   \"if-let\"
   \"when-let\"
   \"with-dyns\"
   \"with-vars\")

  (par_tup_lit
    (_) @pair))

(struct_lit
  (_) @pair)

(tbl_lit
  (_) @pair)

(par_tup_lit
  (sym_lit) @fn-name
  (#any-of? @fn-name
   \"case\"
   \"match\")

  (_) .
  ((_) @pair . (_) @pair)+
  (_)?)

(par_tup_lit
  (sym_lit) @fn-name
  (#eq? @fn-name \"cond\")

  ((_) @pair (_) @pair)+)")

(register-language!
  (Language "janet"
    ;; form-kinds
    '("par_tup_lit" "sqr_tup_lit" "tbl_lit" "sqr_arr_lit"
      "struct_lit"
      "par_arr_lit")
    ;; comment-kinds
    '("comment")
    ;; whitespace
    (list #\space #\tab #\newline)
    ;; pairs-query-src
    janet-pairs-query))
