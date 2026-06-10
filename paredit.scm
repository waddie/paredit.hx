;; paredit.scm — structural editing for Lisp languages in Helix.

;; --- Language definitions (each registers itself with the lang registry) ---
(require "cogs/paredit/langs/clojure.scm")
(require "cogs/paredit/langs/scheme.scm")
(require "cogs/paredit/langs/fennel.scm")
(require "cogs/paredit/langs/janet.scm")
(require "cogs/paredit/langs/commonlisp.scm")

;; --- Configuration ---
(require "cogs/paredit/config.scm")

;; --- Operations ---
(require "cogs/paredit/ops/slurp.scm")
(require "cogs/paredit/ops/barf.scm")
(require "cogs/paredit/ops/drag.scm")
(require "cogs/paredit/ops/raise.scm")
(require "cogs/paredit/ops/unwrap.scm")
(require "cogs/paredit/ops/split-join.scm")

;; NB: structural motions and text-object selections are deliberately NOT
;; provided — Helix's builtin tree-sitter commands already cover them (expand/
;; shrink A-o/A-i, next/prev sibling A-n/A-p, match pair mi(/ma(, match bracket
;; mm). paredit.hx implements only the structural EDITS Helix lacks.

;; --- Diagnostics (foundation smoke test) ---
(require "cogs/paredit/inspect.scm")

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
