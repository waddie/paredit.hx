;; inspect.scm — diagnostic commands for the tree-sitter foundation.
;;
;; These don't edit anything, they report through the statusline.

(require "ts.scm")
(require "lang.scm")
(require "traversal.scm")
(require "pairs.scm")
(require "helix/misc.scm") ; set-status!
(require "helix/editor.scm") ; set-register!

(provide paredit-inspect
  paredit-print-tree
  paredit-inspect-pairs)

;;@doc
;; Report, in the statusline: the detected language, the node kind under the
;; cursor, and the kind + char range of the nearest enclosing form.
(define (paredit-inspect)
  (let ([lang (language-for-doc)]
        [node (node-at-cursor)])
    (cond
      [(not lang)
        (set-status! (string-append
                      "paredit: no registered language (doc language = "
                      (let ([id (current-language)]) (if id id "none"))
                      ")"))]
      [(not node)
        (set-status! "paredit: no syntax node at cursor (empty buffer / no tree?)")]
      [else
        (let* ([rope (current-rope)]
               [form (find-nearest-form lang node)])
          (set-status!
            (string-append
              "paredit["
              (Language-id lang)
              "]"
              " node="
              (tsnode-kind node)
              (if form
                (let ([r (node->char-range rope form)])
                  (string-append
                    " form="
                    (tsnode-kind form)
                    " chars "
                    (number->string (car r))
                    ".."
                    (number->string (cdr r))))
                " form=<none>"))))])))

;;@doc
;; Copy the nearest enclosing form's pretty-printed subtree (or the whole tree
;; root if the cursor isn't in a form) to the system clipboard (register `+`).
(define (paredit-print-tree)
  (let ([lang (language-for-doc)]
        [node (node-at-cursor)]
        [root (current-root)])
    (cond
      [(not root) (set-status! "paredit: no syntax tree")]
      [else
        (let ([target (or (and lang node (find-nearest-form lang node)) root)])
          (set-register! #\+ (list (tsnode-print-tree target)))
          (set-status! "paredit: subtree copied to system clipboard (register +)"))])))

;;@doc
;; Run the language's pairs query over the cursor's top-level form and report the
;; @pair node count + their texts.
(define (paredit-inspect-pairs)
  (let ([lang (language-for-doc)]
        [node (node-at-cursor)])
    (cond
      [(not lang) (set-status! "paredit: no registered language")]
      [(not node) (set-status! "paredit: no syntax node at cursor")]
      [(not (Language-pairs-query-src lang))
        (set-status! (string-append "paredit[" (Language-id lang)
                      "]: no pairs query for this language"))]
      [else
        (let* ([rope (current-rope)]
               [top (or (local-root node) node)]
               [r (node->char-range rope top)]
               [nodes (pair-nodes-in-range lang (car r) (cdr r))]
               [texts (map (lambda (n) (node-text rope n)) nodes)]
               [joined (let loop ([xs texts] [acc ""])
                        (cond
                          [(null? xs) acc]
                          [(equal? acc "") (loop (cdr xs) (car xs))]
                          [else (loop (cdr xs) (string-append acc " | " (car xs)))]))])
          (set-register! #\+ (list joined))
          (set-status!
            (string-append "paredit[" (Language-id lang) "] "
              (number->string (length nodes))
              " @pair: "
              joined)))])))
