# IdemShield 0.2.0 Public-Readiness Design

## Objective

Publish IdemShield `0.2.0` as the first comprehensively hardened public release. The work closes every actionable documentation, package, compatibility, test, automation, and repository-security gap found during the 2026-08-09 audit while preserving the immutable `0.1.0` release.

## Public contract and package family

The three packages continue to ship together:

- `IdemShield.AspNetCore`
- `IdemShield.Redis`
- `IdemShield.SqlServer`

Version `0.2.0` will retain .NET 8 compatibility and add an explicitly built and tested .NET 10 asset. Provider packages will depend on the matching core package version rather than accepting an unbounded future core version. Package validation will compare public API compatibility with the published `0.1.0` baseline and package verification will assert metadata, framework assets, dependency constraints, documentation, symbols, and clean-consumer compilation.

Current supported production dependencies will be selected individually and validated. The existing Dependabot PR that combines unrelated major updates will not be merged as-is. Dependabot configuration will keep future major upgrades isolated from routine compatible updates.

## Runtime hardening

Response replay will exclude security-sensitive or connection-specific headers, including cookie and authentication headers, while retaining documented replayable application headers. Tests will establish the exact header contract.

SQL schema bootstrap will coordinate concurrent application startup so multiple instances cannot race table creation. Existing schema behavior remains compatible, and DBA-managed schema deployment remains supported through `AutoCreateSchema = false`.

No attempt will be made to claim atomicity between an application's business transaction and the IdemShield record. Documentation and repository description will state that limitation precisely.

## Verification

Integration tests will fail in CI if provider connection configuration is missing instead of silently succeeding. Coverage will include:

- middleware key validation, request selection, fingerprint conflicts, concurrency, replay, failure recovery, and sensitive-header filtering;
- Redis claim, completion, deletion, and native expiry;
- SQL claim, duplicate claim, completion, deletion, expiry replacement, cleanup, and concurrent schema initialization;
- clean package consumers targeting .NET 8 and .NET 10.

CI and the release workflow will run restore in locked mode, Release compilation with warnings as errors, formatting verification, all tests against real Redis and SQL Server services, dependency auditing, package creation, package inspection, API compatibility checks, documentation-link validation, and clean-consumer builds. Version validation will use the central package version rather than duplicating a literal value where practical.

## Documentation and public repository

The README will show the actual published status, direct package links and badges, current installation commands, a truthful guarantee boundary, provider choice, operational constraints, and focused documentation links. Architecture, configuration, providers, operations, support, security, versioning, releasing, and changelog documents will be reconciled with the implemented behavior.

GitHub Discussions, private vulnerability reporting, and Dependabot security updates will be enabled. The repository homepage will link to the primary NuGet package. Existing protected-branch, CodeQL, secret-scanning, push-protection, environment approval, and trusted-publishing controls remain in force.

## Release flow

Implementation will occur on `users/shivansh/final-verdicts`. Only intentional tracked project changes and this design are committed; pre-existing local teaching files and untracked historical specs are excluded.

After focused and full verification, the change receives standards and specification review, is pushed through a pull request, and merges only after all protected checks pass. The exact merge commit is tagged `v0.2.0`. A validation-only release rehearsal precedes the protected production run. Publication requires approval of the `nuget` environment, after which all three packages, symbols, GitHub Release assets, NuGet metadata, dependency ranges, and fresh public-feed installations are verified.

## Non-goals

- Rewriting, deleting, or republishing `0.1.0`.
- Manufacturing stars, downloads, endorsements, or NuGet verified-prefix status.
- Adding features unrelated to release correctness and package trust.
- Claiming exactly-once business transactions that the middleware cannot guarantee.

## Completion criteria

The work is complete only when protected GitHub checks and the production release succeed, NuGet lists all three `0.2.0` packages, clean .NET 8 and .NET 10 consumers restore and build from the public feed, public documentation matches the released behavior, and no audit finding remains unresolved without an explicit non-goal above.
