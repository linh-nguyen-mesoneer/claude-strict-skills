#!/usr/bin/env bash
# Tests for review-package. Builds throwaway repos under a temp dir and
# asserts on the package contents and exit codes.
#
# Usage: test-review-package.sh
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
# Deployed name, or the chezmoi source name when run from the dotfiles repo.
pkg="$script_dir/review-package"
[ -e "$pkg" ] || pkg="$script_dir/executable_review-package"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Isolate from the host's git configuration so results do not depend on it.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

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

# Runs review-package and echoes its exit code; output goes to $work/last.out.
exit_code_of() {
  local code=0
  bash "$pkg" "$@" >"$work/last.out" 2>&1 || code=$?
  echo "$code"
}

new_repo() {
  local dir="$work/$1"
  git init -q -b main "$dir"
  cd "$dir"
  echo base-line >base.txt
  echo ignored.log >.gitignore
  git add .
  git commit -qm "base"
}

# A feature branch holding every kind of change a review must see.
new_feature_repo() {
  new_repo "$1"
  git checkout -qb feature
  echo first-commit-marker >a.txt
  git add a.txt
  git commit -qm "first"
  echo second-commit-marker >b.txt
  git add b.txt
  git commit -qm "second"
  echo staged-marker >c.txt
  git add c.txt
  echo unstaged-marker >>base.txt
  echo untracked-marker >d.txt
  echo spaced-marker >"with space.txt"
  echo ignored-marker >ignored.log
  mkdir sub
  echo sub-marker >sub/e.txt
}

test_default_includes_whole_change() {
  new_feature_repo whole
  local out="$work/whole.diff" before after summary
  before=$(git status --porcelain)
  summary=$(bash "$pkg" --out "$out")
  after=$(git status --porcelain)

  for marker in first-commit second-commit staged unstaged untracked spaced sub; do
    assert_contains "$out" "${marker}-marker" "default mode"
  done
  assert_not_contains "$out" "ignored-marker" "default mode skips ignored files"
  assert_eq "$after" "$before" "working tree and index untouched"
  case $summary in
    *"2 commit(s)"*) ;;
    *) fail "summary reports commit count: got '$summary'" ;;
  esac
}

