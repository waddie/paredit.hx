# Helix Paredit Implementation Plan

**Date:** October 19, 2025
**Project:** paredit.hx - Structural editing for Lisp languages in Helix
**Based on:** nvim-paredit analysis and Helix Steel plugin ecosystem review

## Project Overview

**Goal:** Implement paredit-style structural editing for Clojure and other Lisp languages in Helix editor using Steel Scheme plugins.

**Scope:** Core paredit operations (slurp, barf, raise, drag, motions, text objects) with manual s-expression parsing.

**Timeline:** 3 months for MVP, 6 months for full feature set

**Target Languages (Priority Order):**
1. Clojure (primary, most complex)
2. Scheme (secondary)
3. Common Lisp (tertiary)
4. Fennel, Janet (future)

## Project Structure

```
paredit.hx/
├── cog.scm                    # Package manifest
├── README.md                  # User documentation
├── paredit.scm               # Main entry point, exports public API
├── src/
│   ├── core/
│   │   ├── parser.scm        # S-expression parsing engine
│   │   ├── range.scm         # Position and range utilities
│   │   └── rope-utils.scm    # Rope operation wrappers
│   ├── operations/
│   │   ├── slurp.scm         # Slurp forwards/backwards
│   │   ├── barf.scm          # Barf forwards/backwards
│   │   ├── raise.scm         # Raise form/element
│   │   ├── drag.scm          # Drag element/form
│   │   ├── wrap.scm          # Wrap element/form
│   │   └── unwrap.scm        # Unwrap/splice
│   ├── motions/
│   │   ├── element.scm       # W, B, E, gE movements
│   │   └── form.scm          # (, ), [ ], { } movements
│   ├── text-objects/
│   │   └── selections.scm    # af, if, ae, ie text objects
│   └── lang/
│       ├── clojure.scm       # Clojure-specific parsing rules
│       └── scheme.scm        # Scheme-specific parsing rules
├── tests/
│   ├── core/
│   │   └── parser_test.scm
│   └── operations/
│       ├── slurp_test.scm
│       └── barf_test.scm
└── docs/
    ├── API.md                # Public API reference
    ├── CONFIGURATION.md      # User configuration guide
    └── DEVELOPMENT.md        # Developer guide
```

## Phase 1: Foundation (Weeks 1-3)

### Week 1: Project Setup & Core Parsing

**Deliverables:**
- [ ] Repository structure
- [ ] Package manifest (cog.scm)
- [ ] Basic paren matching algorithm

**Files to Create:**
1. `src/core/parser.scm`
```scheme
(provide find-matching-paren
         find-enclosing-form
         find-form-boundaries
         scan-forward-to-boundary
         scan-backward-to-boundary)

;; Core parsing functions
(define (find-matching-paren rope pos direction)
  ;; Walk forwards/backwards tracking depth
  ;; Skip strings, comments, character literals
  ;; Return position of matching paren or #f)

(define (find-enclosing-form rope pos)
  ;; Walk backward to find opening paren
  ;; Return (form-start form-end depth) or #f)
```

2. `src/core/rope-utils.scm`
```scheme
(require-builtin helix/core/text as text.)

(provide rope-char-at
         rope-substring
         rope-line-at
         rope-insert-at
         rope-delete-range
         is-whitespace?
         is-paren?
         is-open-paren?
         is-close-paren?)

(define (rope-char-at rope pos)
  (text.rope-char-ref rope pos))

(define paren-pairs
  (hash #\( #\)
        #\[ #\]
        #\{ #\}))
```

3. `src/core/range.scm`
```scheme
(provide make-range
         range-start
         range-end
         range-contains?
         range-text
         position->offset
         offset->position)

(struct Range (start end) #:transparent)
```

**Testing:**
- [ ] Test paren matching with nested forms
- [ ] Test string handling: `"(foo)"`
- [ ] Test comment handling: `;; (bar)`
- [ ] Test character literals: `#\(`, `#\)`
- [ ] Test mixed paren types: `[({})]`

**Acceptance Criteria:**
- All parser tests pass
- Can correctly find matching parens in complex Clojure code
- Performance acceptable on 1000+ line files

### Week 2: Selection & Range Management

**Deliverables:**
- [ ] Selection API wrapper
- [ ] Range manipulation utilities
- [ ] Element boundary detection

