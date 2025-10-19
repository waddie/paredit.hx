;; selections.scm - Text object selections for paredit
;;
;; Provides text objects that can be used with Helix verbs (d, c, y, v, etc.):
;;   af - select around form (including delimiters)
;;   if - select in form (excluding delimiters)
;;   ae - select around element
;;   ie - select element (same as ae for consistency)
;;
;; Examples:
;;   af on "(a |b c)"  =>  selects "(a b c)"
;;   if on "(a |b c)"  =>  selects "a b c"
;;   ae on "fo|o bar"  =>  selects "foo"

(require "../core/parser.scm")
(require "../core/element.scm")
(require "../core/selection.scm")
(require "../core/range.scm")
(require "../core/rope-utils.scm")

(provide select-around-form
         select-in-form
         select-around-element
         select-element)

;; ============================================================================
;; Form Text Objects
;; ============================================================================

;;@doc
;; Select the enclosing form including its delimiters (text object: af)
(define (select-around-form)
  "Select the enclosing form including its delimiters.

   Text object: af
   Example: (a |b c)  =>  selects |(a b c)|"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (if (not form)
        #f

        (let* ([start (form-start form)]
               [end (+ (form-end form) 1)] ; Include closing delimiter
               [range (make-range start end)])

          ;; Set the selection
          (set-selection! range)
          #t))))

;;@doc
;; Select the contents of the enclosing form excluding its delimiters (text object: if)
(define (select-in-form)
  "Select the contents of the enclosing form excluding its delimiters.

   Text object: if
   Example: (a |b c)  =>  selects (|a b c|)"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (if (not form)
        #f

        (let* ([start (+ (form-start form) 1)] ; Skip opening delimiter
               [end (form-end form)] ; Before closing delimiter
               [range (make-range start end)])

          ;; Handle empty forms
          (if (>= start end)
              #f
              (begin
                ;; Set the selection
                (set-selection! range)
                #t))))))

;; ============================================================================
;; Element Text Objects
;; ============================================================================

;;@doc
;; Select the current element (text object: ae)
(define (select-around-element)
  "Select the current element.

   Text object: ae
   Example: fo|o bar  =>  selects |foo|"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [elem (find-current-element rope pos)])

    (if (not elem)
        #f

        (begin
          ;; Set the selection
          (set-selection! elem)
          #t))))

;;@doc
;; Select the current element (text object: ie, same as ae)
(define (select-element)
  "Select the current element (alias for select-around-element).

   Text object: ie
   Example: fo|o bar  =>  selects |foo|

   Note: In paredit, there's no meaningful distinction between 'around element'
   and 'in element', so both ae and ie select the same thing."

  (select-around-element))

;; ============================================================================
;; Extended Selection Helpers
;; ============================================================================

(define (expand-selection-to-next-form)
  "Expand selection to include the next sibling form.
   Useful for selecting multiple forms."
  (let* ([rope (get-current-rope)]
         [current-range (get-selection-range)])

    (if (not current-range)
        (select-around-form)

        (let* ([end-pos (range-end current-range)]
               [next-pos (skip-whitespace-and-comments-forward rope end-pos)]
               [ch (rope-char-at rope next-pos)])

          (if (is-open-paren? ch)
              (let ([next-form (find-form-boundaries rope next-pos)])
                (if next-form
                    (let* ([new-end (+ (form-end next-form) 1)]
                           [new-range (make-range (range-start current-range) new-end)])
                      (set-selection! new-range)
                      #t)
                    #f))
              #f)))))

(define (shrink-selection-to-inner-form)
  "Shrink selection from 'around form' to 'in form'."
  (let* ([rope (get-current-rope)]
         [current-range (get-selection-range)])

    (if (not current-range)
        #f

        (let* ([start (range-start current-range)]
               [end (range-end current-range)]
               [start-ch (rope-char-at rope start)]
               [end-ch (rope-char-at rope (- end 1))])

          ;; Check if current selection is around a form
          (if (and (is-open-paren? start-ch) (is-close-paren? end-ch))
              (let ([new-range (make-range (+ start 1) (- end 1))])
                (set-selection! new-range)
                #t)
              #f)))))
