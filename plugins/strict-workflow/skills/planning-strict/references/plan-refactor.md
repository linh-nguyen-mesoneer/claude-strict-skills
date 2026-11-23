# Refactor Tasks (planning-strict)

Task rules for a refactor task: one that changes structure (extract, move, rename, rewrite a query, config with no behavior change) and no observable behavior. Read with `plan-core.md` (its test-level and test-strength rules apply here too). The plan's job is to prove nothing observable moved.

**No honest failing test exists; never invent one.** Steps: name the existing tests that cover the behavior (none or partial → first add characterization tests that pass on the current code) → run them, expect PASS → change (full code) → run them again, expect PASS → commit checkpoint. Write `RED: n/a — behavior-preserving, covered by <tests>` in the task.

**Characterization tests** pin what the code does today, including the odd parts others may rely on: result order, error types and messages, rounding, nulls and missing rows, side effects such as commits or log lines. A characterization test that fails on the current code has found a bug: report it, route it to `bugfix-strict`, and do not fix it inside the refactor.

**Impact Map:** every caller of a changed symbol is `unchanged`, with the test that pins it. A caller whose behavior would change means this is not a refactor: split that change into a feature task (`plan-feature.md`) or take it to the Requirements Gate.

**Requirements Gate for refactors:** usually only scope (what is in or out) and which non-functional changes are acceptable (query count, latency, memory, log output). Existing Data & States is `none: no persisted change` unless the refactor moves or reshapes stored data, which makes that part a feature task.

**Performance refactors** add a measurement step with the command and the before/after numbers (query count, timing, allocations), and keep the behavior tests above.

**Task size:** one extract, move, or rewrite per task. Mechanical renames list every reference updated and the search that found them.
