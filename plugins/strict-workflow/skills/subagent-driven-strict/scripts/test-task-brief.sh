#!/usr/bin/env bash
# Tests for task-brief. Builds throwaway repos under a temp dir and asserts on
# the brief contents and exit codes.
#
# Usage: test-task-brief.sh
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
# Deployed name, or the chezmoi source name when run from the dotfiles repo.
brief="$script_dir/task-brief"
[ -e "$brief" ] || brief="$script_dir/executable_task-brief"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Isolate from the host's git configuration so results do not depend on it.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

failures=0

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

assert_contains() {
  grep -qF -- "$2" "$1" || fail "$3: expected '$2' in $1"
}

assert_not_contains() {
  if grep -qF -- "$2" "$1"; then fail "$3: unexpected '$2' in $1"; fi
}

assert_eq() {
  [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"
}

# Runs task-brief and echoes its exit code; output goes to $work/last.out.
exit_code_of() {
  local code=0
  bash "$brief" "$@" >"$work/last.out" 2>&1 || code=$?
  echo "$code"
}

# A repo holding a plan with every heading shape the extractor must handle.
new_plan_repo() {
  local dir="$work/$1"
  git init -q "$dir"
  cd "$dir"
  cat >plan.md <<'EOF'
# Feature Implementation Plan
## Global Constraints
constraints-marker
## Task 1: First
task1-marker
### Step 1: write the test
task1-step-marker
```bash
# Task 2: inside a fence, not a heading
fence-marker
```
task1-tail-marker
## Task 2: Second
task2-marker
## Task 10: Tenth
task10-marker
## Appendix
appendix-marker
EOF
}

test_extracts_task_up_to_next_task() {
  new_plan_repo basic
  local path
  path=$(bash "$brief" plan.md 1)
  # git prints the symlink-resolved root (e.g. macOS /var -> /private/var).
  assert_eq "$path" "$(pwd -P)/.sdd/task-1-brief.md" "prints the brief path"
  for marker in task1 task1-step fence task1-tail; do
    assert_contains "$path" "${marker}-marker" "task 1 body"
  done
  assert_not_contains "$path" "constraints-marker" "task 1 excludes the header"
  assert_not_contains "$path" "task2-marker" "task 1 stops at task 2"
}

test_task_number_matches_exactly() {
  new_plan_repo exact
  local path
  path=$(bash "$brief" plan.md 1)
  assert_not_contains "$path" "task10-marker" "task 1 does not match task 10"
  path=$(bash "$brief" plan.md 10)
  assert_contains "$path" "task10-marker" "task 10 body"
  assert_not_contains "$path" "task1-marker" "task 10 does not match task 1"
}

test_last_task_stops_at_non_task_heading() {
  new_plan_repo last
  local path
  path=$(bash "$brief" plan.md 10)
  assert_not_contains "$path" "appendix-marker" "last task stops at a sibling heading"
}

test_nested_task_stops_at_higher_heading() {
  new_plan_repo nested
  cat >phased.md <<'EOF'
## Phase 1
### Task 1: First
nested-task1-marker
#### Step 1: write the test
nested-step-marker
## Phase 2
phase2-marker
### Task 2: Second
nested-task2-marker
# Notes
notes-marker
EOF
  local path
  path=$(bash "$brief" phased.md 1)
  assert_contains "$path" "nested-task1-marker" "nested task body"
  assert_contains "$path" "nested-step-marker" "nested task keeps deeper headings"
  assert_not_contains "$path" "phase2-marker" "nested task stops at a higher heading"
  path=$(bash "$brief" phased.md 2)
  assert_contains "$path" "nested-task2-marker" "last nested task body"
  assert_not_contains "$path" "notes-marker" "last nested task stops at a top-level heading"
}

test_tilde_and_indented_fences_hide_headings() {
  new_plan_repo fences
  cat >fenced.md <<'EOF'
### Task 1: First
- [ ] Step 1
  ```bash
## Indented fence, not a heading
  ```
~~~python
# Task 2: inside a tilde fence, not a heading
```
still inside the tilde fence
~~~
fenced-tail-marker
### Task 2: Second
fenced-task2-marker
EOF
  local path
  path=$(bash "$brief" fenced.md 1)
  assert_contains "$path" "fenced-tail-marker" "task 1 survives indented and tilde fences"
  assert_not_contains "$path" "fenced-task2-marker" "task 1 still stops at the real task 2"
  path=$(bash "$brief" fenced.md 2)
  assert_eq "$(head -1 "$path")" "### Task 2: Second" "task 2 starts at its real heading"
}

test_nested_fences_close_only_on_a_matching_closer() {
  new_plan_repo nestedfence
  cat >nested.md <<'EOF'
### Task 1: Edit a skill file
````markdown
```bash
# comment in a shell example
```
````
nested-tail-marker
```text
```bash
## inside text fence
```
text-tail-marker
### Task 2: Second
nested-task2-marker
EOF
  local path
  path=$(bash "$brief" nested.md 1)
  assert_contains "$path" "nested-tail-marker" "a shorter inner fence does not close a longer one"
  assert_contains "$path" "text-tail-marker" "a fence line with an info string does not close a fence"
  assert_not_contains "$path" "nested-task2-marker" "task 1 still stops at the real task 2"
}

test_backtick_in_info_string_opens_no_fence() {
  new_plan_repo inlinecode
  cat >inline.md <<'EOF'
### Task 1: First
```js``` is inline code, not a fence
inline-task1-marker
~~~ info with `backticks`
### Task 2: inside a tilde fence, not a heading
~~~
inline-tail-marker
### Task 2: Second
inline-task2-marker
EOF
  local path
  path=$(bash "$brief" inline.md 1)
  assert_contains "$path" "inline-tail-marker" "a tilde fence may have backticks in its info string"
  assert_not_contains "$path" "inline-task2-marker" "a backtick run with a backtick after it opens no fence"
}

test_headings_indented_up_to_three_spaces() {
  new_plan_repo indented
  cat >indented.md <<'EOF'
 ## Task 1: First
indented-task1-marker
    ## Task 2: four spaces make code, not a heading
indented-code-marker
   ## Task 2: Second
indented-task2-marker
  ## Appendix
indented-appendix-marker
EOF
  local path
  path=$(bash "$brief" indented.md 1)
  assert_contains "$path" "indented-task1-marker" "a 1-space indented task heading is found"
  assert_contains "$path" "indented-code-marker" "a 4-space indented line is not a heading"
  assert_not_contains "$path" "indented-task2-marker" "task 1 stops at a 3-space indented task heading"
  path=$(bash "$brief" indented.md 2)
  assert_eq "$(head -1 "$path")" "   ## Task 2: Second" "task 2 starts at its indented heading"
  assert_not_contains "$path" "indented-appendix-marker" "task 2 stops at a 2-space indented sibling heading"
}

test_empty_headings_count_by_level() {
  new_plan_repo empty
  cat >empty.md <<'EOF'
## Task 1: First
empty-task1-marker
####
empty-deeper-marker
##
empty-after-marker
EOF
  local path
  path=$(bash "$brief" empty.md 1)
  assert_contains "$path" "empty-deeper-marker" "an empty deeper heading stays in the task"
  assert_not_contains "$path" "empty-after-marker" "an empty sibling heading ends the task"
}

test_seven_hashes_are_not_a_heading() {
  new_plan_repo seven
  cat >seven.md <<'EOF'
## Task 1: First
####### Task 2: seven hashes, not a heading
seven-body-marker
#######
seven-tail-marker
## Task 2: Second
seven-task2-marker
EOF
  local path
  path=$(bash "$brief" seven.md 1)
  assert_contains "$path" "seven-body-marker" "a 7-hash task line does not start a task"
  assert_contains "$path" "seven-tail-marker" "a bare 7-hash line does not end the task"
  assert_not_contains "$path" "seven-task2-marker" "task 1 still stops at the real task 2"
}

test_setext_headings_have_levels() {
  new_plan_repo setext
  cat >setext.md <<'EOF'
## Task 1: First
setext-task1-marker

Task 2: Second
--------------
setext-task2-marker
- [ ] a list item, not a heading
---
setext-after-break-marker

---
setext-after-rule-marker

Appendix
========
setext-appendix-marker
EOF
  local path
  path=$(bash "$brief" setext.md 1)
  assert_contains "$path" "setext-task1-marker" "task 1 body"
  assert_not_contains "$path" "setext-task2-marker" "task 1 stops at a setext task heading"
  path=$(bash "$brief" setext.md 2)
  assert_eq "$(head -1 "$path")" "Task 2: Second" "task 2 starts at its setext heading text"
  assert_contains "$path" "setext-after-break-marker" "--- after a list item is a thematic break"
  assert_contains "$path" "setext-after-rule-marker" "--- after a blank line is a thematic break"
  assert_not_contains "$path" "setext-appendix-marker" "task 2 stops at a level-1 setext heading"
}

test_html_blocks_hide_headings() {
  new_plan_repo html
  cat >html.md <<'EOF'
### Task 1: First
<!--
## Task 2: commented out, not a heading
-->
html-comment-tail-marker
<pre>
# a shell comment, not a heading
</pre>
html-pre-tail-marker
<!-- one-line comment -->
## Notes
html-notes-marker
EOF
  local path
  path=$(bash "$brief" html.md 1)
  assert_contains "$path" "html-comment-tail-marker" "an HTML comment hides headings"
  assert_contains "$path" "html-pre-tail-marker" "a <pre> block hides headings"
  assert_not_contains "$path" "html-notes-marker" "a heading after a one-line comment still counts"
}

test_crlf_line_endings() {
  new_plan_repo crlf
  printf '%s\r\n' '## Task 1: First' '```bash' '# a shell comment' '```' \
    'crlf-tail-marker' '## Task 2: Second' 'crlf-task2-marker' '' \
    'Appendix' '========' 'crlf-appendix-marker' >crlf.md
  local path
  path=$(bash "$brief" crlf.md 1)
  assert_contains "$path" "crlf-tail-marker" "task 1 body"
  assert_not_contains "$path" "crlf-task2-marker" "a CRLF fence closer closes the fence"
  grep -q $'\r$' "$path" || fail "the brief keeps the plan's line endings"
  path=$(bash "$brief" crlf.md 2)
  assert_not_contains "$path" "crlf-appendix-marker" "a CRLF setext underline is a heading"
}

test_task_number_ends_at_a_separator() {
  new_plan_repo suffix
  cat >suffix.md <<'EOF'
### Task 1: First
sep-task1-marker
### Task 1.5: Between
sep-dotted-marker
### Task 1a: Variant
sep-letter-marker
### Task 1. Dotted name
sep-period-marker
### Task 1
sep-bare-marker
### Task 1-2: Range
sep-range-marker
### Task 1) Paren
sep-paren-marker
### Task 1, part two
sep-comma-marker
### Task 1—Dash
sep-dash-marker
### Task 1- hyphen
sep-hyphen-marker
### Task 1–en dash
sep-endash-marker
### Task 1é
sep-accent-marker
### Task 1/2: Half
sep-slash-marker
### Task 1(a)
sep-paren-letter-marker
### Task 1_x
sep-underscore-marker
### Task 2: Second
EOF
  local path
  path=$(bash "$brief" suffix.md 1)
  assert_contains "$path" "sep-task1-marker" "task 1 body"
  assert_not_contains "$path" "sep-dotted-marker" "Task 1.5 is not task 1"
  assert_not_contains "$path" "sep-letter-marker" "Task 1a is not task 1"
  assert_contains "$path" "sep-period-marker" "Task 1. followed by a name is task 1"
  assert_contains "$path" "sep-bare-marker" "a bare Task 1 heading is task 1"
  assert_not_contains "$path" "sep-range-marker" "Task 1-2 is not task 1"
  assert_contains "$path" "sep-paren-marker" "Task 1) is task 1"
  assert_contains "$path" "sep-comma-marker" "Task 1, is task 1"
  assert_contains "$path" "sep-dash-marker" "Task 1 followed by an em dash is task 1"
  assert_contains "$path" "sep-hyphen-marker" "Task 1- followed by a space is task 1"
  assert_not_contains "$path" "sep-underscore-marker" "Task 1_x is not task 1"
  assert_contains "$path" "sep-endash-marker" "Task 1 followed by an en dash is task 1"
  assert_not_contains "$path" "sep-accent-marker" "Task 1 followed by a non-ASCII letter is not task 1"
  assert_not_contains "$path" "sep-slash-marker" "Task 1/2 is not task 1"
  assert_not_contains "$path" "sep-paren-letter-marker" "Task 1(a) is not task 1"
}

test_block_level_html_ends_at_a_blank_line() {
  new_plan_repo html67
  cat >html67.md <<'EOF'
### Task 1: First
<details>
## Task 2: inside a details block, not a heading
details-body-marker
</details>

<span class="note">
## inside a lone open tag, not a heading
span-body-marker

paragraph text
<span class="note">
## Notes
notes-after-span-marker
EOF
  local path
  path=$(bash "$brief" html67.md 1)
  assert_contains "$path" "details-body-marker" "a <details> block hides headings"
  assert_contains "$path" "span-body-marker" "a lone open tag starts an HTML block"
  assert_not_contains "$path" "notes-after-span-marker" "a lone tag inside a paragraph starts no HTML block"
}

test_html_start_kinds_hide_headings() {
  new_plan_repo htmlkinds
  cat >kinds.md <<'EOF'
### Task 1: First
<script>
# js-comment
</SCRIPT>
<style>
## css
</style>
<textarea>
## text
</textarea>
<?php
## php
?>
<![CDATA[
## cdata
]]>
<!DOCTYPE html
## doctype
>
kinds-tail-marker
## Notes
kinds-notes-marker
EOF
  local path
  path=$(bash "$brief" kinds.md 1)
  assert_contains "$path" "kinds-tail-marker" "every HTML block kind hides headings"
  assert_not_contains "$path" "kinds-notes-marker" "a heading after the HTML blocks still counts"
}

test_multi_line_setext_heading() {
  new_plan_repo multisetext
  cat >multi.md <<'EOF'
### Task 1: First
multi-task1-marker

line one
line two
---
multi-after-marker
EOF
  local path
  path=$(bash "$brief" multi.md 1)
  assert_contains "$path" "multi-task1-marker" "task 1 body"
  assert_not_contains "$path" "line two" "a two-line paragraph underlined by --- is a heading"
  assert_not_contains "$path" "multi-after-marker" "the multi-line setext heading ends the task"
}

test_setext_underline_needs_a_paragraph() {
  new_plan_repo notsetext
  cat >notsetext.md <<'EOF'
### Task 1: First
> a block quote
---
1. an ordered item
---
***
---
| a |
---
<b>inline html</b>
---
notsetext-html-marker
***
Task 2: Second
---
notsetext-task2-marker
EOF
  local path
  path=$(bash "$brief" notsetext.md 1)
  assert_contains "$path" "| a |" "quote, list, break, and table lines are not setext text"
  assert_not_contains "$path" "notsetext-html-marker" "a line of inline HTML is paragraph text"
  path=$(bash "$brief" notsetext.md 2)
  assert_eq "$(head -1 "$path")" "Task 2: Second" "a paragraph after a thematic break can be a setext heading"
}

test_lone_tag_after_a_list_item_is_text() {
  new_plan_repo lazytag
  printf '%s\n' '### Task 1: First' '- [ ] step' '<br>' '### Task 2: Second' \
    'lazytag-task2-marker' >lazy.md
  local path
  path=$(bash "$brief" lazy.md 1)
  assert_not_contains "$path" "lazytag-task2-marker" "a lone tag continuing a list item starts no HTML block"
}

test_html_block_variants() {
  new_plan_repo htmlvar
  cat >var.md <<'EOF'
### Task 1: First
<div class="x">text
## hidden by a div with content
div-body-marker

paragraph text
<section>
## hidden by a section interrupting a paragraph
section-body-marker

</span>
## hidden by a lone closing tag
closetag-body-marker

<SCRIPT>
# js comment
</SCRIPT>
## Notes
upper-notes-marker
EOF
  local path
  path=$(bash "$brief" var.md 1)
  assert_contains "$path" "div-body-marker" "a block-level tag with content starts an HTML block"
  assert_contains "$path" "section-body-marker" "a block-level tag interrupts a paragraph"
  assert_contains "$path" "closetag-body-marker" "a lone closing tag starts an HTML block"
  assert_not_contains "$path" "upper-notes-marker" "an upper-case closer ends a script block"
}

test_list_and_quote_interrupt_a_paragraph() {
  new_plan_repo interrupt
  cat >intr.md <<'EOF'
### Task 1: First
paragraph text
1. first item
---
after-list-marker
paragraph text
> a quote
---
after-quote-marker
EOF
  local path
  path=$(bash "$brief" intr.md 1)
  assert_contains "$path" "after-list-marker" "a 1. item ends the paragraph, so --- is a break"
  assert_contains "$path" "after-quote-marker" "a quote ends the paragraph, so --- is a break"
}

test_setext_levels_differ() {
  new_plan_repo levels
  cat >levels.md <<'EOF'
# Task 1: First
Sub
---
level2-marker

End
===
level1-marker
EOF
  local path
  path=$(bash "$brief" levels.md 1)
  assert_contains "$path" "level2-marker" "a - underline is level 2, below a level-1 task"
  assert_not_contains "$path" "level1-marker" "an = underline is level 1"
}

test_one_line_uppercase_html_block_closes() {
  new_plan_repo preline
  printf '%s\n' '### Task 1: First' '<PRE>x</PRE>' '### Task 2: Second' \
    'preline-task2-marker' >pre.md
  local path
  path=$(bash "$brief" pre.md 1)
  assert_not_contains "$path" "preline-task2-marker" "an uppercase one-line HTML block ends on its own line"
}

test_paragraph_after_a_fence_is_held() {
  new_plan_repo fencepara
  printf '%s\n' '### Task 1: First' '- step' '```' 'code' '```' 'Appendix' '===' \
    'fencepara-appendix-marker' >fp.md
  local path
  path=$(bash "$brief" fp.md 1)
  assert_not_contains "$path" "fencepara-appendix-marker" "a setext heading right after a fence ends the task"
}

test_four_space_fence_is_indented_code() {
  new_plan_repo codefence
  printf '%s\n' '## Task 1: First' 'text' '' '    ```' '    code' '' '## Task 2: Second' \
    'codefence-task2-marker' >cf.md
  local path
  path=$(bash "$brief" cf.md 1)
  assert_not_contains "$path" "codefence-task2-marker" "a fence indented 4 spaces outside a list is indented code"
}

test_headings_inside_containers() {
  new_plan_repo containers
  cat >cont.md <<'EOF'
## Task 1: First
cont-task1-marker
- ## Task 2: In a list item
cont-task2-marker
> ## Task 3: In a quote
cont-task3-marker
1. ## Task 4: In an ordered item
cont-task4-marker
- > ## Task 5: In a quote in a list
cont-task5-marker
-	## Task 6: After a tab
cont-task6-marker
## Task 7: Last
EOF
  local path i
  path=$(bash "$brief" cont.md 1)
  assert_contains "$path" "cont-task1-marker" "task 1 body"
  assert_not_contains "$path" "cont-task2-marker" "a heading in a list item ends the task"
  for i in 2 3 4 5 6; do
    path=$(bash "$brief" cont.md "$i")
    assert_contains "$path" "cont-task${i}-marker" "task $i heading inside a container is found"
    assert_not_contains "$path" "Task 7" "task $i stops at the next task"
  done
}

test_container_content_is_not_a_heading() {
  new_plan_repo contcode
  cat >cc.md <<'EOF'
## Task 1: First
-      # Task 2: five spaces after a marker make code
> ```
> # Task 2: in a fence in a quote
> ```
- item
      ## Task 2: paragraph text in an item, not a heading
> quoted
continued lazily
===
contcode-tail-marker
## Task 2: Second
contcode-task2-marker
EOF
  local path
  path=$(bash "$brief" cc.md 1)
  assert_contains "$path" "contcode-tail-marker" "code, fences, and lazy text in containers hide headings"
  assert_not_contains "$path" "contcode-task2-marker" "task 1 still stops at the real task 2"
}

test_paragraph_after_indented_code() {
  new_plan_repo afterindent
  printf '%s\n' '## Task 1: First' 'text' '' '    code' 'Appendix' '===' \
    'afterindent-marker' >ai.md
  local path
  path=$(bash "$brief" ai.md 1)
  assert_not_contains "$path" "afterindent-marker" "a setext heading right after indented code ends the task"
}

test_lines_that_open_no_list_item() {
  new_plan_repo nolist
  cat >nl.md <<'EOF'
## Task 1: First
nolist-task1-marker

    - ## Task 2: four spaces make code, not a list item
- - -
    ## Task 2: indented code after a break, not a list item
1234567890) ## Task 2: ten digits make no list item
-## Task 2: no space after the marker
paragraph text
2. ## Task 2: an item not numbered 1 cannot interrupt a paragraph

    code
===
nolist-tail-marker
## Task 2: Second
nolist-task2-marker
EOF
  local path
  path=$(bash "$brief" nl.md 1)
  assert_contains "$path" "nolist-tail-marker" "code, breaks, and lazy text open no list item"
  assert_not_contains "$path" "nolist-task2-marker" "task 1 still stops at the real task 2"
}

