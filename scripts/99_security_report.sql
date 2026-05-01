USE [master]
GO

/* 1) SERVER-LEVEL PERMISSIONS REPORT */
SELECT 
    p.name AS Principal, 
    p.type_desc AS Type, 
    perm.permission_name AS Permission, 
    perm.state_desc AS State
FROM sys.server_principals p
JOIN sys.server_permissions perm ON p.principal_id = perm.grantee_principal_id
WHERE p.name NOT LIKE '##%' AND p.name NOT LIKE 'MS_%';
GO

/* 2) PREPARE TEMPORARY TABLES FOR CROSS-DATABASE AUDIT */
IF OBJECT_ID('tempdb..#DatabaseRoleMemberships') IS NOT NULL
    DROP TABLE #DatabaseRoleMemberships;

IF OBJECT_ID('tempdb..#DatabaseExplicitPermissions') IS NOT NULL
    DROP TABLE #DatabaseExplicitPermissions;
GO

CREATE TABLE #DatabaseRoleMemberships
(
    DatabaseName SYSNAME,
    UserName SYSNAME,
    UserType NVARCHAR(60),
    RoleName SYSNAME NULL
);

CREATE TABLE #DatabaseExplicitPermissions
(
    DatabaseName SYSNAME,
    PrincipalName SYSNAME,
    PrincipalType NVARCHAR(60),
    PermissionName NVARCHAR(128),
    StateDesc NVARCHAR(60),
    ClassDesc NVARCHAR(60),
    SchemaName SYSNAME NULL,
    ObjectName SYSNAME NULL,
    ObjectType NVARCHAR(60) NULL
);
GO

/* 3) DYNAMICALLY COLLECT DATA FROM ALL ONLINE USER DATABASES */
DECLARE @DynamicSQL NVARCHAR(MAX) = N'';

SELECT @DynamicSQL = @DynamicSQL + N'
USE ' + QUOTENAME(name) + N';

INSERT INTO #DatabaseRoleMemberships (DatabaseName, UserName, UserType, RoleName)
SELECT
    DB_NAME(),
    u.name,
    u.type_desc,
    r.name
FROM sys.database_principals u
LEFT JOIN sys.database_role_members m
    ON u.principal_id = m.member_principal_id
LEFT JOIN sys.database_principals r
    ON m.role_principal_id = r.principal_id
WHERE u.type_desc <> ''DATABASE_ROLE''
  AND u.name NOT IN (''dbo'', ''guest'', ''INFORMATION_SCHEMA'', ''sys'');

INSERT INTO #DatabaseExplicitPermissions
(
    DatabaseName,
    PrincipalName,
    PrincipalType,
    PermissionName,
    StateDesc,
    ClassDesc,
    SchemaName,
    ObjectName,
    ObjectType
)
SELECT
    DB_NAME(),
    dp.name,
    dp.type_desc,
    perm.permission_name,
    perm.state_desc,
    perm.class_desc,
    OBJECT_SCHEMA_NAME(perm.major_id),
    OBJECT_NAME(perm.major_id),
    o.type_desc
FROM sys.database_permissions perm
JOIN sys.database_principals dp
    ON perm.grantee_principal_id = dp.principal_id
LEFT JOIN sys.objects o
    ON perm.major_id = o.object_id
WHERE dp.name NOT IN (''dbo'', ''guest'', ''INFORMATION_SCHEMA'', ''sys'');'
FROM sys.databases
WHERE database_id > 4
  AND state_desc = 'ONLINE';

EXEC sys.sp_executesql @DynamicSQL;
GO

/* 4) FINAL REPORT OUTPUT */
SELECT
    DatabaseName,
    UserName AS [User],
    UserType,
    RoleName AS [Role]
FROM #DatabaseRoleMemberships
ORDER BY DatabaseName, UserName, RoleName;
GO

SELECT
    DatabaseName,
    PrincipalName,
    PrincipalType,
    PermissionName,
    StateDesc,
    ClassDesc,
    SchemaName,
    ObjectName,
    ObjectType
FROM #DatabaseExplicitPermissions
ORDER BY DatabaseName, PrincipalName, PermissionName, SchemaName, ObjectName;
GO
