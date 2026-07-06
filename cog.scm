(define package-name 'paredit.hx)
(define version "0.3.0")

;; ts-utils.hx: shared tree-sitter glue (ts.scm) and sibling navigation
;; (nav.scm).
(define dependencies
  '((#:name "ts-utils.hx"
     #:git-url
     "https://github.com/waddie/ts-utils.hx"
     #:sha
     "ea38be16925c0024ed9f3ca2340e0fee291b5439")))
