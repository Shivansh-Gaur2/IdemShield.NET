# Changelog

All notable changes to IdemShield.NET are documented here. The project follows [Semantic Versioning](https://semver.org/) and keeps unreleased work at the top.

[Unreleased]: https://github.com/Shivansh-Gaur2/IdemShield.NET/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Shivansh-Gaur2/IdemShield.NET/releases/tag/v0.2.0
[0.1.0]: https://github.com/Shivansh-Gaur2/IdemShield.NET/releases/tag/v0.1.0

## [Unreleased]

## [0.2.0] - 2026-08-09

### Added

- Native .NET 10 package assets alongside continued .NET 8 support.
- Package API compatibility validation against the published `0.1.0` baseline.
- Redis expiry and SQL store, concurrency, expiry-replacement, and schema-startup integration coverage.
- Documentation-link and dual-framework clean-consumer validation.

### Changed

- Provider packages now require the exact matching `IdemShield.AspNetCore` version.
- Centralized and updated production and test dependency versions.
- SQL automatic schema initialization now coordinates concurrent application instances.
- CI fails when provider integration configuration is missing.

### Security

- Response replay excludes cookie, authentication, server-generated, and connection-specific headers.

### Removed

- Removed the accidentally exposed `FingerprintCalculator` helper from the public binary contract. It was declared internal in source and was never intended for consumer use.

## [0.1.0] - 2026-08-08

### Added

- ASP.NET Core idempotency middleware with configurable key scoping and concurrency handling.
- Redis and SQL Server storage providers.
- Coordinated SQL Server expiry cleanup.
- Release builds, provider integration tests, package validation, and consumer smoke testing in CI.

### Changed

- Renamed the project and package family from IdemPotent to IdemShield before public release.
