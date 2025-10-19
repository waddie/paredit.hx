# Helix Paredit Implementation - Feasibility Study

**Date:** October 19, 2025
**Author:** AI Code Assistant
**Purpose:** Evaluate the feasibility of implementing paredit functionality for Helix editor using Steel Scheme plugins

## Executive Summary

**Verdict: FEASIBLE WITH SIGNIFICANT LIMITATIONS**

Implementing paredit for Helix using Steel Scheme plugins is technically feasible but will require a fundamentally different approach than nvim-paredit. The key limitation is that **Helix does not expose tree-sitter APIs to Steel plugins**, requiring manual s-expression parsing. However, Helix provides sufficient text manipulation, selection, and command APIs to implement most paredit operations.

## Key Findings

### 1. Critical Limitation: No Tree-Sitter Access from Steel

The Helix Steel FFI **does not expose tree-sitter functionality** to plugins:
- No direct AST node access
- No tree-sitter query API
- No syntax tree traversal
- No incremental parsing information

**Impact:** All s-expression identification and navigation must be implemented through manual text parsing using Rope operations.

**Evidence:** Analysis of `/Users/waddie/source/helix/helix-term/src/commands/engine/steel/mod.rs` (6,105 lines, 173+ registered functions) shows no tree-sitter related FFI bindings.

### 2. Available APIs for Implementation

Despite the tree-sitter limitation, Helix provides comprehensive APIs:

#### Text Manipulation (helix/core/text module)
- **Rope operations**: Character/byte/line slicing, insertion, modification
- **Efficient text access**: Large file handling via Rope data structure
- **Position conversions**: char↔byte↔line offset conversions
- **Regex on Ropes**: Pattern matching, finding, splitting

#### Editor Commands (helix/commands.scm)
- **Selection manipulation**:
  - `current-selection-object`, `set-current-selection-object!`
  - `push-range-to-selection!`, `remove-current-selection-range!`
  - `replace-selection-with`
- **Built-in tree-sitter commands** (can be invoked, but not queried):
  - `expand_selection` - Expand to parent syntax node
  - `shrink_selection` - Shrink to previously expanded node
  - `select_next_sibling` / `select_prev_sibling` - Navigate syntax tree
  - `select_textobject_around` / `select_textobject_inner`
  - `move_parent_node_start` / `move_parent_node_end`
- **Surround operations**: `surround_add`, `surround_replace`, `surround_delete`
- **Text insertion**: `insert_char`, `insert_string`

#### Document Access
- `editor->text` - Get document as Rope
- `editor-document->path`, `editor-document->language`
- `get-current-line-number`, `cx->pos`
- `current_selection`, `current-highlighted-text!`

#### Plugin Infrastructure
- `push-component!` - Create UI overlays/widgets
- `new-component!` - Build interactive components
- Event handling and keybinding system
- Background task execution via `enqueue-thread-local-callback`

### 3. Existing Example: scheme-indent.scm

The `helix-config/cogs/scheme-indent.scm` plugin demonstrates:
- Manual s-expression parsing via character-by-character traversal
- Paren matching by walking text backwards
- Depth tracking for nested structures
- Integration with Helix's indent system
- Use of Rope API for efficient text access

**Key insight:** This proves that structural Lisp operations can be implemented without tree-sitter by manual parsing.

### 4. Gap Analysis vs nvim-paredit

| Feature | nvim-paredit | Helix Steel Implementation |
|---------|--------------|----------------------------|
| **Language Detection** | Tree-sitter queries | Manual parsing OR language detection via `editor-document->language` |
| **Form Identification** | `@form` captures | Manual paren matching |
| **Node Traversal** | Recursive AST walking | Character iteration + depth tracking |
| **Form Edges** | Anonymous node detection | String-based delimiter finding |
| **Cursor Positioning** | Node range APIs | Position math + Rope offsets |
| **Text Modification** | Neovim buf APIs | Rope manipulation + `replace-selection-with` |
| **Performance** | O(log n) tree queries | O(n) text scanning (slower) |
| **Accuracy** | AST-guaranteed | Best-effort via parsing |

### 5. Steel Scheme Capabilities

