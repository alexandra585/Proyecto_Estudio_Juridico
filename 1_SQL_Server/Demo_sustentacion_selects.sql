-- =====================================================================
-- ESTUDIO JURÍDICO MAGALLANES-MONTERO · DEMO PARA LA SUSTENTACIÓN
-- Solo consultas (SELECT): no modifica nada. Ejecutar con F5 (o seleccionar un bloque y F5).
-- Muestra que la base tiene las 36 tablas y que lo que se registra en la web se guarda aquí,
-- con el enlace a MongoDB (columnas *_mongo_id = _id del documento en MongoDB Atlas / Compass).
-- =====================================================================
USE magallanes_montero_prueba36;   -- cambie el nombre si su base es otra
GO

-- 1) ESTRUCTURA: 36 tablas, sus filas, FK, CHECK, triggers y vistas
SELECT t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams'
GROUP BY t.name ORDER BY t.name;

SELECT (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0 AND name <> 'sysdiagrams') AS tablas,
       (SELECT COUNT(*) FROM sys.foreign_keys)      AS llaves_foraneas,
       (SELECT COUNT(*) FROM sys.check_constraints) AS reglas_check,
       (SELECT COUNT(*) FROM sys.triggers WHERE parent_class = 1) AS triggers,
       (SELECT COUNT(*) FROM sys.views)             AS vistas;
GO

-- 2) T1 · LANDING / BANDEJA → PERSONA, CONSULTA, CITA, NOTIFICACION (lo último registrado)
SELECT TOP 5 * FROM dbo.consulta ORDER BY id_consulta DESC;
SELECT TOP 5 * FROM dbo.persona  ORDER BY id_persona DESC;

SELECT TOP 5 * FROM dbo.cita ORDER BY id_cita DESC;
SELECT TOP 8 * FROM dbo.notificacion ORDER BY id_notificacion DESC;
GO

-- 3) T2 · PROPUESTA → CONTRATO (firma) → CUOTAS → CASO (expediente; su _id de MongoDB)
SELECT TOP 5 * FROM dbo.propuesta ORDER BY id_propuesta DESC;
SELECT TOP 5 * FROM dbo.contrato  ORDER BY id_contrato DESC;     -- fecha_firma NULL = pendiente de firma
SELECT TOP 10 * FROM dbo.cuota    ORDER BY id_cuota DESC;
SELECT TOP 5 * FROM dbo.caso ORDER BY id_caso DESC;          -- expediente_mongo_id = _id en MongoDB «expedientes»
GO

-- 4) T3 · ESCRITO → PRESENTACIÓN → RESOLUCIÓN Y PLAZO (texto completo en MongoDB «archivos»)
SELECT TOP 5 * FROM dbo.documento_legal ORDER BY id_documento DESC;   -- archivo_mongo_id = _id en MongoDB «archivos»
SELECT TOP 5 * FROM dbo.presentacion ORDER BY id_presentacion DESC;
SELECT TOP 5 * FROM dbo.resolucion   ORDER BY id_resolucion DESC;
SELECT TOP 5 * FROM dbo.plazo ORDER BY id_plazo DESC;              -- semáforo en días hábiles
GO

-- 5) T4 · COMPROBANTE → PAGO → CIERRE → ENCUESTA (respuestas completas en MongoDB «encuestas»)
SELECT TOP 5 * FROM dbo.comprobante ORDER BY id_comprobante DESC;
SELECT TOP 5 * FROM dbo.pago        ORDER BY id_pago DESC;
SELECT TOP 10 * FROM dbo.vw_cuota_estado;                              -- pagada / pendiente / vencida
SELECT TOP 5 * FROM dbo.encuesta    ORDER BY id_encuesta DESC;
GO

-- 6) ENLACE SQL SERVER ↔ MONGODB: cada fila con su documento en MongoDB
--    Copie un _id y búsquelo en MongoDB Atlas: Data Explorer → colección → Filter { _id: ObjectId('...') }
SELECT 'caso → expedientes' AS enlace, CAST(id_caso AS VARCHAR(10)) AS id_sql, expediente_mongo_id AS mongo_id
FROM dbo.caso WHERE expediente_mongo_id IS NOT NULL
UNION ALL
SELECT 'documento_legal → archivos', CAST(id_documento AS VARCHAR(10)), archivo_mongo_id
FROM dbo.documento_legal WHERE archivo_mongo_id IS NOT NULL
ORDER BY 1, 2 DESC;
GO

-- 7) DIAGRAMA: en el Explorador de objetos → la base → Database Diagrams → clic derecho → New Database Diagram
--    → seleccionar las tablas (o todas) → Add. Si SSMS 20 muestra «This backend version is not supported»,
--    usar los diagramas de 3_DER (PNG / draw.io): es una limitación de SSMS 20 con SQL Server 2025.
