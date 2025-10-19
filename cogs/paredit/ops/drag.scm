;; ops/drag.scm — swap an element / form / pair with its neighbour.
;;
;;   (a b| c)  --drag-element-forward-->   (a c b|)
;;   (a b| c)  --drag-element-backward-->  (b| a c)
;;
;; Strategy: resolve the node to move (node-root for an element; node-root of the
;; nearest form for a form drag); find its sibling in the drag direction
;; (comment-skipping); swap their text via edit.scm `swap-ranges`. The cursor
;; follows the moved node, preserving its offset within that node.

(require "cogs/paredit/ts.scm")
(require "cogs/paredit/lang.scm")
(require "cogs/paredit/traversal.scm")
(require "cogs/paredit/edit.scm")
(require "cogs/paredit/pairs.scm")
(require "helix/misc.scm") ; set-status!, cursor-position

(provide drag-element-forward
  drag-element-backward
  drag-form-forward
  drag-form-backward
  drag-pair-forward
  drag-pair-backward)

;; Swap the char-span [cstart,cend) (the "current" span, where the cursor is)
;; with [sstart,send) (the sibling span), then move the cursor to follow the
;; current span to its new location, preserving the cursor's offset within it.
;; The two spans must not overlap.
(define (drag-swap-spans cstart cend sstart send)
  (let* ([rope (current-rope)]
         [ctext (char-range-text rope cstart cend)]
         [stext (char-range-text rope sstart send)]
         [clen (- cend cstart)]
         [slen (- send sstart)]
         [cursor (cursor-position)]
         ;; cursor offset within the moved span, clamped to stay on it
         [offset (let ([o (- cursor cstart)])
                  (cond
                    [(< o 0) 0]
                    [(>= o clen) (max 0 (- clen 1))]
                    [else o]))]
         ;; where the moved text ends up: dragging forward (sibling after),
         ;; everything before the sibling shifts by (slen - clen); dragging
         ;; backward it lands at the sibling's old start
         [new-start (if (> sstart cstart)
                     (+ sstart (- slen clen))
                     sstart)])
    (swap-ranges (cons cstart cend) ctext (cons sstart send) stext)
    (set-cursor-char (+ new-start offset))))

;; Swap two nodes' text, cursor following `current`.
(define (drag-swap current sibling)
  (let* ([rope (current-rope)]
         [cr (node->char-range rope current)]
         [sr (node->char-range rope sibling)])
    (drag-swap-spans (car cr) (cdr cr) (car sr) (cdr sr))))

;; Shared driver. `select-target` maps (lang node-at-cursor) -> the node to drag;
;; `sibling-fn` maps (lang node) -> the sibling to swap with (or #f).
(define (do-drag select-target sibling-fn)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [current (and node (select-target lang node))])
          (cond
            [(not current) (set-status! "paredit: nothing to drag")]
            [else
              (let ([sibling (sibling-fn lang current)])
                (if sibling
                  (drag-swap current sibling)
                  (set-status! "paredit: no sibling to drag past")))]))])))

;; The form to drag: the nearest enclosing form, unwrapped to its element root
;; (so a reader-macro-wrapped form drags as a whole), or #f.
(define (form-root lang node)
  (let ([f (find-nearest-form lang node)])
    (and f (node-root lang f))))

;; Swap the current element with the next sibling.
;;
;;   (a b| c)   =>   (a c b|)
;;@doc
;; Drag the current element forward
(define (drag-element-forward)
  (do-drag node-root next-sibling-skipping-comments))

;; Swap the current element with the previous sibling.
;;
;;   (a b| c)   =>   (b| a c)
;;@doc
;; Drag the current element backward
(define (drag-element-backward)
  (do-drag node-root prev-sibling-skipping-comments))

;; Swap the enclosing form with the next sibling.
;;
;;   ((a|) (b))   =>   ((b) (a|))
;;@doc
;; Drag the current form forward
(define (drag-form-forward)
  (do-drag form-root next-sibling-skipping-comments))

;; Swap the enclosing form with the previous sibling.
;;
;;   ((a) (b|))   =>   ((b|) (a))
;;@doc
;; Drag the current form backward
(define (drag-form-backward)
  (do-drag form-root prev-sibling-skipping-comments))

;; The char-span (cons start end) covering a whole pair chunk: from the first
;; node's start to the last node's end (so "key value" moves as a unit).
(define (chunk-span chunk)
  (let* ([rope (current-rope)]
         [first (car chunk)]
         [last (list-ref chunk (- (length chunk) 1))])
    (cons (node-start-char rope first)
      (node-end-char rope last))))

;; 0-based index of the chunk containing `target`, or #f.
(define (chunk-index-of target chunks)
  (let loop ([i 0] [xs chunks])
    (cond
      [(null? xs) #f]
      [(member target (car xs)) i]
      [else (loop (+ i 1) (cdr xs))])))

;; Drag the pair chunk containing `target` past its neighbour in `nodes`
;; (an ordered @pair list). `step` is +1 (forward) or -1 (backward).
(define (drag-pair-chunks target nodes step)
  (let* ([chunks (pair-chunks nodes)]
         [idx (chunk-index-of target chunks)]
         [other (and idx (+ idx step))])
    (cond
      [(not idx) (set-status! "paredit: pair not found")]
      [(or (< other 0) (>= other (length chunks)))
        (set-status! "paredit: no pair to drag past")]
      [else
        (let ([cur (list-ref chunks idx)]
              [oth (list-ref chunks other)])
          (if (or (not (= (length cur) 2)) (not (= (length oth) 2)))
            (set-status! "paredit: incomplete pair")
            (let ([cs (chunk-span cur)]
                  [os (chunk-span oth)])
              (drag-swap-spans (car cs) (cdr cs) (car os) (cdr os)))))])))

;; Shared driver for pair drags. `step`/`sibling-fn` give the direction; when the
;; cursor's element isn't part of a pairwise set we fall back to a plain element
;; drag (mirroring nvim-paredit's auto_drag_pairs behaviour).
(define (do-drag-pair step sibling-fn)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [target (and node (node-root lang node))])
          (cond
            [(not target) (set-status! "paredit: nothing to drag")]
            [else
              (let ([nodes (pairwise-nodes-for lang target)])
                (if nodes
                  (drag-pair-chunks target nodes step)
                  ;; not pairwise — behave like a plain element drag
                  (let ([sibling (sibling-fn lang target)])
                    (if sibling
                      (drag-swap target sibling)
                      (set-status! "paredit: no sibling to drag past")))))]))])))

;; Swap the current key/value pair with the next pair.
;;
;;   (let [a| 1 b 2])   =>   (let [b 2 a| 1])
;;@doc
;; Drag the current pair forward
(define (drag-pair-forward)
  (do-drag-pair 1 next-sibling-skipping-comments))

;; Swap the current key/value pair with the previous pair.
;;
;;   (let [a 1 b| 2])   =>   (let [b| 2 a 1])
;;@doc
;; Drag the current pair backward
(define (drag-pair-backward)
  (do-drag-pair -1 prev-sibling-skipping-comments))