test_empty_item_and_new_containers_end_a_paragraph() {
  new_plan_repo emptyitem
  printf '%s\n' '## Task 1: First' 'Sub' '-' 'emptyitem-setext-marker' >ei.md
  printf '%s\n' '## Task 1: First' 'para' '> ===' '' 'para' '- ===' 'newcont-tail-marker' >nc.md
  local path
  path=$(bash "$brief" ei.md 1)
  assert_not_contains "$path" "emptyitem-setext-marker" "a lone - under a paragraph is a setext underline"
  path=$(bash "$brief" nc.md 1)
  assert_contains "$path" "newcont-tail-marker" "a quote or list marker ends the paragraph above it"
}

test_list_item_spans_blank_lines() {
  new_plan_repo blankitem
  printf '%s\n' '## Task 1: First' '- item' '' '     ## Task 2: Second' 'blankitem-task2-marker' >bi.md
  local path
  path=$(bash "$brief" bi.md 1)
  assert_not_contains "$path" "blankitem-task2-marker" "a list item continues past a blank line"
}

test_quote_fence_ends_with_the_quote() {
  new_plan_repo quotefence
  printf '%s\n' '## Task 1: First' '> ```' '> code' '## Task 2: Second' 'quotefence-task2-marker' >qf.md
  local path
  path=$(bash "$brief" qf.md 1)
  assert_not_contains "$path" "quotefence-task2-marker" "a fence in a quote ends with the quote"
  printf '%s\n' '## Task 1: First' '> quote' '>    ## Task 2: Second' 'quotespace-task2-marker' >qs.md
  path=$(bash "$brief" qs.md 1)
  assert_not_contains "$path" "quotespace-task2-marker" "one space after > belongs to the marker"
  printf '%s\n' '## Task 1: First' '>    ## Task 2: Second' 'quoteopen-task2-marker' >qo.md
  path=$(bash "$brief" qo.md 1)
  assert_not_contains "$path" "quoteopen-task2-marker" "one space after an opening > belongs to the marker"
}

