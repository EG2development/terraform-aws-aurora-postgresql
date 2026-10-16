<!--
Title = the commit on main (squash merge) = what release-please reads:
  feat: ...  fix: ...  docs: ...  chore: ...  refactor: ...  test: ...  ci: ...
  feat!: ... for a breaking change, with a "BREAKING CHANGE: ..." paragraph at the end.
First release of a new module: make  Release-As: 1.0.0  the last line of this text.
Write in prose: a line that looks like "fix: ..." becomes a changelog entry.
-->

## What changed

## Plan impact for existing callers

<!-- none | in-place update of ... | replacement of ... (then the title needs "!") -->

## How it was checked

- [ ] `terraform test`
- [ ] `tflint --recursive`
- [ ] `terraform-docs .` (README tables regenerated)
- [ ] `docs/` pages still true (reference: names, IAM, permissions; how-to steps)
