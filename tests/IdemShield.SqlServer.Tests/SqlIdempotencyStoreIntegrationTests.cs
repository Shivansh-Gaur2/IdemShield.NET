using IdemShield.AspNetCore;
using IdemShield.SqlServer;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace IdemShield.SqlServer.Tests;

public class SqlIdempotencyStoreIntegrationTests
{
    [Fact]
    [Trait("Category", "Integration")]
    public async Task Store_claims_completes_reads_and_deletes_a_record()
    {
        var connectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_SQL_TEST_CONNECTION");
        if (connectionString is null)
        {
            return;
        }
        var store = CreateStore(connectionString);
        var key = $"sql-store-test-{Guid.NewGuid():N}";
        var record = CreateRecord(key, DateTimeOffset.UtcNow.AddMinutes(5));

        try
        {
            Assert.True(await store.TryInsertInProgressAsync(record, CancellationToken.None));
            Assert.False(await store.TryInsertInProgressAsync(record, CancellationToken.None));

            var inProgress = await store.GetAsync(key, CancellationToken.None);
            Assert.NotNull(inProgress);
            Assert.Equal(IdempotencyStatus.InProgress, inProgress.Status);

            await store.UpdateAsCompletedAsync(
                key,
                201,
                "{\"orderId\":42}",
                "{\"Content-Type\":\"application/json\"}",
                CancellationToken.None);

            var completed = await store.GetAsync(key, CancellationToken.None);
            Assert.NotNull(completed);
            Assert.Equal(IdempotencyStatus.Completed, completed.Status);
            Assert.Equal(201, completed.ResponseStatusCode);
            Assert.Equal("{\"orderId\":42}", completed.ResponseBody);
        }
        finally
        {
            await store.DeleteAsync(key, CancellationToken.None);
        }

        Assert.Null(await store.GetAsync(key, CancellationToken.None));
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task Store_replaces_an_expired_record_with_the_same_key()
    {
        var connectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_SQL_TEST_CONNECTION");
        if (connectionString is null)
        {
            return;
        }
        var store = CreateStore(connectionString);
        var key = $"sql-expired-replacement-{Guid.NewGuid():N}";

        try
        {
            Assert.True(await store.TryInsertInProgressAsync(
                CreateRecord(key, DateTimeOffset.UtcNow.AddMinutes(-1)),
                CancellationToken.None));
            Assert.Null(await store.GetAsync(key, CancellationToken.None));

            Assert.True(await store.TryInsertInProgressAsync(
                CreateRecord(key, DateTimeOffset.UtcNow.AddMinutes(5)),
                CancellationToken.None));
            Assert.NotNull(await store.GetAsync(key, CancellationToken.None));
        }
        finally
        {
            await store.DeleteAsync(key, CancellationToken.None);
        }
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task Concurrent_claims_have_exactly_one_winner()
    {
        var connectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_SQL_TEST_CONNECTION");
        if (connectionString is null)
        {
            return;
        }
        var store = CreateStore(connectionString);
        var key = $"sql-concurrent-claim-{Guid.NewGuid():N}";

        try
        {
            var claims = Enumerable.Range(0, 12)
                .Select(_ => store.TryInsertInProgressAsync(
                    CreateRecord(key, DateTimeOffset.UtcNow.AddMinutes(5)),
                    CancellationToken.None));

            var results = await Task.WhenAll(claims);

            Assert.Single(results, result => result);
        }
        finally
        {
            await store.DeleteAsync(key, CancellationToken.None);
        }
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task Concurrent_schema_initialization_is_safe()
    {
        var baseConnectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_SQL_TEST_CONNECTION");
        if (baseConnectionString is null)
        {
            return;
        }
        var databaseName = $"IdemShieldSchema{Guid.NewGuid():N}";
        var adminConnectionString = WithDatabase(baseConnectionString, "master");
        var isolatedConnectionString = WithDatabase(baseConnectionString, databaseName);

        await ExecuteAdminCommandAsync(adminConnectionString, $"CREATE DATABASE [{databaseName}]");
        try
        {
            var initializations = Enumerable.Range(0, 12).Select(_ => Task.Run(() =>
            {
                var services = new ServiceCollection();
                services.UseSqlServerStore(isolatedConnectionString, options => options.EnableCleanup = false);
            }));

            await Task.WhenAll(initializations);

            await using var connection = new SqlConnection(isolatedConnectionString);
            await connection.OpenAsync();
            await using var command = new SqlCommand(
                "SELECT COUNT(*) FROM sys.tables WHERE name = 'IdempotencyRecords'",
                connection);
            Assert.Equal(1, Convert.ToInt32(await command.ExecuteScalarAsync()));
        }
        finally
        {
            SqlConnection.ClearAllPools();
            await ExecuteAdminCommandAsync(
                adminConnectionString,
                $"ALTER DATABASE [{databaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{databaseName}]");
        }
    }

    private static SqlIdempotencyStore CreateStore(string connectionString)
    {
        var services = new ServiceCollection();
        services.UseSqlServerStore(connectionString, options => options.EnableCleanup = false);
        return new SqlIdempotencyStore(connectionString);
    }

    private static IdempotencyRecord CreateRecord(string key, DateTimeOffset expiresAt) => new()
    {
        IdempotencyKey = key,
        RequestFingerprint = "sql-store-integration-test",
        Status = IdempotencyStatus.InProgress,
        CreatedAt = DateTimeOffset.UtcNow,
        ExpiresAt = expiresAt
    };

    private static string WithDatabase(string connectionString, string databaseName)
    {
        var builder = new SqlConnectionStringBuilder(connectionString)
        {
            InitialCatalog = databaseName
        };
        return builder.ConnectionString;
    }

    private static async Task ExecuteAdminCommandAsync(string connectionString, string commandText)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(commandText, connection);
        await command.ExecuteNonQueryAsync();
    }
}
