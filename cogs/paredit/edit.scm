;; edit.scm — selection-first edit primitives.

(require "helix/static.scm") ; range, range->selection, set-current-selection-object!, replace-selection-with

(provide make-edit
  edit-start
  edit-end
  edit-text
  apply-edits
  swap-ranges
  set-cursor-char)

;;@doc
;; Construct an edit. `text` defaults to "" (a deletion).
(define (make-edit start end text)
  (list start end text))

(define (edit-start e) (list-ref e 0))
(define (edit-end e) (list-ref e 1))
(define (edit-text e) (list-ref e 2))

;;@doc
;; Apply a list of edits to the focused document. Edits are sorted DESCENDING by
;; start char-offset and applied one at a time, so the char offsets of
;; not-yet-applied edits remain valid throughout. Edits must not overlap.
(define (apply-edits edits)
  (let ([ordered (sort edits (lambda (a b) (> (edit-start a) (edit-start b))))])
    (for-each apply-one-edit ordered)))

;; Apply a single edit by selecting its range and replacing.
(define (apply-one-edit e)
  (set-current-selection-object!
    (range->selection (range (edit-start e) (edit-end e))))
  (replace-selection-with (edit-text e)))

;;@doc
;; Swap the text of two char-ranges. `r1` / `r2` are (cons start end); `t1` /
;; `t2` are their current texts. The text from each range is written into the
;; other. Ranges must not overlap.
(define (swap-ranges r1 t1 r2 t2)
  (apply-edits
    (list (make-edit (car r1) (cdr r1) t2)
      (make-edit (car r2) (cdr r2) t1))))

;;@doc
;; Place the primary cursor at char offset `char-pos` (a 1-width selection).
(define (set-cursor-char char-pos)
  (set-current-selection-object!
    (range->selection (range char-pos (+ char-pos 1)))))
