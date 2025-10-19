;; element.scm - Element boundary detection
;;
;; This module provides functions for identifying and working with "elements",
;; which are atomic units in an s-expression (symbols, numbers, strings, forms).

(require "rope-utils.scm")
(require "range.scm")
(require "parser.scm")

(provide find-current-element
         find-next-element
         find-prev-element
         element-at-pos
         skip-whitespace-forward
         skip-whitespace-backward
         skip-whitespace-and-comments-forward
         skip-whitespace-and-comments-backward)

;; ============================================================================
;; Whitespace and Comment Skipping
;; ============================================================================

(define (skip-whitespace-forward rope pos)
  "Skip forward over whitespace characters.
   Returns: First non-whitespace position or end of rope"
  (let loop ([i pos])
    (let ([ch (rope-char-at rope i)])
      (cond
        [(not ch) i] ; End of rope
        [(is-whitespace? ch) (loop (+ i 1))]
        [else i]))))

(define (skip-whitespace-backward rope pos)
  "Skip backward over whitespace characters.
   Returns: First non-whitespace position or start of rope"
  (let loop ([i pos])
    (cond
      [(< i 0) 0]
      [else
       (let ([ch (rope-char-at rope i)])
         (if (is-whitespace? ch)
             (loop (- i 1))
             i))])))

(define (skip-whitespace-and-comments-forward rope pos)
  "Skip forward over whitespace and line comments.
   Returns: First non-whitespace, non-comment position"
  (let loop ([i pos])
    (let ([ch (rope-char-at rope i)])
      (cond
        [(not ch) i] ; End of rope
        [(is-whitespace? ch) (loop (+ i 1))]
        ;; Skip to end of line
        [(equal? ch #\;) (loop (skip-whitespace-forward rope (find-line-end rope i)))]
        [else i]))))

(define (skip-whitespace-and-comments-backward rope pos)
  "Skip backward over whitespace and line comments.
   Returns: First non-whitespace, non-comment position"
  (let loop ([i pos])
    (cond
      [(< i 0) 0]
      [else
       (let ([ch (rope-char-at rope i)])
         (cond
           [(is-whitespace? ch) (loop (- i 1))]
           [(in-comment? rope i)
            ;; Find the start of the comment (the semicolon)
            (let inner-loop ([j i])
              (cond
                [(< j 0) 0]
                ;; Found comment start, skip whitespace before it
                [(equal? (rope-char-at rope j) #\;) (loop (skip-whitespace-backward rope (- j 1)))]
                [else (inner-loop (- j 1))]))]
           [else i]))])))

;; ============================================================================
;; Element Detection
;; ============================================================================

(define (find-element-start rope pos)
  "Find the start of the element at or before pos.
   Scans backward to find the beginning of the current symbol/form/string."
  (cond
    ;; If we're at a paren, it's a form
    [(is-paren? (rope-char-at rope pos)) pos]

    ;; Otherwise scan backward to find element start
    [else
     (let loop ([i pos])
       (cond
         [(< i 0) 0]
         [else
          (let ([ch (rope-char-at rope i)])
            (cond
              ;; Hit a boundary
              [(is-whitespace? ch) (+ i 1)]
              [(is-paren? ch) (+ i 1)]
              [(equal? ch #\;) (+ i 1)]

              ;; In a string - find the opening quote
              [(and (equal? ch #\") (not (in-string? rope (- i 1)))) i]

              ;; Keep scanning
              [(= i 0) 0] ; Start of file
              [else (loop (- i 1))]))]))]))

(define (find-element-end rope pos)
  "Find the end of the element at or after pos.
   Scans forward to find the end of the current symbol/form/string."
  (let ([ch (rope-char-at rope pos)])
    (cond
      ;; If at opening paren, find matching closing paren
      [(is-open-paren? ch)
       (let ([close (find-matching-paren rope pos 1)])
         (if close
             (+ close 1)
             pos))]

      ;; If at closing paren, just this position
      [(is-close-paren? ch) (+ pos 1)]

      ;; If in a string, find the closing quote
      [(equal? ch #\")
       (let loop ([i (+ pos 1)]
                  [escaped? #f])
         (let ([c (rope-char-at rope i)])
           (cond
             [(not c) i]
             [escaped? (loop (+ i 1) #f)]
             [(equal? c #\\) (loop (+ i 1) #t)]
             [(equal? c #\") (+ i 1)]
             [else (loop (+ i 1) #f)])))]

      ;; Otherwise scan forward to boundary
      [else
       (let loop ([i pos])
         (let ([c (rope-char-at rope i)])
           (cond
             [(not c) i] ; End of file
             [(is-whitespace? c) i]
             [(is-paren? c) i]
             [(equal? c #\;) i]
             [else (loop (+ i 1))])))])))

(define (find-current-element rope pos)
  "Find the element at the current position.
   Returns: Range of the element or #f if at whitespace/comment"
  (let* ([ch (rope-char-at rope pos)]
         [adjusted-pos (if (is-whitespace? ch)
                           (skip-whitespace-forward rope pos)
                           pos)])
    (if (>= adjusted-pos (rope-len rope))
        #f
        (let* ([start (find-element-start rope adjusted-pos)]
               [end (find-element-end rope start)])
          (if (and start end (< start end))
              (make-range start end)
              #f)))))

(define (find-next-element rope pos)
  "Find the next element after pos.
   Returns: Range of the next element or #f if none found"
  (let* ([current (find-current-element rope pos)])
    (if current
        (let* ([after-current (range-end current)]
               [next-pos (skip-whitespace-and-comments-forward rope after-current)])
          (if (>= next-pos (rope-len rope))
              #f
              (find-current-element rope next-pos)))
        ;; Not on an element, skip forward to next
        (let ([next-pos (skip-whitespace-and-comments-forward rope pos)])
          (if (>= next-pos (rope-len rope))
              #f
              (find-current-element rope next-pos))))))

(define (find-prev-element rope pos)
  "Find the previous element before pos.
   Returns: Range of the previous element or #f if none found"
  (let* ([start-search (skip-whitespace-and-comments-backward rope (- pos 1))])
    (if (<= start-search 0)
        #f
        (let* ([elem-end start-search]
               [elem-start (find-element-start rope elem-end)])
          (if (and elem-start elem-end (< elem-start elem-end))
              (make-range elem-start (+ elem-end 1))
              #f)))))

(define (element-at-pos rope pos)
  "Get the element at the given position. Alias for find-current-element."
  (find-current-element rope pos))
