-- =====================================================================
-- ESTUDIO JURÍDICO MAGALLANES-MONTERO · PORTAL DEL CLIENTE Y FIRMA DEL CONTRATO
-- Ejecutar UNA vez en SSMS (F5) DESPUÉS de magallanes_montero_validaciones.sql.
-- Se puede volver a ejecutar: cada paso revisa si ya está hecho.
--
-- Qué cambia en el modelo (sigue teniendo 36 tablas):
--   CONTRATO.fecha_firma      ahora admite NULL  → NULL = «pendiente de firma del cliente»
--   CONTRATO.modalidad_firma  columna NUEVA      → DIGITAL (en el portal) o PRESENCIAL (en el estudio)
--   2 reglas CHECK nuevas: modalidad válida y «fecha y modalidad van juntas».
--   NOTIFICACION.tipo_evento  la lista del CHECK suma 'APERTURA_EXPEDIENTE' (aviso al cliente cuando se abre su caso).
--
-- Qué NO cambia (ya estaba en el modelo de 36 tablas):
--   USUARIO.id_persona   → cuentas del portal del cliente
--   NOTIFICACION         → avisos al cliente y a la campana del panel (canal SISTEMA)
--   ENCUESTA             → fecha_envio (al cerrar el caso) / fecha_respuesta (la responde el cliente)
--   MongoDB «archivos»   → firma.modalidad / firmado_por / fecha (+ imagen de la firma dibujada)
-- =====================================================================
USE magallanes_montero_prueba36;   -- cambie el nombre si su base es otra
GO

-- 1) fecha_firma admite NULL (contrato pendiente de firma)
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.contrato') AND name = 'fecha_firma' AND is_nullable = 0)
    ALTER TABLE dbo.contrato ALTER COLUMN fecha_firma DATE NULL;
GO

-- 2) Columna nueva: modalidad_firma
IF COL_LENGTH('dbo.contrato', 'modalidad_firma') IS NULL
    ALTER TABLE dbo.contrato ADD modalidad_firma VARCHAR(10) NULL;
GO

-- 3) Los contratos que ya existían se firmaron en el estudio (AS-IS): PRESENCIAL
UPDATE dbo.contrato SET modalidad_firma = 'PRESENCIAL' WHERE fecha_firma IS NOT NULL AND modalidad_firma IS NULL;
GO

-- 4) Reglas CHECK
IF OBJECT_ID('dbo.ck_contrato_modalidad_firma') IS NULL
    ALTER TABLE dbo.contrato WITH CHECK ADD CONSTRAINT ck_contrato_modalidad_firma
        CHECK (modalidad_firma IS NULL OR modalidad_firma IN ('DIGITAL', 'PRESENCIAL'));
IF OBJECT_ID('dbo.ck_contrato_firma_completa') IS NULL
    ALTER TABLE dbo.contrato WITH CHECK ADD CONSTRAINT ck_contrato_firma_completa      -- Regla: firmado = fecha + modalidad; pendiente = ambos NULL
        CHECK ((fecha_firma IS NULL AND modalidad_firma IS NULL) OR (fecha_firma IS NOT NULL AND modalidad_firma IS NOT NULL));
GO

-- 4b) Nuevo evento de notificación: APERTURA_EXPEDIENTE (W09 avisa al cliente en su portal)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'ck_notificacion_tipo_evento' AND definition LIKE '%APERTURA_EXPEDIENTE%')
BEGIN
    IF OBJECT_ID('dbo.ck_notificacion_tipo_evento') IS NOT NULL
        ALTER TABLE dbo.notificacion DROP CONSTRAINT ck_notificacion_tipo_evento;
    ALTER TABLE dbo.notificacion WITH CHECK ADD CONSTRAINT ck_notificacion_tipo_evento
        CHECK (tipo_evento IN ('CONFIRMACION_CONSULTA', 'RECORDATORIO_CITA', 'ALERTA_PLAZO', 'AVISO_AUDIENCIA', 'RECORDATORIO_CUOTA',
                               'CONSTANCIA_PAGO', 'ENVIO_ENCUESTA', 'FIRMA_DOCUMENTO', 'APERTURA_EXPEDIENTE'));
