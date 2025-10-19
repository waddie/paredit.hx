;; range.scm - Position and range utilities
;;
;; This module provides abstractions for working with positions and ranges
;; in the text buffer.

(provide make-range
         range?
         range-start
         range-end
         range-contains?
         range-length
         range-valid?
         range-overlaps?
         range-merge
         make-form
         form?
         form-start
         form-end
         form-depth
         form-paren-type
         form-open-char
         form-close-char)

;; ============================================================================
;; Range Structure
;; ============================================================================

(struct Range (start end) #:transparent)

(define (make-range start end)
  "Create a range from start to end positions."
  (if (<= start end)
      (Range start end)
      (Range end start)))

(define (range? obj)
  "Check if object is a Range."
  (Range? obj))

(define (range-start range)
  "Get the start position of a range."
  (Range-start range))

(define (range-end range)
  "Get the end position of a range."
  (Range-end range))

(define (range-contains? range pos)
  "Check if position is within the range (inclusive)."
  (and (>= pos (range-start range)) (<= pos (range-end range))))

(define (range-length range)
  "Get the length of the range."
  (- (range-end range) (range-start range)))

(define (range-valid? range)
  "Check if range is valid (start <= end)."
  (<= (range-start range) (range-end range)))

(define (range-overlaps? range1 range2)
  "Check if two ranges overlap."
  (or (range-contains? range1 (range-start range2))
      (range-contains? range1 (range-end range2))
      (range-contains? range2 (range-start range1))
      (range-contains? range2 (range-end range1))))

(define (range-merge range1 range2)
  "Merge two ranges into one encompassing both."
  (make-range (min (range-start range1) (range-start range2))
              (max (range-end range1) (range-end range2))))

;; ============================================================================
;; Form Structure
;; ============================================================================
;; A Form is a Range with additional metadata about the s-expression

(struct Form (start end depth paren-type) #:transparent)

(define (make-form start end depth paren-type)
  "Create a Form structure representing an s-expression.

   Args:
     start: Position of opening paren
     end: Position of closing paren
     depth: Nesting depth (0 = top-level)
     paren-type: Symbol - 'round, 'square, or 'curly"
  (Form start end depth paren-type))

(define (form? obj)
  "Check if object is a Form."
  (Form? obj))

(define (form-start form)
  "Get the start position of a form (opening paren)."
  (Form-start form))

(define (form-end form)
  "Get the end position of a form (closing paren)."
  (Form-end form))

(define (form-depth form)
  "Get the nesting depth of a form."
  (Form-depth form))

(define (form-paren-type form)
  "Get the paren type of a form ('round, 'square, or 'curly)."
  (Form-paren-type form))

(define (form-open-char form)
  "Get the opening character for this form type."
  (case (form-paren-type form)
    [(round) #\(]
    [(square) #\[]
    [(curly) #\{]
    [else #f]))

(define (form-close-char form)
  "Get the closing character for this form type."
  (case (form-paren-type form)
    [(round) #\)]
    [(square) #\]]
    [(curly) #\}]
    [else #f]))
