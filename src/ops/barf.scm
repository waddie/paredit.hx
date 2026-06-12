;; ops/barf.scm — eject the last/first child out of the enclosing form.
;;
;;   (a| b c)   --barf-forward-->   (a| b) c
;;   (a b| c)   --barf-backward-->  a (b| c)
;;
;; Strategy: find the nearest form; find its last/first named child ignoring
;; comments; move the form's closing/opening delimiter to just inside that
;; child's boundary (two edits). Then reposition the cursor.

(require "../ts.scm")
(require "../lang.scm")
(require "../traversal.scm")
(require "../edit.scm")
(require "../cursor.scm")
(require "helix/misc.scm") ; set-status!, cursor-position

(provide barf-forward
  barf-backward)

;; Last element of a non-empty list.
(define (last-of xs)
  (list-ref xs (- (length xs) 1)))

;; ws-char? is provided by lang.scm.
(define (starts-with-ws? lang s)
  (and (> (string-length s) 0) (ws-char? lang (string-ref s 0))))

(define (ends-with-ws? lang s)
  (and (> (string-length s) 0)
    (ws-char? lang (string-ref s (- (string-length s) 1)))))

;; Shrink the enclosing form, ejecting its last element to the right.
;;
;;   (foo| bar baz)   =>   (foo| bar) baz
;;
;; Move the closing delimiter to just after the second-to-last element (or just
;; after the opening delimiter if there is only one element), as a single
;; span-replace over [anchor, close-end).
;;@doc
;; Barf the last element out of the current form
(define (barf-forward)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (cond
            [(not form) (set-status! "paredit: cursor not inside a form")]
            [else
              (let ([children (children-skipping-comments lang form)])
                (cond
                  [(null? children) (set-status! "paredit: nothing to barf")]
                  [else
                    (let* ([rope (current-rope)]
                           [edges (get-form-edges rope form)]
                           [open-end (cdr (car edges))]
                           [close-range (cdr edges)]
                           [close-start (car close-range)]
                           [close-end (cdr close-range)]
                           [close-text (char-range-text rope close-start close-end)]
                           [last-child (last-of children)]
                           [prev (prev-sibling-skipping-comments lang last-child)]
                           ;; where the closing delimiter lands: after the previous
                           ;; element, or right after the opening delimiter
                           [anchor (if prev (node-end-char rope prev) open-end)]
                           [middle-text (char-range-text rope anchor close-start)]
                           ;; ensure the ejected element is separated from the delimiter
                           [sep (if (starts-with-ws? lang middle-text) "" " ")]
                           [cursor (cursor-position)]
                           ;; the closing delimiter is re-written first at `anchor`,
                           ;; so that is its new position
                           [edge-char anchor])
                      (apply-edits
                        (list (make-edit anchor close-end
                               (string-append close-text sep middle-text))))
                      (reposition-cursor cursor edge-char #f))]))]))])))

;; Shrink the enclosing form, ejecting its first element to the left.
;;
;;   (foo bar| baz)   =>   foo (bar| baz)
;;
;; Mirror of barf-forward: move the opening delimiter to just before the second
;; element (or just before the closing delimiter if there is only one element),
;; as a single span-replace over [open-start, anchor).
;;@doc
;; Barf the first element out of the current form
(define (barf-backward)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (cond
            [(not form) (set-status! "paredit: cursor not inside a form")]
            [else
              (let ([children (children-skipping-comments lang form)])
                (cond
                  [(null? children) (set-status! "paredit: nothing to barf")]
                  [else
                    (let* ([rope (current-rope)]
                           [edges (get-form-edges rope form)]
                           [open-range (car edges)]
                           [open-start (car open-range)]
                           [open-end (cdr open-range)]
                           [open-text (char-range-text rope open-start open-end)]
                           [close-start (car (cdr edges))]
                           [first-child (car children)]
                           [next (next-sibling-skipping-comments lang first-child)]
                           ;; where the opening delimiter lands: before the second
                           ;; element, or right before the closing delimiter
                           [anchor (if next (node-start-char rope next) close-start)]
                           [middle-text (char-range-text rope open-end anchor)]
                           ;; ensure the ejected element is separated from the delimiter
                           [sep (if (ends-with-ws? lang middle-text) "" " ")]
                           [cursor (cursor-position)]
                           ;; the opening delimiter is re-written after middle-text
                           ;; and the separator, so its new start sits past both
                           [edge-char (+ open-start
                                       (string-length middle-text)
                                       (string-length sep))])
                      (apply-edits
                        (list (make-edit open-start anchor
                               (string-append middle-text sep open-text))))
                      (reposition-cursor cursor edge-char #t))]))]))])))
