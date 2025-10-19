;; selection.scm - Selection management and cursor positioning
;;
;; This module provides wrappers around Helix's selection and cursor APIs,
;; making it easier to work with selections in paredit operations.

(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require "range.scm")

(provide get-current-selection
         set-selection!
         get-cursor-position
         get-selection-range
         replace-selection!
         select-range!
         move-cursor-to!
         get-current-rope
         get-document-id)

;; ============================================================================
;; Document Access
;; ============================================================================

(define (get-document-id)
  "Get the current document ID."
  (editor->doc-id (editor-focus)))

(define (get-current-rope)
  "Get the rope for the current document."
  (editor->text (get-document-id)))

;; ============================================================================
;; Cursor and Selection
;; ============================================================================

(define (get-cursor-position)
  "Get the current cursor position as a character offset."
  (cursor-position))

(define (get-current-selection)
  "Get the current selection object."
  (helix.static.current-selection-object))

(define (get-selection-range)
  "Get the current selection as a Range.
   Returns: Range structure with start and end positions"
  (let ([sel (get-current-selection)])
    (if sel
        (let ([anchor (list-ref sel 0)]
              [head (list-ref sel 1)])
          (make-range (min anchor head) (max anchor head)))
        #f)))

(define (set-selection! range)
  "Set the selection to the given range.

   Args:
     range: A Range structure or a list (start end)"
  (let ([start (if (range? range)
                   (range-start range)
                   (car range))]
        [end (if (range? range)
                 (range-end range)
                 (cadr range))])
    ;; Create a Helix Range object and convert to Selection
    (let ([helix-range (helix.static.range start end)])
      (helix.static.set-current-selection-object! (helix.static.range->selection helix-range)))))

(define (select-range! range)
  "Select the given range. Alias for set-selection!."
  (set-selection! range))

(define (move-cursor-to! pos)
  "Move the cursor to the given position."
  ;; Create a Helix Range object with both anchor and head at the same position
  (let ([helix-range (helix.static.range pos pos)])
    (helix.static.set-current-selection-object! (helix.static.range->selection helix-range))))

(define (replace-selection! text)
  "Replace the current selection with the given text."
  (helix.static.replace-selection-with text))

;; ============================================================================
;; Selection Utilities
;; ============================================================================

(define (expand-selection-to-range range)
  "Expand the current selection to include the given range."
  (let ([current (get-selection-range)])
    (if current
        (let ([new-range (range-merge current range)]) (set-selection! new-range))
        (set-selection! range))))

(define (selection-contains-pos? pos)
  "Check if the current selection contains the given position."
  (let ([sel-range (get-selection-range)])
    (if sel-range
        (range-contains? sel-range pos)
        #f)))
