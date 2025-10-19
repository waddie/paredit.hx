;; paredit.scm - Structural editing for Lisp languages in Helix
;;
;; This is the main entry point for the paredit plugin.
;; It provides setup and configuration for paredit operations.

(require "helix/editor.scm")
(require "cogs/paredit/core/parser.scm")
(require "cogs/paredit/core/range.scm")
(require "cogs/paredit/core/rope-utils.scm")
(require "cogs/paredit/core/selection.scm")
(require "cogs/paredit/core/element.scm")
(require "cogs/paredit/lang/clojure.scm")

(provide setup-paredit
         paredit-enabled?
         get-paredit-config
         set-paredit-config!

         ;; Re-export core functionality for convenience
         find-matching-paren
         find-enclosing-form
         find-current-element
         find-next-element
         find-prev-element)

;; ============================================================================
;; Configuration
;; ============================================================================

;; Default paredit configuration
(define *paredit-config*
  (hash 'enabled-languages
        '("clojure" "scheme" "lisp" "racket" "fennel")
        'cursor-behavior
        'auto ; 'auto, 'remain, or 'follow
        'auto-indent
        #t
        'enabled
        #t))

(define (get-paredit-config #:key [key #f])
  "Get paredit configuration.
   If key is provided, returns value for that key.
   Otherwise returns entire config hash."
  (if key
      (hash-try-get *paredit-config* key)
      *paredit-config*))

(define (set-paredit-config! key value)
  "Set a paredit configuration value."
  (set! *paredit-config* (hash-insert *paredit-config* key value)))

(define (merge-config! user-config)
  "Merge user configuration with defaults."
  (for-each (lambda (key) (set-paredit-config! key (hash-ref user-config key)))
            (hash-keys->list user-config)))

;; ============================================================================
;; Language Detection
;; ============================================================================

(define (get-current-language)
  "Get the language ID for the current document."
  (let* ([focus (editor-focus)]
         [doc-id (editor->doc-id focus)])
    (editor-document->language doc-id)))

(define (paredit-enabled-for-language? lang)
  "Check if paredit is enabled for the given language."
  (let ([enabled-langs (get-paredit-config #:key 'enabled-languages)]) (member lang enabled-langs)))

(define (paredit-enabled?)
  "Check if paredit is enabled for the current buffer."
  (and (get-paredit-config #:key 'enabled)
       (let ([lang (get-current-language)]) (and lang (paredit-enabled-for-language? lang)))))

;; ============================================================================
;; Setup and Initialization
;; ============================================================================

(define (setup-paredit #:config [user-config (hash)])
  "Initialize paredit with optional user configuration.

   Example usage:
     (setup-paredit #:config (hash 'cursor-behavior 'remain
                                   'enabled-languages '(\"clojure\" \"scheme\")))

   Configuration options:
     - enabled-languages: List of language IDs to enable paredit for
     - cursor-behavior: 'auto, 'remain, or 'follow
     - auto-indent: Boolean, whether to auto-indent after operations
     - enabled: Boolean, global enable/disable"

  ;; Merge user config
  (merge-config! user-config)

  ;; Log successful initialization
  (displayln "paredit.hx initialized")
  (displayln (string-append "  Enabled for: "
                            (list->string (get-paredit-config #:key 'enabled-languages))))
  (displayln (string-append "  Cursor behavior: "
                            (symbol->string (get-paredit-config #:key 'cursor-behavior)))))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(define (log-paredit-info message)
  "Log a paredit informational message."
  (displayln (string-append "[paredit] " message)))

(define (log-paredit-error message)
  "Log a paredit error message."
  (displayln (string-append "[paredit ERROR] " message)))

(define (paredit-operation-wrapper operation-fn operation-name)
  "Wrapper for paredit operations that checks if paredit is enabled
   and handles errors gracefully."
  (lambda args
    (if (paredit-enabled?)
        (with-handler
         (lambda (err)
           (log-paredit-error (string-append operation-name " failed: " (error-object-message err)))
           #f)
         (apply operation-fn args))
        (log-paredit-info (string-append operation-name
                                         " skipped (paredit not enabled for this language)")))))

;; ============================================================================
;; Version and Info
;; ============================================================================

(define *paredit-version* "0.1.0")

(define (paredit-version)
  "Get the paredit version string."
  *paredit-version*)

(define (paredit-info)
  "Display paredit information."
  (displayln (string-append "paredit.hx v" *paredit-version*))
  (displayln "Structural editing for Lisp languages in Helix")
  (displayln "")
  (displayln "Status:")
  (displayln (string-append "  Enabled: " (if (get-paredit-config #:key 'enabled) "yes" "no")))
  (displayln (string-append "  Current language: " (or (get-current-language) "unknown")))
  (displayln (string-append "  Active for current buffer: " (if (paredit-enabled?) "yes" "no"))))
