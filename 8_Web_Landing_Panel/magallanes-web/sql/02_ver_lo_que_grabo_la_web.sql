-- =====================================================================
-- Para mostrar al profesor lo que grabaron la Landing (T1) y el panel (cita)
-- =====================================================================
USE magallanes_montero_prueba36;     -- base con las 36 tablas
GO
-- ---------- Landing · última consulta que llegó por la web
DECLARE @c INT = (SELECT MAX(id_consulta) FROM dbo.consulta WHERE canal = 'LANDING');

SELECT 'CONSULTA' AS tabla, id_consulta, id_persona, id_materia, id_registrado_por, canal, estado, es_urgente, fecha_hora_recepcion, resumen
FROM dbo.consulta WHERE id_consulta = @c;

SELECT 'PERSONA (cliente)' AS tabla, p.id_persona, p.tipo_persona, p.tipo_documento, p.nro_documento, p.nombres, p.apellidos,
       p.telefono, p.email, p.acepta_tratamiento_datos, p.fecha_registro
FROM dbo.persona p WHERE p.id_persona = (SELECT id_persona FROM dbo.consulta WHERE id_consulta = @c);

SELECT 'CONSULTA_CONTRAPARTE' AS tabla, cc.id_consulta, cc.id_persona, p.tipo_persona,
       COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS contraparte
FROM dbo.consulta_contraparte cc JOIN dbo.persona p ON p.id_persona = cc.id_persona WHERE cc.id_consulta = @c;

SELECT 'NOTIFICACION' AS tabla, n.id_notificacion, n.id_persona, n.id_empleado, n.tipo_evento, n.canal, n.estado, n.fecha_programada, n.mensaje
FROM dbo.notificacion n WHERE n.id_consulta = @c ORDER BY n.id_notificacion;

-- ---------- Panel · citas agendadas para esa consulta
SELECT 'CITA' AS tabla, ci.* FROM dbo.cita ci WHERE ci.id_consulta = @c;
GO
-- ---------- Panel · último ingreso (W02)
SELECT 'USUARIO' AS tabla, email, ultimo_acceso FROM dbo.usuario WHERE ultimo_acceso IS NOT NULL ORDER BY ultimo_acceso DESC;
GO
