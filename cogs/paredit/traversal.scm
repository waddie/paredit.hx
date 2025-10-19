;; traversal.scm — structural navigation over the tree.

(require "cogs/paredit/ts.scm")
(require "cogs/paredit/lang.scm")

(provide named-siblings
  node-index
  next-named-sibling
  prev-named-sibling
  next-sibling-skipping-comments
  prev-sibling-skipping-comments
  children-skipping-comments
  find-nearest-form
  find-enclosing-form
  node-root
  local-root
  get-form-edges)

;;;; ---------------------------------------------------------------------------
;;;; Sibling navigation
;;;; ---------------------------------------------------------------------------

;;@doc
;; The named children of `node`'s parent (i.e. `node`'s sibling cohort), or '()
;; if it has no parent.
(define (named-siblings node)
  (let ([parent (tsnode-parent node)])
    (if parent (tsnode-named-children parent) '())))

;;@doc
;; Zero-based index of `node` within `siblings` (compared by `equal?`), or #f.
(define (node-index node siblings)
  (let loop ([i 0] [xs siblings])
    (cond
      [(null? xs) #f]
      [(equal? node (car xs)) i]
      [else (loop (+ i 1) (cdr xs))])))

;;@doc
;; The next named sibling of `node`, or #f.
(define (next-named-sibling node)
  (let* ([siblings (named-siblings node)]
         [idx (node-index node siblings)])
    (if (and idx (< (+ idx 1) (length siblings)))
      (list-ref siblings (+ idx 1))
      #f)))

;;@doc
;; The previous named sibling of `node`, or #f.
(define (prev-named-sibling node)
  (let* ([siblings (named-siblings node)]
         [idx (node-index node siblings)])
    (if (and idx (> idx 0))
      (list-ref siblings (- idx 1))
      #f)))

;;@doc
;; The next named sibling of `node` that is not a comment in `lang`, or #f.
(define (next-sibling-skipping-comments lang node)
  (let loop ([n (next-named-sibling node)])
    (cond
      [(not n) #f]
      [(comment? lang n) (loop (next-named-sibling n))]
      [else n])))

;;@doc
;; The previous named sibling of `node` that is not a comment in `lang`, or #f.
(define (prev-sibling-skipping-comments lang node)
  (let loop ([n (prev-named-sibling node)])
    (cond
      [(not n) #f]
      [(comment? lang n) (loop (prev-named-sibling n))]
      [else n])))

;;@doc
;; Named children of `node`, with comments (in `lang`) removed.
(define (children-skipping-comments lang node)
  (filter (lambda (c) (not (comment? lang c)))
    (tsnode-named-children node)))

;;;; ---------------------------------------------------------------------------
;;;; Form finding
;;;; ---------------------------------------------------------------------------

;;@doc
;; Climb from `node` (inclusive) to the nearest enclosing form in `lang`, or #f.
(define (find-nearest-form lang node)
  (let loop ([n node])
    (cond
      [(not n) #f]
      [(form? lang n) n]
      [else (loop (tsnode-parent n))])))

;;@doc
;; Climb to the nearest form STRICTLY enclosing `node` — both excluding `node`
;; itself AND skipping any co-extensive wrapper forms (forms that cover the exact
;; same byte span as `node`). Some grammars nest co-extensive nodes: Common Lisp
;; parses `(loop …)` as a `loop_macro` inside a `list_lit` wrapper sharing the
;; same span, so the naive parent of a `loop_macro` is a form with an identical
;; range — raising into it would be a no-op. Returns the first ancestor form
;; whose span is strictly larger than `node`'s, or #f.
(define (find-enclosing-form lang node)
  (let ([ns (tsnode-start-byte node)]
        [ne (tsnode-end-byte node)])
    (let loop ([n (tsnode-parent node)])
      (cond
        [(not n) #f]
        [(and (form? lang n)
            (or (not (= (tsnode-start-byte n) ns))
              (not (= (tsnode-end-byte n) ne))))
          n]
        [else (loop (tsnode-parent n))]))))

;;;; ---------------------------------------------------------------------------
;;;; Operation-shaped helpers
;;;; ---------------------------------------------------------------------------

;;@doc
;; The highest ancestor of `node` that is still a direct child of its enclosing
;; form — i.e. the whole "element" a cursor sits inside, unwrapping reader macros
;; / quoting (so the cursor on `foo` inside `'foo` yields the whole `'foo`).
;; Climb while the parent is a non-form, non-root wrapper node; stop and return
;; the current node once its parent is a form or the document root.
(define (node-root lang node)
  (let loop ([n node])
    (let ([parent (tsnode-parent n)])
      (cond
        [(not parent) n] ; n is the document root itself
        [(form? lang parent) n] ; parent is a form => n is its element
        [(not (tsnode-parent parent)) n] ; parent is the document root => n is top-level
        [else (loop parent)]))))

;;@doc
;; The top-level form containing `node`: climb until the parent is the tree root.
;; Returns #f if `node` is the root.
(define (local-root node)
  (let loop ([n node])
    (let ([parent (tsnode-parent n)])
      (cond
        [(not parent) #f] ; n is the root
        [(not (tsnode-parent parent)) n] ; parent is the root => n is top-level
        [else (loop parent)]))))

;;@doc
;; The opening- and closing-delimiter char ranges of `form`, as
;; (cons open-range close-range) where each range is (cons start-char end-char),
;; or #f for a form with no children. The delimiters are the form's first and
;; last children (e.g. the "(" and ")" of a list_lit, which are anonymous
;; children flanking the named element children).
(define (get-form-edges rope form)
  (let ([children (tsnode-children form)])
    (if (null? children)
      #f
      (let ([open (car children)]
            [close (list-ref children (- (length children) 1))])
        (cons (node->char-range rope open)
          (node->char-range rope close))))))
