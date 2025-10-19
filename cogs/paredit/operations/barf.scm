;; barf.scm - Barf operations (push elements out of a form)
;;
;; Barf operations move the closing or opening delimiter of a form
;; to exclude an element at the edge of the form.
;;
;; Examples:
;;   barf-forward:  (a b| c)  =>  (a b|) c
;;   barf-backward: (a |b c)  =>  a (|b c)

(require "../core/parser.scm")
(require "../core/element.scm")
(require "../core/selection.scm")
(require "../core/range.scm")
(require "../core/rope-utils.scm")
(require "helix/editor.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text)

(provide barf-forward
         barf-backward)

;; ============================================================================
;; Helper Functions
;; ============================================================================

(define (get-closing-char paren-type)
  "Get the closing character for a given paren type."
  (cond
    [(equal? paren-type 'round) #\)]
    [(equal? paren-type 'square) #\]]
    [(equal? paren-type 'curly) #\}]
    [else #\)]))

(define (get-opening-char paren-type)
  "Get the opening character for a given paren type."
  (cond
    [(equal? paren-type 'round) #\(]
    [(equal? paren-type 'square) #\[]
    [(equal? paren-type 'curly) #\{]
    [else #\(]))

(define (cursor-behavior)
  "Get the configured cursor behavior mode."
  'auto)

(define (find-last-element-in-form rope form)
  "Find the last element inside a form (before the closing delimiter).

   Returns: Range of the last element or #f if form is empty"
  (let* ([close-pos (form-end form)]
         ;; Start searching backward from just before the closing delimiter
         [search-start (skip-whitespace-and-comments-backward rope (- close-pos 1))])

    (if (<= search-start (form-start form))
        #f ; Form is empty
        ;; Find the element at this position
        (let* ([elem-end search-start]
               [elem-start (find-element-start rope elem-end)])
          (if (and elem-start elem-end (> elem-start (form-start form)) (< elem-end close-pos))
              (make-range elem-start (+ elem-end 1))
              #f)))))

(define (find-first-element-in-form rope form)
  "Find the first element inside a form (after the opening delimiter).

   Returns: Range of the first element or #f if form is empty"
  (let* ([open-pos (form-start form)]
         ;; Start searching forward from just after the opening delimiter
         [search-start (skip-whitespace-and-comments-forward rope (+ open-pos 1))])

    (if (>= search-start (form-end form))
        #f ; Form is empty
        ;; Find the element at this position
        (find-current-element rope search-start))))

;; ============================================================================
;; Barf Forward
;; ============================================================================

;;@doc
;; Push the last element out of the current form by moving the closing delimiter
(define (barf-forward)
  "Barf the last element out of the current form.

   Example: (a b| c)  =>  (a b|) c

   Algorithm:
   1. Find the enclosing form
   2. Find the last element in the form
   3. Move the closing delimiter to before that element"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (when form
      (let* ([last-elem (find-last-element-in-form rope form)])

        (when last-elem
          (let* ([close-pos (form-end form)]
                 [close-char (get-closing-char (form-paren-type form))]
                 [last-elem-end (range-end last-elem)]
                 ;; Find where to place the closing delimiter by skipping whitespace backward
                 ;; from just before the last element starts
                 [ws-end-pos (skip-whitespace-and-comments-backward rope (- (range-start last-elem) 1))]
                 [new-close-pos (+ ws-end-pos 1)]
                 ;; Calculate cursor behavior
                 [behavior (cursor-behavior)])

            ;; Extract text from new-close-pos to close-pos (whitespace + element)
            ;; and prepend the closing delimiter
            (let* ([text-to-preserve
                    (rope->string (rope->slice rope new-close-pos close-pos))]
                   [new-text
                    (string-append (char->string close-char) text-to-preserve)])

              ;; Replace range [new-close-pos, close-pos+1) with new text
              ;; This moves the ) to where whitespace started and preserves whitespace + element
              (set-selection! (make-range new-close-pos (+ close-pos 1)))
              (replace-selection! new-text)

              ;; Update cursor position
              (let ([final-cursor (cond
                                    [(equal? behavior 'follow) (+ new-close-pos 1)]
                                    [(equal? behavior 'remain) pos]
                                    [else ; 'auto
                                     (if (>= pos (range-start last-elem))
                                         pos ; Cursor on/after barfed element
                                         pos)])])
                (move-cursor-to! final-cursor)))))))))

;; ============================================================================
;; Barf Backward
;; ============================================================================

;;@doc
;; Push the first element out of the current form by moving the opening delimiter
(define (barf-backward)
  "Barf the first element out of the current form.

   Example: (a |b c)  =>  a (|b c)

   Algorithm:
   1. Find the enclosing form
   2. Find the first element in the form
   3. Move the opening delimiter to after that element"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (when form
      (let* ([first-elem (find-first-element-in-form rope form)])

        (when first-elem
          (let* ([open-pos (form-start form)]
                 [open-char (get-opening-char (form-paren-type form))]
                 [first-elem-end (range-end first-elem)]
                 ;; Skip whitespace after the first element
                 [new-open-pos (skip-whitespace-and-comments-forward rope first-elem-end)]
                 ;; Calculate cursor behavior
                 [behavior (cursor-behavior)])

            ;; Use single-range replacement to avoid zero-width selection issues
            ;; Extract text from after old delimiter to new position, then prepend new delimiter
            (let* ([text-between (rope->string (rope->slice rope (+ open-pos 1) new-open-pos))]
                   [new-text (string-append text-between (char->string open-char))])

              ;; Replace range [open-pos, new-open-pos) with new text
              (set-selection! (make-range open-pos new-open-pos))
              (replace-selection! new-text)

              ;; Update cursor position
              (let ([final-cursor
                     (cond
                       [(equal? behavior 'follow) (- new-open-pos 1)] ; After the new delimiter
                       [(equal? behavior 'remain) pos]
                       [else ; 'auto
                        (if (<= pos first-elem-end)
                            ;; Cursor on/before barfed element - keep relative
                            pos
                            ;; Cursor after - keep position
                            pos)])])
                (move-cursor-to! final-cursor)))))))))