test_default_outfile_is_outside_repo() {
  new_feature_repo outfile
  local summary path
  summary=$(bash "$pkg")
  path=${summary#wrote }
  path=${path%%: base*}
  [ -s "$path" ] || fail "default outfile exists and is non-empty: '$path'"
  case $path in
    "$PWD"/*) fail "default outfile must live outside the repo: '$path'" ;;
  esac
  assert_eq "$(git status --porcelain --ignored | grep -c review || true)" "0" "no package left in repo"
  rm -rf "$(dirname "$path")"
}

test_pathspec_limits_package() {
  new_feature_repo pathspec
  local out="$work/pathspec.diff"
  bash "$pkg" --out "$out" -- sub >/dev/null
  assert_contains "$out" "sub-marker" "pathspec keeps matching untracked file"
  assert_not_contains "$out" "first-commit-marker" "pathspec drops other commits"
  assert_not_contains "$out" "untracked-marker" "pathspec drops other untracked files"
}

test_head_excludes_working_tree() {
  new_feature_repo head
  local out="$work/head.diff"
  bash "$pkg" --head HEAD --out "$out" >/dev/null
  assert_contains "$out" "first-commit-marker" "--head keeps commits"
  assert_contains "$out" "second-commit-marker" "--head keeps commits"
  assert_not_contains "$out" "staged-marker" "--head drops staged changes"
  assert_not_contains "$out" "untracked-marker" "--head drops untracked files"
}

test_explicit_base_narrows_range() {
  new_feature_repo base
  local out="$work/base.diff"
  bash "$pkg" --base HEAD~1 --head HEAD --out "$out" >/dev/null
  assert_contains "$out" "second-commit-marker" "--base keeps later commit"
  assert_not_contains "$out" "first-commit-marker" "--base drops earlier commit"
}

test_diff_attribute_does_not_hide_changes() {
  new_repo attrs
  printf 'lock.json -diff\n*.lock -diff\n' >.gitattributes
  echo old-lock >lock.json
  seq 1 30 >old.lock
  echo old-spaced >"sp ace.lock"
  printf 'old\0bin' >blob.dat
  git add .
  git commit -qm "attributes"
  git checkout -qb feature
  echo committed-lock-marker >lock.json
  git mv old.lock new.lock
  echo renamed-lock-marker >>new.lock
  echo spaced-lock-marker >"sp ace.lock"
  git commit -qam "lock"
  printf 'new\0bin' >blob.dat
  echo 'untracked.json -diff' >>.gitattributes
  echo untracked-lock-marker >untracked.json
  local out="$work/attrs.diff" head_out="$work/attrs-head.diff" spec_out="$work/attrs-spec.diff"
  bash "$pkg" --base main --out "$out" >/dev/null
  bash "$pkg" --base main --head HEAD --out "$head_out" >/dev/null
  bash "$pkg" --base main --out "$spec_out" -- "sp ace.lock" >/dev/null
  assert_contains "$out" "committed-lock-marker" "-diff attribute on a tracked file"
  assert_contains "$out" "untracked-lock-marker" "-diff attribute on an untracked file"
  assert_contains "$out" "spaced-lock-marker" "-diff attribute on a path with a space"
  assert_contains "$out" "rename from old.lock" "renamed -diff file stays a rename"
  assert_contains "$out" "renamed-lock-marker" "renamed -diff file shows its change"
  assert_contains "$head_out" "committed-lock-marker" "-diff attribute with --head"
  assert_contains "$spec_out" "spaced-lock-marker" "pathspec keeps the matching -diff file"
  assert_not_contains "$spec_out" "committed-lock-marker" "pathspec drops other -diff files"
  assert_contains "$out" "Binary files a/blob.dat and b/blob.dat differ" "genuine binary still detected"
}

test_eol_conversion_kept_for_other_files() {
  new_repo eol
  echo '*.txt text eol=crlf' >.gitattributes
  printf 'eol-1\neol-2\neol-3\n' >crlf.txt
  # Silences git's "LF will be replaced by CRLF" notice for the setup files.
  git -c core.safecrlf=false add .
  git commit -qm "crlf"
  # Recheck out so the working tree holds CRLF, as a real checkout would.
  rm crlf.txt
  git checkout -- crlf.txt
  git checkout -qb feature
  printf 'eol-1\r\nEOL-2\r\neol-3\r\n' >crlf.txt
  local out="$work/eol.diff"
  bash "$pkg" --base main --out "$out" >/dev/null 2>&1
  assert_contains "$out" "+EOL-2" "eol=crlf file shows its change"
  assert_not_contains "$out" "+eol-1" "eol=crlf file is not rewritten whole"
}

# Puts a `git` on PATH that runs $2 (shell code) first, then the real git.
make_git_shim() {
  local dir=$1 real_git
  real_git=$(command -v git)
  mkdir "$dir"
  {
    echo '#!/usr/bin/env bash'
    echo "$2"
    echo "exec \"$real_git\" \"\$@\""
  } >"$dir/git"
  chmod +x "$dir/git"
}

test_old_git_warns_and_still_writes() {
  new_feature_repo oldgit
  local shim="$work/oldgit-bin" out="$work/oldgit.diff" code=0
  # Reports a pre-2.40 version, as Apple Git does.
  make_git_shim "$shim" 'if [ "$1" = version ]; then echo "git version 2.39.5 (Apple Git-154)"; exit 0; fi'
  PATH="$shim:$PATH" bash "$pkg" --out "$out" >"$work/oldgit.out" 2>&1 || code=$?
  assert_eq "$code" "0" "old git still writes a package"
  assert_contains "$work/oldgit.out" "warning: git older than 2.40" "old git warns"
  assert_contains "$out" "first-commit-marker" "old git package content"
}

test_check_attr_failure_exits_2() {
  new_feature_repo attrfail
  local shim="$work/attrfail-bin" code=0
  make_git_shim "$shim" 'if [ "$1" = check-attr ]; then exit 1; fi'
  PATH="$shim:$PATH" bash "$pkg" --out "$work/attrfail.diff" >"$work/attrfail.out" 2>&1 || code=$?
  assert_eq "$code" "2" "failing git check-attr is an error"
  assert_contains "$work/attrfail.out" "review-package: git check-attr failed" "failing git check-attr is reported"
}

test_changed_paths_failure_exits_2() {
  new_feature_repo namefail
  local shim="$work/namefail-bin" code=0
  # Only the attribute pass lists names with --no-renames.
  make_git_shim "$shim" 'for arg; do if [ "$arg" = --no-renames ]; then exit 128; fi; done'
  PATH="$shim:$PATH" bash "$pkg" --out "$work/namefail.diff" >"$work/namefail.out" 2>&1 || code=$?
  assert_eq "$code" "2" "failing git diff --name-only is an error"
  assert_contains "$work/namefail.out" "review-package: git diff --name-only failed" "failing git diff --name-only is reported"
}

test_nothing_to_review_exits_3() {
  new_repo clean
  local out="$work/clean.diff"
  assert_eq "$(exit_code_of --out "$out")" "3" "clean tree on the base branch"
  [ ! -e "$out" ] || fail "no package is written when there is nothing to review"
}

test_bad_base_exits_2() {
  new_feature_repo badbase
  assert_eq "$(exit_code_of --base no-such-ref)" "2" "unknown base ref"
}

test_unknown_option_exits_2() {
  new_feature_repo badopt
  assert_eq "$(exit_code_of --bogus)" "2" "unknown option"
}

test_outside_repo_exits_2() {
  mkdir "$work/not-a-repo"
  cd "$work/not-a-repo"
  assert_eq "$(exit_code_of)" "2" "outside a git repository"
}

test_default_includes_whole_change
test_default_outfile_is_outside_repo
test_pathspec_limits_package
test_head_excludes_working_tree
test_explicit_base_narrows_range
test_diff_attribute_does_not_hide_changes
test_eol_conversion_kept_for_other_files
test_old_git_warns_and_still_writes
test_check_attr_failure_exits_2
test_changed_paths_failure_exits_2
test_nothing_to_review_exits_3
test_bad_base_exits_2
test_unknown_option_exits_2
test_outside_repo_exits_2

if [ "$failures" -gt 0 ]; then
  echo "$failures assertion(s) failed"
  exit 1
fi
echo "all review-package tests passed"
