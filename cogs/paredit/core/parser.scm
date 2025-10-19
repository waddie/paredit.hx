;; parser.scm - S-expression parsing engine
;;
;; This module provides the core parsing functionality for identifying
;; s-expressions without relying on tree-sitter. It uses character-by-character
;; traversal with depth tracking and context awareness.

(require "rope-utils.scm")
(require "range.scm")

(provide find-matching-paren
         find-enclosing-form
         find-form-boundaries
         scan-forward-to-boundary
         scan-backward-to-boundary
         find-top-level-form
         find-line-end
         in-string?
         in-comment?)

;; ============================================================================
;; Context Detection
;; ============================================================================

(define (is-line-comment-start? rope pos)
  "Check if position is the start of a line comment (;)."
  (let ([ch (rope-char-at rope pos)]) (equal? ch #\;)))

(define (find-line-end rope pos)
  "Find the end of the current line starting from pos."
  (let loop ([i pos])
    (let ([ch (rope-char-at rope i)])
      (cond
        [(not ch) i] ; End of file
        [(equal? ch #\newline) i]
        [else (loop (+ i 1))]))))

(define (is-char-literal? rope pos)
  "Check if position is inside a character literal (#\\x).
   Returns #t if the previous char is #\\ and the one before that is #."
  (and (>= pos 2)
       (let ([prev (rope-char-at rope (- pos 1))]
             [prev2 (rope-char-at rope (- pos 2))])
         (and (equal? prev #\\) (equal? prev2 #\#)))))

(define (skip-char-literal rope pos direction)
  "Skip over a character literal.
   For forward: if at #, skip to after the character
   For backward: if after character, skip to before #"
  (cond
    [(= direction 1)
     (let ([ch (rope-char-at rope pos)])
       (if (equal? ch #\#)
           (let ([next (rope-char-at rope (+ pos 1))])
             (if (equal? next #\\)
                 (+ pos 3) ; Skip #\x
                 (+ pos 1)))
           (+ pos 1)))]
    [else
     (if (is-char-literal? rope pos)
         (- pos 2) ; Skip back before #\
         (- pos 1))]))

(define (in-string? rope pos)
  "Check if position is inside a string by counting unescaped quotes before it."
  (let loop ([i 0]
             [in-str? #f]
             [escaped? #f])
    (cond
      [(>= i pos) in-str?]
      [(>= i (rope-len rope)) in-str?]
      [else
       (let ([ch (rope-char-at rope i)])
         (cond
           [escaped? (loop (+ i 1) in-str? #f)]
           [(equal? ch #\\) (loop (+ i 1) in-str? #t)]
           [(equal? ch #\") (loop (+ i 1) (not in-str?) #f)]
           [else (loop (+ i 1) in-str? #f)]))])))

(define (in-comment? rope pos)
  "Check if position is inside a line comment."
  (let loop ([i pos])
    (cond
      [(< i 0) #f]
      [else
       (let ([ch (rope-char-at rope i)])
         (cond
           [(equal? ch #\newline) #f] ; Found newline before comment
           [(equal? ch #\;) #t] ; Found comment start
           [else (loop (- i 1))]))])))

;; ============================================================================
;; Paren Matching
;; ============================================================================

(define (find-matching-paren rope pos direction)
  "Find the matching paren for the paren at pos.

   Args:
     rope: The text rope
     pos: Position of the paren to match
     direction: 1 for forward (find closing), -1 for backward (find opening)

   Returns: Position of matching paren, or #f if not found"

  (let ([start-char (rope-char-at rope pos)])
    (if (not (is-paren? start-char))
        #f
        (let ([target-char (matching-paren start-char)])
          (let loop ([i (+ pos direction)]
                     [depth 0]
                     [in-string? #f]
                     [escaped? #f])
            (let ([ch (rope-char-at rope i)])
              (cond
                ;; Out of bounds
                [(not ch) #f]

                ;; Handle escape sequences
                [escaped? (loop (+ i direction) depth in-string? #f)]
                [(and (equal? ch #\\) (not in-string?))
                 ;; Check for character literal
                 (if (and (= direction 1) (= i (+ pos 1)) (equal? start-char #\#))
                     #f ; This is a char literal, not a form
                     (loop (+ i direction) depth in-string? #t))]

                ;; Handle strings
                [(equal? ch #\") (loop (+ i direction) depth (not in-string?) #f)]

                ;; Inside string - ignore parens
                [in-string? (loop (+ i direction) depth in-string? #f)]

                ;; Handle line comments
                [(and (equal? ch #\;) (not in-string?))
                 (if (= direction 1)
                     (loop (find-line-end rope i) depth in-string? #f)
                     ;; Going backward, just skip this char
                     (loop (+ i direction) depth in-string? #f))]

                ;; Found a matching character at depth 0
                [(and (equal? ch target-char) (= depth 0)) i]

                ;; Found target char at deeper depth
                [(equal? ch target-char) (loop (+ i direction) (- depth 1) in-string? #f)]

                ;; Found same char as start - increase depth
                [(equal? ch start-char) (loop (+ i direction) (+ depth 1) in-string? #f)]

                ;; Regular character
                [else (loop (+ i direction) depth in-string? #f)])))))))

;; ============================================================================
;; Form Finding
;; ============================================================================

(define (find-enclosing-form rope pos)
  "Find the form that encloses the given position.

   Returns: A Form structure or #f if not found"

  (let loop ([i (- pos 1)]
             [depth 0]
             [in-string? #f])
    (cond
      [(< i 0) #f] ; Reached start of file
      [else
       (let ([ch (rope-char-at rope i)])
         (cond
           ;; Handle strings (backward)
           [(equal? ch #\")
            (let ([escaped? (and (> i 0) (equal? (rope-char-at rope (- i 1)) #\\))])
              (if escaped?
                  (loop (- i 1) depth in-string?)
                  (loop (- i 1) depth (not in-string?))))]

           ;; Inside string - keep going
           [in-string? (loop (- i 1) depth in-string?)]

           ;; Found opening paren at depth 0
           [(and (is-open-paren? ch) (= depth 0))
            (let* ([close-pos (find-matching-paren rope i 1)]
                   [ptype (cond
                            [(equal? ch #\() 'round]
                            [(equal? ch #\[) 'square]
                            [(equal? ch #\{) 'curly]
                            [else 'unknown])])
              (if close-pos
                  (make-form i close-pos 0 ptype)
                  #f))]

           ;; Found opening paren at deeper depth
           [(is-open-paren? ch) (loop (- i 1) (- depth 1) in-string?)]

           ;; Found closing paren - increase depth
           [(is-close-paren? ch) (loop (- i 1) (+ depth 1) in-string?)]

           ;; Regular character
           [else (loop (- i 1) depth in-string?)]))])))

(define (find-form-boundaries rope start-pos)
  "Given a position on an opening paren, find the form boundaries.

   Returns: A Form structure or #f"
  (let ([ch (rope-char-at rope start-pos)])
    (if (is-open-paren? ch)
        (let ([close-pos (find-matching-paren rope start-pos 1)])
          (if close-pos
              (let ([ptype (cond
                             [(equal? ch #\() 'round]
                             [(equal? ch #\[) 'square]
                             [(equal? ch #\{) 'curly]
                             [else 'unknown])])
                (make-form start-pos close-pos 0 ptype))
              #f))
        #f)))

;; ============================================================================
;; Boundary Scanning
;; ============================================================================

(define (scan-forward-to-boundary rope pos #:stop-at-paren? [stop-at-paren? #t])
  "Scan forward to the next element boundary.

   Boundaries are:
   - Whitespace
   - Opening/closing parens (if stop-at-paren? is #t)
   - End of file

   Returns: Position of boundary or #f"

  (let loop ([i pos]
             [in-string? #f]
             [escaped? #f])
    (let ([ch (rope-char-at rope i)])
      (cond
        [(not ch) i] ; End of file
        [escaped? (loop (+ i 1) in-string? #f)]
        [(equal? ch #\\) (loop (+ i 1) in-string? #t)]
        [(equal? ch #\") (loop (+ i 1) (not in-string?) #f)]
        [in-string? (loop (+ i 1) in-string? #f)]
        [(is-whitespace? ch) i]
        [(and stop-at-paren? (is-paren? ch)) i]
        [(equal? ch #\;) i] ; Comment is a boundary
        [else (loop (+ i 1) in-string? #f)]))))

(define (scan-backward-to-boundary rope pos #:stop-at-paren? [stop-at-paren? #t])
  "Scan backward to the previous element boundary.

   Returns: Position of boundary or #f"

  (let loop ([i pos]
             [depth 0])
    (cond
      [(< i 0) 0] ; Start of file
      [else
       (let ([ch (rope-char-at rope i)])
         (cond
           [(in-string? rope i) (loop (- i 1) depth)]
           [(in-comment? rope i) (loop (- i 1) depth)]
           [(is-whitespace? ch) i]
           [(and stop-at-paren? (is-paren? ch)) i]
           [else (loop (- i 1) depth)]))])))

;; ============================================================================
;; Top-Level Form Finding
;; ============================================================================

(define (find-top-level-form rope pos)
  "Find the top-level form containing the given position.

   Returns: A Form structure representing the top-level form, or #f"

  (let loop ([current-pos pos]
             [last-form #f])
    (let ([form (find-enclosing-form rope current-pos)])
      (if form
          ;; Found a form, check if there's one enclosing it
          (loop (form-start form) form)
          ;; No more enclosing forms, return the last one found
          last-form))))
