# Versioning Policy

IdemShield follows Semantic Versioning.

## Preview releases

During `0.x`, minor versions may introduce breaking API or persistence changes. Breaking changes will be documented in `CHANGELOG.md` with migration guidance.

## Stable releases

Version `1.0.0` will mark the first stable public API and persistence contract. After `1.0.0`:

- Patch releases contain compatible fixes.
- Minor releases add backward-compatible functionality.
- Major releases may contain documented breaking changes.

Package versions in the IdemShield family are released together so provider dependencies remain unambiguous.
Provider packages require the exact matching `IdemShield.AspNetCore` version.

## Framework support

Release `0.2.0` provides native .NET 8 and .NET 10 assets. Framework support follows Microsoft's support lifecycle. A framework that reaches end of support may be removed in a later pre-`1.0.0` minor release with changelog and migration guidance.

## Support window

Until a formal long-term-support policy is announced, security and correctness fixes target the latest release line. Consumers should stay current within the documented compatibility constraints.
