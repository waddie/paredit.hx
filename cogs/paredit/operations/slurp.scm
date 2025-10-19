;; slurp.scm - Slurp operations (pull adjacent elements into a form)
;;
;; Slurp operations move the closing or opening delimiter of a form
;; to encompass an adjacent element.
;;
;; Examples:
;;   slurp-forward:  (a b|) c  =>  (a b| c)
;;   slurp-backward: a (|b c)  =>  (a |b c)

(require "../core/parser.scm")
(require "../core/element.scm")
(require "../core/selection.scm")
(require "../core/range.scm")
(require "../core/rope-utils.scm")
(require "helix/editor.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text)

(provide slurp-forward
         slurp-backward)

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
  "Get the configured cursor behavior mode.
   Options: 'auto, 'remain, 'follow"
  ;; TODO: Get from config once integrated
  'auto)

(define (update-cursor-after-slurp original-pos form-end new-form-end behavior)
  "Update cursor position after slurp operation based on behavior mode.

   Args:
     original-pos: Cursor position before slurp
     form-end: Original form end position
     new-form-end: New form end position after slurp
     behavior: Cursor behavior mode ('auto, 'remain, 'follow)"
  (cond
    [(equal? behavior 'remain) original-pos]
    [(equal? behavior 'follow) new-form-end]
    ;; Auto: if cursor was near the end delimiter, follow it
    [(equal? behavior 'auto) (if (<= (abs (- original-pos form-end)) 2) new-form-end original-pos)]
    [else original-pos]))

;; ============================================================================
;; Slurp Forward
;; ============================================================================

;;@doc
;; Pull the next element into the current form by moving the closing delimiter
(define (slurp-forward)
  "Slurp the next element into the current form.

   Example: (a b|) c  =>  (a b| c)

   Algorithm:
   1. Find the enclosing form
   2. Find the next element after the closing delimiter
   3. Move the closing delimiter to after that element"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (when form
      (let* ([close-pos (form-end form)]
             [close-char (get-closing-char (form-paren-type form))]
             ;; Find the next element after the closing paren
             [next-elem (find-next-element rope (+ close-pos 1))])

        (when next-elem
          (let* ([new-close-pos (range-end next-elem)]
                 ;; Calculate cursor adjustment
                 [behavior (cursor-behavior)]
                 [new-cursor (update-cursor-after-slurp pos close-pos new-close-pos behavior)])

            ;; Use single replacement to preserve whitespace correctly
            ;; Extract text from after old ) to end of next element, then append )
            (let* ([text-to-keep (rope->string (rope->slice rope (+ close-pos 1) new-close-pos))]
                   [new-text (string-append text-to-keep (char->string close-char))])

              ;; Replace [close-pos, new-close-pos) with text-to-keep + )
              (set-selection! (make-range close-pos new-close-pos))
              (replace-selection! new-text)

              ;; Update cursor position
              (move-cursor-to! new-cursor))))))))

;; ============================================================================
;; Slurp Backward
;; ============================================================================

;;@doc
;; Pull the previous element into the current form by moving the opening delimiter
(define (slurp-backward)
  "Slurp the previous element into the current form.

   Example: a (|b c)  =>  (a |b c)

   Algorithm:
   1. Find the enclosing form
   2. Find the previous element before the opening delimiter
   3. Move the opening delimiter to before that element"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])

    (when form
      (let* ([open-pos (form-start form)]
             [open-char (get-opening-char (form-paren-type form))]
             ;; Find the previous element before the opening paren
             [prev-elem (find-prev-element rope open-pos)])

        (when prev-elem
          (let* ([prev-elem-start (range-start prev-elem)]
                 [prev-elem-end (range-end prev-elem)]
                 ;; Calculate cursor behavior
                 [behavior (cursor-behavior)])

            ;; Check if there's a `(` immediately before prev-elem
            (let* ([pos-before-elem (if (> prev-elem-start 0)
                                        (- prev-elem-start 1)
                                        0)]
                   [char-before-elem (if (> prev-elem-start 0)
                                         (rope-char-at rope pos-before-elem)
                                         #\space)]
                   ;; Determine starting position for the new opening paren
                   [new-open-pos
                    (if (is-open-paren? char-before-elem) pos-before-elem prev-elem-start)]
                   ;; Extract the text that will be kept
                   [kept-text (rope->string (rope->slice rope new-open-pos open-pos))]
                   ;; New text is: opening paren + kept text
                   [new-text (string-append (char->string open-char) kept-text)])

              ;; Replace range [new-open-pos, open-pos+1) with new text
              (set-selection! (make-range new-open-pos (+ open-pos 1)))
              (replace-selection! new-text)

              ;; Update cursor position
              (let ([final-cursor (cond
                                    [(equal? behavior 'follow) (+ new-open-pos 1)]
                                    [(equal? behavior 'remain) pos]
                                    [else ; 'auto
                                     (if (<= (abs (- pos open-pos)) 2)
                                         (+ new-open-pos 1) ; Follow the opening delimiter
                                         pos)])])
                (move-cursor-to! final-cursor)))))))))
