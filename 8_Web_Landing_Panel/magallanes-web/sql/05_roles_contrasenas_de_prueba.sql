-- =====================================================================
-- ROLES DEL PANEL · contraseñas de prueba para cada rol
-- Ejecutar UNA vez en SSMS (F5) sobre magallanes_montero_prueba36.
--
-- El rol NO es una tabla nueva: sale de empleado.cargo (3FN, ya existe).
--   ADMINISTRADOR → Gerencia (ve todo + dashboard)
--   ABOGADO       → propuestas, expediente nuevo, escritos y resoluciones, dashboard
--   SECRETARIA    → consultas y citas, contratos y cuotas, cobranza y cierre
--   PRACTICANTE   → escritos y resoluciones
-- Solo se guarda el HASH BCrypt, nunca la contraseña.
-- =====================================================================
USE magallanes_montero_prueba36;
GO
--   gabriela.montero@mmabogados.pe (ADMINISTRADOR) → Gerencia2026!
UPDATE dbo.usuario SET contrasena_hash = '$2a$10$yYJnZ/yM.FSkGxdtClciA.6KqtcVXJILuxUR5FDyr4aLUvCWe0b6q', activo = 1
WHERE email = N'gabriela.montero@mmabogados.pe';
--   miguel.rojas@mmabogados.pe (PRACTICANTE) → Practicante2026!
UPDATE dbo.usuario SET contrasena_hash = '$2a$10$L3POegXtz5ppMiBJ8C2JaONQicrKKYKJJxJbJdNl9Mdt81eRmVczK', activo = 1
WHERE email = N'miguel.rojas@mmabogados.pe';
--   lucia.montero@mmabogados.pe (ABOGADO) → Abogado2026!
UPDATE dbo.usuario SET contrasena_hash = '$2a$10$GZoZjj4ytv1AfuzwJAsu5edWvgSkxBamHcDGYEnZ0qET3UbVA68XW', activo = 1
WHERE email = N'lucia.montero@mmabogados.pe';
GO
SELECT u.email, e.cargo AS rol, u.activo FROM dbo.usuario u JOIN dbo.empleado e ON e.id_empleado = u.id_empleado ORDER BY e.cargo;
GO
