;; ops/slurp.scm — slurp the next/prev sibling into the enclosing form.
;;
;;   (a| b) c   --slurp-forward-->   (a| b c)
;;   a (b| c)   --slurp-backward-->  (a b| c)
;;
;; Strategy: find the nearest form; find the form node's next/prev sibling
;; (comment-skipping); take the form's closing/opening delimiter range via
;; get-form-edges; emit two edits — delete the delimiter at its current position
;; and reinsert it just past/before the sibling. Then reposition the cursor.

(require "../ts.scm")
(require "../lang.scm")
(require "../traversal.scm")
(require "../edit.scm")
(require "../cursor.scm")
(require "helix/misc.scm") ; set-status!, cursor-position

(provide slurp-forward
  slurp-backward)

;; Extend the enclosing form rightward over the following element.
;;
;;   (foo| bar) baz   =>   (foo| bar baz)
;;
;; Move the enclosing form's closing delimiter to just after the form's next
;; sibling. Expressed as a SINGLE contiguous span-replace over
;; [close-delim-start, target-end): drop the leading closing delimiter and
;; re-append it after the slurped text. (A point-insert is avoided on purpose —
;; Helix expands a zero-width selection to the next grapheme, so replacing it
;; overwrites rather than inserts; see edit.scm.) Net document length is
;; unchanged and the cursor sits left of the span, so its position is restored.
;;@doc
;; Slurp the next element into the current form
(define (slurp-forward)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (cond
            [(not form) (set-status! "paredit: cursor not inside a form")]
            [else
              (let ([target (next-sibling-skipping-comments lang form)])
                (cond
                  [(not target) (set-status! "paredit: nothing to slurp")]
                  [else
                    (let* ([rope (current-rope)]
                           [edges (get-form-edges rope form)])
                      (if (not edges)
                        (set-status! "paredit: form has no delimiters")
                        (slurp-forward-edit lang rope form target edges)))]))]))])))

;; Emit the slurp-forward edit once the form, target, and edges are resolved.
(define (slurp-forward-edit lang rope form target edges)
  (let* ([close-range (cdr edges)]
         [close-start (car close-range)]
         [close-end (cdr close-range)]
         [close-text (char-range-text rope close-start close-end)]
         [target-end (node-end-char rope target)]
         ;; text between the old delimiter and the slurped element's end
         [middle-text (char-range-text rope close-end target-end)]
         ;; an empty form has no element to separate from, so the
         ;; old form/element gap shouldn't become leading space
         [middle (if (null? (children-skipping-comments lang form))
                  (trim-leading-ws lang middle-text)
                  middle-text)]
         [cursor (cursor-position)]
         ;; the closing delimiter is re-appended after `middle`,
         ;; so its new start is close-start + (length of middle)
         [edge-char (+ close-start (string-length middle))])
    (apply-edits
      (list (make-edit close-start target-end
             (string-append middle close-text))))
    (reposition-cursor cursor edge-char #f)))

;; Extend the enclosing form leftward over the preceding element.
;;
;;   foo (bar| baz)   =>   (foo bar| baz)
;;
;; Mirror of slurp-forward: move the opening delimiter to just before the form's
;; previous sibling, as a single span-replace over [prev-sibling-start, open-end).
;;@doc
;; Slurp the previous element into the current form
(define (slurp-backward)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (cond
            [(not form) (set-status! "paredit: cursor not inside a form")]
            [else
              (let ([target (prev-sibling-skipping-comments lang form)])
                (cond
                  [(not target) (set-status! "paredit: nothing to slurp")]
                  [else
                    (let* ([rope (current-rope)]
                           [edges (get-form-edges rope form)])
                      (if (not edges)
                        (set-status! "paredit: form has no delimiters")
                        (slurp-backward-edit lang rope form target edges)))]))]))])))

;; Emit the slurp-backward edit once the form, target, and edges are resolved.
(define (slurp-backward-edit lang rope form target edges)
  (let* ([open-range (car edges)]
         [open-start (car open-range)]
         [open-end (cdr open-range)]
         [open-text (char-range-text rope open-start open-end)]
         [target-start (node-start-char rope target)]
         ;; text between the preceding element's start and the old delimiter
         [middle-text (char-range-text rope target-start open-start)]
         ;; an empty form has no element to separate from, so the
         ;; old form/element gap shouldn't become trailing space
         [middle (if (null? (children-skipping-comments lang form))
                  (trim-trailing-ws lang middle-text)
                  middle-text)]
         [cursor (cursor-position)]
         ;; the opening delimiter is re-prepended at target-start
         [edge-char target-start])
    (apply-edits
      (list (make-edit target-start open-end
             (string-append open-text middle))))
    (reposition-cursor cursor edge-char #t)))
