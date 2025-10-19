# paredit.hx

Structural editing for Lisp languages in Helix editor using Steel Scheme.

## Project Status

**Phase 1: Foundation - COMPLETE** ✓

Core parsing infrastructure has been implemented and validated.

### Completed Components

**Core Parsing Engine** (cogs/paredit/core/):
- `rope-utils.scm` - Rope operation wrappers and character utilities
- `range.scm` - Position/range abstractions and Form structures
- `parser.scm` - S-expression parsing with depth tracking
  - Paren matching (forward/backward with depth tracking)
  - String handling (skip parens inside strings)
  - Comment handling (line comments with `;`)
  - Character literal handling (`#\(`, `#\)`, etc.)
  - Form boundary detection
  - Top-level form finding
- `selection.scm` - Helix selection API wrappers
- `element.scm` - Element boundary detection
  - Find current/next/previous elements
  - Whitespace and comment skipping

**Language Support** (cogs/paredit/lang/):
- `clojure.scm` - Clojure-specific parsing
  - Reader macro detection (`@`, `'`, `` ` ``, `~`, `^`, `#`)
  - Dispatch macro handling (`#(`, `#{`, `#_`, `#"`, `#'`)
  - Comment form detection (`(comment ...)`)

**Main Entry Point**:
- `paredit.scm` - Plugin configuration and setup
  - Language detection
  - Configuration system
  - Module re-exports

### Implementation Stats

- **Files**: 7 Steel Scheme modules
- **Lines of Code**: 1,125
- **Validation**: All files pass tree-sitter structural validation
- **Edge Cases Handled**:
  - Strings containing parens: `"(foo)"`
  - Character literals: `#\(`, `#\)`
  - Line comments: `; (not a form)`
  - Nested forms: `((a (b)) c)`
  - Mixed paren types: `[({})]`
  - Clojure reader macros

### Key Design Decisions

1. **Manual Parsing**: No tree-sitter access from Steel plugins
2. **Depth Tracking**: Character-by-character traversal with paren depth
3. **Context Awareness**: Skip parens in strings, comments, char literals
4. **Modular Design**: Separate language-specific parsing rules
5. **Rope-Based**: Efficient text access via Helix's Rope API

## Architecture

```
paredit.hx/
├── paredit.scm                # Main entry point, public API
├── cogs/paredit/
│   ├── core/                  # Core parsing and utilities
│   │   ├── parser.scm         # S-expression parsing engine
│   │   ├── range.scm          # Position/range utilities
│   │   ├── rope-utils.scm     # Rope operation wrappers
│   │   ├── selection.scm      # Selection management
│   │   └── element.scm        # Element boundary detection
│   ├── operations/            # Paredit operations (Phase 2)
│   ├── motions/               # Motion commands (Phase 2)
│   ├── text-objects/          # Text object selections (Phase 2)
│   └── lang/                  # Language-specific parsing
│       └── clojure.scm        # Clojure reader rules
└── tests/                     # Test suite (pending)
```

## API Overview (Phase 1)

### Core Parsing Functions

```scheme
(require "paredit.scm")

;; Find matching paren
(find-matching-paren rope pos direction)  ; direction: 1=forward, -1=backward

;; Find enclosing form
(find-enclosing-form rope pos)  ; Returns Form structure or #f

;; Element navigation
(find-current-element rope pos)
(find-next-element rope pos)
(find-prev-element rope pos)

;; Boundary scanning
(scan-forward-to-boundary rope pos)
(scan-backward-to-boundary rope pos)
```

### Configuration

```scheme
;; Setup paredit with default config
(setup-paredit)

;; Custom configuration
(setup-paredit
  #:config (hash 'enabled-languages '("clojure" "scheme")
                 'cursor-behavior 'remain
                 'auto-indent #t))

;; Check if enabled
(paredit-enabled?)  ; #t or #f
```

## Next Steps: Phase 2

**Basic Operations** (Weeks 4-6):
- [ ] Slurp/barf (forwards/backwards)
- [ ] Text objects (af, if, ae, ie)
- [ ] Motions (W, B, E, (, ))
- [ ] Cursor behavior modes

## Development

### Requirements

- Helix with Steel support
- Steel REPL for testing

### Testing in Helix

```bash
# Load in Helix
:config-reload

# View debug output
:open-debug-window
```

### Validation

```bash
# Validate all Scheme files
python3 /path/to/lisp-validator/scripts/validate_tree_sitter.py cogs/
```

## Design Constraints

**Critical Limitation**: Helix does not expose tree-sitter APIs to Steel plugins.

This means:
- All parsing is manual (character-by-character)
- Performance is O(n) text scanning vs O(log n) tree queries
- Edge cases require careful handling
- More test coverage needed

**Mitigation strategies**:
- Cache parsed results
- Limit scanning to current top-level form
- Efficient Rope operations
- Comprehensive test suite

## References

- **Feasibility Study**: `progress-docs/HELIX_PAREDIT_FEASIBILITY.md`
- **Implementation Plan**: `progress-docs/HELIX_PAREDIT_IMPLEMENTATION_PLAN.md`
- **Project Guidelines**: `CLAUDE.md`

## Attribution

- Inspired by nvim-paredit by julienvincent
- Based on Paredit by Phil Hagelberg
- Uses Helix Steel plugin system by mattwparas

## License

AGPL-3.0-or-later

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

