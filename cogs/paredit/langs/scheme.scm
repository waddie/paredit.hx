;; langs/scheme.scm — Scheme language definition.
;; Scheme has no pairs query upstream.

(require "cogs/paredit/lang.scm")

(register-language!
  (Language "scheme"
    ;; form-kinds
    '("list" "vector" "byte_vector")
    ;; comment-kinds
    '("comment" "block_comment")
    ;; string-kinds
    '("string")
    ;; whitespace
    (list #\space #\tab #\newline)
    ;; pairs-query-src
    #f))