test_sibling_items_end_a_paragraph_in_an_item() {
  new_plan_repo sibling
  printf '%s\n' '1. ## Task 1: First' '   body' '2. ## Task 2: Second' '   sibling-two-marker' >sib.md
  printf '%s\n' '## Task 1: First' '- intro' '2. ## Task 2: Second' 'sibling-bullet-marker' >sb.md
  printf '%s\n' '## Task 1: First' '- intro' '-' '  ===' 'sibling-empty-marker' >se.md
  local path
  path=$(bash "$brief" sib.md 1)
  assert_not_contains "$path" "sibling-two-marker" "item 2. after body text in item 1. is a new item"
  path=$(bash "$brief" sb.md 1)
  assert_not_contains "$path" "sibling-bullet-marker" "a 2. item after a bullet paragraph is a new list"
  path=$(bash "$brief" se.md 1)
  assert_contains "$path" "sibling-empty-marker" "an empty sibling item is a new item, not setext text"
}

test_last_line_at_eof_is_kept() {
  new_plan_repo eof
  printf '### Task 1: First\n\neof-last-line-marker\n' >eof.md
  local path
  path=$(bash "$brief" eof.md 1)
  assert_contains "$path" "eof-last-line-marker" "a paragraph ending the file is kept"
}

test_brief_dir_is_ignored() {
  new_plan_repo ignored
  local before
  before=$(git status --porcelain)
  bash "$brief" plan.md 2 >/dev/null
  assert_eq "$(git status --porcelain)" "$before" ".sdd/ never shows in git status"
}

