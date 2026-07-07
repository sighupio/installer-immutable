# argument-specs harness

Validates every role `meta/argument_specs.yml` against fixtures on localhost — no
cluster, no role tasks. Uses `ansible.builtin.validate_argument_spec` per entry-point.

## Run

```bash
mise run test:argument-specs
```

## What it checks

- **Coverage** — the declared spec entry-points (globbed from `roles/*/meta/argument_specs.yml`)
  match `manifest.yml`, and every entry-point has a positive fixture. Adding a spec
  entry without a fixture fails the harness.
- **Positive** — each entry-point's `fixtures/<role>/<entry>.positive.yml` (the
  declared-option projection of the furyctl-rendered outdir values) MUST pass validation.
- **Negative** — for entry-points with a `required: true` option,
  `fixtures/<role>/<entry>.negative.yml` omits one required var and MUST fail validation
  (asserted via `block`/`rescue`).

## Files

- `validate.yml` — the harness playbook.
- `_negative.yml` — one negative case (included per entry-point with required vars).
- `manifest.yml` — generated `role → entry → required[]` map (coverage source of truth).
- `fixtures/<role>/<entry>.{positive,negative}.yml` — derived from the rendered outdir.

Fixtures are regenerated from `contract-table.json` + a real furyctl outdir, not hand-authored.
