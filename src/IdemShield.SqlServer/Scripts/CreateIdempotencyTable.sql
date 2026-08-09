DECLARE @schemaLockResult INT;

EXEC @schemaLockResult = sp_getapplock
    @Resource = 'IdemShield.SqlServer.SchemaInitialization',
    @LockMode = 'Exclusive',
    @LockOwner = 'Session',
    @LockTimeout = 30000;

IF @schemaLockResult < 0
BEGIN
    THROW 51000, 'IdemShield could not acquire the SQL schema initialization lock.', 1;
END;

BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'IdempotencyRecords')
    BEGIN
        CREATE TABLE IdempotencyRecords (
            IdempotencyKey NVARCHAR(255) NOT NULL PRIMARY KEY,
            RequestFingerprint NVARCHAR(64) NOT NULL,
            Status TINYINT NOT NULL,
            ResponseStatusCode INT NULL,
            ResponseBody NVARCHAR(MAX) NULL,
            ResponseHeaders NVARCHAR(MAX) NULL,
            CreatedAt DATETIMEOFFSET NOT NULL,
            ExpiresAt DATETIMEOFFSET NOT NULL
        );

        CREATE INDEX IX_IdempotencyRecords_ExpiresAt ON IdempotencyRecords (ExpiresAt);
    END;
END TRY
BEGIN CATCH
    EXEC sp_releaseapplock
        @Resource = 'IdemShield.SqlServer.SchemaInitialization',
        @LockOwner = 'Session';
    THROW;
END CATCH;

EXEC sp_releaseapplock
    @Resource = 'IdemShield.SqlServer.SchemaInitialization',
    @LockOwner = 'Session';