test_missing_task_exits_3() {
  new_plan_repo missing
  assert_eq "$(exit_code_of plan.md 7)" "3" "unknown task number"
  [ ! -e .sdd/task-7-brief.md ] || fail "no brief is left for a missing task"
}

test_bad_arguments_exit_2() {
  new_plan_repo badargs
  assert_eq "$(exit_code_of plan.md)" "2" "missing task number"
  assert_eq "$(exit_code_of plan.md x1)" "2" "non-digit task number"
  assert_eq "$(exit_code_of no-such-plan.md 1)" "2" "missing plan file"
}

test_outside_repo_exits_2() {
  mkdir "$work/not-a-repo"
  cd "$work/not-a-repo"
  echo "## Task 1: x" >plan.md
  assert_eq "$(exit_code_of plan.md 1)" "2" "outside a git repository"
}

test_extracts_task_up_to_next_task
test_task_number_matches_exactly
test_last_task_stops_at_non_task_heading
test_nested_task_stops_at_higher_heading
test_tilde_and_indented_fences_hide_headings
test_nested_fences_close_only_on_a_matching_closer
test_backtick_in_info_string_opens_no_fence
test_headings_indented_up_to_three_spaces
test_empty_headings_count_by_level
test_seven_hashes_are_not_a_heading
test_setext_headings_have_levels
test_html_blocks_hide_headings
test_crlf_line_endings
test_task_number_ends_at_a_separator
test_block_level_html_ends_at_a_blank_line
test_html_start_kinds_hide_headings
test_multi_line_setext_heading
test_setext_underline_needs_a_paragraph
test_last_line_at_eof_is_kept
test_sibling_items_end_a_paragraph_in_an_item
test_lines_that_open_no_list_item
test_empty_item_and_new_containers_end_a_paragraph
test_list_item_spans_blank_lines
test_quote_fence_ends_with_the_quote
test_four_space_fence_is_indented_code
test_headings_inside_containers
test_container_content_is_not_a_heading
test_paragraph_after_indented_code
test_one_line_uppercase_html_block_closes
test_paragraph_after_a_fence_is_held
test_lone_tag_after_a_list_item_is_text
test_html_block_variants
test_list_and_quote_interrupt_a_paragraph
test_setext_levels_differ
test_brief_dir_is_ignored
test_missing_task_exits_3
test_bad_arguments_exit_2
test_outside_repo_exits_2

if [ "$failures" -gt 0 ]; then
  echo "$failures assertion(s) failed"
  exit 1
fi
echo "all task-brief tests passed"
