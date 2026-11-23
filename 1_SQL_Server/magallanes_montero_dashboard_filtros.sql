-- =====================================================================
-- ESTUDIO JURÍDICO MAGALLANES-MONTERO · FILTRO POR FECHAS DEL DASHBOARD
-- Ejecutar DESPUÉS de magallanes_montero_vistas_dashboard.sql (usa sus vistas).
--
-- El dashboard filtra por periodo (Hoy, Semana, Mes, Trimestre, Año, 12 meses o Desde/Hasta).
-- Los indicadores se calculan en SQL Server con FUNCIONES CON PARÁMETROS (inline table-valued
-- functions): la base recibe @desde y @hasta y devuelve el resultado ya filtrado.
--
--   Indicadores DEL PERIODO (cambian con el filtro):
--     ingresos cobrados (fecha del pago), gastos (fecha del gasto), ganancia, facturado (fecha de emisión),
--     honorarios contratados (fecha de firma), consultas recibidas, embudo, canales, satisfacción.
--   Indicadores AL DÍA DE HOY (no dependen del filtro: son una foto del estado actual):
--     por cobrar, casos activos, plazos por vencer, cuotas vencidas, audiencias de los próximos 7 días.
-- =====================================================================
USE magallanes_montero_prueba36;   -- cambie el nombre si su base es otra
GO
IF OBJECT_ID('dbo.fn_dash_satisfaccion') IS NOT NULL DROP FUNCTION dbo.fn_dash_satisfaccion;
IF OBJECT_ID('dbo.fn_dash_consultas_canal') IS NOT NULL DROP FUNCTION dbo.fn_dash_consultas_canal;
IF OBJECT_ID('dbo.fn_dash_embudo') IS NOT NULL DROP FUNCTION dbo.fn_dash_embudo;
IF OBJECT_ID('dbo.fn_dash_rentabilidad_abogado') IS NOT NULL DROP FUNCTION dbo.fn_dash_rentabilidad_abogado;
IF OBJECT_ID('dbo.fn_dash_rentabilidad_materia') IS NOT NULL DROP FUNCTION dbo.fn_dash_rentabilidad_materia;
IF OBJECT_ID('dbo.fn_dash_cobranza') IS NOT NULL DROP FUNCTION dbo.fn_dash_cobranza;
IF OBJECT_ID('dbo.fn_dash_resumen') IS NOT NULL DROP FUNCTION dbo.fn_dash_resumen;
IF OBJECT_ID('dbo.vw_dash_cobro_linea') IS NOT NULL DROP VIEW dbo.vw_dash_cobro_linea;
GO

-- F0. Cada PAGO repartido entre las líneas de su comprobante (en proporción al importe de la línea).
--     Así se sabe CUÁNDO entró el dinero (fecha_pago) y a qué materia/abogado corresponde.
CREATE VIEW dbo.vw_dash_cobro_linea AS
SELECT p.id_pago, CAST(p.fecha_pago AS DATE) AS fecha, l.id_comprobante, l.nro_linea, l.origen,
       l.id_caso, l.id_materia, l.id_abogado,
       p.monto / (1 + c.tasa_igv) * l.importe_sin_igv / NULLIF(t.subtotal, 0) AS cobrado_sin_igv
FROM dbo.pago p
JOIN dbo.comprobante c           ON c.id_comprobante = p.id_comprobante
JOIN dbo.vw_comprobante_total t  ON t.id_comprobante = p.id_comprobante
JOIN dbo.vw_dash_ingreso_linea l ON l.id_comprobante = p.id_comprobante
WHERE c.estado <> 'ANULADO';
GO

