-- =====================================================================
-- ESTUDIO JURÍDICO MAGALLANES-MONTERO · VISTAS DEL DASHBOARD GERENCIAL
-- Ejecutar DESPUÉS de magallanes_montero_sqlserver_v36.sql y de los datos de prueba.
-- No crea tablas: solo VISTAS (los indicadores se CALCULAN, no se guardan → 3FN).
--
-- Definiciones (iguales en la web, en Figma y en el informe):
--   Ingresos cobrados (sin IGV) = Σ pago.monto / (1 + comprobante.tasa_igv)
--   Gastos de los casos         = Σ gasto_caso.monto
--   Ganancia neta               = ingresos cobrados (sin IGV) − gastos de los casos
--   Por cobrar (con IGV)        = Σ saldo de vw_comprobante_saldo (comprobantes no anulados)
--   Cuota litis                 = Σ vw_liquidacion_cuota_litis.monto_cuota_litis
--   Cada pago se reparte entre las líneas del comprobante en proporción a su importe, así el
--   ingreso por materia y por abogado suma exactamente el ingreso total.
-- =====================================================================
USE magallanes_montero_prueba36;   -- cambie el nombre si su base es otra
GO
IF OBJECT_ID('dbo.vw_dash_satisfaccion') IS NOT NULL DROP VIEW dbo.vw_dash_satisfaccion;
IF OBJECT_ID('dbo.vw_dash_carga_abogado') IS NOT NULL DROP VIEW dbo.vw_dash_carga_abogado;
IF OBJECT_ID('dbo.vw_dash_consultas_canal') IS NOT NULL DROP VIEW dbo.vw_dash_consultas_canal;
IF OBJECT_ID('dbo.vw_dash_embudo') IS NOT NULL DROP VIEW dbo.vw_dash_embudo;
IF OBJECT_ID('dbo.vw_dash_rentabilidad_abogado') IS NOT NULL DROP VIEW dbo.vw_dash_rentabilidad_abogado;
IF OBJECT_ID('dbo.vw_dash_rentabilidad_materia') IS NOT NULL DROP VIEW dbo.vw_dash_rentabilidad_materia;
IF OBJECT_ID('dbo.vw_dash_cobranza_mensual') IS NOT NULL DROP VIEW dbo.vw_dash_cobranza_mensual;
IF OBJECT_ID('dbo.vw_dash_resumen') IS NOT NULL DROP VIEW dbo.vw_dash_resumen;
IF OBJECT_ID('dbo.vw_dash_ingreso_linea') IS NOT NULL DROP VIEW dbo.vw_dash_ingreso_linea;
GO

-- D1. Cada línea de comprobante con su origen (consulta, cuota o gasto), materia, abogado,
--     importe sin IGV y la parte ya cobrada (pagado / total del comprobante).
CREATE VIEW dbo.vw_dash_ingreso_linea AS
SELECT d.id_comprobante, d.nro_linea, c.fecha_emision,
       CASE WHEN d.id_gasto IS NOT NULL THEN 'REEMBOLSO_GASTO'
            WHEN d.id_cuota IS NOT NULL THEN q.concepto
            ELSE 'CONSULTA' END                                              AS origen,
       COALESCE(ca.id_caso, cg.id_caso)                                      AS id_caso,
       COALESCE(ca.id_materia, cg.id_materia, cp.id_materia, cc.id_materia)  AS id_materia,
       COALESCE(ca.id_abogado_responsable, cg.id_abogado_responsable, pr.id_abogado, cc.id_revisor_conflicto) AS id_abogado,
       ROUND(d.cantidad * d.valor_unitario, 2)                               AS importe_sin_igv,
       ROUND(d.cantidad * d.valor_unitario * s.pagado / NULLIF(s.total, 0), 2) AS cobrado_sin_igv
FROM dbo.detalle_comprobante d
JOIN dbo.comprobante c            ON c.id_comprobante = d.id_comprobante
JOIN dbo.vw_comprobante_saldo s   ON s.id_comprobante = d.id_comprobante
LEFT JOIN dbo.cuota q             ON q.id_cuota = d.id_cuota
LEFT JOIN dbo.contrato k          ON k.id_contrato = q.id_contrato
LEFT JOIN dbo.caso ca             ON ca.id_contrato = k.id_contrato
LEFT JOIN dbo.propuesta pr        ON pr.id_propuesta = k.id_propuesta
LEFT JOIN dbo.consulta cp         ON cp.id_consulta = pr.id_consulta
LEFT JOIN dbo.gasto_caso g        ON g.id_gasto = d.id_gasto
LEFT JOIN dbo.caso cg             ON cg.id_caso = g.id_caso
LEFT JOIN dbo.consulta cc         ON cc.id_consulta = c.id_consulta
WHERE c.estado <> 'ANULADO';
GO

