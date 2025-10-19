;; pairs.scm — pairwise structural detection (maps, let-bindings, cond, ...).

(require "helix/treesitter.scm")
(require "cogs/paredit/ts.scm")
(require "cogs/paredit/lang.scm")
(require "cogs/paredit/traversal.scm")

(provide build-pairs-loader
  pair-nodes-in-range
  pair-chunks
  pairwise-nodes-for)

;;@doc
;; Build a TSQueryLoader from `lang`'s pairs-query-src (compiling once), or #f
;; if the language has no pairs query. The returned loader yields the compiled
;; query only for `lang`'s id and #f for every other layer.
(define (build-pairs-loader lang)
  (let ([src (Language-pairs-query-src lang)])
    (if src
      (let ([query (string->tsquery (Language-id lang) src)]
            [id (Language-id lang)])
        (tsquery-loader
          (lambda (layer-lang)
            (if (equal? layer-lang id) query #f))))
      #f)))

;;@doc
;; All @pair nodes within the char range [lo, hi) of the focused document, in
;; document order, or '() when the language has no pairs query / no matches.
;; query-document-byte-range returns a single aggregated TSMatch whose "pair"
;; capture flattens every @pair node across the range (TSMatch pitfall), so we
;; sort by start byte and let `pair-chunks` recover the key/value grouping.
(define (pair-nodes-in-range lang lo-char hi-char)
  (let ([loader (build-pairs-loader lang)])
    (if (not loader)
      '()
      (let* ([rope (current-rope)]
             [lo-byte (char->byte rope lo-char)]
             [hi-byte (char->byte rope hi-char)]
             [match (query-document-byte-range loader (current-doc-id) lo-byte hi-byte)])
        (if (and match (TSMatch? match))
          (let ([pairs (tsmatch-capture match "pair")])
            (if (list? pairs)
              (sort pairs (lambda (a b) (< (tsnode-start-byte a)
                                         (tsnode-start-byte b))))
              '()))
          '())))))

;;@doc
;; The pairwise @pair nodes (in document order) that `target` belongs to, or #f
;; when `target` is not part of a pairwise set in its enclosing form (so callers
;; fall back to a plain element drag). `target` should be an element root
;; (node-root). Filters the query's flat @pair list down to nodes that are direct
;; children of `target`'s enclosing form and not comments, then requires `target`
;; itself to be among them.
(define (pairwise-nodes-for lang target)
  (let ([enclosing (tsnode-parent target)])
    (if (not enclosing)
      #f
      (let* ([rope (current-rope)]
             [top (or (local-root target) target)]
             [r (node->char-range rope top)]
             [all (pair-nodes-in-range lang (car r) (cdr r))]
             [siblings (filter (lambda (n)
                                (and (not (comment? lang n))
                                  (let ([p (tsnode-parent n)])
                                    (and p (equal? p enclosing)))))
                        all)])
        (if (member target siblings) siblings #f)))))

;;@doc
;; Group an ordered list of @pair nodes into 2-element chunks (key/value pairs).
(define (pair-chunks pair-nodes)
  (let loop ([xs pair-nodes] [acc '()])
    (cond
      [(null? xs) (reverse acc)]
      [(null? (cdr xs)) (reverse (cons (list (car xs)) acc))]
      [else (loop (cddr xs) (cons (list (car xs) (cadr xs)) acc))])))
