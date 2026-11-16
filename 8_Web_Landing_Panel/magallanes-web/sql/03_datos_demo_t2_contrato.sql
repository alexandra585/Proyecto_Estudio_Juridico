-- =====================================================================
-- Datos para la demostración del módulo T2 (W08 · contrato y cuotas)
-- Ejecutar DESPUÉS de magallanes_montero_sqlserver_v36.sql y
-- magallanes_montero_datos_prueba_v36.sql (en SSMS: F5).
-- =====================================================================
USE magallanes_montero_prueba36;   -- base con las 36 tablas
GO

-- W08 lista las propuestas ACEPTADAS que aún no tienen contrato.
-- En los datos de prueba todas las aceptadas ya tienen contrato, así que la clienta
-- Sofía Cárdenas (consulta 8) acepta la versión 2 de su propuesta (S/ 2,600 en 2 cuotas).
UPDATE dbo.propuesta
SET estado = 'ACEPTADA', fecha_respuesta = '2026-10-15'
WHERE id_propuesta = 10 AND estado = 'ENVIADA';

SELECT p.id_propuesta, p.version, p.estado, p.monto_honorarios, p.nro_cuotas, c.id_consulta, c.estado AS estado_consulta
FROM dbo.propuesta p JOIN dbo.consulta c ON c.id_consulta = p.id_consulta
WHERE p.id_propuesta = 10;
GO
