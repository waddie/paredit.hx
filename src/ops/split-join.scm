;; ops/split-join.scm — split one form/string into two, and join two into one.

(require "../ts.scm")
(require "../lang.scm")
(require "../traversal.scm")
(require "../edit.scm")
(require "helix/misc.scm") ; set-status!, cursor-position

(provide paredit-split
  paredit-join)

;;;; ---------------------------------------------------------------------------
;;;; Shared helpers
;;;; ---------------------------------------------------------------------------

;; The nearest enclosing form OR string literal of `node` (inclusive), or #f.
(define (find-nearest-container lang node)
  (let loop ([n node])
    (cond
      [(not n) #f]
      [(form? lang n) n]
      [(str? lang n) n]
      [else (loop (tsnode-parent n))])))

;; The opening- and closing-delimiter char ranges of a container, as
;; (cons open-range close-range) where each range is (cons start end), or #f.
;; Forms delegate to get-form-edges; string literals use their first/last char.
(define (container-edges lang rope node)
  (if (str? lang node)
    (let* ([r (node->char-range rope node)]
           [s (car r)]
           [e (cdr r)])
      ;; Treat as a splittable/joinable string only when it is delimited by a
      ;; matching pair of double quotes (open = first char, close = last char).
      ;; Guards against string node-kinds that are NOT "…"-quoted — e.g. Fennel's
      ;; keywords (:foo), which share the `string` node kind but have no
      ;; symmetric delimiters. Such nodes fall through to #f, so split/join bail.
      (if (and (>= (- e s) 2)
           (equal? (string-ref (char-range-text rope s (+ s 1)) 0) #\")
           (equal? (string-ref (char-range-text rope (- e 1) e) 0) #\"))
        (cons (cons s (+ s 1)) (cons (- e 1) e))
        #f))
    (get-form-edges rope node)))

;; Is the whole string `s` made of `lang`-whitespace (so a gap can be collapsed)?
(define (all-ws? lang s)
  (let ([len (string-length s)])
    (let loop ([i 0])
      (or (>= i len)
        (and (ws-char? lang (string-ref s i)) (loop (+ i 1)))))))

;;;; ---------------------------------------------------------------------------
;;;; Split
;;;; ---------------------------------------------------------------------------

;;@doc
;; Split the enclosing form or string at the cursor into two
(define (paredit-split)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let* ([node (node-at-cursor)]
               [container (and node (find-nearest-container lang node))])
          (cond
            [(not container)
              (set-status! "paredit: cursor not inside a form or string")]
            [else (do-split lang container)]))])))

(define (do-split lang container)
  (let* ([rope (current-rope)]
         [edges (container-edges lang rope container)])
    (cond
      [(not edges) (set-status! "paredit: nothing to split")]
      [else
        (let* ([open-range (car edges)]
               [close-range (cdr edges)]
               [interior-start (cdr open-range)] ; just past the opening delimiter
               [interior-end (car close-range)] ; just before the closing delimiter
               [open-text (char-range-text rope (car open-range) (cdr open-range))]
               [close-text (char-range-text rope (car close-range) (cdr close-range))]
               [raw-cut (cursor-position)]
               ;; clamp the cut into the interior [interior-start, interior-end]
               [cut (cond
                     [(< raw-cut interior-start) interior-start]
                     [(> raw-cut interior-end) interior-end]
                     [else raw-cut])])
          (cond
            ;; an empty container has nothing to split into two
            [(>= interior-start interior-end)
              (set-status! "paredit: form is empty")]
            [else
              (let* ([interior (char-range-text rope interior-start interior-end)]
                     ;; In a STRING, whitespace is significant content — never
                     ;; consume it; split at the literal cursor so the space falls
                     ;; into one of the two new strings. In a FORM, whitespace is
                     ;; mere element separation, so absorb it around the cut.
                     [is-string (str? lang container)]
                     [ws-start (if is-string
                                cut
                                (scan-ws-left lang interior interior-start cut))]
                     [ws-end (if is-string
                              cut
                              (scan-ws-right lang interior interior-start interior-end cut))]
                     [inserted (string-append close-text " " open-text)])
                ;; Express as a span-replace, never a zero-width insert (Helix
                ;; expands a zero-width selection to the next grapheme and would
                ;; overwrite it). When no whitespace was consumed we borrow one
                ;; neighbouring grapheme and re-emit it on the far side.
                (cond
                  [(> ws-end ws-start)
                    (apply-edits (list (make-edit ws-start ws-end inserted)))]
                  [(< cut interior-end)
                    (let ([nextc (char-range-text rope cut (+ cut 1))])
                      (apply-edits
                        (list (make-edit cut (+ cut 1)
                               (string-append inserted nextc)))))]
                  [else ; cut == interior-end: borrow the preceding grapheme
                    (let ([prevc (char-range-text rope (- cut 1) cut)])
                      (apply-edits
                        (list (make-edit (- cut 1) cut
                               (string-append prevc inserted)))))])
                ;; point lands between the two new forms, just past the close
                (set-cursor-char (+ ws-start (string-length close-text))))]))])))

;; Scan left from `cut` over whitespace, not past `base` (the interior start).
;; `interior` is the text of [base, …); the char at absolute position p is
;; interior[p - base].
(define (scan-ws-left lang interior base cut)
  (let loop ([p cut])
    (if (and (> p base) (ws-char? lang (string-ref interior (- p base 1))))
      (loop (- p 1))
      p)))

;; Scan right from `cut` over whitespace, not past `limit` (the interior end).
(define (scan-ws-right lang interior base limit cut)
  (let loop ([p cut])
    (if (and (< p limit) (ws-char? lang (string-ref interior (- p base))))
      (loop (+ p 1))
      p)))

;;;; ---------------------------------------------------------------------------
;;;; Join
;;;; ---------------------------------------------------------------------------

;;@doc
;; Join the form or string before the cursor with the one after it
(define (paredit-join)
  (let ([lang (language-for-doc)])
    (cond
      [(not lang) (set-status! "paredit: not a recognised lisp buffer")]
      [else
        (let ([node (node-at-cursor)])
          (cond
            [(not node) (set-status! "paredit: cursor not inside a form")]
            [else (do-join lang node)]))])))

(define (do-join lang node)
  (let* ([rope (current-rope)]
         [enclosing (find-nearest-form lang node)]
         ;; the pair lives in the cohort of `enclosing` (cursor in a gap between
         ;; two children) or is `enclosing` itself joined forward (cursor inside
         ;; the left form). At top level the cohort is the document root's forms.
         [ctx (or enclosing (current-root))]
         [children (children-skipping-comments lang ctx)]
         [cur (cursor-position)]
         [straddled (pick-join-pair rope children cur)]
         [fallback (and enclosing
                    (let ([sib (next-sibling-skipping-comments lang enclosing)])
                      (and sib (cons enclosing sib))))]
         ;; prefer the straddled pair, but only if it is joinable — a gap
         ;; between two atoms (e.g. `(a | b) (c d)`) falls through to joining
         ;; `enclosing` with its sibling rather than erroring
         [pair (cond
                [(and straddled
                    (joinable-same? lang (car straddled) (cdr straddled)))
                  straddled]
                [(and fallback
                    (joinable-same? lang (car fallback) (cdr fallback)))
                  fallback]
                [else #f])])
    (cond
      [pair (join-pair lang rope (car pair) (cdr pair))]
      [(or straddled fallback)
        (set-status! "paredit: can only join two forms or two strings")]
      [else (set-status! "paredit: nothing to join")])))

;; The adjacent (left . right) child pair straddling `cur`: left is the last
;; child ending at or before the cursor, right its following sibling. #f if there
;; is no such gap (cursor before the first child, or left has no next sibling).
(define (pick-join-pair rope children cur)
  (let ([n (length children)])
    (let scan ([xs children] [idx 0] [best #f])
      (cond
        [(null? xs)
          (if (and best (< (+ best 1) n))
            (cons (list-ref children best) (list-ref children (+ best 1)))
            #f)]
        [(<= (node-end-char rope (car xs)) cur)
          (scan (cdr xs) (+ idx 1) idx)]
        [else (scan (cdr xs) (+ idx 1) best)]))))

;; Two nodes are joinable iff both are forms or both are strings (bracket TYPE
;; may differ — that is the coercion case; form-vs-string is refused).
(define (joinable-same? lang a b)
  (or (and (form? lang a) (form? lang b))
    (and (str? lang a) (str? lang b))))

(define (join-pair lang rope left right)
  (let ([left-edges (container-edges lang rope left)]
        [right-edges (container-edges lang rope right)])
    (cond
      [(or (not left-edges) (not right-edges))
        (set-status! "paredit: cannot join these")]
      [else
        (let* ([left-close (cdr left-edges)]
               [right-open (car right-edges)]
               [right-close (cdr right-edges)]
               [lc-start (car left-close)]
               [lc-end (cdr left-close)]
               [lc-text (char-range-text rope lc-start lc-end)]
               [ro-start (car right-open)]
               [ro-end (cdr right-open)]
               [rc-start (car right-close)]
               [rc-end (cdr right-close)]
               [rc-text (char-range-text rope rc-start rc-end)]
               [between (char-range-text rope lc-end ro-start)]
               ;; The separator that replaces the inter-element gap: a space for
               ;; forms (element separation), but NOTHING for strings — the gap
               ;; between two string literals is not content, so joining must
               ;; concatenate their contents directly (any wanted space already
               ;; lives inside one of the strings).
               [sep (if (str? lang left) "" " ")]
               ;; coerce the result to the left form's brackets when they differ
               [coerce (if (equal? lc-text rc-text)
                        '()
                        (list (make-edit rc-start rc-end lc-text)))])
          (apply-edits
            (append coerce
              (if (all-ws? lang between)
                ;; no comment between: collapse the gap and both inner delimiters
                ;; into the separator, in one edit
                (list (make-edit lc-start ro-end sep))
                ;; a comment sits between: preserve it — just delete the two
                ;; inner delimiters
                (list (make-edit lc-start lc-end "")
                  (make-edit ro-start ro-end "")))))
          ;; point lands at the join, where the former left-close stood
          (set-cursor-char lc-start))])))
