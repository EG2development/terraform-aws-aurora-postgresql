# Contributing

1. Branch from `dev`: `feat/...`, `fix/...`, `docs/...`, `chore/...`.
2. Make one small change. Add or update a test under `tests/` and an example if the
   interface changed.
3. Run the checks: `terraform fmt -recursive`, `terraform init -backend=false`,
   `terraform validate`, `terraform test`, `tflint --recursive`, `terraform-docs .`.
   Or `pre-commit install` once and let it run them.
4. Open a pull request into `dev` whose **title** is a Conventional Commit (`feat:`, `fix:`,
   `docs:`, `chore:`; `feat!:` for a breaking change). The title becomes the commit.
5. CI and one approval, then squash merge into `dev`. A maintainer promotes `dev` to
   `main` with `scripts/promote.sh` from the standards repository; release-please
   releases from `main`.

Procedures: [terraform-module-standards/docs/runbooks](https://github.com/EG2development/terraform-module-standards/tree/main/docs/runbooks).
Rules: [the standard](https://github.com/EG2development/terraform-module-standards/blob/main/docs/standard.md).