END
GO

-- 5) Cuentas del PORTAL DEL CLIENTE (tabla USUARIO con id_persona).
--    Todo cliente con contrato tiene cuenta. Contraseña de prueba: Cliente2026!  (solo se guarda el hash BCrypt)
--    El cliente entra con su DNI/RUC o con su correo.
DECLARE @hash VARCHAR(100) = '$2a$10$Jo4FFD3S6tBD5AkKUkIE0.T/7pU4Eu5d6m98vGJf4Wj8f.y9SkWeK';
;WITH sin_cuenta AS (
    SELECT p.id_persona, LOWER(p.email) AS email,
           LOWER(p.tipo_documento) + p.nro_documento + '@portal.mmabogados.pe' AS email_generado,
           ROW_NUMBER() OVER (PARTITION BY LOWER(p.email) ORDER BY p.id_persona) AS n   -- dos personas con el mismo correo: solo la 1.ª lo usa
    FROM dbo.persona p
    WHERE p.nro_documento IS NOT NULL
      AND EXISTS (SELECT 1 FROM dbo.contrato k WHERE k.id_cliente = p.id_persona)
      AND NOT EXISTS (SELECT 1 FROM dbo.usuario u WHERE u.id_persona = p.id_persona))
INSERT INTO dbo.usuario (id_persona, email, contrasena_hash, activo)
SELECT id_persona,
       CASE WHEN email IS NOT NULL AND n = 1 AND NOT EXISTS (SELECT 1 FROM dbo.usuario u WHERE u.email = sin_cuenta.email)
            THEN email ELSE email_generado END,
       @hash, 1
FROM sin_cuenta
WHERE NOT EXISTS (SELECT 1 FROM dbo.usuario u WHERE u.email = sin_cuenta.email_generado);
UPDATE dbo.usuario SET contrasena_hash = @hash, activo = 1 WHERE id_persona IS NOT NULL;
GO

