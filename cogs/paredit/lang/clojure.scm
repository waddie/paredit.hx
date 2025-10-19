;; clojure.scm - Clojure-specific parsing rules
;;
;; This module provides Clojure-specific functionality for handling
;; reader macros, dispatch macros, and other Clojure-specific syntax.

(require "../core/rope-utils.scm")

(provide is-reader-macro?
         is-dispatch-macro?
         is-discard-macro?
         is-clojure-comment-form?
         skip-reader-macro
         clojure-reader-macros
         clojure-dispatch-macros)

;; ============================================================================
;; Clojure Reader Macros
;; ============================================================================

;; Map of Clojure reader macro characters to their meaning
(define clojure-reader-macros
  (hash #\@ 'deref #\' 'quote #\` 'syntax-quote #\~ 'unquote #\^ 'meta #\# 'dispatch))

;; Map of Clojure dispatch macro characters (after #) to their meaning
(define clojure-dispatch-macros
  (hash #\(
        'lambda ; #(...)
        #\{
        'set ; #{...}
        #\_
        'discard ; #_
        #\"
        'regex ; #"..."
        #\'
        'var ; #'
        #\^
        'meta ; #^
        #\?
        'reader-cond ; #?
        #\:
        'namespaced-map ; #:
        #\!
        'comment)) ; #!/usr/bin/env clojure

(define (is-reader-macro? rope pos)
  "Check if position is at a reader macro character.
   Returns: The macro type symbol or #f"
  (let ([ch (rope-char-at rope pos)]) (hash-try-get clojure-reader-macros ch)))

(define (is-dispatch-macro? rope pos)
  "Check if position is at a dispatch macro (# followed by special char).
   Returns: The dispatch type symbol or #f"
  (let ([ch (rope-char-at rope pos)])
    (if (equal? ch #\#)
        (let ([next-ch (rope-char-at rope (+ pos 1))])
          (if next-ch
              (hash-try-get clojure-dispatch-macros next-ch)
              #f))
        #f)))

(define (is-discard-macro? rope pos)
  "Check if position is at a discard macro (#_).
   The discard macro causes the next form to be ignored by the reader."
  (and (equal? (rope-char-at rope pos) #\#) (equal? (rope-char-at rope (+ pos 1)) #\_)))

;; ============================================================================
;; Comment Forms
;; ============================================================================

(define (is-clojure-comment-form? rope pos)
  "Check if position is at the start of a (comment ...) form.
   Returns: #t if at (comment, #f otherwise"
  (and (equal? (rope-char-at rope pos) #\()
       (let ([next-pos (+ pos 1)])
         ;; Skip whitespace after opening paren
         (let loop ([i next-pos])
           (let ([ch (rope-char-at rope i)])
             (cond
               [(not ch) #f]
               [(is-whitespace? ch) (loop (+ i 1))]
               [(equal? ch #\c)
                ;; Check if it spells "comment"
                (and (equal? (rope-char-at rope (+ i 1)) #\o)
                     (equal? (rope-char-at rope (+ i 2)) #\m)
                     (equal? (rope-char-at rope (+ i 3)) #\m)
                     (equal? (rope-char-at rope (+ i 4)) #\e)
                     (equal? (rope-char-at rope (+ i 5)) #\n)
                     (equal? (rope-char-at rope (+ i 6)) #\t)
                     ;; Must be followed by whitespace or closing paren
                     (let ([after (rope-char-at rope (+ i 7))])
                       (or (is-whitespace? after) (equal? after #\)))))]
               [else #f]))))))

;; ============================================================================
;; Reader Macro Skipping
;; ============================================================================

(define (skip-reader-macro rope pos)
  "Skip over a reader macro at pos and return the position after it.
   This handles macros like @, ', `, ~, ^, and dispatch macros like #(, #{, #_, etc.

   Returns: Position after the reader macro"
  (let ([ch (rope-char-at rope pos)])
    (cond
      ;; Dispatch macros starting with #
      [(equal? ch #\#)
       (let ([next-ch (rope-char-at rope (+ pos 1))])
         (cond
           ;; Anonymous function #(...)
           [(equal? next-ch #\() pos] ; Don't skip, it's a form

           ;; Set literal #{...}
           [(equal? next-ch #\{) pos] ; Don't skip, it's a form

           ;; Regex #"..."
           [(equal? next-ch #\") pos] ; Don't skip, it's a string-like form

           ;; Discard macro #_
           [(equal? next-ch #\_) (+ pos 2)] ; Skip both # and _

           ;; Var quote #'
           [(equal? next-ch #\') (+ pos 2)]

           ;; Reader conditional #?
           [(equal? next-ch #\?) (+ pos 2)]

           ;; Namespaced map #:
           [(equal? next-ch #\:) (+ pos 2)]

           ;; Symbolic value ##Inf, ##NaN, etc.
           [(equal? next-ch #\#) (+ pos 2)]

           ;; Tagged literal #inst, #uuid, etc.
           [else (+ pos 1)]))]

      ;; Simple reader macros
      [(equal? ch #\@) (+ pos 1)] ; Deref
      [(equal? ch #\') (+ pos 1)] ; Quote
      [(equal? ch #\`) (+ pos 1)] ; Syntax quote
      [(equal? ch #\~) (+ pos 1)] ; Unquote
      [(equal? ch #\^) (+ pos 1)] ; Meta

      ;; Not a reader macro
      [else pos])))

;; ============================================================================
;; Clojure-Specific Utilities
;; ============================================================================

(define (is-clojure-whitespace? ch)
  "Check if character is whitespace in Clojure (including comma)."
  (or (is-whitespace? ch) (equal? ch #\,)))

(define (is-clojure-symbol-char? ch)
  "Check if character is valid in a Clojure symbol."
  (and ch
       (not (is-whitespace? ch))
       (not (is-paren? ch))
       (not (equal? ch #\;))
       (not (equal? ch #\"))
       (not (equal? ch #\,))))

(define (is-namespace-separator? rope pos)
  "Check if position is at a namespace separator (/).
   In Clojure, / is used for namespace/name separation."
  (equal? (rope-char-at rope pos) #\/))