-- D2. Tarjetas principales (una sola fila).
CREATE VIEW dbo.vw_dash_resumen AS
SELECT
  (SELECT ROUND(COALESCE(SUM(cobrado_sin_igv), 0), 2) FROM dbo.vw_dash_ingreso_linea)                AS ingresos_cobrados,
  (SELECT COALESCE(SUM(monto), 0) FROM dbo.gasto_caso)                                               AS gastos_casos,
  (SELECT ROUND(COALESCE(SUM(cobrado_sin_igv), 0), 2) FROM dbo.vw_dash_ingreso_linea)
     - (SELECT COALESCE(SUM(monto), 0) FROM dbo.gasto_caso)                                          AS ganancia_neta,
  (SELECT COALESCE(SUM(saldo), 0) FROM dbo.vw_comprobante_saldo WHERE estado_pago IN ('PENDIENTE','PAGADO_PARCIAL')) AS por_cobrar,
  (SELECT ROUND(COALESCE(SUM(importe_sin_igv), 0), 2) FROM dbo.vw_dash_ingreso_linea)                AS facturado_sin_igv,
  (SELECT COALESCE(SUM(monto_cuota_litis), 0) FROM dbo.vw_liquidacion_cuota_litis)                   AS cuota_litis,
  (SELECT COALESCE(SUM(p.monto_honorarios), 0) FROM dbo.contrato k JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta) AS honorarios_contratados,
  (SELECT COUNT(*) FROM dbo.caso WHERE estado = 'ACTIVO')                                            AS casos_activos,
  (SELECT COUNT(*) FROM dbo.vw_plazos_por_vencer)                                                    AS plazos_por_vencer,
  (SELECT COUNT(*) FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA')                                AS cuotas_vencidas,
  (SELECT COALESCE(SUM(monto), 0) FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA')                 AS monto_cuotas_vencidas,
  (SELECT COUNT(*) FROM dbo.audiencia WHERE estado IN ('PROGRAMADA','REPROGRAMADA')
      AND fecha_hora >= CAST(GETDATE() AS DATE) AND fecha_hora < DATEADD(DAY, 8, CAST(GETDATE() AS DATE))) AS audiencias_7_dias;
GO

-- D3. Cobranza por mes (sin IGV): pagos agrupados por el mes en que se cobraron.
CREATE VIEW dbo.vw_dash_cobranza_mensual AS
SELECT FORMAT(p.fecha_pago, 'yyyy-MM') AS mes,
       ROUND(SUM(p.monto / (1 + c.tasa_igv)), 2) AS cobrado_sin_igv,
       COUNT(*) AS pagos
FROM dbo.pago p JOIN dbo.comprobante c ON c.id_comprobante = p.id_comprobante
WHERE c.estado <> 'ANULADO'
GROUP BY FORMAT(p.fecha_pago, 'yyyy-MM');
GO

-- D4. Rentabilidad por materia: ingresos cobrados − gastos de sus casos.
CREATE VIEW dbo.vw_dash_rentabilidad_materia AS
SELECT m.id_materia, m.nombre AS materia,
       ROUND(COALESCE(i.ingresos, 0), 2) AS ingresos,
       COALESCE(g.gastos, 0)             AS gastos,
       ROUND(COALESCE(i.ingresos, 0) - COALESCE(g.gastos, 0), 2) AS ganancia,
       (SELECT COUNT(*) FROM dbo.caso x WHERE x.id_materia = m.id_materia) AS casos
FROM dbo.materia m
LEFT JOIN (SELECT id_materia, SUM(cobrado_sin_igv) AS ingresos FROM dbo.vw_dash_ingreso_linea GROUP BY id_materia) i ON i.id_materia = m.id_materia
LEFT JOIN (SELECT c.id_materia, SUM(g.monto) AS gastos FROM dbo.gasto_caso g JOIN dbo.caso c ON c.id_caso = g.id_caso GROUP BY c.id_materia) g ON g.id_materia = m.id_materia;
GO

-- D5. Rentabilidad y carga por abogado.
CREATE VIEW dbo.vw_dash_rentabilidad_abogado AS
SELECT a.id_empleado AS id_abogado, e.nombres + N' ' + e.apellidos AS abogado,
       ROUND(COALESCE(i.ingresos, 0), 2) AS ingresos,
       COALESCE(g.gastos, 0)             AS gastos,
       ROUND(COALESCE(i.ingresos, 0) - COALESCE(g.gastos, 0), 2) AS ganancia,
       (SELECT COUNT(*) FROM dbo.caso x WHERE x.id_abogado_responsable = a.id_empleado AND x.estado = 'ACTIVO') AS casos_activos
FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado
LEFT JOIN (SELECT id_abogado, SUM(cobrado_sin_igv) AS ingresos FROM dbo.vw_dash_ingreso_linea GROUP BY id_abogado) i ON i.id_abogado = a.id_empleado
LEFT JOIN (SELECT c.id_abogado_responsable, SUM(g.monto) AS gastos FROM dbo.gasto_caso g JOIN dbo.caso c ON c.id_caso = g.id_caso GROUP BY c.id_abogado_responsable) g ON g.id_abogado_responsable = a.id_empleado;
GO

-- D6. Embudo comercial: de cada 100 consultas, cuántas llegan a cita, propuesta y contrato.
CREATE VIEW dbo.vw_dash_embudo AS
SELECT 1 AS orden, 'Consultas' AS etapa, COUNT(*) AS cantidad FROM dbo.consulta
UNION ALL SELECT 2, 'Con cita',      COUNT(DISTINCT id_consulta) FROM dbo.cita
UNION ALL SELECT 3, 'Con propuesta', COUNT(DISTINCT id_consulta) FROM dbo.propuesta
UNION ALL SELECT 4, 'Contratadas',   COUNT(DISTINCT p.id_consulta) FROM dbo.contrato k JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta;
GO

-- D7. Consultas y contratos por canal (cuánto aporta la Landing Page frente a WhatsApp, llamadas…).
CREATE VIEW dbo.vw_dash_consultas_canal AS
SELECT c.canal, COUNT(*) AS consultas, COUNT(x.id_consulta) AS contratadas
FROM dbo.consulta c
LEFT JOIN (SELECT DISTINCT p.id_consulta FROM dbo.propuesta p
           JOIN dbo.contrato k ON k.id_propuesta = p.id_propuesta) x ON x.id_consulta = c.id_consulta
GROUP BY c.canal;
GO

-- D8. Carga de trabajo por abogado: casos activos, plazos pendientes y audiencias próximas.
CREATE VIEW dbo.vw_dash_carga_abogado AS
SELECT a.id_empleado AS id_abogado, e.nombres + N' ' + e.apellidos AS abogado,
       (SELECT COUNT(*) FROM dbo.caso c WHERE c.id_abogado_responsable = a.id_empleado AND c.estado = 'ACTIVO') AS casos_activos,
       (SELECT COUNT(*) FROM dbo.plazo p JOIN dbo.caso c ON c.id_caso = p.id_caso
         WHERE c.id_abogado_responsable = a.id_empleado AND p.fecha_cumplimiento IS NULL) AS plazos_pendientes,
       (SELECT COUNT(*) FROM dbo.audiencia au WHERE au.id_abogado = a.id_empleado
         AND au.estado IN ('PROGRAMADA','REPROGRAMADA') AND au.fecha_hora >= CAST(GETDATE() AS DATE)) AS audiencias_proximas
FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado;
GO

-- D9. Satisfacción del cliente: calificación promedio (1-5) y NPS = % promotores (9-10) − % detractores (0-6).
CREATE VIEW dbo.vw_dash_satisfaccion AS
SELECT COUNT(*) AS encuestas_enviadas,
       COUNT(calificacion) AS respondidas,
       CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)) AS calificacion_promedio,
       CAST(100.0 * (SUM(CASE WHEN nps >= 9 THEN 1 ELSE 0 END) - SUM(CASE WHEN nps <= 6 THEN 1 ELSE 0 END))
            / NULLIF(COUNT(nps), 0) AS DECIMAL(5,1)) AS nps
FROM dbo.encuesta;
GO

-- Comprobación: ver todos los indicadores
SELECT * FROM dbo.vw_dash_resumen;
SELECT * FROM dbo.vw_dash_cobranza_mensual ORDER BY mes;
SELECT * FROM dbo.vw_dash_rentabilidad_materia ORDER BY ganancia DESC;
SELECT * FROM dbo.vw_dash_rentabilidad_abogado ORDER BY ganancia DESC;
SELECT * FROM dbo.vw_dash_embudo ORDER BY orden;
SELECT * FROM dbo.vw_dash_consultas_canal ORDER BY consultas DESC;
SELECT * FROM dbo.vw_dash_carga_abogado;
SELECT * FROM dbo.vw_dash_satisfaccion;
-- Control: los ingresos por materia suman lo mismo que el total
SELECT (SELECT SUM(ingresos) FROM dbo.vw_dash_rentabilidad_materia) AS suma_materias,
       (SELECT ingresos_cobrados FROM dbo.vw_dash_resumen) AS total;
GO