-- 6) DEMO: María Elena Torres (cliente actual) contrata un segundo servicio y el contrato queda PENDIENTE DE FIRMA.
--    Así se puede mostrar la firma digital en el portal sin preparar nada.
IF NOT EXISTS (SELECT 1 FROM dbo.consulta WHERE id_persona = 2 AND resumen LIKE N'Desalojo del local alquilado%')
BEGIN
    DECLARE @persona INT = (SELECT id_persona FROM dbo.persona WHERE tipo_documento = 'DNI' AND nro_documento = '40987123');
    DECLARE @civil SMALLINT = (SELECT TOP 1 id_materia FROM dbo.materia ORDER BY id_materia);   -- Civil
    DECLARE @secre INT = (SELECT TOP 1 id_empleado FROM dbo.empleado WHERE cargo = 'SECRETARIA' AND activo = 1);
    DECLARE @abog INT = (SELECT TOP 1 a.id_empleado FROM dbo.abogado a JOIN dbo.abogado_materia am ON am.id_abogado = a.id_empleado
                         WHERE am.id_materia = @civil ORDER BY am.es_principal DESC);
    DECLARE @cons INT, @prop INT, @cont INT, @nro NVARCHAR(20);

    INSERT INTO dbo.consulta (id_persona, id_materia, id_registrado_por, canal, fecha_hora_recepcion, resumen, existe_conflicto,
                              id_revisor_conflicto, fecha_revision_conflicto, monto_consulta, estado)
    VALUES (@persona, @civil, @secre, 'WHATSAPP', DATEADD(DAY, -6, SYSDATETIME()),
            N'Desalojo del local alquilado en Lince: el inquilino no paga hace 5 meses', 0, @abog, DATEADD(DAY, -5, SYSDATETIME()), 100.00, 'CONTRATADA');
    SET @cons = SCOPE_IDENTITY();
    INSERT INTO dbo.cita (id_consulta, id_abogado, fecha_hora, modalidad, recordatorio_enviado, estado)
    VALUES (@cons, @abog, DATEADD(HOUR, 10, CAST(DATEADD(DAY, -4, CAST(GETDATE() AS DATE)) AS DATETIME2(0))), 'PRESENCIAL', 1, 'ASISTIO');
    INSERT INTO dbo.propuesta (id_consulta, id_abogado, version, monto_honorarios, porcentaje_cuota_litis, nro_cuotas, fecha_envio, fecha_respuesta, estado)
    VALUES (@cons, @abog, 1, 2400.00, 0, 3, DATEADD(DAY, -3, CAST(GETDATE() AS DATE)), DATEADD(DAY, -1, CAST(GETDATE() AS DATE)), 'ACEPTADA');
    SET @prop = SCOPE_IDENTITY();

    SELECT @nro = 'CT-' + CAST(YEAR(GETDATE()) AS VARCHAR(4)) + '-' +
           RIGHT('0000' + CAST(COALESCE(MAX(TRY_CAST(RIGHT(nro_contrato, 4) AS INT)), 0) + 1 AS VARCHAR(4)), 4)
    FROM dbo.contrato WHERE nro_contrato LIKE 'CT-' + CAST(YEAR(GETDATE()) AS VARCHAR(4)) + '-%';
    INSERT INTO dbo.contrato (id_propuesta, id_cliente, nro_contrato, fecha_firma, modalidad_firma, tipo_encargo, modalidad_pago, con_carta_poder)
    VALUES (@prop, @persona, @nro, NULL, NULL, 'PATROCINIO', 'CUOTAS', 1);                  -- ← PENDIENTE DE FIRMA
    SET @cont = SCOPE_IDENTITY();
    INSERT INTO dbo.cuota (id_contrato, nro_cuota, concepto, monto, fecha_vencimiento) VALUES
      (@cont, 1, 'ADELANTO', 800.00, DATEADD(DAY, 3,  CAST(GETDATE() AS DATE))),
      (@cont, 2, 'CUOTA',    800.00, DATEADD(DAY, 33, CAST(GETDATE() AS DATE))),
      (@cont, 3, 'CUOTA',    800.00, DATEADD(DAY, 63, CAST(GETDATE() AS DATE)));
    INSERT INTO dbo.notificacion (id_persona, id_consulta, tipo_evento, canal, mensaje, fecha_programada, fecha_envio, estado)
    VALUES (@persona, @cons, 'FIRMA_DOCUMENTO', 'SISTEMA', N'Su contrato ' + @nro + N' está listo. Revíselo y fírmelo en su portal.', SYSDATETIME(), SYSDATETIME(), 'ENVIADA');
END
GO

-- 7) Verificación
SELECT k.id_contrato, k.nro_contrato, k.fecha_firma, k.modalidad_firma,
       CASE WHEN k.fecha_firma IS NULL THEN 'PENDIENTE DE FIRMA' ELSE 'FIRMADO' END AS estado_firma,
       COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente
FROM dbo.contrato k JOIN dbo.persona p ON p.id_persona = k.id_cliente ORDER BY k.id_contrato DESC;

SELECT u.email, p.tipo_documento + ' ' + p.nro_documento AS entra_con, 'Cliente2026!' AS contrasena_prueba, u.activo
FROM dbo.usuario u JOIN dbo.persona p ON p.id_persona = u.id_persona ORDER BY u.id_usuario;

-- Prueba de la regla nueva (debe fallar y se deshace):
BEGIN TRY
    BEGIN TRAN;
    UPDATE TOP (1) dbo.contrato SET modalidad_firma = NULL WHERE fecha_firma IS NOT NULL;   -- firmado sin modalidad → NO
    ROLLBACK;
    PRINT 'ERROR: la regla ck_contrato_firma_completa no funcionó';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT 'OK, SQL Server rechazó un contrato firmado sin modalidad: ' + ERROR_MESSAGE();
END CATCH
GO
