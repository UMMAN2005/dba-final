USE [master]
GO

SELECT 
    p.name AS Principal, 
    p.type_desc AS Type, 
    perm.permission_name AS Permission, 
    perm.state_desc AS State
FROM sys.server_principals p
JOIN sys.server_permissions perm ON p.principal_id = perm.grantee_principal_id
WHERE p.name NOT LIKE '##%' AND p.name NOT LIKE 'MS_%';
GO

USE CoreDB;
GO
SELECT 
    u.name AS [User],   
    r.name AS [Role]      
FROM sys.database_role_members m  
RIGHT JOIN sys.database_principals u ON m.member_principal_id = u.principal_id  
LEFT JOIN sys.database_principals r ON m.role_principal_id = r.principal_id  
WHERE u.type_desc != 'DATABASE_ROLE' AND u.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys');
GO
