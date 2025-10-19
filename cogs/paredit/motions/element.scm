;; element.scm - Element-based motion commands
;;
;; Provides motions for navigating between elements (symbols, forms, etc.):
;;   W  - move to next element head (beginning)
;;   B  - move to previous element head (beginning)
;;   E  - move to next element tail (end)
;;   gE - move to previous element tail (end)
;;
;; These are analogous to Vim's word motions but operate on s-expression elements.

(require "../core/parser.scm")
(require "../core/element.scm")
(require "../core/selection.scm")
(require "../core/range.scm")
(require "../core/rope-utils.scm")

(provide move-to-next-element-head
         move-to-prev-element-head
         move-to-next-element-tail
         move-to-prev-element-tail)

;; ============================================================================
;; Forward Element Motions
;; ============================================================================

;;@doc
;; Move cursor to the beginning of the next element (motion: W)
(define (move-to-next-element-head)
  "Move cursor to the beginning of the next element.

   Motion: W
   Example: fo|o bar  =>  foo |bar"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [next-elem (find-next-element rope pos)])

    (if (not next-elem)
        #f

        (begin
          (move-cursor-to! (range-start next-elem))
          #t))))

;;@doc
;; Move cursor to the end of the next element (motion: E)
(define (move-to-next-element-tail)
  "Move cursor to the end of the next element.

   Motion: E
   Example: fo|o bar  =>  foo ba|r"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         ;; First, check if we're in the middle of an element
         [current-elem (find-current-element rope pos)])

    (if (not current-elem)
        ;; Not on an element, find next
        (let ([next-elem (find-next-element rope pos)])
          (if next-elem
              (begin
                (move-cursor-to! (- (range-end next-elem) 1))
                #t)
              #f))

        ;; On an element
        (let ([elem-end (- (range-end current-elem) 1)])
          (if (< pos elem-end)
              ;; Move to end of current element
              (begin
                (move-cursor-to! elem-end)
                #t)
              ;; Already at end, move to next
              (let ([next-elem (find-next-element rope pos)])
                (if next-elem
                    (begin
                      (move-cursor-to! (- (range-end next-elem) 1))
                      #t)
                    #f)))))))

;; ============================================================================
;; Backward Element Motions
;; ============================================================================

;;@doc
;; Move cursor to the beginning of the previous element (motion: B)
(define (move-to-prev-element-head)
  "Move cursor to the beginning of the previous element.

   Motion: B
   Example: foo ba|r  =>  |foo bar"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         ;; First, check if we're in the middle of an element
         [current-elem (find-current-element rope pos)])

    (if (not current-elem)
        ;; Not on an element, find previous
        (let ([prev-elem (find-prev-element rope pos)])
          (if prev-elem
              (begin
                (move-cursor-to! (range-start prev-elem))
                #t)
              #f))

        ;; On an element
        (let ([elem-start (range-start current-elem)])
          (if (> pos elem-start)
              ;; Move to start of current element
              (begin
                (move-cursor-to! elem-start)
                #t)
              ;; Already at start, move to previous
              (let ([prev-elem (find-prev-element rope pos)])
                (if prev-elem
                    (begin
                      (move-cursor-to! (range-start prev-elem))
                      #t)
                    #f)))))))

;;@doc
;; Move cursor to the end of the previous element (motion: gE)
(define (move-to-prev-element-tail)
  "Move cursor to the end of the previous element.

   Motion: gE
   Example: foo ba|r  =>  fo|o bar"

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [prev-elem (find-prev-element rope pos)])

    (if (not prev-elem)
        #f

        (begin
          (move-cursor-to! (- (range-end prev-elem) 1))
          #t))))

;; ============================================================================
;; Extended Element Motions
;; ============================================================================

(define (move-to-next-element-head-n n)
  "Move cursor forward n elements.

   Args:
     n: Number of elements to skip (default 1)"
  (let loop ([count n])
    (if (<= count 0)
        #t
        (if (move-to-next-element-head)
            (loop (- count 1))
            #f))))

(define (move-to-prev-element-head-n n)
  "Move cursor backward n elements.

   Args:
     n: Number of elements to skip (default 1)"
  (let loop ([count n])
    (if (<= count 0)
        #t
        (if (move-to-prev-element-head)
            (loop (- count 1))
            #f))))
