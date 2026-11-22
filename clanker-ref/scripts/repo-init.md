# repo-init

`scripts/repo-init/repo-init` creates a forgejo repo, the same repo on github and a forgejo to github push mirror, with signed commits required on the default branch of both. It runs on the host. `ssm init` offers it as the `repo-init` host step when no origin was given, the step replaces the placeholder origin with the forgejo ssh url the script prints.

## Decisions

- The mirror is an ssh one (`use_ssh: true`). Forgejo generates an ed25519 key per mirror and returns `public_key`, the script adds it to the github repo as a write deploy key. Rejected: a github token stored in forgejo, a fine-grained one can't cover a repo that doesn't exist yet and a broad one would sit on the server.
- Signed commits are the only rule, the user's choice. The mirror pushes the same signed commits so the github ruleset needs no bypass actor. Adding `non_fast_forward` or `deletion` rules later would need a `DeployKey` bypass, the mirror force pushes and prunes.
- A refused github ruleset (403, private repo on a free plan) is a warning, not a failure. A failing step would block the ssm run script for good.
- Stdout is only the origin url, the ssm step captures it. Everything else goes to stderr.
- Every step looks up what exists before creating, so a rerun resumes. That is what makes the ssm step safe to retry.

## Gotchas

- Forgejo only does ssh mirrors when it finds `ssh`. The unit's `path` doesn't list openssh but the nixpkgs package wraps the binary with it (`pkgs/by-name/fo/forgejo/generic.nix`), nothing to add on the host. Look at the package wrapper, not only the unit, before concluding a tool is missing.
- The forgejo module installs `forgejo-lts` (15.x when this was written), not `nixpkgs#forgejo`. Check API fields against the LTS branch: `https://codeberg.org/forgejo/forgejo/raw/branch/v15.0/forgejo/templates/swagger/v1_json.tmpl` (strip the `{{...}}` before jq). `codeberg.org/swagger.v1.json` times out.
- Forgejo's ssh for mirrors uses `StrictHostKeyChecking=accept-new` with its own known_hosts, github's host key needs no setup.
- A forgejo branch protection without `enable_push: true` blocks every push to the branch.
- Forgejo protects by branch name, so the step passes `git config init.defaultBranch` (what `ssm init` writes for `main`) as `--default-branch`. Github uses `~DEFAULT_BRANCH`, which works on an empty repo.
- Commits only verify against signing keys uploaded to each account. The script warns when an account lists none, it can't tell whether the listed ones match.

## Testing

No real API is reachable from the sandbox. `FORGEJO_URL` and `GITHUB_API_URL` point the script at a mock, a small `http.server` that keeps the repos, rules, mirrors and keys in memory was enough to cover the first run, the rerun (no POSTs), the 403 ruleset and `--no-github`. It was never run against the real forgejo or github from here.
