# paredit.hx

Structural editing for Lisp languages in Helix, written in Steel Scheme. It uses
Helix’s tree-sitter API to provide slurp, barf, raise, splice, drag, split, and
join operations for Clojure, Common Lisp, Fennel, Janet and Scheme.

paredit.hx implements only the structural edits Helix does not already provide.
Navigation, selection, wrapping, and pair matching are left to Helix’s built-in
tree-sitter commands (see “Relationship to Helix built-ins” below).

## Installation

The plugin expects `paredit.scm` and the `cogs/paredit/` directory to sit under
your Helix runtime configuration directory (for example `~/.config/helix/`), so
that the module paths such as `cogs/paredit/ts.scm` resolve.

1. Place the repository contents there, for example by symlinking:

   ```sh
   ln -s /path/to/paredit.hx/paredit.scm ~/.config/helix/paredit.scm
   ln -s /path/to/paredit.hx/cogs/paredit ~/.config/helix/cogs/paredit
   ```

2. Load it from your Steel init (`~/.config/helix/init.scm`):

   ```scheme
   (require "paredit.scm")
   ```

3. Reload with `:config-reload`, or restart Helix.

The commands listed below are then available as typable commands, for example
`:slurp-forward`.

## Commands

| Command                  | Effect                                                          |
| ------------------------ | --------------------------------------------------------------- |
| `:barf-backward`         | Eject the first element out of the current form                 |
| `:barf-forward`          | Eject the last element out of the current form                  |
| `:drag-element-backward` | Swap the current element with the previous sibling              |
| `:drag-element-forward`  | Swap the current element with the next sibling                  |
| `:drag-form-backward`    | Swap the enclosing form with the previous sibling               |
| `:drag-form-forward`     | Swap the enclosing form with the next sibling                   |
| `:drag-pair-backward`    | Swap the current key/value pair with the previous pair          |
| `:drag-pair-forward`     | Swap the current key/value pair with the next pair              |
| `:paredit-join`          | Join the form or string before the cursor with the one after it |
| `:paredit-split`         | Split the form or string at the cursor into two                 |
| `:raise-element`         | Replace the enclosing form with the current element             |
| `:raise-form`            | Replace the enclosing form with the current form                |
| `:slurp-backward`        | Extend the current form leftward over the prev element          |
| `:slurp-forward`         | Extend the current form rightward over the next element         |
| `:splice-form`           | Remove the enclosing form’s delimiters, keeping contents        |

Which element or form a command acts on is decided by the tree-sitter node under
the cursor. With the cursor on a symbol, an element operation acts on that
symbol; with the cursor on an opening delimiter, it acts on the whole form.

`:paredit-split` cuts the enclosing form (or string) at the cursor into two:
`(a| b)` becomes `(a) (b)`, and `"a| b"` becomes `"a" "b"`. The cut falls at the
exact cursor position, mid-token included. `:paredit-join` is the inverse, merging
the form (or string) before the cursor with the one after it: `(a)| (b)` becomes
`(a b)`. Joining forms of different bracket types adopts the left form’s brackets,
so `(a) [b]` becomes `(a b)`. Inside a string, whitespace is treated as content.
Split keeps it and join never inserts it.

## Supported languages

| Language    | Helix id      | Pairs (drag-pair)                                               |
| ----------- | ------------- | --------------------------------------------------------------- |
| Clojure     | `clojure`     | Yes: `let`/`loop`/`binding`/`case`/`cond`/`condp`, maps         |
| Common Lisp | `common-lisp` | No query; bindings nest, so element drag moves them             |
| Fennel      | `fennel`      | No query; `binding_pair` grouping makes element drag move pairs |
| Janet       | `janet`       | Yes: struct, table, `cond`, `case`, `match`                     |
| Scheme      | `scheme`      | No query; bindings nest, so element drag moves them             |

For `drag-pair`, when the cursor is not inside a recognised pairwise context the
command falls back to an element drag. In Scheme and Common Lisp, bindings are
nested lists, so an element drag already moves the whole binding. In Janet, the
`let` binding container is a square-bracket tuple, which the upstream pairs query
does not match, so `drag-pair` on a Janet `let` falls back to an element drag.

## Keybindings

You can bind the provided commands in `init.scm` using the `keymap` form.

The bindings below group the operations by direction under two sub-menus:
`<space>>` for the forward operations and `<space><` for the backward ones for
both `normal` and `select` mode.

