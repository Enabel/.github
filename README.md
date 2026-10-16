# .github

Organisation-wide defaults and shared CI for Enabel repositories on GitHub.

## Community defaults

A repository without its own file of the same name uses these:

- `pull_request_template.md`: pull request template
- `ISSUE_TEMPLATE/`: issue templates (bug, task, tech debt, user story)

## CI for Symfony applications

In a repository: **Actions → New workflow**, then pick from *By Enabel*:

| Workflow template | Adds | Does |
|---|---|---|
| Enabel Symfony CI | `.github/workflows/ci.yml` | `qa`, `tests`, `secrets` through `symfony-app.yml` |
| Upsun preview comment | `.github/workflows/preview.yml` | comments the Upsun `pr-N` URL on pull requests |

Also copy [`templates/dependabot.yml`](templates/dependabot.yml) to
`.github/dependabot.yml` (no organisation default exists for Dependabot).

`preview.yml` reacts to the `upsun` commit status. GitHub runs status-triggered
workflows from the default branch: it works once merged on `main`.

### `symfony-app.yml` inputs

| Input | Default | Use |
|---|---|---|
| `php-version` | `8.4` | PHP version |
| `php-extensions` | empty | added to `intl, zip, pdo_mysql, gd, mbstring, bcmath` |
| `system-packages` | empty | extra apt packages for the tests job |
| `upsun-config` | `.upsun/config.yaml` | where test services are read from |
| `typesense` | empty | Typesense version for the tests, e.g. `'29.0'`: starts it, exports `TYPESENSE_URL`/`KEY`/`PREFIX`, runs `enabel:typesense:create` and `import` after the migrations |

Database and Redis are not configured: `scripts/upsun-services.sh` starts the
services the application reaches through its Upsun relationships, with the same
images and versions, and exports `<RELATIONSHIP>_URL`.

Python dependencies declared for the application
(`applications.*.dependencies.python3`, e.g. WeasyPrint) are installed by
`scripts/upsun-dependencies.sh` in the tests job, with the same pinned versions.
System libraries they need go through the `system-packages` input.

- `qa`: composer validate/audit, Symfony lints, XLIFF, Doctrine schema, php-cs-fixer, phpstan
- `tests`: Upsun services, migrations on an empty database, full schema validation (migrations vs mapping), PHPUnit (no coverage)
- `secrets`: gitleaks on the commits of the pull request or push

### Other projects

A project that cannot use `symfony-app.yml` (OpenLegacy, Zend Framework 1)
keeps its own jobs and calls the shared secret scan:

```yaml
jobs:
  secrets:
    uses: enabel/.github/.github/workflows/secrets.yml@v1
```

### Versions

Callers use `@v1`.

- fix or compatible change: tag `vX.Y.Z`, then move `v1`
  (`git tag -f v1 && git push -f origin v1`)
- breaking change: `v2.0.0`; Dependabot offers the upgrade in projects

### Development

Docker only.

```bash
make lint   # shellcheck + actionlint
make test   # scripts/upsun-services.sh tests (SKIP_DOCKER=1 skips integration)
```

Design and decisions: `enabel/platform-docs` (private), `specs/`.
