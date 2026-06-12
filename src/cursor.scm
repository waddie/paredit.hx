;; cursor.scm — cursor placement policy after an operation.
;;
;; Three modes (config.scm `cursor-behaviour`):
;;   remain : keep the cursor at its original absolute char position
;;   follow : move the cursor to track the delimiter that moved (the "edge")
;;   auto   : keep it in place unless the moved edge swept past it (leaving it
;;            outside the form), in which case snap it to the edge

(require "edit.scm")
(require "config.scm")

(provide reposition-cursor)

;;@doc
;; Place the cursor after a slurp/barf according to the active cursor-behaviour.
;; * original-char : where the cursor was before the edit
;; * edge-char     : the moved delimiter's new char position ('follow target)
;; * reversed?     : #t for a backward (leftward edge) operation, #f for forward
;; (porting nvim-paredit's position_cursor_according_to_edge)
(define (reposition-cursor original-char edge-char reversed?)
  (let ([mode (cursor-behaviour)])
    (cond
      [(equal? mode 'follow) (set-cursor-char edge-char)]
      [(equal? mode 'auto)
        (let ([out-of-bounds (if reversed?
                              (< original-char edge-char)
                              (> original-char edge-char))])
          (set-cursor-char (if out-of-bounds edge-char original-char)))]
      ;; 'remain (and any unexpected value) keeps the original position
      [else (set-cursor-char original-char)])))
