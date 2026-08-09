# Support

## Compatibility

IdemShield `0.2.0` targets .NET 8 and .NET 10 and supports ASP.NET Core applications using:

- Redis through `StackExchange.Redis`.
- SQL Server 2022 or a compatible SQL Server edition supporting `sp_getapplock` and `DATETIMEOFFSET`.

Compatibility claims are limited to environments exercised by CI or documented by the underlying provider.

## Getting help

- Use [GitHub Discussions](https://github.com/Shivansh-Gaur2/IdemShield.NET/discussions) for usage questions and design conversations.
- Open a GitHub issue for reproducible defects or documentation gaps.
- Follow `SECURITY.md` for vulnerabilities.

Include the package version, .NET version, provider version, deployment topology, relevant configuration, and a minimal reproduction. Remove credentials and sensitive application data from logs.

Preview releases may contain breaking changes. The versioning policy in `docs/versioning.md` explains the compatibility commitment.
