;; paredit.scm — structural editing for Lisp languages in Helix.

;; --- Language definitions (each registers itself with the lang registry) ---
(require "src/langs/clojure.scm")
(require "src/langs/scheme.scm")
(require "src/langs/fennel.scm")
(require "src/langs/janet.scm")
(require "src/langs/commonlisp.scm")

;; --- Configuration ---
(require "src/config.scm")

;; --- Operations ---
(require "src/ops/slurp.scm")
(require "src/ops/barf.scm")
(require "src/ops/drag.scm")
(require "src/ops/raise.scm")
(require "src/ops/unwrap.scm")
(require "src/ops/split-join.scm")

;; NB: structural motions and text-object selections are deliberately NOT
;; provided — Helix's builtin tree-sitter commands already cover them (expand/
;; shrink A-o/A-i, next/prev sibling A-n/A-p, match pair mi(/ma(, match bracket
;; mm). paredit.hx implements only the structural EDITS Helix lacks.

;; --- Diagnostics (foundation smoke test) ---
(require "src/inspect.scm")

(provide
  ;; diagnostics
  paredit-inspect
  paredit-print-tree
  paredit-inspect-pairs
  ;; configuration
  set-paredit-cursor-behaviour!
  ;; operations
  barf-backward
  barf-forward
  drag-element-backward
  drag-element-forward
  drag-form-backward
  drag-form-forward
  drag-pair-backward
  drag-pair-forward
  paredit-join
  paredit-split
  raise-element
  raise-form
  slurp-backward
  slurp-forward
  splice-form)
