# download-retries check

Checks that every task of the roles that downloads a file with `get_url` retries a failed
download, on localhost — no cluster, no role tasks. A download without a retry fails the play
on the first refused connection, and an upgrade then stops with a node already cordoned.

## Run

```bash
mise run test:download-retries
```

The task first proves the check on the fixtures, then runs it on `roles/`. To check other
files or directories, call the script:

```bash
scripts/check-download-retries.sh roles/sysext/tasks
```

## What it checks

- **Tasks** — every `*.yml` and `*.yaml` file under the given directories, and every task in
  them at any depth of `block`, `rescue` and `always`.
- **Modules** — `ansible.builtin.get_url`, `ansible.legacy.get_url` and the short name `get_url`.
- **Rule** — the task must have both `until` and `retries`. For each task that does not, the
  script prints `<file>: <task name>` and exits 1.

## What it does not check

- A download done with another module, for example `ansible.builtin.uri` with `dest`, or `curl`
  in `ansible.builtin.command`.
- The values: the condition of `until`, the number of `retries`, and `delay`.
- That a download really retries on a node. The check reads the files; it runs no task.

## Files

- `../../scripts/check-download-retries.sh` — the check.
- `fixtures/pass.yml` — downloads with a retry, under the three module names and inside nested
  blocks. The check MUST report nothing.
- `fixtures/fail-*.yml` — one download without a retry each (no `retries`, no `until`, two
  blocks deep, in `rescue`, in `always`, short module name, legacy module name). The check
  MUST report each file.

A new case needs a new `fail-<case>.yml` fixture: the mise task picks it up by its name.
