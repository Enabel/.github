# Symfony Application

This directory contains all additional files for a Symfony application on GitHub.

## Contents

- `/tools`: Contains tools useful for coding standards.
  - `/tools/php-cs-fixer`: PHP-CS-Fixer is a tool to check & fix code according to standards like PSR-12.
  - `/tools/phpstan`: PHPStan is a static code analysis tool.
- `/.php-cs-fixer.dist.php`: PHP-CS-Fixer configuration.
- `/.php-version`: PHP version. [see symfony-cli](https://symfony.com/doc/current/setup/symfony_cli.html#selecting-php-version)
- `/.symfony.local.yaml`: Symfony CLI configuration. [see symfony-cli](https://symfony.com/doc/current/setup/symfony_cli.html#advanced-configuration)
- `/Makefile`: Makefile to run commands like `run`, `abort`, `analyze` and `fix`.
- `/php.ini`: Project-specific PHP configuration.
- `/phpstan.dist.neon`: PHPStan configuration.
- `/phpunit.dist.xml`: PHPUnit configuration.

## Recommended dependencies

- [Dama/Doctrine](https://github.com/dmaicher/doctrine-test-bundle): Isolates database transactions for each test.
- [Zenstruck/foundry](https://github.com/zenstruck/foundry): Easily create fake objects for testing.

## Github Actions workflows

- [symfony-application](/workflow-templates/symfony-application.yaml): Workflow with validate, security, code-style & tests