**Files to Create:**
1. `src/core/selection.scm`
```scheme
(require (prefix-in hx. "helix/static.scm"))

(provide get-current-selection
         set-selection
         get-selection-range
         replace-selection
         get-cursor-position)

(define (get-current-selection)
  (hx.current-selection-object))

(define (set-selection range)
  (let ([start (range-start range)]
        [end (range-end range)])
    (hx.set-current-selection-object!
      (make-selection-object start end))))
```

2. `src/core/element.scm`
```scheme
(provide find-current-element
         find-next-element
         find-prev-element
         element-at-pos)

(define (find-current-element rope pos)
  ;; Scan backward to whitespace/paren
  ;; Scan forward to whitespace/paren
  ;; Return element range)

(define (find-next-element rope pos)
  ;; Skip whitespace and comments forward
  ;; Find element boundary
  ;; Return element range)
```

**Testing:**
- [ ] Selection creation and retrieval
- [ ] Element detection in various contexts
- [ ] Whitespace handling
- [ ] Comment skipping

**Acceptance Criteria:**
- Can correctly identify element boundaries
- Selection API works reliably
- Edge cases handled (start/end of file, empty forms)

### Week 3: Language Support & Configuration

**Deliverables:**
- [ ] Clojure-specific parsing
- [ ] Language detection
- [ ] Configuration system

**Files to Create:**
1. `src/lang/clojure.scm`
```scheme
(provide clojure-comment?
         clojure-string-delimiter?
         clojure-dispatch-macro?
         clojure-reader-macro?)

;; Clojure-specific rules
(define clojure-reader-macros
  (hash "@" 'deref
        "'" 'quote
        "`" 'syntax-quote
        "~" 'unquote
        "#" 'dispatch))

(define (clojure-comment? rope pos)
  ;; Check for ; or #_
  ;; Check for (comment ...) form)
```

2. `paredit.scm` (main entry point)
```scheme
(require (prefix-in hx. "helix/static.scm"))
(require "src/core/parser.scm")
(require "src/operations/slurp.scm")

(provide setup-paredit
         paredit-slurp-forward
         paredit-barf-forward)

