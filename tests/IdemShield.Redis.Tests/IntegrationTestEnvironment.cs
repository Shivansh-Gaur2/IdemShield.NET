namespace IdemShield.Redis.Tests;

internal static class IntegrationTestEnvironment
{
    public static string? GetConnectionStringOrFailInCi(string variableName)
    {
        var connectionString = Environment.GetEnvironmentVariable(variableName);
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            return connectionString;
        }

        if (string.Equals(Environment.GetEnvironmentVariable("CI"), "true", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"CI must define {variableName} so provider integration tests cannot silently pass.");
        }

        return null;
    }
}
