# Security Policy

## Supported Versions

Submersion is currently pre-1.0 release. Security updates are applied to the latest version only.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

Once the project reaches stable multi-version releases, older major versions will receive security patches for 6 months after a new major version is released.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, report vulnerabilities through one of these channels:

1. **GitHub Private Vulnerability Reporting** (preferred): Use the "Report a vulnerability" button on the [Security tab](https://github.com/submersion-app/submersion/security/advisories/new) of this repository.
2. **Email**: Send details to security@submersion.app.

### What to include

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof of concept
- The version(s) affected
- Any suggested fix, if you have one

### What to expect

- **Acknowledgment** within 48 hours of your report
- **Status update** within 7 days with an initial assessment
- **Resolution target** of 30 days for confirmed vulnerabilities, though critical issues will be prioritized for faster fixes
- Credit in the release notes (unless you prefer to remain anonymous)

### Scope

The following are in scope for security reports:

- The Submersion application (iOS, macOS, Android, Windows, Linux)
- Data handling: dive log storage, import/export (UDDF), database operations
- Bluetooth communication with dive computers
- Any cloud sync or network functionality
- Build and release pipeline (CI/CD) if it could compromise end users

The following are out of scope:

- Vulnerabilities in third-party dependencies (report these to the upstream project, but let us know so we can update)
- Social engineering attacks
- Denial of service attacks

## Security Practices

- All secrets are managed through environment variables and GitHub Secrets; none are committed to the repository
- GitHub secret scanning and push protection are enabled
- Pre-push hooks run static analysis (`flutter analyze`) on every push
- Dependencies are reviewed before adoption
