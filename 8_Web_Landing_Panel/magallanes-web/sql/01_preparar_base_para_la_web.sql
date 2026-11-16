-- =====================================================================
-- Ejecutar UNA vez en SSMS (F5) después de:
--   magallanes_montero_sqlserver_v36.sql  y  magallanes_montero_datos_prueba_v36.sql
-- 1) Crea el usuario de SQL Server que usa la aplicación (si no existe).
-- 2) Pone contraseñas conocidas a dos cuentas de prueba del panel (tabla USUARIO).
-- =====================================================================
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'app_magallanes')
    CREATE LOGIN app_magallanes WITH PASSWORD = N'Magallanes2026!';
GO

USE magallanes_montero_prueba36;     -- base con las 36 tablas
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_magallanes')
    CREATE USER app_magallanes FOR LOGIN app_magallanes;
ALTER ROLE db_datareader ADD MEMBER app_magallanes;   -- SELECT (tablas y vistas)
ALTER ROLE db_datawriter ADD MEMBER app_magallanes;   -- INSERT / UPDATE / DELETE
GO

-- Contraseñas de prueba del panel. En la tabla solo se guarda el HASH BCrypt (nunca la contraseña).
--   karen.paredes@mmabogados.pe   (SECRETARIA)  →  Secretaria2026!
--   hector.magallanes@mmabogados.pe (ABOGADO)    →  Abogado2026!
UPDATE dbo.usuario SET contrasena_hash = '$2a$10$hs6D.8tAYgIQMCLwMh/m1egpTTxf0BAR79eIzLSY5uuiab5zIQOIO'
WHERE email = N'karen.paredes@mmabogados.pe';
UPDATE dbo.usuario SET contrasena_hash = '$2a$10$q0PcvLqE7WRnW/Nq1tYnZeSuRCz2PMJFoGRUG8OZnifPgCX5DmrFG'
WHERE email = N'hector.magallanes@mmabogados.pe';

SELECT u.email, e.cargo, u.activo, LEFT(u.contrasena_hash, 7) + '…' AS hash
FROM dbo.usuario u JOIN dbo.empleado e ON e.id_empleado = u.id_empleado
WHERE u.email IN (N'karen.paredes@mmabogados.pe', N'hector.magallanes@mmabogados.pe');
GO
