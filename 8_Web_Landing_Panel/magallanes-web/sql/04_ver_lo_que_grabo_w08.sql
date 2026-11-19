-- =====================================================================
-- W08 · Contrato y cronograma de cuotas — ver en SSMS lo que grabó la web
-- Base: magallanes_montero_prueba36  (F5 después de pulsar «Registrar contrato»)
-- =====================================================================
USE magallanes_montero_prueba36;
GO

-- 1) La cabecera: el último contrato
SELECT TOP 1 * FROM dbo.contrato ORDER BY id_contrato DESC;

-- 2) El detalle: sus cuotas (la vista calcula VENCIDA, no se guarda)
SELECT * FROM dbo.vw_cuota_estado
WHERE id_contrato = (SELECT MAX(id_contrato) FROM dbo.contrato)
ORDER BY nro_cuota;

-- 3) La consulta de origen pasó a CONTRATADA y la propuesta está ACEPTADA
SELECT k.nro_contrato, p.id_propuesta, p.estado AS estado_propuesta, p.fecha_respuesta,
       c.id_consulta, c.estado AS estado_consulta
FROM dbo.contrato k
JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta
JOIN dbo.consulta  c ON c.id_consulta  = p.id_consulta
WHERE k.id_contrato = (SELECT MAX(id_contrato) FROM dbo.contrato);
GO

-- =====================================================================
-- Prueba de ROLLBACK (lo mismo que pasa en la web si se elige un cliente sin documento):
-- el trigger trg_contrato_cliente_documento lanza el error 50011 y no queda NADA grabado.
-- =====================================================================
DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.contrato);
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO dbo.contrato (id_propuesta, id_cliente, nro_contrato, fecha_firma, tipo_encargo, modalidad_pago)
        VALUES (9, (SELECT TOP 1 id_persona FROM dbo.persona WHERE nro_documento IS NULL),
                'CT-PRUEBA-01', CAST(GETDATE() AS DATE), 'PATROCINIO', 'CUOTAS');
        INSERT INTO dbo.cuota (id_contrato, nro_cuota, concepto, monto, fecha_vencimiento)
        VALUES (SCOPE_IDENTITY(), 1, 'CUOTA', 100, CAST(GETDATE() AS DATE));
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
SELECT @antes AS contratos_antes, (SELECT COUNT(*) FROM dbo.contrato) AS contratos_despues;  -- deben ser iguales
GO
