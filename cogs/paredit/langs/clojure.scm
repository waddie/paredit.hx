;; langs/clojure.scm — Clojure language definition.

(require "cogs/paredit/lang.scm")

(define clojure-pairs-query
  "(list_lit
  (sym_lit) @fn-name
  (#any-of? @fn-name
   \"let\"
   \"loop\"
   \"binding\"
   \"with-open\"
   \"with-redefs\")

  (vec_lit
    (_) @pair))

(map_lit
  (_) @pair)

(list_lit
  (sym_lit) @fn-name
  (#eq? @fn-name \"case\")

  (_) .
  ((_) @pair . (_) @pair)+
  (_)?)

(list_lit
  (sym_lit) @fn-name
  (#eq? @fn-name \"cond\")

  ((_) @pair (_) @pair)+)

(list_lit
  (sym_lit) @fn-name
  (#any-of? @fn-name
   \"cond->\"
   \"cond->>\")
  (_)
  .
  ((_) @pair . (_) @pair)+)

(list_lit
  (sym_lit) @fn-name
  (#eq? @fn-name \"condp\")

  (_) (_)
  .
  ((_) @pair . (_) @pair)+
  .
  (_)?)")

(register-language!
  (Language "clojure"
    ;; form-kinds
    '("list_lit" "set_lit" "vec_lit" "anon_fn_lit"
      "read_cond_lit"
      "map_lit"
      "ns_map_lit")
    ;; comment-kinds
    '("comment")
    ;; whitespace — Clojure treats commas as whitespace
    (list #\space #\tab #\newline #\,)
    ;; pairs-query-src
    clojure-pairs-query))
