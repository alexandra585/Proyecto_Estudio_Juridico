# Organización del equipo · Sistema web Magallanes-Montero

Un solo proyecto (**Spring Boot + HTML/CSS/JS + SQL Server + MongoDB**), cuatro módulos. Cada integrante programa una **transacción de negocio** completa
(las mismas T1–T4 del informe, sección 4.5) y la presenta: formulario → COMMIT en SQL Server → filas en SSMS → diagrama de sus tablas.

| Integrante | Módulo | Pantallas (Figma) | Transacción | Tablas que graba | MongoDB | Estado |
|---|---|---|---|---|---|---|
| **Alexandra** | Captación + Dashboard | W01 Landing, W02 Login, W04 Bandeja, W06 Cita, **W03 Dashboard** | **T1** (+ inicio de T2) | PERSONA, CONSULTA, CONSULTA_CONTRAPARTE, NOTIFICACION, CITA | — (dashboard lee solo SQL) | ✅ Hecho |
| Compañero 1 | Contratación y apertura | W07, W08, W09 | **T2** | PROPUESTA, CONTRATO, CUOTA, CASO, CASO_PARTE, CASO_ETAPA | `expedientes` | Base lista |
| Compañero 2 | Gestión del expediente | W11, W12, W13 | **T3** | DOCUMENTO_LEGAL, DOCUMENTO_JURISPRUDENCIA, PRESENTACION, RESOLUCION, PLAZO | `archivos` | Base lista |
| Compañero 3 | Cobranza y cierre | W18, W19, W21, W22 | **T4** | COMPROBANTE, DETALLE_COMPROBANTE, PAGO, NOTIFICACION, ENCUESTA | `encuestas` | Base lista |

Guías: `GUIA_COMPANERO_1_T2.md`, `GUIA_COMPANERO_2_T3.md`, `GUIA_COMPANERO_3_T4.md` (tablas, columnas, orden de los INSERT, reglas y guion).

## Cómo encaja todo (flujo completo)

```
W01 Landing ──T1──► CONSULTA (RECIBIDA) ──W06──► CITA (AGENDADA) ──W07──► PROPUESTA ──W08──► CONTRATO + CUOTAS ──W09──► CASO (+ expediente Mongo)
                                                                                                               │
W03 Dashboard ◄── vistas vw_dash_* ◄── PAGO ◄─W19─ COMPROBANTE ◄─W18─ CUOTAS/GASTOS      PLAZO ◄─W13─ RESOLUCION ◄─W12─ PRESENTACION ◄─W11─ ESCRITO (+ archivo Mongo)
                                         │
                                         └─W21─► CASO CERRADO + ENCUESTA ─W22─► respuesta (SQL resumen + Mongo completa)
```

## SQL Server y MongoDB: qué va en cada una (decisión final)

| SQL Server (relacional) | MongoDB (no relacional) |
|---|---|
| Todo lo que se cuenta, se suma o tiene FK obligatoria: personas, consultas, citas, contratos, cuotas, casos, plazos, comprobantes, pagos | Contenido variable o pesado: expediente digital (bitácora, etiquetas), archivos con versiones (escritos, resoluciones, actas, contratos firmados), preguntas y respuestas completas de la encuesta |
| Las 4 transacciones T1–T4 (COMMIT/ROLLBACK) | Se guarda **antes** del COMMIT de SQL; su `_id` (24 caracteres) va en la columna `*_mongo_id`; si SQL hace ROLLBACK se borra (compensación) |
| El **dashboard** lee solo vistas de SQL Server (vw_dash_*) | La encuesta deja en SQL el resumen (calificación, NPS) que usa el dashboard |

## Reglas para no chocar en GitHub

1. Repositorio: https://github.com/alexandra585/Proyecto_Estudio_Juridico — rama `main` protegida; cada uno trabaja en su rama (`t2-…`, `t3-…`, `t4-…`).
2. Cada uno toca **solo** su paquete Java (`web/t2`, `web/t3`, `web/t4`), su página (`panel/t2-…html`) y su `js/t2.js`.
3. Archivos comunes (`menu.js`, `estilos.css`, `panel.css`, `application.properties`, `pom.xml`): cambios solo avisando al grupo.
4. Nunca subir contraseñas reales: `application.properties` usa el usuario de prueba `app_magallanes`.
5. Antes del Pull Request: `mvn spring-boot:run` sin errores y probar el flujo con SSMS abierto.
