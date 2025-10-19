;; config.scm — runtime configuration for paredit.hx.
;;
;; Minimal mutable config store. Currently just the cursor-behaviour mode used
;; by `cursor.scm`.

(provide cursor-behaviour
  set-paredit-cursor-behaviour!
  normalise-cursor-behaviour
  valid-cursor-behaviour?)

;; One of: 'remain 'follow 'auto  (see cursor.scm)
(define *cursor-behaviour* 'auto)

;; Strip a single leading quote char from `s` (e.g. "'remain" -> "remain").
(define (strip-leading-quote s)
  (if (and (> (string-length s) 0) (equal? (string-ref s 0) #\'))
    (substring s 1 (string-length s))
    s))

;;@doc
;; Coerce `mode` to one of the canonical cursor-behaviour symbols ('remain,
;; 'follow, 'auto), or #f if it names none of them.
(define (normalise-cursor-behaviour mode)
  (let ([name
          (cond
            [(symbol? mode) (symbol->string mode)]
            [(string? mode) (strip-leading-quote mode)]
            ;; (quote sym) reader form — unwrap to the inner symbol's name
            [(and (list? mode)
                (= (length mode) 2)
                (equal? (car mode) 'quote)
                (symbol? (car (cdr mode))))
              (symbol->string (car (cdr mode)))]
            [else #f])])
    (cond
      [(equal? name "remain") 'remain]
      [(equal? name "follow") 'follow]
      [(equal? name "auto") 'auto]
      [else #f])))

;;@doc
;; Is `mode` a recognised cursor-behaviour (in any accepted representation)?
(define (valid-cursor-behaviour? mode)
  (and (normalise-cursor-behaviour mode) #t))

;;@doc
;; The current cursor-behaviour mode (always one of the canonical symbols).
(define (cursor-behaviour)
  *cursor-behaviour*)

;;@doc
;; Set the cursor-behaviour mode to 'remain, 'follow, or 'auto. Accepts the
;; symbol, the equivalent string, or a quoted form; errors on anything else.
(define (set-paredit-cursor-behaviour! mode)
  (let ([sym (normalise-cursor-behaviour mode)])
    (if sym
      (set! *cursor-behaviour* sym)
      (error "invalid cursor-behaviour (expected remain, follow, or auto), got:" mode))))
