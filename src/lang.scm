;; lang.scm — language registry for paredit.hx
;;
;; A "language" tells paredit which node kinds are forms, which are comments,
;; what counts as inter-element whitespace, and (optionally) the tree-sitter
;; query source used for pairwise operations.
;;
;; Languages register themselves by requiring their module from `langs/` and
;; calling `register-language!`. `lang.scm` exposes the lookup + the form?/
;; comment? predicates the rest of the codebase uses.

(require "ts.scm")

(provide
  ;; Steel `provide` has no `struct-out`; list the struct's generated bindings.
  Language
  Language?
  Language-id
  Language-form-kinds
  Language-comment-kinds
  Language-string-kinds
  Language-whitespace
  Language-pairs-query-src
  register-language!
  lookup-language
  language-for-doc
  form?
  comment?
  str?
  form-kind?
  comment-kind?
  string-kind?
  ws-char?
  trim-leading-ws
  trim-trailing-ws)

;;@doc
;; A language definition.
;; * id              : string?            Helix language id (editor-document->language)
;; * form-kinds      : (listof string?)   node kinds treated as forms
;; * comment-kinds   : (listof string?)   node kinds treated as comments
;; * string-kinds    : (listof string?)   node kinds treated as string literals
;; * whitespace      : (listof char?)     element separators (e.g. #\space, #\,)
;; * pairs-query-src : (or string? #f)    paredit/pairs source, or #f if none
(struct Language (id form-kinds comment-kinds string-kinds whitespace pairs-query-src)
  #:transparent)

;; id (string) -> Language
(define *languages* (hash))

;;@doc
;; Register (or replace) a language definition. Called by each langs/*.scm.
(define (register-language! lang)
  (set! *languages* (hash-insert *languages* (Language-id lang) lang)))

;;@doc
;; Language? for the given Helix language id, or #f if unregistered.
(define (lookup-language id)
  (if (hash-contains? *languages* id)
    (hash-ref *languages* id)
    #f))

;;@doc
;; Language? for the currently focused document, or #f.
(define (language-for-doc)
  (let ([id (current-language)])
    (and id (lookup-language id))))

;;;; ---------------------------------------------------------------------------
;;;; Predicates
;;;; ---------------------------------------------------------------------------

;;@doc
;; Is `kind` (a string) a form kind in `lang`?
(define (form-kind? lang kind)
  (member kind (Language-form-kinds lang)))

;;@doc
;; Is `kind` (a string) a comment kind in `lang`?
(define (comment-kind? lang kind)
  (member kind (Language-comment-kinds lang)))

;;@doc
;; Is `kind` (a string) a string-literal kind in `lang`?
(define (string-kind? lang kind)
  (member kind (Language-string-kinds lang)))

;;@doc
;; Is `node` a form in `lang`?
(define (form? lang node)
  (and (form-kind? lang (tsnode-kind node)) #t))

;;@doc
;; Is `node` a comment in `lang`? Honours both the language's comment kinds and
;; tree-sitter's `extra?` flag (comments often live outside the grammar proper).
(define (comment? lang node)
  (or (tsnode-extra? node)
    (and (comment-kind? lang (tsnode-kind node)) #t)))

;;@doc
;; Is `node` a string literal in `lang`? (Named `str?` to avoid shadowing the
;; Steel builtin `string?`.)
(define (str? lang node)
  (and (string-kind? lang (tsnode-kind node)) #t))

;;;; ---------------------------------------------------------------------------
;;;; Whitespace helpers (parameterised by the language's whitespace set, so e.g.
;;;; Clojure's comma counts)
;;;; ---------------------------------------------------------------------------

;;@doc Is char `c` whitespace in `lang`?
(define (ws-char? lang c)
  (and (member c (Language-whitespace lang)) #t))

;;@doc `s` with leading `lang`-whitespace removed.
(define (trim-leading-ws lang s)
  (let ([len (string-length s)])
    (let loop ([i 0])
      (if (and (< i len) (ws-char? lang (string-ref s i)))
        (loop (+ i 1))
        (substring s i len)))))

;;@doc `s` with trailing `lang`-whitespace removed.
(define (trim-trailing-ws lang s)
  (let loop ([n (string-length s)])
    (if (and (> n 0) (ws-char? lang (string-ref s (- n 1))))
      (loop (- n 1))
      (substring s 0 n))))
