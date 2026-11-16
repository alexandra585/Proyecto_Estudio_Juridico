# Proyecto Estudio Jurídico Magallanes-Montero · Base de Datos II (UTP)

Base de datos híbrida (**SQL Server + MongoDB**) y sistema web para la gestión de consultas, expedientes y facturación
del Estudio Jurídico Magallanes-Montero. Incluye BPMN AS-IS/TO-BE, modelo conceptual (Chen), lógico y físico (36 tablas),
normalización, prototipo en Figma, dashboard gerencial y la aplicación web (Java Spring Boot).

* Prototipo en Figma: https://www.figma.com/design/JyHrpDAn41uGzJNggzBJsa/MM-Abogados---Prototipo-BD-v36
* Base de datos de trabajo: `magallanes_montero_prueba36` (SQL Server 2022, instancia `MSSQLSERVER01`)

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `0_BPMN/AS-IS`, `0_BPMN/TO-BE` | Diagramas BPMN 2.0 (Bizagi) de los 3 procesos + imágenes. El TO-BE es el que va en el informe (sección 3.4). |
| `1_SQL_Server` | Script de creación v36 (36 tablas, 70 FK, 65 CHECK, 10 triggers, 13 índices, 6 vistas), datos de prueba, pruebas de reglas y **vistas del dashboard** (`magallanes_montero_vistas_dashboard.sql`). |
| `2_MongoDB` | `mongodb_colecciones.js`: colecciones `expedientes`, `archivos`, `formularios_encuesta`, `encuestas`. |
| `3_DER` | DER conceptual (Chen), lógico y físico (draw.io + PNG). |
| `4_Informe` | Informe final (Word y PDF). |
| `5_Normalizacion` | Normalización 1FN–3FN de DOCUMENTO_LEGAL y COMPROBANTE. |
| `6_Mapa_Pantallas_Tablas` | Qué pantalla graba y lee cada tabla. |
| `7_Figma` | Secciones del prototipo exportadas (incluye la **8 · Dashboard gerencial**). |
| `8_Web_Landing_Panel/magallanes-web` | **Aplicación web**: Landing + panel + dashboard + módulos T2/T3/T4. Guías del equipo en `docs/`. |

## Orden para levantar todo

1. SSMS: `1_SQL_Server/magallanes_montero_sqlserver_v36.sql` → `..._datos_prueba_v36.sql` → `magallanes_montero_vistas_dashboard.sql`
   → `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql`.
2. MongoDB Compass (pestaña Mongosh): `2_MongoDB/mongodb_colecciones.js`.
3. VS Code en `8_Web_Landing_Panel/magallanes-web`: `mvn spring-boot:run` → http://localhost:8080
   (panel: `karen.paredes@mmabogados.pe` / `Secretaria2026!`).

## Equipo y reparto

Ver `8_Web_Landing_Panel/magallanes-web/docs/ORGANIZACION_EQUIPO.md`.

| Integrante | Transacción | Pantallas |
|---|---|---|
| Alexandra | T1 + Dashboard | W01 Landing, W02 Login, W04 Bandeja, W06 Cita, W03 Dashboard |
| Compañero 1 | T2 | W07 Propuesta, W08 Contrato y cuotas, W09 Nuevo expediente |
| Compañero 2 | T3 | W11 Escrito, W12 Presentación, W13 Resolución y plazo |
| Compañero 3 | T4 | W18 Comprobante, W19 Pago, W21 Cierre, W22 Encuesta |
