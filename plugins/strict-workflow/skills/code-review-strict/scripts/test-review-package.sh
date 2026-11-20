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
test_nothing_to_review_exits_3
test_bad_base_exits_2
test_unknown_option_exits_2
test_outside_repo_exits_2

if [ "$failures" -gt 0 ]; then
  echo "$failures assertion(s) failed"
  exit 1
fi
echo "all review-package tests passed"
