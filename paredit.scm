;; paredit.scm - Structural editing for Lisp languages in Helix
;;
;; This is the main entry point for the paredit plugin.
;; It provides setup and configuration for paredit operations.

(require "helix/editor.scm")
(require "helix/commands.scm")
(require "cogs/paredit/core/parser.scm")
(require "cogs/paredit/core/range.scm")
(require "cogs/paredit/core/rope-utils.scm")
(require "cogs/paredit/core/selection.scm")
(require "cogs/paredit/core/element.scm")
(require "cogs/paredit/lang/clojure.scm")

;; Phase 2: Operations, motions, and text objects
(require "cogs/paredit/operations/slurp.scm")
(require "cogs/paredit/operations/barf.scm")
(require "cogs/paredit/motions/element.scm")
(require "cogs/paredit/motions/form.scm")
(require "cogs/paredit/text-objects/selections.scm")

(provide paredit-version
         paredit-info
         ;; Not obviuosly useful
         ; setup-paredit
         ; paredit-enabled?
         ; get-paredit-config
         ; set-paredit-config!

         ;; Re-export core functionality for convenience
         find-matching-paren
         find-enclosing-form
         find-current-element
         find-next-element
         find-prev-element

         ;; Operations
         slurp-forward
         slurp-backward
         barf-forward
         barf-backward

         ;; Text objects
         select-around-form
         select-in-form
         ;; No obvious use for these
         ; select-around-element
         ; select-element

         ;; Element motions
         move-to-next-element-head
         move-to-prev-element-head
         move-to-next-element-tail
         move-to-prev-element-tail

         ;; Form motions
         move-to-parent-form-start
         move-to-parent-form-end
         move-to-next-form-start
         move-to-prev-form-start)

;; ============================================================================
;; Configuration
;; ============================================================================

;; Default paredit configuration
(define *paredit-config*
  (hash 'enabled-languages
        '("clojure" "scheme" "elisp" "common-lisp" "fennel")
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
  (merge-config! user-config))

;; ============================================================================
;; Utility Functions
;; ============================================================================

(define (log-paredit-info message)
  "Log a paredit informational message."
  (echo (string-append "[paredit] " message)))

(define (log-paredit-error message)
  "Log a paredit error message."
  (echo (string-append "[paredit ERROR] " message)))

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

(define *paredit-version* "0.1.0-alpha")

(define (paredit-version)
  "Get the paredit version string."
  *paredit-version*)

(define (paredit-info)
  "Display paredit information."
  (echo (string-append "paredit.hx v"
                       *paredit-version*
                       " | Enabled: "
                       (if (get-paredit-config #:key 'enabled) "yes" "no")
                       " | Language: "
                       (or (get-current-language) "unknown")
                       " | Active: "
                       (if (paredit-enabled?) "yes" "no"))))

;; ============================================================================
;; Example Keybindings
;; ============================================================================
;;
;; Below are example keybindings for paredit operations.
;; To use them, add these to your Helix config.toml or init.scm:
;;
;; Example config.toml:
;;   [keys.normal]
;;   ">" = { ")" = ":run-steel paredit/slurp-forward", ... }
;;   "<" = { ")" = ":run-steel paredit/barf-forward", ... }
;;
;; Example init.scm:
;;   (require "paredit/paredit.scm")
;;   (setup-paredit)
;;
;;   ;; Define keybindings
;;   (define paredit-keybindings
;;     (hash
;;       ;; Normal mode
;;       "normal" (hash
;;         ">" (hash
;;           ")" slurp-forward       ; >) - slurp next element into form
;;           "(" barf-backward       ; >( - barf first element out
;;           "e" 'drag-element-fwd   ; >e - drag element forward (Phase 3)
;;           "f" 'drag-form-fwd)     ; >f - drag form forward (Phase 3)
;;         "<" (hash
;;           ")" barf-forward        ; <) - barf last element out
;;           "(" slurp-backward      ; <( - slurp previous element in
;;           "e" 'drag-element-back  ; <e - drag element backward (Phase 3)
;;           "f" 'drag-form-back)    ; <f - drag form backward (Phase 3)
;;         "W" move-to-next-element-head      ; W - next element start
;;         "B" move-to-prev-element-head      ; B - prev element start
;;         "E" move-to-next-element-tail      ; E - next element end
;;         "(" move-to-parent-form-start      ; ( - parent form start
;;         ")" move-to-parent-form-end)       ; ) - parent form end
;;
;;       ;; Select mode
;;       "select" (hash
;;         "a" (hash
;;           "f" select-around-form    ; af - select around form (with parens)
;;           "e" select-around-element) ; ae - select element
;;         "i" (hash
;;           "f" select-in-form        ; if - select in form (without parens)
;;           "e" select-element))))    ; ie - select element
;;
;; ============================================================================
;; Recommended Keybindings Summary
;; ============================================================================
;;
;; Operations:
;;   >)  - slurp-forward      Pull next element into form
;;   <(  - slurp-backward     Pull previous element into form
;;   <)  - barf-forward       Push last element out of form
;;   >(  - barf-backward      Push first element out of form
;;
;; Element Motions:
;;   W   - Next element start
;;   B   - Previous element start
;;   E   - Next element end
;;   gE  - Previous element end
;;
;; Form Motions:
;;   (   - Parent form start
;;   )   - Parent form end
;;
;; Text Objects:
;;   af  - Around form (including parens)
;;   if  - In form (excluding parens)
;;   ae  - Around element
;;   ie  - In element (same as ae)
;;
;; Usage with verbs:
;;   daf - Delete around form
;;   cif - Change in form
;;   yae - Yank element
;;   vaf - Select around form
;;
