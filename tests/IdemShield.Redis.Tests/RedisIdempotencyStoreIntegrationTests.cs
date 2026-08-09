using IdemShield.AspNetCore;
using IdemShield.Redis;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace IdemShield.Redis.Tests;

public class RedisIdempotencyStoreIntegrationTests
{
    [Fact]
    [Trait("Category", "Integration")]
    public async Task Store_round_trips_and_releases_an_idempotency_record()
    {
        var connectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_REDIS_TEST_CONNECTION");
        if (connectionString is null)
        {
            return;
        }

        var key = $"redis-test-{Guid.NewGuid():N}";
        var services = new ServiceCollection();
        services.UseRedisStore(connectionString);
        await using var provider = services.BuildServiceProvider();
        var store = provider.GetRequiredService<IIdempotencyStore>();
        var record = new IdempotencyRecord
        {
            IdempotencyKey = key,
            RequestFingerprint = "redis-integration-test",
            Status = IdempotencyStatus.InProgress,
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(5)
        };

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
    public async Task Store_expires_records_using_the_redis_key_ttl()
    {
        var connectionString = IntegrationTestEnvironment.GetConnectionStringOrFailInCi("IDEMSHIELD_REDIS_TEST_CONNECTION");
        if (connectionString is null)
        {
            return;
        }
        var key = $"redis-expiry-test-{Guid.NewGuid():N}";
        var services = new ServiceCollection();
        services.UseRedisStore(connectionString);
        await using var provider = services.BuildServiceProvider();
        var store = provider.GetRequiredService<IIdempotencyStore>();
        var record = new IdempotencyRecord
        {
            IdempotencyKey = key,
            RequestFingerprint = "redis-expiry-test",
            Status = IdempotencyStatus.InProgress,
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddMilliseconds(250)
        };

        try
        {
            Assert.True(await store.TryInsertInProgressAsync(record, CancellationToken.None));

            for (var attempt = 0; attempt < 40; attempt++)
            {
                if (await store.GetAsync(key, CancellationToken.None) is null)
                {
                    return;
                }

                await Task.Delay(50);
            }

            Assert.Fail("Redis did not expire the idempotency record within two seconds.");
        }
        finally
        {
            await store.DeleteAsync(key, CancellationToken.None);
        }
    }
}
