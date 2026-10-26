# Security policy

This policy applies to every Enabel repository on GitHub that has no `SECURITY.md` of its own.

## Reporting a vulnerability

Send the details to **csirt@enabel.be**. Please do not open a public issue, pull request or discussion for a
security problem.

Include what you can of:

- the application or package and, if relevant, the URL or version;
- the steps to reproduce, and the impact you observed;
- your contact details, if you want to be kept informed.

## Supported versions

- **Applications:** only the version running in production (the `main` branch) receives security fixes.
- **Packages (bundles, themes, coding standard):** only the latest release receives security fixes.

## ASVS target level

Each in-house application is developed against a target level of the
[OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)
(ASVS). Proposed levels, to be validated by the CISO:

| Repository | ASVS target level |
|---|---|
| AuthProxy | L2 |
| EAgle | L2 |
| EnabelIntegrationPlatform | L2 |
| GrantManagement | L2 |
| Impala | L2 |
| Mandate | L2 |
| OWL | L2 |
| Travel | L2 |
| InformationPortal | L1 |
| OpenLegacy | L1 |
| Redirect | L1 |

L2 applies to applications whose users sign in to handle internal data; L1 to public websites that publish open
information.
