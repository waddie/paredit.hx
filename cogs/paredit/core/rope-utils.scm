;; rope-utils.scm - Rope operation wrappers and character utilities
;;
;; This module provides a clean API for working with Helix's Rope data structure
;; and common character classification functions.

(require-builtin helix/core/text as text.)

(provide rope-char-at
         rope-substring
         rope-line-at
         rope-len
         rope-line-count
         is-whitespace?
         is-paren?
         is-open-paren?
         is-close-paren?
         matching-paren
         paren-type)

;; ============================================================================
;; Rope Operations
;; ============================================================================

(define (rope-char-at rope pos)
  "Get character at position in rope. Returns character or #f if out of bounds."
  (if (and (>= pos 0) (< pos (text.rope-len-chars rope)))
      (text.rope-char-ref rope pos)
      #f))

(define (rope-substring rope start end)
  "Extract substring from rope between start and end positions."
  (if (and (>= start 0) (<= end (text.rope-len-chars rope)) (<= start end))
      (text.rope->slice rope start end)
      ""))

(define (rope-line-at rope line-num)
  "Get the text of a specific line number (0-indexed)."
  (if (and (>= line-num 0) (< line-num (text.rope-len-lines rope)))
      (text.rope->line rope line-num)
      ""))

(define (rope-len rope)
  "Get the length of the rope in characters."
  (text.rope-len-chars rope))

(define (rope-line-count rope)
  "Get the number of lines in the rope."
  (text.rope-len-lines rope))

;; ============================================================================
;; Character Classification
;; ============================================================================

(define (is-whitespace? ch)
  "Check if character is whitespace."
  (and ch (or (equal? ch #\space) (equal? ch #\tab) (equal? ch #\newline) (equal? ch #\return))))

(define (is-paren? ch)
  "Check if character is any kind of parenthesis/bracket/brace."
  (and ch
       (or (equal? ch #\()
           (equal? ch #\))
           (equal? ch #\[)
           (equal? ch #\])
           (equal? ch #\{)
           (equal? ch #\}))))

(define (is-open-paren? ch)
  "Check if character is an opening parenthesis/bracket/brace."
  (and ch (or (equal? ch #\() (equal? ch #\[) (equal? ch #\{))))

(define (is-close-paren? ch)
  "Check if character is a closing parenthesis/bracket/brace."
  (and ch (or (equal? ch #\)) (equal? ch #\]) (equal? ch #\}))))

;; ============================================================================
;; Paren Matching
;; ============================================================================

;; Mapping of opening parens to their closing counterparts
(define paren-pairs (hash #\( #\) #\[ #\] #\{ #\}))

;; Mapping of closing parens to their opening counterparts
(define reverse-paren-pairs (hash #\) #\( #\] #\[ #\} #\{))

(define (matching-paren ch)
  "Get the matching paren for a given paren character.
   Returns the closing paren for opening, or opening for closing."
  (cond
    [(is-open-paren? ch) (hash-ref paren-pairs ch)]
    [(is-close-paren? ch) (hash-ref reverse-paren-pairs ch)]
    [else #f]))

(define (paren-type open close)
  "Check if open and close parens match. Returns the paren type or #f."
  (cond
    [(and (equal? open #\() (equal? close #\))) 'round]
    [(and (equal? open #\[) (equal? close #\])) 'square]
    [(and (equal? open #\{) (equal? close #\})) 'curly]
    [else #f]))