(define paredit-config
  (hash 'enabled-languages '("clojure" "scheme")
        'cursor-behavior 'auto
        'auto-indent #t))

(define (setup-paredit #:config config)
  ;; Merge user config
  ;; Register keybindings
  ;; Setup language hooks)
```

**Testing:**
- [ ] Language detection works
- [ ] Clojure-specific features recognized
- [ ] Configuration merging works

**Acceptance Criteria:**
- Language-specific behavior implemented
- Configuration system functional
- Plugin loads without errors

## Phase 2: Basic Operations (Weeks 4-6)

### Week 4: Slurp & Barf

**Deliverables:**
- [ ] Slurp forwards/backwards
- [ ] Barf forwards/backwards
- [ ] Cursor behavior modes

**Files to Create:**
1. `src/operations/slurp.scm`
```scheme
(require "../core/parser.scm")
(require "../core/element.scm")

(provide slurp-forwards
         slurp-backwards)

(define (slurp-forwards)
  ;; 1. Find enclosing form
  ;; 2. Find closing delimiter
  ;; 3. Find next element after closing
  ;; 4. Delete closing delimiter
  ;; 5. Insert closing after next element
  ;; 6. Update cursor position based on mode

  (let* ([rope (get-current-rope)]
         [pos (get-cursor-position)]
         [form (find-enclosing-form rope pos)])
    (when form
      (let* ([close-pos (form-end form)]
             [next-elem (find-next-element rope close-pos)]
             [new-close-pos (range-end next-elem)])
        ;; Perform text modification
        (delete-char-at rope close-pos)
        (insert-char-at rope new-close-pos (closing-char form))
        ;; Handle cursor
        (update-cursor-position form 'slurp-forward)))))
```

2. `src/operations/barf.scm`
```scheme
(provide barf-forwards
         barf-backwards)

(define (barf-forwards)
  ;; 1. Find enclosing form
  ;; 2. Find last element in form
  ;; 3. Move closing delimiter before last element
  ;; 4. Update cursor

  (let* ([form (find-enclosing-form rope pos)]
         [last-elem (find-last-element-in-form rope form)])
    (when last-elem
      ;; Move closing delimiter
      (delete-char-at rope (form-end form))
      (insert-char-at rope (range-start last-elem)
                      (closing-char form)))))
```

**Testing:**
- [ ] Slurp/barf on various form types: `()`, `[]`, `{}`
- [ ] Nested form handling
- [ ] Cursor positioning in each mode (remain/follow/auto)
- [ ] Multi-element forms
- [ ] Empty forms

**Test Cases:**
```scheme
;; Slurp forward
"a (|)" => "(|a )"
"a (b|)" => "(b| a)"
"(a|) b c" => "(a| b) c"

;; Barf forward
"(a b|)" => "(a|) b"
"(|a b c)" => "(|a b) c"

;; Nested
"((a|) b)" => "((a| b))" ; slurp
"((a b|))" => "((a|) b)" ; barf
```

**Acceptance Criteria:**
- All basic slurp/barf operations work correctly
- Cursor behavior configurable
- No text corruption
- Handles edge cases gracefully

### Week 5: Text Objects

**Deliverables:**
- [ ] Around form (af)
- [ ] In form (if)
- [ ] Around element (ae)
- [ ] Element (ie)

**Files to Create:**
1. `src/text-objects/selections.scm`
```scheme
(provide select-around-form
         select-in-form
         select-around-element
         select-element)

(define (select-around-form)
  ;; Find enclosing form including delimiters
  (let ([form (find-enclosing-form rope (get-cursor-position))])
    (when form
      (set-selection (make-range (form-start form)
                                  (+ (form-end form) 1))))))

(define (select-in-form)
  ;; Find enclosing form excluding delimiters
  (let ([form (find-enclosing-form rope (get-cursor-position))])
    (when form
      (set-selection (make-range (+ (form-start form) 1)
                                  (form-end form))))))

(define (select-around-element)
  ;; Select current element
  (let ([elem (find-current-element rope (get-cursor-position))])
    (when elem
      (set-selection elem))))
```

**Testing:**
- [ ] af selects including parens
- [ ] if selects excluding parens
- [ ] ae/ie select current element
- [ ] Works with cursor at different positions
- [ ] Nested form selection

**Acceptance Criteria:**
- Text objects work with Helix verbs (d, c, y, v)
- Repeatable with `.` (if possible)
- Nested forms selected correctly
- Visual mode integration works

### Week 6: Motions

**Deliverables:**
- [ ] Element motions (W, B, E, gE)
- [ ] Form motions ((, ), [, ])

**Files to Create:**
1. `src/motions/element.scm`
```scheme
(provide move-to-next-element-head      ; W
         move-to-prev-element-head      ; B
         move-to-next-element-tail      ; E
         move-to-prev-element-tail)     ; gE

(define (move-to-next-element-head)
  ;; Skip whitespace/comments forward
  ;; Stop at next element start
  (let ([next-pos (scan-forward-to-element-start rope (get-cursor-position))])
    (when next-pos
      (move-cursor-to next-pos))))
```

2. `src/motions/form.scm`
```scheme
(provide move-to-parent-form-start      ; (
         move-to-parent-form-end        ; )
         move-to-top-level-form-head)   ; T

(define (move-to-parent-form-start)
  (let ([form (find-enclosing-form rope (get-cursor-position))])
    (when form
      (move-cursor-to (form-start form)))))
```

**Testing:**
- [ ] W moves to next element start
- [ ] B moves to previous element start
- [ ] E moves to next element end
- [ ] ( moves to parent form start
- [ ] ) moves to parent form end
- [ ] Works with visual mode

**Acceptance Criteria:**
- All motions implemented and working
- Compatible with Helix motion model
- Can be combined with verbs (dW, cB, etc.)
- Works in nested contexts

## Phase 3: Advanced Operations (Weeks 7-9)

### Week 7: Raise

**Deliverables:**
- [ ] Raise element
- [ ] Raise form

**Files to Create:**
1. `src/operations/raise.scm`
```scheme
(provide raise-element
         raise-form)

(define (raise-element)
  ;; 1. Find current element
  ;; 2. Find parent form
  ;; 3. Replace parent with element text

  (let* ([elem (find-current-element rope pos)]
         [parent (find-enclosing-form rope pos)])
    (when (and elem parent)
      (let ([elem-text (rope-substring rope elem)])
        (replace-range parent elem-text)))))

(define (raise-form)
  ;; Similar but preserve form structure
  (let* ([form (find-form-at-cursor rope pos)]
         [parent (find-enclosing-form rope (form-start form))])
    (when (and form parent)
      (let ([form-text (rope-substring rope form)])
        (replace-range parent form-text)))))
```

**Testing:**
- [ ] Raise element from nested position
- [ ] Raise form preserving structure
- [ ] Multiple nesting levels
- [ ] Edge cases (top-level, single element)

**Test Cases:**
```scheme
;; Raise element
"(a (b c|))" => "(a c|)"
"(+ 1 (* 2 3|))" => "(+ 1 3|)"

;; Raise form
"(a (b c|))" => "(b c|)"
"(outer (inner| elem))" => "(inner| elem)"
```

**Acceptance Criteria:**
- Raise operations work correctly
- Maintains proper spacing
- Cursor positioned appropriately

### Week 8: Drag

**Deliverables:**
- [ ] Drag element forwards/backwards
- [ ] Drag form forwards/backwards

**Files to Create:**
1. `src/operations/drag.scm`
```scheme
(provide drag-element-forwards
         drag-element-backwards
         drag-form-forwards
         drag-form-backwards)

(define (drag-element-forwards)
  ;; 1. Find current element
  ;; 2. Find next element
  ;; 3. Swap their positions (including whitespace)

  (let* ([elem1 (find-current-element rope pos)]
         [elem2 (find-next-element rope (range-end elem1))])
    (when (and elem1 elem2)
      (swap-text-ranges rope elem1 elem2))))

(define (swap-text-ranges rope range1 range2)
  ;; Extract text from both ranges
  ;; Delete in reverse order (range2 then range1)
  ;; Insert in correct order
  (let ([text1 (rope-substring rope range1)]
        [text2 (rope-substring rope range2)])
    ;; Perform swap with careful offset management
    (rope-replace rope range2 text1)
    (rope-replace rope range1 text2)))
```

**Testing:**
- [ ] Drag element right/left
- [ ] Drag form right/left
- [ ] Preserve whitespace
- [ ] Handle comments between elements
- [ ] Multiple consecutive drags

**Test Cases:**
```scheme
;; Drag element forward
"(a| b c)" => "(b a| c)"
"(foo| bar baz)" => "(bar foo| baz)"

;; Drag element backward
"(a b| c)" => "(b| a c)"

;; Drag form forward
"((a|) (b) (c))" => "((b) (a|) (c))"
```

**Acceptance Criteria:**
- Drag operations work smoothly
- Whitespace handled correctly
- Works with different element types
- No text corruption

### Week 9: Wrap & Unwrap

**Deliverables:**
- [ ] Wrap element
- [ ] Wrap form
- [ ] Unwrap/splice

**Files to Create:**
1. `src/operations/wrap.scm`
```scheme
(provide wrap-element-round      ; Wrap with ()
         wrap-element-square     ; Wrap with []
         wrap-element-curly      ; Wrap with {}
         wrap-form)

(define (wrap-element-round)
  ;; Find current element
  ;; Insert opening paren before
  ;; Insert closing paren after
  (let ([elem (find-current-element rope pos)])
    (when elem
      (insert-char-at rope (range-start elem) #\()
      (insert-char-at rope (+ (range-end elem) 1) #\)))))
```

2. `src/operations/unwrap.scm`
```scheme
(provide unwrap-form
         splice-form)

(define (unwrap-form)
  ;; Find enclosing form
  ;; Delete opening delimiter
  ;; Delete closing delimiter
  (let ([form (find-enclosing-form rope pos)])
    (when form
      (delete-char-at rope (form-end form))     ; Delete close first
      (delete-char-at rope (form-start form))))) ; Then delete open
```

**Testing:**
- [ ] Wrap with different paren types
- [ ] Unwrap preserves content
- [ ] Cursor positioning
- [ ] Nested unwrap

**Acceptance Criteria:**
- Wrap operations insert correct delimiters
- Unwrap removes only delimiters
- Content preserved correctly
- Works with all paren types

## Phase 4: Polish & Testing (Weeks 10-12)

### Week 10: Configuration & Keybindings

**Deliverables:**
- [ ] Full configuration system
- [ ] Default keybindings
- [ ] Custom keybinding support

**Updates to paredit.scm:**
```scheme
(define default-keybindings
  (hash "normal"
        (hash ">" (hash ")" 'paredit-slurp-forward
                        "(" 'paredit-barf-backward
                        "e" 'paredit-drag-element-forward
                        "f" 'paredit-drag-form-forward)
              "<" (hash ")" 'paredit-barf-forward
                        "(" 'paredit-slurp-backward
                        "e" 'paredit-drag-element-backward
                        "f" 'paredit-drag-form-backward)
              "W" 'paredit-move-to-next-element-head
              "B" 'paredit-move-to-prev-element-head
              "(" 'paredit-move-to-parent-form-start
              ")" 'paredit-move-to-parent-form-end)
        "select"
        (hash "a" (hash "f" 'paredit-select-around-form
                        "e" 'paredit-select-element)
              "i" (hash "f" 'paredit-select-in-form
                        "e" 'paredit-select-element))))

(define (setup-paredit . config)
  ;; Merge config
  ;; Register keybindings based on enabled languages
  (when (paredit-enabled-for-language?)
    (register-keybindings default-keybindings)))
```

**Testing:**
- [ ] Keybindings register correctly
- [ ] Custom keybindings override defaults
- [ ] Language-specific activation works

**Acceptance Criteria:**
- Configuration documented
- Keybindings work as expected
- User can customize easily

### Week 11: Performance Optimization

**Deliverables:**
- [ ] Benchmarking suite
- [ ] Performance optimizations
- [ ] Caching strategy

**Optimizations:**
1. **Parsing Cache**
```scheme
(define form-cache (make-hash))

(define (find-enclosing-form-cached rope pos)
  (let ([cache-key (rope-fingerprint rope)])
    (hash-try-get form-cache cache-key
      (lambda ()
        (let ([result (find-enclosing-form rope pos)])
          (hash-insert! form-cache cache-key result)
          result)))))
```

2. **Limit Scan Scope**
```scheme
(define (find-top-level-form rope pos)
  ;; Only scan within current top-level form
  ;; Don't scan entire file
  (let ([bounds (find-top-level-boundaries rope pos)])
    (find-enclosing-form
      (rope-slice rope (car bounds) (cdr bounds))
      (- pos (car bounds)))))
```

3. **Lazy Evaluation**
```scheme
(define (find-all-forms-in-buffer rope)
  ;; Return lazy sequence, not eager list
  (make-lazy-seq
    (lambda ()
      (scan-for-forms rope 0))))
```

**Benchmarking:**
- [ ] Measure operation times on various file sizes
- [ ] Profile hot paths
- [ ] Compare before/after optimization

**Targets:**
- Slurp/barf: < 50ms on 1000 line files
- Text objects: < 100ms
- Motions: < 50ms

**Acceptance Criteria:**
- Performance acceptable for daily use
- No noticeable lag on typical files
- Graceful degradation on very large files

### Week 12: Documentation & Release

**Deliverables:**
- [ ] README with installation and usage
- [ ] API documentation
- [ ] Configuration guide
- [ ] Comparison to nvim-paredit
- [ ] Changelog
- [ ] GitHub release

**Documentation Files:**

1. `README.md`
```markdown
# paredit.hx

Structural editing for Lisp languages in Helix editor.

## Features
- Slurp & Barf
- Raise form/element
- Drag element/form
- Text objects (af, if, ae, ie)
- Motions (W, B, E, (, ), etc.)

## Installation

### Using Forge
forge pkg install --git https://github.com/username/paredit.hx.git

### From Source
git clone ...
cd paredit.hx
cargo steel-lib

## Quick Start

Add to your init.scm:
(require "paredit/paredit.scm")
(setup-paredit)

## Keybindings
...
```

2. `docs/API.md`
- Document all public functions
- Include examples
- Parameter descriptions

3. `docs/CONFIGURATION.md`
- All config options
- Examples
- Language-specific settings

**Acceptance Criteria:**
- Documentation complete and accurate
- Installation instructions tested
- Ready for public release

## Testing Strategy

### Unit Tests

**Coverage Requirements:**
- Parser: 90%+ coverage
- Operations: 85%+ coverage
- Utilities: 80%+ coverage

**Test Organization:**
```
tests/
├── core/
│   ├── parser_test.scm
│   ├── element_test.scm
│   └── rope-utils_test.scm
├── operations/
│   ├── slurp_test.scm
│   ├── barf_test.scm
│   ├── raise_test.scm
│   └── drag_test.scm
└── integration/
    └── full_workflow_test.scm
```

**Test Utilities:**
```scheme
(define (test-operation before-text cursor-pos operation expected-text expected-cursor)
  ;; Setup rope with before-text
  ;; Position cursor at cursor-pos
  ;; Execute operation
  ;; Assert text equals expected-text
  ;; Assert cursor at expected-cursor)
```

### Integration Tests

**Scenarios to Test:**
- [ ] Complete editing session (multiple operations)
- [ ] Undo/redo compatibility
- [ ] Multi-cursor support (if applicable)
- [ ] Large file performance
- [ ] Real-world code samples

### Manual Testing

**Test Files:**
- Sample Clojure projects (various sizes)
- Edge case collections
- Performance test files (1000+ lines)

## Success Metrics

### MVP (3 months)
- [ ] 10 core operations implemented
- [ ] Works on Clojure files
- [ ] 5+ active users
- [ ] < 5 critical bugs

### Full Release (6 months)
- [ ] 20+ operations
- [ ] Clojure + Scheme support
- [ ] 50+ active users
- [ ] < 2 critical bugs
- [ ] Documentation complete
- [ ] Performance targets met

## Risk Mitigation

### Technical Risks

| Risk | Mitigation |
|------|------------|
| Performance too slow | Aggressive caching, limit scope, early benchmarking |
| Edge cases break parser | Extensive test suite, real-world testing |
| Helix API changes | Version pinning, monitor changes, modular design |
| User adoption low | Good docs, familiar keybindings, community outreach |

### Process Risks

| Risk | Mitigation |
|------|------------|
| Scope creep | Strict phase adherence, defer non-critical features |
| Burnout | Realistic timelines, community contributions welcome |
| Compatibility issues | Test on multiple Helix versions |

## Community & Contribution

### Initial Launch
- [ ] Post to Helix discussions
- [ ] Announce on Reddit r/Clojure, r/lisp
- [ ] Tweet announcement
- [ ] Create demo video

### Ongoing
- [ ] Encourage community contributions
- [ ] Responsive to issues
- [ ] Monthly releases
- [ ] Maintain changelog

## Future Enhancements (Post-MVP)

**6-12 months:**
- [ ] Pairwise dragging (map pairs, let bindings)
- [ ] Auto-indentation (like nvim-paredit)
- [ ] Visual feedback components
- [ ] Additional language support (Common Lisp, Fennel, Janet)
- [ ] Tree-sitter FFI (if accepted by Helix)

**12+ months:**
- [ ] LSP-based refactoring integration
- [ ] Custom reader macro support
- [ ] Structural search and replace
- [ ] Integration with REPL workflows
- [ ] Collaborative editing support

## Development Environment

### Required Tools
- Helix with Steel support (mattwparas/helix fork)
- Steel REPL (`steel-repl`)
- Forge package manager (`forge`)
- Rust toolchain (for native modules, if needed)

### Setup
```bash
# Install Helix with Steel
git clone https://github.com/mattwparas/helix
cd helix
cargo xtask steel

# Install Steel tools
cargo install --git https://github.com/mattwparas/steel.git steel-forge

# Clone paredit.hx
git clone https://github.com/username/paredit.hx
cd paredit.hx

# Install dependencies
forge install
```

### Development Workflow
1. Write code in `src/`
2. Write tests in `tests/`
3. Run tests: `steel tests/run_tests.scm`
4. Test in Helix: Reload via `:config-reload`
5. Iterate

### Debugging
- Use `displayln` for logging
- `:open-debug-window` in Helix shows Steel output
- Steel REPL for interactive testing
- Add `(log::info! ...)` calls liberally

## Dependencies

### Required
- `helix/core/text` - Rope operations
- `helix/commands` - Editor commands
- `helix/static` - Static commands

### Optional
- Custom Rust FFI module (if performance becomes critical)
- Tree-sitter-clojure (for potential future integration)

## License & Attribution

**License:** MIT (same as nvim-paredit)

**Attribution:**
- Inspired by nvim-paredit by julienvincent
- Based on Paredit by Phil Hagelberg and community
- Uses Helix Steel plugin system by mattwparas

## Appendix A: Complete Operation List

### Slurp & Barf (Priority 1)
- [x] `slurp-forwards` - >)
- [x] `slurp-backwards` - <(
- [x] `barf-forwards` - <)
- [x] `barf-backwards` - >(

### Drag (Priority 2)
- [ ] `drag-element-forwards` - >e
- [ ] `drag-element-backwards` - <e
- [ ] `drag-form-forwards` - >f
- [ ] `drag-form-backwards` - <f

### Raise (Priority 2)
- [ ] `raise-element` - <localleader>O
- [ ] `raise-form` - <localleader>o

### Wrap & Unwrap (Priority 3)
- [ ] `wrap-element-round` - (wrap with ())
- [ ] `wrap-element-square` - (wrap with [])
- [ ] `wrap-element-curly` - (wrap with {})
- [ ] `unwrap-form` - <localleader>@

### Text Objects (Priority 1)
- [x] `select-around-form` - af
- [x] `select-in-form` - if
- [x] `select-element` - ae/ie

### Motions (Priority 1)
- [x] `move-to-next-element-head` - W
- [x] `move-to-prev-element-head` - B
- [x] `move-to-next-element-tail` - E
- [x] `move-to-prev-element-tail` - gE
- [x] `move-to-parent-form-start` - (
- [x] `move-to-parent-form-end` - )
- [ ] `move-to-top-level-form-head` - T

### Future Operations (Priority 4)
- [ ] `drag-pair-forwards` - >p (requires pair detection)
- [ ] `drag-pair-backwards` - <p
- [ ] `delete-form`
- [ ] `delete-element`
- [ ] `kill-form` (delete with yank)
- [ ] `copy-form`
- [ ] `transpose-forms`

## Appendix B: Comparison to nvim-paredit

| Aspect | nvim-paredit | paredit.hx |
|--------|--------------|------------|
| **Foundation** | Tree-sitter queries | Manual parsing |
| **Language** | Lua | Steel Scheme |
| **Extensibility** | Query files | Language modules |
| **Performance** | Fast (AST) | Moderate (text scanning) |
| **Accuracy** | High (AST-based) | Good (parser-based) |
| **Line Count** | ~2000 LOC | ~1500 LOC (estimated) |
| **Dependencies** | Neovim, tree-sitter | Helix, Steel |
| **Setup** | Install plugin | Install via Forge |
| **Languages** | Clojure, Fennel, Scheme, CL, Janet | Clojure, Scheme (MVP) |

**Philosophy Difference:**
- nvim-paredit: Leverage tree-sitter for accuracy
- paredit.hx: Manual parsing for flexibility

## Appendix C: Reference Implementation Snippets

### Paren Matching (Core Algorithm)
```scheme
(define (find-matching-paren rope pos direction)
  (define (char-at i) (text.rope-char-ref rope i))
  (define (is-open? c) (member c '(#\( #\[ #\{)))
  (define (is-close? c) (member c '(#\) #\] #\})))
  (define (matches? open close)
    (or (and (equal? open #\() (equal? close #\)))
        (and (equal? open #\[) (equal? close #\]))
        (and (equal? open #\{) (equal? close #\}))))

  (let loop ([i pos] [depth 0] [in-string? #f] [escape? #f])
    (cond
      [(>= i (text.rope-len-chars rope)) #f]  ; End of file
      [(< i 0) #f]                            ; Start of file
      [else
       (let ([ch (char-at i)])
         (cond
           [escape? (loop (+ i direction) depth in-string? #f)]
           [(equal? ch #\\) (loop (+ i direction) depth in-string? #t)]
           [(equal? ch #\") (loop (+ i direction) depth (not in-string?) #f)]
           [in-string? (loop (+ i direction) depth in-string? #f)]
           [(and (equal? direction 1) (is-open? ch))
            (loop (+ i direction) (+ depth 1) in-string? #f)]
           [(and (equal? direction 1) (is-close? ch))
            (if (and (= depth 0) (matches? (char-at pos) ch))
                i
                (loop (+ i direction) (- depth 1) in-string? #f))]
           [(and (equal? direction -1) (is-close? ch))
            (loop (+ i direction) (+ depth 1) in-string? #f)]
           [(and (equal? direction -1) (is-open? ch))
            (if (and (= depth 0) (matches? ch (char-at pos)))
                i
                (loop (+ i direction) (- depth 1) in-string? #f))]
           [else (loop (+ i direction) depth in-string? #f)]))])))
```

This is a complete implementation blueprint for paredit.hx.
