;; langs/commonlisp.scm — Common Lisp language definition.
;;
;; Upstream the forms query is structural: `(list_lit open: "(") @form` plus
;; `(loop_macro)` and `(defun)`. The `open: "("` field constraint is satisfied
;; by virtually every list_lit, so for the kind-set approach listing "list_lit"
;; is sufficient for the common case; "loop_macro" and "defun" are distinct
;; kinds the grammar lifts out of a wrapping list_lit. Common Lisp has no pairs
;; query upstream.

(require "cogs/paredit/lang.scm")

(register-language!
  (Language "common-lisp"
    ;; form-kinds
    '("list_lit" "loop_macro" "defun")
    ;; comment-kinds (none captured upstream; rely on extra? at runtime)
    '()
    ;; whitespace
    (list #\space #\tab #\newline)
    ;; pairs-query-src
    #f))
