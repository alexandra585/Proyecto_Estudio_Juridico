-- =====================================================================
-- Prueba en SSMS de las MISMAS sentencias SQL que ejecuta el código Java
-- (Landing + agendar cita). Todo va dentro de una transacción que al final
-- se deshace con ROLLBACK: la base queda igual. Si ve "OK" al final, el SQL está bien.
-- =====================================================================
USE magallanes_montero_prueba36;     -- base con las 36 tablas
GO
SET NOCOUNT ON;
BEGIN TRANSACTION;
DECLARE @p INT, @c INT, @cp INT, @cita INT;
DECLARE @fecha DATETIME2(0) = DATEADD(HOUR, 10, CAST(CAST(DATEADD(DAY, 2, GETDATE()) AS DATE) AS DATETIME2(0)));

-- ===== Landing · T1 (ConsultaRepositorio.registrarDesdeLanding)
INSERT INTO dbo.persona (tipo_persona, tipo_documento, nro_documento, nombres, apellidos, razon_social, telefono, email, acepta_tratamiento_datos)
VALUES ('NATURAL', 'DNI', '49999901', N'Ana Lucía', N'Salazar Díaz', NULL, '932109876', 'ana.salazar@example.com', 1);
SET @p = SCOPE_IDENTITY();
INSERT INTO dbo.consulta (id_persona, id_materia, id_registrado_por, canal, resumen, es_urgente)
VALUES (@p, 4, NULL, 'LANDING', N'Mi expareja dejó de pagar la pensión de mis dos hijos', 0);
SET @c = SCOPE_IDENTITY();
INSERT INTO dbo.persona (tipo_persona, tipo_documento, nro_documento, nombres, apellidos, razon_social, telefono, email, acepta_tratamiento_datos)
VALUES ('NATURAL', NULL, NULL, N'Carlos', N'Ramos Vela', NULL, NULL, NULL, 0);
SET @cp = SCOPE_IDENTITY();
INSERT INTO dbo.consulta_contraparte (id_consulta, id_persona) VALUES (@c, @cp);
INSERT INTO dbo.notificacion (id_persona, id_consulta, tipo_evento, canal, mensaje, fecha_programada)
VALUES (@p, @c, 'CONFIRMACION_CONSULTA', 'WHATSAPP', N'Hola Ana Lucía, recibimos su consulta.', SYSDATETIME());

-- ===== Lecturas de la Landing (PublicoRepositorio)
SELECT id_materia, nombre, descripcion FROM dbo.materia ORDER BY id_materia;
SELECT e.id_empleado, e.nombres + ' ' + e.apellidos AS socio, a.nro_colegiatura,
       (SELECT STRING_AGG(m.nombre, ' · ') WITHIN GROUP (ORDER BY am.es_principal DESC, m.nombre)
          FROM dbo.abogado_materia am JOIN dbo.materia m ON m.id_materia = am.id_materia WHERE am.id_abogado = a.id_empleado) AS materias
FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado WHERE e.activo = 1;
SELECT CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)) AS promedio, COUNT(calificacion) AS respuestas FROM dbo.encuesta;

-- ===== Panel · abogados de la materia y agendar cita (CitaRepositorio.agendar)
SELECT a.id_empleado, e.nombres + ' ' + e.apellidos AS abogado, am.es_principal
FROM dbo.abogado_materia am JOIN dbo.abogado a ON a.id_empleado = am.id_abogado
JOIN dbo.empleado e ON e.id_empleado = a.id_empleado WHERE am.id_materia = 4;

SELECT c.estado, c.existe_conflicto FROM dbo.consulta c WITH (UPDLOCK, ROWLOCK) WHERE c.id_consulta = @c;
SELECT COUNT(*) AS choques FROM dbo.cita WITH (UPDLOCK, HOLDLOCK) WHERE id_abogado = 2 AND fecha_hora = @fecha
  AND estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA');

INSERT INTO dbo.cita (id_consulta, id_abogado, fecha_hora, modalidad) VALUES (@c, 2, @fecha, 'PRESENCIAL');
SET @cita = SCOPE_IDENTITY();
UPDATE dbo.consulta SET estado = 'AGENDADA' WHERE id_consulta = @c;
INSERT INTO dbo.notificacion (id_persona, id_empleado, id_consulta, tipo_evento, canal, mensaje, fecha_programada)
VALUES (@p, NULL, @c, 'RECORDATORIO_CITA', 'WHATSAPP', N'Su cita es mañana.', DATEADD(DAY, -1, @fecha));
INSERT INTO dbo.notificacion (id_persona, id_empleado, id_consulta, tipo_evento, canal, mensaje, fecha_programada)
VALUES (NULL, 2, @c, 'RECORDATORIO_CITA', 'SISTEMA', N'Nueva cita.', SYSDATETIME());

SELECT 'OK: Landing (T1) y agendar cita funcionan' AS resultado, @p AS id_persona, @c AS id_consulta, @cita AS id_cita;
ROLLBACK TRANSACTION;   -- deshace todo
GO
