;; form.scm - Form-based motion commands
;;
;; Provides motions for navigating to form boundaries:
;;   (  - move to parent form start (opening delimiter)
;;   )  - move to parent form end (closing delimiter)
;;
;; These motions help navigate the structure of nested s-expressions.

(require "../core/parser.scm")
(require "../core/element.scm")
(require "../core/selection.scm")
(require "../core/range.scm")
(require "../core/rope-utils.scm")

(provide move-to-parent-form-start
         move-to-parent-form-end
         move-to-next-form-start
         move-to-prev-form-start)

;; ============================================================================
;; Parent Form Motions
;; ============================================================================

;;@doc
;; Move cursor to the opening delimiter of the parent form (motion: ()
(define (move-to-parent-form-start)
  "Move cursor to the opening delimiter of the parent form.

   Motion: (
   Example: (a (b |c))  =>  (a |(b c))"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (if (not form)
        #f

        (begin
          (move-cursor-to! (form-start form))
          #t))))

;;@doc
;; Move cursor to the closing delimiter of the parent form (motion: ))
(define (move-to-parent-form-end)
  "Move cursor to the closing delimiter of the parent form.

   Motion: )
   Example: (a (b |c))  =>  (a (b c)|)"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (if (not form)
        #f

        (begin
          (move-cursor-to! (form-end form))
          #t))))

;; ============================================================================
;; Sibling Form Motions
;; ============================================================================

;;@doc
;; Move cursor to the start of the next sibling form
(define (move-to-next-form-start)
  "Move cursor to the start of the next sibling form.

   Example: (a) |(b) (c)  =>  (a) (b) |(c)"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         ;; Skip forward to find next opening paren
         [search-pos (skip-whitespace-and-comments-forward rope (+ pos 1))])

    (if (>= search-pos (rope-len rope))
        #f

        (let loop ([i search-pos])
          (if (>= i (rope-len rope))
              #f

              (let ([ch (rope-char-at rope i)])
                (cond
                  ;; Found opening paren
                  [(is-open-paren? ch)
                   (move-cursor-to! i)
                   #t]

                  ;; Skip whitespace and continue
                  [(is-whitespace? ch) (loop (+ i 1))]

                  ;; Skip comments
                  [(equal? ch #\;) (loop (skip-whitespace-and-comments-forward rope i))]

                  ;; Found something else (closing paren, symbol, etc.)
                  ;; This means we're not at a form boundary
                  [else #f])))))))

;;@doc
;; Move cursor to the start of the previous sibling form
(define (move-to-prev-form-start)
  "Move cursor to the start of the previous sibling form.

   Example: (a) (b) |(c)  =>  (a) |(b) (c)"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         ;; Skip backward to find previous opening paren
         [search-pos (skip-whitespace-and-comments-backward rope (- pos 1))])

    (if (<= search-pos 0)
        #f

        ;; We're now at the last non-whitespace char before current position
        ;; If it's a closing paren, find its matching opening paren
        (let ([ch (rope-char-at rope search-pos)])
          (if (is-close-paren? ch)
              (let ([matching-open (find-matching-paren rope search-pos -1)])
                (if matching-open
                    (begin
                      (move-cursor-to! matching-open)
                      #t)
                    #f))
              #f)))))

;; ============================================================================
;; Top-Level Form Motions
;; ============================================================================

(define (move-to-top-level-form-start)
  "Move cursor to the start of the top-level form containing the cursor.

   Example: (a (b (c |d)))  =>  |(a (b (c d)))"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [top-form (find-top-level-form rope pos)])

    (if (not top-form)
        #f

        (begin
          (move-cursor-to! (form-start top-form))
          #t))))

(define (move-to-top-level-form-end)
  "Move cursor to the end of the top-level form containing the cursor.

   Example: (a (b (c |d)))  =>  (a (b (c d)))|"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [top-form (find-top-level-form rope pos)])

    (if (not top-form)
        #f

        (begin
          (move-cursor-to! (form-end top-form))
          #t))))