Steel is a **Scheme dialect embedded in Rust** with:
- R7RS-small compliance (mostly)
- Functional programming: first-class functions, closures, tail recursion
- Mutable state: `set!`, mutable structs
- Pattern matching: `cond`, destructuring
- Macros: `syntax-rules`, `define-syntax`
- FFI: Rust integration, C-compatible
- Standard library: lists, vectors, hashmaps, hashsets
- Regex support
- String manipulation

**Strengths for paredit:**
- Character/string manipulation
- Recursive algorithms (well-suited for paren matching)
- Stateful tracking (for depth, position)
- Pattern matching for different paren types

## Detailed API Mapping

### Paredit Operation → Helix Steel Implementation

#### 1. Slurp/Barf
**nvim-paredit approach:**
- Query tree-sitter for form node
- Find form edges via anonymous nodes
- Calculate new delimiter positions
- Modify buffer

**Helix Steel approach:**
```scheme
;; Pseudo-code
(define (slurp-forward)
  (let* ([rope (editor->text (editor->doc-id (editor-focus)))]
         [pos (cx->pos)]
         [form-info (find-enclosing-form rope pos)])  ; Manual parsing
    (when form-info
      (let ([new-close-pos (find-next-element-end rope (form-close form-info))])
        (delete-at-position rope (form-close form-info))
        (insert-at-position rope new-close-pos ")")))))
```

**Implementation strategy:**
1. Parse backward from cursor to find opening paren
2. Track depth to find matching closing paren
3. Find next/previous element boundary
4. Move delimiter characters via deletion + insertion

#### 2. Drag Element
**nvim-paredit approach:**
- Identify current element via tree-sitter
- Find next/previous element
- Swap text ranges

**Helix Steel approach:**
```scheme
(define (drag-element-forward)
  (let* ([rope (editor->text doc-id)]
         [elem-range (find-current-element rope pos)]  ; Manual parsing
         [next-range (find-next-element rope (range-end elem-range))])
    (swap-text-ranges rope elem-range next-range)))
```

**Implementation strategy:**
1. Identify element boundaries by scanning for whitespace/parens
2. Skip comments (by pattern matching `;`)
3. Select both ranges
4. Transpose text content

#### 3. Raise Form/Element
**nvim-paredit approach:**
- Find enclosing form via tree-sitter parent navigation
- Get child element/form
- Replace parent range with child text

**Helix Steel approach:**
```scheme
(define (raise-element)
  (let* ([elem-text (get-element-at-cursor)]
         [parent-range (find-enclosing-form rope pos)])
    (replace-range parent-range elem-text)))
```

#### 4. Text Object Selections
**nvim-paredit approach:**
- Tree-sitter captures for `@form` nodes
- Range extraction from AST

**Helix Steel approach:**
```scheme
(define (select-around-form)
  (let ([form-range (find-enclosing-form rope pos)])
    (set-selection-to-range form-range)))
```

**Alternative:** Could potentially add Clojure/Scheme textobjects.scm queries to Helix runtime and use built-in `select_textobject_around` command.

#### 5. Motions (W, B, E, gE)
**nvim-paredit approach:**
- Tree-sitter navigation between element nodes

**Helix Steel approach:**
```scheme
(define (move-to-next-element-head)
  (let ([next-pos (scan-forward-to-element-start rope pos)])
    (move-cursor-to next-pos)))
```

**Implementation strategy:**
- Scan forward/backward skipping whitespace and comments
- Stop at paren boundaries or symbol starts
- Use `helix.static.move_*` commands or direct cursor positioning

## Implementation Challenges

### Major Challenges

1. **Performance**
   - Tree-sitter: O(log n) queries
   - Manual parsing: O(n) character scanning
   - **Mitigation:**
     - Cache parsed structure per edit
     - Limit scanning to current top-level form
     - Use Steel's efficient Rope operations

2. **Edge Cases**
   - Strings containing parens: `"(foo)"`
   - Character literals: `#\(`, `#\)`
   - Comments: `;; (not a form)`
   - Reader macros: `#(`, `@form`, `^metadata`
   - **Mitigation:**
     - Implement proper Clojure/Scheme reader logic
     - Reuse patterns from scheme-indent.scm
     - Extensive test coverage

3. **Language Support**
   - nvim-paredit: Extensible via tree-sitter queries
   - Helix Steel: Requires separate parsing logic per language
   - **Mitigation:**
     - Start with Clojure only
     - Design modular language backends
     - Share common paren-matching logic

