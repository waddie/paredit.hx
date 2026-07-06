;; ops/raise.scm — replace the enclosing form with the current form/element.
;;
;;   (a (b| c) d)  --raise-form-->     (b| c)       [nearest form = (b c)]
;;   (a (b| c) d)  --raise-element-->  (a b| d)      [element = b]
;;
;; Strategy: take the target node (the current form, or the element the cursor
;; sits in); read its text via node-text; replace the ENCLOSING form's full
;; range with that text as a single span-replace; place the cursor at the
;; enclosing form's old start.

(require "ts-utils.hx/ts.scm")
(require "../lang.scm")
(require "../traversal.scm")
(require "../edit.scm")
(require "helix/misc.scm") ; set-status!

(provide raise-form
  raise-element)

;; Replace `target`'s enclosing form with `target`'s text. Shared by both
;; raise-form and raise-element; they differ only in how `target` is chosen.
(define (do-raise lang target)
  (let ([enclosing (find-enclosing-form lang target)])
    (cond
      [(not enclosing) (set-status! "paredit: no enclosing form to raise into")]
      [else
        (let* ([rope (current-rope)]
               [text (node-text rope target)]
               [enc-range (node->char-range rope enclosing)]
               [start (car enc-range)]
               [end (cdr enc-range)])
          (apply-edits (list (make-edit start end text)))
          (set-cursor-char start))])))

;; Replace the enclosing form with the current (nearest) form.
;;
;;   (a (b| c) d)   =>   (b| c)
;;@doc
;; Raise the current form into its parent
(define (raise-form)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (if form
            (do-raise lang form)
            (set-status! "paredit: cursor not inside a form")))])))

;; Replace the enclosing form with the current element.
;;
;;   (a (b| c) d)   =>   (a b| d)
;;@doc
;; Raise the current element into the enclosing form
(define (raise-element)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let ([node (node-at-cursor)])
          (if node
            (do-raise lang (node-root lang node))
            (set-status! "paredit: no element at cursor")))])))
