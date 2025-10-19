;; ts.scm — tree-sitter helper layer for paredit.hx
;;
;; Wrapper over `helix/treesitter.scm` plus the editor glue, translates
;; TS bytes / Helix chars.

(require "helix/treesitter.scm")
(require-builtin helix/core/text as text.)
(require "helix/editor.scm") ; editor-focus, editor->doc-id, editor->text, editor-document->language
(require "helix/misc.scm") ; cursor-position

(provide
  ;; document / tree access
  current-doc-id
  current-rope
  current-language
  current-tree
  current-root
  ;; offset conversion
  char->byte
  byte->char
  ;; node geometry (returns CHAR offsets)
  node-start-char
  node-end-char
  node->char-range
  node-text
  char-range-text
  ;; lookup
  node-at-cursor
  node-at-char
  named-node-at-char
  ;; re-exports used pervasively (so callers need only require this module)
  tsnode-parent
  tsnode-children
  tsnode-named-children
  tsnode-kind
  tsnode-named?
  tsnode-extra?
  tsnode-start-byte
  tsnode-end-byte
  tsnode-print-tree
  TSNode?
  TSTree?)

;;;; ---------------------------------------------------------------------------
;;;; Document / tree access
;;;; ---------------------------------------------------------------------------

;;@doc
;; DocumentId of the currently focused view.
(define (current-doc-id)
  (editor->doc-id (editor-focus)))

;;@doc
;; The focused document's text as a Rope. Needed for every byte<->char conversion.
(define (current-rope)
  (editor->text (current-doc-id)))

;;@doc
;; Helix language id of the focused document (e.g. "clojure"), or #f.
(define (current-language)
  (editor-document->language (current-doc-id)))

;;@doc
;; Root parse tree of the focused document, or #f if it has no grammar
;; (scratch buffer, unconfigured language, ...). Callers MUST handle #f.
(define (current-tree)
  (document->tree (current-doc-id)))

;;@doc
;; Root TSNode of the focused document, or #f when there is no tree.
(define (current-root)
  (let ([tree (current-tree)])
    (and tree (tstree->root tree))))

;;;; ---------------------------------------------------------------------------
;;;; Offset conversion
;;;; ---------------------------------------------------------------------------

;;@doc
;; CHAR offset -> BYTE offset, against `rope`.
(define (char->byte rope char-idx)
  (text.rope-char->byte rope char-idx))

;;@doc
;; BYTE offset -> CHAR offset, against `rope`.
(define (byte->char rope byte-idx)
  (text.rope-byte->char rope byte-idx))

;;;; ---------------------------------------------------------------------------
;;;; Node geometry — all results are CHAR offsets
;;;; ---------------------------------------------------------------------------

;;@doc
;; Start of `node` as a CHAR offset.
(define (node-start-char rope node)
  (byte->char rope (tsnode-start-byte node)))

;;@doc
;; End of `node` as a CHAR offset (exclusive, matching tree-sitter).
(define (node-end-char rope node)
  (byte->char rope (tsnode-end-byte node)))

;;@doc
;; (cons start-char end-char) for `node`.
(define (node->char-range rope node)
  (cons (node-start-char rope node)
    (node-end-char rope node)))

;;@doc
;; The source text spanned by `node`, as a string. Slices by CHAR offset
;; (rope->slice), the conversion path proven by slurp/barf — rope->byte-slice
;; raises a RopeyError on this build.
(define (node-text rope node)
  (char-range-text rope (node-start-char rope node) (node-end-char rope node)))

;;@doc
;; The source text between CHAR offsets [start, end), as a string.
(define (char-range-text rope start end)
  (text.rope->string (text.rope->slice rope start end)))

;;;; ---------------------------------------------------------------------------
;;;; Lookup
;;;; ---------------------------------------------------------------------------

;;@doc
;; Smallest NAMED node covering CHAR offset `char-pos` in `root`, or #f.
;; `rope` is needed for the char->byte conversion.
(define (named-node-at-char root rope char-pos)
  (let ([byte (char->byte rope char-pos)])
    (tsnode-named-descendant-byte-range root byte byte)))

;;@doc
;; Smallest node (named or anonymous) covering CHAR offset `char-pos`, or #f.
(define (node-at-char root rope char-pos)
  (let ([byte (char->byte rope char-pos)])
    (tsnode-descendant-byte-range root byte byte)))

;;@doc
;; The named node under the primary cursor of the focused document, or #f when
;; there is no syntax tree or no node at the cursor. The common entry point for
;; operations and motions.
(define (node-at-cursor)
  (let ([root (current-root)])
    (and root
      (named-node-at-char root (current-rope) (cursor-position)))))