4. **Cursor Behavior**
   - nvim-paredit: Fine-grained control via Neovim API
   - Helix: Less cursor control, relies on selection model
   - **Mitigation:**
     - Work with Helix's selection-first model
     - Use `set-current-selection-object!` for positioning

### Minor Challenges

1. **Indentation**
   - nvim-paredit: Custom native indentor
   - Helix: Can use `hx.custom-insert-newline` (see scheme-indent.scm)
   - **Solution:** Implement similar indentation logic

2. **Dot Repeat**
   - nvim-paredit: Explicit dot-repeat support
   - Helix: No direct equivalent in Steel
   - **Limitation:** May not be achievable

3. **Visual Feedback**
   - nvim-paredit: Built-in Neovim UI
   - Helix: Component system available
   - **Solution:** Use `push-component!` for visual indicators

## Recommended Implementation Strategy

### Phase 1: Core Infrastructure (2-3 weeks)

**Goal:** Build foundation for s-expression parsing

1. **Paren Matching Engine**
   ```scheme
   (provide find-matching-paren
            find-enclosing-form
            find-form-boundaries
            find-element-boundaries)
   ```
   - Implement depth-tracking parser (similar to scheme-indent.scm)
   - Handle strings, comments, character literals
   - Support `()`, `[]`, `{}` pairs
   - Test extensively with edge cases

2. **Position and Range Utilities**
   ```scheme
   (provide rope-position->offset
            offset->rope-position
            make-range
            range-contains?
            range-text)
   ```
   - Wrapper around Rope offset conversions
   - Range manipulation helpers

3. **Selection Management**
   ```scheme
   (provide select-range
            get-current-range
            replace-current-selection)
   ```
   - Interface with Helix selection APIs
   - Handle multi-selection (if needed)

### Phase 2: Basic Operations (2-3 weeks)

**Goal:** Implement fundamental paredit operations

1. **Text Objects**
   - `select-around-form` (af)
   - `select-in-form` (if)
   - `select-element` (ae/ie)

2. **Motions**
   - `move-to-next-element-head` (W)
   - `move-to-prev-element-head` (B)
   - `move-to-parent-form-start` (()
   - `move-to-parent-form-end` ())

3. **Basic Editing**
   - `slurp-forwards` (>))
   - `barf-forwards` (<))
   - `raise-element` (<localleader>O)

### Phase 3: Advanced Operations (2-3 weeks)

**Goal:** Complete paredit feature set

1. **Dragging**
   - `drag-element-forwards` (>e)
   - `drag-element-backwards` (<e)
   - Pairwise dragging (optional, complex)

2. **More Editing**
   - `raise-form` (<localleader>o)
   - `unwrap-form` (<localleader>@)
   - `wrap-element`

3. **Slurp/Barf Variants**
   - All directional variants
   - Cursor behavior modes (remain/follow/auto)

### Phase 4: Polish & Optimization (1-2 weeks)

1. **Performance**
   - Benchmark operations
   - Add caching for repeated queries
   - Optimize hot paths

2. **User Experience**
   - Keybinding configuration
   - Visual feedback for operations
   - Error messages

3. **Documentation**
   - Usage guide
   - Configuration examples
   - Comparison to nvim-paredit

## Alternative Approaches

### Option A: Hybrid with Built-in Commands

**Idea:** Use Helix's built-in tree-sitter commands where possible

```scheme
;; Leverage expand_selection for form selection
(define (select-form)
  (helix.static.expand_selection)  ; Use built-in tree-sitter
  ;; Then validate/adjust selection boundaries
  (validate-form-selection))
```

**Pros:**
- Reuse existing tree-sitter functionality
- Less code to maintain
- Potentially more accurate

**Cons:**
- Still need manual parsing for most operations
- Helix commands may not match paredit semantics exactly
- Limited to what Helix exposes

### Option B: Propose Tree-Sitter FFI to Helix

**Idea:** Contribute tree-sitter API bindings to Helix Steel FFI

**Required APIs:**
```rust
// Proposed additions to helix-term/src/commands/engine/steel/mod.rs
fn tree_sitter_node_at_cursor() -> SteelVal
fn tree_sitter_query() -> SteelVal
fn tree_sitter_node_range() -> SteelVal
fn tree_sitter_node_children() -> SteelVal
fn tree_sitter_node_parent() -> SteelVal
fn tree_sitter_node_type() -> SteelVal
```

