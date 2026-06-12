;; ops/unwrap.scm — splice: remove the enclosing form's delimiters, keeping its
;; contents.
;;
;;   (a (b| c) d)  --splice-->  (a b| c d)
;;
;; Strategy: find the nearest form; get its opening and closing delimiter ranges
;; via get-form-edges; delete both (two edits, applied descending so offsets
;; stay valid). The cursor shifts left by the opening delimiter's width.

(require "../ts.scm")
(require "../lang.scm")
(require "../traversal.scm")
(require "../edit.scm")
(require "helix/misc.scm") ; set-status!, cursor-position

(provide splice-form)

;; Remove the delimiters of the enclosing form, splicing its contents into
;; the parent.
;;
;;   (a (b| c) d)   =>   (a b| c d)
;;@doc
;; Splice the enclosing form, removing its delimiters
(define (splice-form)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [form (and node (find-nearest-form lang node))])
          (cond
            [(not form) (set-status! "paredit: cursor not inside a form")]
            [else
              (let* ([rope (current-rope)]
                     [edges (get-form-edges rope form)])
                (cond
                  [(not edges) (set-status! "paredit: form has no delimiters")]
                  [else
                    (let* ([open-range (car edges)]
                           [close-range (cdr edges)]
                           [open-start (car open-range)]
                           [open-end (cdr open-range)]
                           [open-len (- open-end open-start)]
                           [cursor (cursor-position)])
                      (apply-edits
                        (list (make-edit (car close-range) (cdr close-range) "")
                          (make-edit open-start open-end "")))
                      ;; the cursor is inside the form, hence after the opening
                      ;; delimiter, so it shifts left by the delimiter's width
                      (set-cursor-char (if (>= cursor open-end)
                                        (- cursor open-len)
                                        cursor)))]))]))])))
