;; langs/fennel.scm — Fennel language definition.
;; Fennel has no pairs query upstream.

(require "cogs/paredit/lang.scm")

(register-language!
  (Language "fennel"
    ;; form-kinds
    '("list" "list_binding" "sequence" "sequence_binding"
      "sequence_arguments"
      "table"
      "table_binding"
      "table_metadata"
      "case_catch"
      "case_form"
      "case_guard"
      "match_form"
      "case_try_form"
      "match_try_form"
      "if_form"
      "fn_form"
      "lambda_form"
      "macro_form"
      "hashfn_form"
      "each_form"
      "collect_form"
      "icollect_form"
      "accumulate_form"
      "for_form"
      "fcollect_form"
      "faccumulate_form"
      "local_form"
      "var_form"
      "global_form"
      "set_form"
      "let_form"
      "let_vars"
      "import_macros_form"
      "quote_form"
      "unquote_form")
    ;; comment-kinds (none captured upstream; rely on extra? at runtime)
    '()
    ;; string-kinds — `string` is polymorphic in this grammar (covers both
    ;; "…" strings and :colon strings); split/join guards on actual " delimiters,
    ;; so keyword-ish strings are safely ignored. `string_binding`/`docstring`
    ;; are the "…"-quoted string in binding/doc positions.
    '("string" "string_binding" "docstring")
    ;; whitespace — Fennel treats commas as whitespace
    (list #\space #\tab #\newline #\,)
    ;; pairs-query-src
    #f))