**Pros:**
- Would enable proper paredit implementation
- Benefits all Steel plugins
- Aligns with nvim-paredit approach

**Cons:**
- Requires upstream contribution
- Long timeline (months)
- May not align with Helix maintainers' vision

**Recommendation:** File an issue with Helix project to gauge interest

### Option C: External Parser via FFI

**Idea:** Write a Rust crate that parses s-expressions, expose via Steel FFI

```scheme
(require-builtin paredit-parser as pp::)

(define form-info (pp::parse-form rope pos))
```

**Pros:**
- Rust performance for parsing
- Reusable across Steel plugins
- Can use proper parser libraries (e.g., tree-sitter-clojure directly)

**Cons:**
- Requires building native library
- Distribution complexity
- Still missing tree-sitter integration

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Performance too slow | Medium | High | Caching, limit scan scope, optimize hot paths |
| Edge cases unhandled | High | Medium | Extensive testing, incremental features |
| User adoption low | Medium | Low | Good docs, familiar keybindings |
| Maintenance burden | Medium | Medium | Modular design, good test coverage |
| Helix API changes | Low | High | Monitor Helix releases, version pinning |

## Recommendations

### Proceed with Implementation: YES

**Reasoning:**
1. Core paredit operations are implementable without tree-sitter
2. Steel provides sufficient text manipulation APIs
3. Existing scheme-indent.scm demonstrates feasibility
4. Fills a real gap (no s-expression text objects in Helix)
5. Valuable even if performance is suboptimal

### Suggested Roadmap

**Short Term (3 months):**
- Implement Phase 1-2 (core + basic operations)
- Focus on Clojure only
- Get user feedback early

**Medium Term (6 months):**
- Complete Phase 3-4
- Add Scheme support
- Performance optimization

**Long Term (12+ months):**
- Explore tree-sitter FFI contribution to Helix
- Add more language support
- Advanced features (auto-indent, etc.)

### Development Priorities

1. **Must Have:**
   - Slurp/barf (forwards/backwards)
   - Form/element text objects
   - Basic motions (W, B, (, ))
   - Raise element

2. **Should Have:**
   - Drag element
   - Wrap/unwrap
   - All motion variants
   - Cursor behavior modes

3. **Nice to Have:**
   - Pairwise dragging
   - Auto-indentation
   - Multiple language support
   - Visual feedback components

## Conclusion

Implementing paredit for Helix using Steel Scheme plugins is **feasible and recommended**, with the understanding that:

1. **It will be fundamentally different** from nvim-paredit due to lack of tree-sitter access
2. **Performance will be slower** due to manual text parsing
3. **Edge cases will be harder** to handle correctly
4. **Maintenance will be higher** due to manual parsing logic

However, the benefits outweigh the costs:
- Fills a real gap in Helix ecosystem
- Demonstrates Steel plugin capabilities
- Provides valuable structural editing for Lisp programmers
- Could drive improvements to Helix Steel FFI

**Next steps:**
1. Create proof-of-concept for paren matching engine
2. Implement 2-3 basic operations (slurp, text objects)
3. Gather community feedback
4. Decide whether to continue full implementation

---

**Appendix A: Key File Locations**

- Helix Steel FFI: `/Users/waddie/source/helix/helix-term/src/commands/engine/steel/mod.rs`
- Rope API: `/Users/waddie/source/helix/helix-core/src/extensions.rs`
- Components API: `/Users/waddie/source/helix/helix-term/src/commands/engine/steel/components.rs`
- Example indent plugin: `/Users/waddie/source/nrepl.hx/steel-resources/helix-config/cogs/scheme-indent.scm`
- Steel docs: `/Users/waddie/source/nrepl.hx/steel-resources/steel-docs.md`

**Appendix B: Relevant nvim-paredit Files for Reference**

- Tree-sitter integration: `lua/nvim-paredit/treesitter/forms.lua`
- Slurp/barf: `lua/nvim-paredit/api/slurping.lua`, `lua/nvim-paredit/api/barfing.lua`
- Dragging: `lua/nvim-paredit/api/dragging.lua`
- Motions: `lua/nvim-paredit/api/motions.lua`
- Test patterns: `tests/nvim-paredit/slurp_spec.lua`
