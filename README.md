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
| Enabel Symfony bundle CI | `.github/workflows/ci.yml` | `qa`, `tests`, `secrets` through `symfony-bundle.yml` |
| Upsun preview comment | `.github/workflows/preview.yml` | comments the Upsun `pr-N` URL on pull requests |

Dependency updates come from Renovate, configured once for the organisation in
`enabel/renovate-config`: add the repository to the Mend Renovate app, no file
is needed in the project. Keep Dependabot alerts enabled (Renovate reads them
for security updates) and Dependabot security updates disabled.

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
| `fixtures` | `false` | `true` runs `doctrine:fixtures:load` after the migrations (and before the Typesense import), for tests that read the fixtures |
| `sass` | `false` | `true` runs `yarn install --frozen-lockfile` and `sass:build` before the tests (symfonycasts/sass-bundle with Sass sources in `node_modules`) |

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

## CI for Symfony bundles

Template **Enabel Symfony bundle CI**, through `symfony-bundle.yml`. Same check
names as the application CI (`ci / qa`, `ci / tests`, `ci / secrets`): one
branch ruleset fits both.

The matrix is fixed: PHP 8.4 lowest, 8.4 highest, 8.5 highest, all on Symfony 8
(`SYMFONY_REQUIRE=8.*` through Flex). Dependencies are resolved with
`composer update`: a lock file in the bundle is ignored.

- `qa`: composer validate (strict) and audit, `php -l` on `src`, php-cs-fixer
  and phpstan when installed (`tools/<tool>` first, then `vendor/bin`)
- `tests`: one entry per matrix line, then a `tests` job that fails if any
  failed; PHPUnit when a `phpunit.xml(.dist)` exists (no coverage)
- `secrets`: gitleaks, as for applications

| Input | Default | Use |
|---|---|---|
| `typesense` | empty | space-separated versions, e.g. `'29.0 30.1'`: one server each, exports `TYPESENSE_V<major>_URL` and `TYPESENSE_API_KEY` |

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
- breaking change: `v2.0.0`; Renovate offers the upgrade in projects

### Development

Docker only.

```bash
make lint   # shellcheck + actionlint
make test   # scripts/upsun-services.sh tests (SKIP_DOCKER=1 skips integration)
```

Design and decisions: `enabel/platform-docs` (private), `specs/`.
