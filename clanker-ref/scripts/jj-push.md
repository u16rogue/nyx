# jj-push and the first push of a new project

A project fresh out of `ssm init` has no commit, so no bookmark can exist yet. `jj-push` creates it on the first push instead of `ssm init`.

- No bookmark in `::@-`: `jj-push` creates one at `finished()`, named after git's `init.defaultBranch` (fallback `main`). `ssm init` writes that key into the repo config when `main` is picked, the unborn branch from `git init -b` is gone once jj detaches HEAD.
- A bookmark the remote doesn't have is tracked before the push. jj 0.47 refuses to push an untracked new bookmark ("Refusing to create new remote bookmark") and still exits 0. Tracking a bookmark whose remote ref doesn't exist works, it lists as `@origin (not created yet)`.
- `finished()` is `root()` when nothing is finished, it's never empty. Check `finished() ~ root()`.
- `ssm init` adds `origin` with the `git_origin` answer, or the placeholder `origin-is-not-set://...`. `jj-push` dies on that prefix before it touches anything, keep the two in sync.

## Rejected

- Bookmark on `root()` at init: works, but every jj command then warns "Ref cannot point to the root commit in Git" until it moves.
- Bookmark on `@` at init: `jj split` and `jj new -B @` keep it on `@`, it never gets into `::@-`.
- An initial commit made by `./init`: it would commit the scaffold on the user's behalf, and the jj identity only exists in the sandbox at that point.

## Testing

It runs outside a sandbox with a faked context: `NYX_SBX_SHELL_DIR=<t>/sbx`, a `<project>/.nyx-sbx/ptr` symlink to `<t>/sbx/ctx`, the identity in `<t>/sbx/ctx/fs-root/$HOME/.config/jj/config.toml` with `signing.backend = "ssh"` and a throwaway `ssh-keygen` key, a bare repo as origin. Unset `NYX_SBX_ID` for the call.