The direction-agnostic operations (`raise-form`, `raise-element`, `splice-form`,
`paredit-split`, `paredit-join`) appear under both sub-menus.

In `init.scm`, after `(require "paredit.scm")`:

```scheme
(keymap (global)
        (normal (space (> (s ":slurp-forward")
                          (b ":barf-forward")
                          (e ":drag-element-forward")
                          (f ":drag-form-forward")
                          (p ":drag-pair-forward")
                          (r ":raise-form")
                          (R ":raise-element")
                          (x ":splice-form")
                          (S ":paredit-split")
                          (j ":paredit-join"))))
        (select (space (> (s ":slurp-forward")
                          (b ":barf-forward")
                          (e ":drag-element-forward")
                          (f ":drag-form-forward")
                          (p ":drag-pair-forward")
                          (r ":raise-form")
                          (R ":raise-element")
                          (x ":splice-form")
                          (S ":paredit-split")
                          (j ":paredit-join")))))
(keymap (global)
        (normal (space (< (s ":slurp-backward")
                          (b ":barf-backward")
                          (e ":drag-element-backward")
                          (f ":drag-form-backward")
                          (p ":drag-pair-backward")
                          (r ":raise-form")
                          (R ":raise-element")
                          (x ":splice-form")
                          (S ":paredit-split")
                          (j ":paredit-join"))))
        (select (space (< (s ":slurp-backward")
                          (b ":barf-backward")
                          (e ":drag-element-backward")
                          (f ":drag-form-backward")
                          (p ":drag-pair-backward")
                          (r ":raise-form")
                          (R ":raise-element")
                          (x ":splice-form")
                          (S ":paredit-split")
                          (j ":paredit-join")))))
```

So `<space>>s` slurps forward and `<space><s` slurps backward. The sub-keys are
`s` slurp, `b` barf, `e` drag element, `f` drag form, `p` drag pair, `r` raise
form, `R` raise element, `x` splice, `S` split, `j` join. Split and join are
direction-agnostic, so they behave the same under either sub-menu.

## Relationship to Helix built-ins

paredit.hx does not provide motions, text-object selections, or wrapping,
because Helix’s tree-sitter integration already covers them:

| Want to                          | Use                                        |
| -------------------------------- | ------------------------------------------ |
| Select around / in a form        | `ma(` / `mi(` (match around / in a pair)   |
| Select an element / parent form  | `A-o` / `A-i` (expand / shrink selection)  |
| Move to next / prev element      | `A-n` / `A-p` (select next / prev sibling) |
| Jump between matching delimiters | `mm` (match bracket)                       |
| Wrap a selection                 | `ms<char>` (surround add)                  |

To wrap a form, select it (for example with `mi(` or `A-o`) and then `ms(`.

## Diagnostics

These commands report through the statusline and do not modify the buffer:

| Command                  | Effect                                                                               |
| ------------------------ | ------------------------------------------------------------------------------------ |
| `:paredit-inspect`       | Report the language, the node kind at the cursor, and the enclosing form             |
| `:paredit-print-tree`    | Copy the enclosing form’s tree-sitter subtree to the system clipboard (register `+`) |
| `:paredit-inspect-pairs` | Report the `@pair` nodes the pairs query finds in the current top-level form         |

## Cursor behaviour

After a slurp or barf, where the cursor lands is governed by a configurable mode,
set from `init.scm` with `(set-paredit-cursor-behaviour! 'mode)`:

| Mode     | Effect                                                                                        |
| -------- | --------------------------------------------------------------------------------------------- |
| `remain` | Keep the cursor at its original position                                                      |
| `follow` | Move the cursor to the delimiter that moved                                                   |
| `auto`   | Keep it in place, unless barfing swept it out of the form, then snap it back inside (default) |

The default is `auto`. Because slurp only grows the form, the cursor never falls
out of bounds, so `auto` and `remain` behave identically for slurp; they differ
only for barf when the cursor sat on the ejected element. Drag, raise, and splice
use fixed cursor placement and are unaffected by this setting.

## Limitations

- `drag-pair` depends on a per-language pairs query; see the language table for
  current coverage.

## Attribution

- Inspired by nvim-paredit by Julien Vincent.
- Based on Paredit by Taylor R Campbell.
- Uses the Helix Steel plugin system by Matthew Paras.

## License

AGPL-3.0-or-later. See `LICENSE`.