-- F1. Tarjetas principales para un periodo.
CREATE FUNCTION dbo.fn_dash_resumen (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT
  -- Del periodo
  i.ingresos                                     AS ingresos_cobrados,
  g.gastos                                       AS gastos_casos,
  ROUND(i.ingresos - g.gastos, 2)                AS ganancia_neta,
  (SELECT ROUND(COALESCE(SUM(importe_sin_igv), 0), 2) FROM dbo.vw_dash_ingreso_linea
    WHERE fecha_emision BETWEEN @desde AND @hasta)                                   AS facturado_sin_igv,
  (SELECT COALESCE(SUM(v.monto_cuota_litis), 0) FROM dbo.vw_liquidacion_cuota_litis v
    JOIN dbo.liquidacion q ON q.id_liquidacion = v.id_liquidacion
    WHERE q.fecha_liquidacion BETWEEN @desde AND @hasta)                             AS cuota_litis,
  (SELECT COALESCE(SUM(pr.monto_honorarios), 0) FROM dbo.contrato k
    JOIN dbo.propuesta pr ON pr.id_propuesta = k.id_propuesta
    WHERE k.fecha_firma BETWEEN @desde AND @hasta)                                   AS honorarios_contratados,
  (SELECT COUNT(*) FROM dbo.contrato WHERE fecha_firma BETWEEN @desde AND @hasta)   AS contratos_firmados,
  (SELECT COUNT(*) FROM dbo.consulta
    WHERE CAST(fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta)              AS consultas_recibidas,
  (SELECT COUNT(*) FROM dbo.pago WHERE CAST(fecha_pago AS DATE) BETWEEN @desde AND @hasta) AS pagos_registrados,
  -- Al día de hoy (no dependen del filtro)
  (SELECT COALESCE(SUM(saldo), 0) FROM dbo.vw_comprobante_saldo WHERE estado_pago IN ('PENDIENTE','PAGADO_PARCIAL')) AS por_cobrar,
  (SELECT COUNT(*) FROM dbo.caso WHERE estado = 'ACTIVO')                            AS casos_activos,
  (SELECT COUNT(*) FROM dbo.vw_plazos_por_vencer)                                    AS plazos_por_vencer,
  (SELECT COUNT(*) FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA')                AS cuotas_vencidas,
  (SELECT COALESCE(SUM(monto), 0) FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA') AS monto_cuotas_vencidas,
  (SELECT COUNT(*) FROM dbo.audiencia WHERE estado IN ('PROGRAMADA','REPROGRAMADA')
      AND fecha_hora >= CAST(GETDATE() AS DATE) AND fecha_hora < DATEADD(DAY, 8, CAST(GETDATE() AS DATE))) AS audiencias_7_dias
FROM (SELECT ROUND(COALESCE(SUM(cobrado_sin_igv), 0), 2) AS ingresos
      FROM dbo.vw_dash_cobro_linea WHERE fecha BETWEEN @desde AND @hasta) i
CROSS JOIN (SELECT COALESCE(SUM(monto), 0) AS gastos FROM dbo.gasto_caso WHERE fecha BETWEEN @desde AND @hasta) g;
GO

-- F2. Cobranza del periodo agrupada automáticamente:
--     hasta 31 días → por DÍA · hasta 92 días → por SEMANA (lunes) · más → por MES.
CREATE FUNCTION dbo.fn_dash_cobranza (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT x.granularidad, x.periodo,
       ROUND(SUM(x.cobrado_sin_igv), 2) AS cobrado_sin_igv,
       COUNT(DISTINCT x.id_pago)        AS pagos
FROM (SELECT id_pago, cobrado_sin_igv,
             CASE WHEN DATEDIFF(DAY, @desde, @hasta) <= 31 THEN 'DIA'
                  WHEN DATEDIFF(DAY, @desde, @hasta) <= 92 THEN 'SEMANA'
                  ELSE 'MES' END AS granularidad,
             CASE WHEN DATEDIFF(DAY, @desde, @hasta) <= 31 THEN CONVERT(CHAR(10), fecha, 23)
                  WHEN DATEDIFF(DAY, @desde, @hasta) <= 92            -- lunes de la semana (1900-01-01 fue lunes)
                       THEN CONVERT(CHAR(10), DATEADD(DAY, -(DATEDIFF(DAY, '19000101', fecha) % 7), fecha), 23)
                  ELSE CONVERT(CHAR(7), fecha, 23) END AS periodo
      FROM dbo.vw_dash_cobro_linea
      WHERE fecha BETWEEN @desde AND @hasta) x
GROUP BY x.granularidad, x.periodo;
GO

-- F3. Rentabilidad por materia en el periodo.
CREATE FUNCTION dbo.fn_dash_rentabilidad_materia (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT m.id_materia, m.nombre AS materia,
       ROUND(COALESCE(i.ingresos, 0), 2) AS ingresos,
       COALESCE(g.gastos, 0)             AS gastos,
       ROUND(COALESCE(i.ingresos, 0) - COALESCE(g.gastos, 0), 2) AS ganancia,
       (SELECT COUNT(*) FROM dbo.caso x WHERE x.id_materia = m.id_materia) AS casos
FROM dbo.materia m
LEFT JOIN (SELECT id_materia, SUM(cobrado_sin_igv) AS ingresos FROM dbo.vw_dash_cobro_linea
           WHERE fecha BETWEEN @desde AND @hasta GROUP BY id_materia) i ON i.id_materia = m.id_materia
LEFT JOIN (SELECT c.id_materia, SUM(g.monto) AS gastos FROM dbo.gasto_caso g JOIN dbo.caso c ON c.id_caso = g.id_caso
           WHERE g.fecha BETWEEN @desde AND @hasta GROUP BY c.id_materia) g ON g.id_materia = m.id_materia;
GO

-- F4. Rentabilidad por abogado en el periodo (+ carga actual).
CREATE FUNCTION dbo.fn_dash_rentabilidad_abogado (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT a.id_empleado AS id_abogado, e.nombres + N' ' + e.apellidos AS abogado,
       ROUND(COALESCE(i.ingresos, 0), 2) AS ingresos,
       COALESCE(g.gastos, 0)             AS gastos,
       ROUND(COALESCE(i.ingresos, 0) - COALESCE(g.gastos, 0), 2) AS ganancia,
       (SELECT COUNT(*) FROM dbo.caso x WHERE x.id_abogado_responsable = a.id_empleado AND x.estado = 'ACTIVO') AS casos_activos
FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado
LEFT JOIN (SELECT id_abogado, SUM(cobrado_sin_igv) AS ingresos FROM dbo.vw_dash_cobro_linea
           WHERE fecha BETWEEN @desde AND @hasta GROUP BY id_abogado) i ON i.id_abogado = a.id_empleado
LEFT JOIN (SELECT c.id_abogado_responsable, SUM(g.monto) AS gastos FROM dbo.gasto_caso g JOIN dbo.caso c ON c.id_caso = g.id_caso
           WHERE g.fecha BETWEEN @desde AND @hasta GROUP BY c.id_abogado_responsable) g ON g.id_abogado_responsable = a.id_empleado;
GO

-- F5. Embudo comercial de las consultas RECIBIDAS en el periodo (cohorte).
CREATE FUNCTION dbo.fn_dash_embudo (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT 1 AS orden, 'Consultas' AS etapa, COUNT(*) AS cantidad
FROM dbo.consulta c WHERE CAST(c.fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta
UNION ALL
SELECT 2, 'Con cita', COUNT(*) FROM dbo.consulta c
WHERE CAST(c.fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta
  AND EXISTS (SELECT 1 FROM dbo.cita x WHERE x.id_consulta = c.id_consulta)
UNION ALL
SELECT 3, 'Con propuesta', COUNT(*) FROM dbo.consulta c
WHERE CAST(c.fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta
  AND EXISTS (SELECT 1 FROM dbo.propuesta x WHERE x.id_consulta = c.id_consulta)
UNION ALL
SELECT 4, 'Contratadas', COUNT(*) FROM dbo.consulta c
WHERE CAST(c.fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta
  AND EXISTS (SELECT 1 FROM dbo.propuesta x JOIN dbo.contrato k ON k.id_propuesta = x.id_propuesta
              WHERE x.id_consulta = c.id_consulta);
GO

-- F6. Consultas del periodo por canal y cuántas terminaron en contrato.
CREATE FUNCTION dbo.fn_dash_consultas_canal (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT c.canal, COUNT(*) AS consultas, COUNT(x.id_consulta) AS contratadas
FROM dbo.consulta c
LEFT JOIN (SELECT DISTINCT p.id_consulta FROM dbo.propuesta p JOIN dbo.contrato k ON k.id_propuesta = p.id_propuesta) x
       ON x.id_consulta = c.id_consulta
WHERE CAST(c.fecha_hora_recepcion AS DATE) BETWEEN @desde AND @hasta
GROUP BY c.canal;
GO

-- F7. Satisfacción de las encuestas enviadas en el periodo.
CREATE FUNCTION dbo.fn_dash_satisfaccion (@desde DATE, @hasta DATE)
RETURNS TABLE AS RETURN
SELECT COUNT(*) AS encuestas_enviadas,
       COUNT(calificacion) AS respondidas,
       CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)) AS calificacion_promedio,
       CAST(100.0 * (SUM(CASE WHEN nps >= 9 THEN 1 ELSE 0 END) - SUM(CASE WHEN nps <= 6 THEN 1 ELSE 0 END))
            / NULLIF(COUNT(nps), 0) AS DECIMAL(5,1)) AS nps
FROM dbo.encuesta
WHERE CAST(fecha_envio AS DATE) BETWEEN @desde AND @hasta;
GO

-- Permiso para la aplicación: leer las funciones (db_datareader solo cubre tablas y vistas).
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_magallanes')
    GRANT SELECT ON SCHEMA::dbo TO app_magallanes;
GO

-- Comprobación: año 2026 completo y control de que la suma por materia = total del periodo
SELECT * FROM dbo.fn_dash_resumen('2026-01-01', '2026-12-31');
SELECT * FROM dbo.fn_dash_cobranza('2026-01-01', '2026-12-31') ORDER BY periodo;
SELECT * FROM dbo.fn_dash_cobranza('2026-10-01', '2026-10-31') ORDER BY periodo;   -- por día
SELECT (SELECT ROUND(SUM(ingresos), 2) FROM dbo.fn_dash_rentabilidad_materia('2026-01-01', '2026-12-31')) AS suma_materias,
       (SELECT ingresos_cobrados FROM dbo.fn_dash_resumen('2026-01-01', '2026-12-31')) AS total_periodo,
       (SELECT ingresos_cobrados FROM dbo.vw_dash_resumen) AS total_historico;
SELECT * FROM dbo.fn_dash_embudo('2026-01-01', '2026-12-31') ORDER BY orden;
GO
