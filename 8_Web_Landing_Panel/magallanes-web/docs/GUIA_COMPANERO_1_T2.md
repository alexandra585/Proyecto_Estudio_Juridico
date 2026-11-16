# Compañero 1 · Transacción T2 · Contratación y apertura del expediente

Estudio Jurídico Magallanes-Montero · Base de Datos II · UTP

**Pantallas de Figma:** W07 · Propuesta de honorarios → W08 · Contrato y cronograma de cuotas → W09 · Nuevo expediente (apertura del caso).
**Proceso:** P1 · Captación, consulta y apertura (TO-BE, parte final).
**Viene de:** la consulta que se agendó en W06 (estado `AGENDADA`) — la hizo Alexandra.
**Sigue en:** T3 (Compañero 2) usa el `CASO` que se abre aquí.

## Qué graba cada pantalla (en este orden)

| Pantalla | Tabla | Operación | Regla / detalle |
|---|---|---|---|
| W07 | PROPUESTA | INSERT | `version` = siguiente de la consulta (UNIQUE id_consulta+version); honorarios ≥ 0; % cuota litis 0–100 |
| W07 | CONSULTA | UPDATE | `estado = 'PROPUESTA'` |
| (aceptación) | PROPUESTA | UPDATE | `estado = 'ACEPTADA'`, `fecha_respuesta` (botón «El cliente aceptó») |
| W08 | CONTRATO | INSERT | 1 contrato por propuesta (UNIQUE); `trg_contrato_cliente_documento`: cliente con DNI/RUC |
| W08 | CUOTA | INSERT (n) | suma de cuotas = honorarios; `monto > 0`; `nro_cuota` sin repetir |
| W08 | CONSULTA | UPDATE | `estado = 'CONTRATADA'` |
| W09 | **expedientes (MongoDB)** | insert | `{ id_caso, codigo_interno, materia, resumen_hechos, etiquetas[], archivos[], bitacora[] }` |
| W09 | CASO | INSERT | `codigo_interno` EXP-AAAA-NNNN (UNIQUE); `expediente_mongo_id` = _id de Mongo |
| W09 | CASO_PARTE | INSERT (n) | cliente (`tipo_parte = 'CLIENTE'`) y contrapartes de CONSULTA_CONTRAPARTE (`'CONTRAPARTE'`), con su ROL_PROCESAL |
| W09 | CASO_ETAPA | INSERT | primera etapa (ETAPA_PROCESAL con menor `orden`); solo una etapa abierta (`uq_caso_etapa_abierta`) |

**Ayuda:** la versión de escritorio de W08 ya existe en `8_Java_Formularios/.../ContratoDAO.java` (contrato + cuotas en una transacción): adaptarla a `T2Repositorio.registrarContrato`.
**Datos de prueba:** consulta 9 (estado AGENDADA) para W07; la propuesta 10 de la consulta 8 queda ACEPTADA (lista para W08) con `sql/03_datos_demo_t2_contrato.sql`.

## Columnas de las tablas que graba (script v36)

**PROPUESTA**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_propuesta` | INT | Sí |
| `id_consulta` | INT | Sí |
| `id_abogado` | INT | Sí |
| `version` | TINYINT | Sí |
| `monto_honorarios` | DECIMAL(12,2) | Sí |
| `porcentaje_cuota_litis` | DECIMAL(5,2) | Sí |
| `nro_cuotas` | TINYINT | Sí |
| `fecha_envio` | DATE | Sí |
| `fecha_respuesta` | DATE | No |
| `estado` | VARCHAR(14) | Sí |

**CONTRATO**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_contrato` | INT | Sí |
| `id_propuesta` | INT | Sí |
| `id_cliente` | INT | Sí |
| `nro_contrato` | NVARCHAR(20) | Sí |
| `fecha_firma` | DATE | Sí |
| `tipo_encargo` | VARCHAR(14) | Sí |
| `modalidad_pago` | VARCHAR(14) | Sí |
| `con_carta_poder` | BIT | Sí |
| `archivo_mongo_id` | CHAR(24) | No |

**CUOTA**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_cuota` | INT | Sí |
| `id_contrato` | INT | Sí |
| `id_liquidacion` | INT | No |
| `nro_cuota` | TINYINT | Sí |
| `concepto` | VARCHAR(11) | Sí |
| `monto` | DECIMAL(12,2) | Sí |
| `fecha_vencimiento` | DATE | Sí |
| `estado` | VARCHAR(14) | Sí |

**CASO**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_caso` | INT | Sí |
| `id_contrato` | INT | Sí |
| `id_materia` | SMALLINT | Sí |
| `id_abogado_responsable` | INT | Sí |
| `codigo_interno` | NVARCHAR(20) | Sí |
| `nro_expediente_judicial` | NVARCHAR(40) | No |
| `descripcion` | NVARCHAR(500) | Sí |
| `es_alta_complejidad` | BIT | Sí |
| `estado` | VARCHAR(9) | Sí |
| `fecha_apertura` | DATE | Sí |
| `fecha_cierre` | DATE | No |
| `expediente_mongo_id` | CHAR(24) | No |

**CASO_PARTE**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_caso` | INT | Sí |
| `id_persona` | INT | Sí |
| `id_rol` | SMALLINT | Sí |
| `tipo_parte` | VARCHAR(11) | Sí |
| `abogado_externo` | NVARCHAR(120) | No |

**CASO_ETAPA**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_caso_etapa` | INT | Sí |
| `id_caso` | INT | Sí |
| `id_etapa` | SMALLINT | Sí |
| `fecha_inicio` | DATE | Sí |
| `fecha_fin` | DATE | No |

## Cómo trabajar (igual para los tres)

1. **Clonar el repositorio** y abrir la carpeta `8_Web_Landing_Panel/magallanes-web` en VS Code.
2. Preparar la base: ejecutar en SSMS, en orden, `1_SQL_Server/magallanes_montero_sqlserver_v36.sql`, `..._datos_prueba_v36.sql`,
   `magallanes_montero_vistas_dashboard.sql` y `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql`
   (ajustar el nombre de la base si no es `magallanes_montero_prueba36`).
3. Revisar `src/main/resources/application.properties` (servidor, puerto, base, usuario `app_magallanes`).
4. MongoDB: instalar **MongoDB Community Server** y **MongoDB Compass**, abrir la pestaña *Mongosh* y ejecutar `2_MongoDB/mongodb_colecciones.js`.
5. Ejecutar `mvn spring-boot:run` y entrar a `http://localhost:8080/panel/login.html` (karen.paredes@mmabogados.pe / Secretaria2026!).
6. **Trabajar solo en su paquete y sus páginas** para no chocar con los demás:
   * Java: `src/main/java/pe/edu/utp/magallanes/web/t2/` (Controller + Repositorio ya creados con los SQL de ejemplo en comentarios).
   * Web: `src/main/resources/static/panel/t2-contratacion.html` (+ un `js/t2.js` propio). El menú (`js/menu.js`) y los estilos ya están.
7. **Modelo a copiar**: la pantalla *W04 · Bandeja y W06 · Cita*:
   * `static/panel/index.html` + `static/js/panel.js` → formulario, `fetch()` y mensajes COMMIT/ROLLBACK.
   * `repositorio/CitaRepositorio.java` → transacción completa con validaciones, `RETURN_GENERATED_KEYS` y `rollback()`.
8. Debajo de cada campo poner la etiqueta morada `<span class="bd">tabla.columna</span>` (igual que en Figma).
9. GitHub: crear una rama `t2-nombre`, hacer *commits* pequeños y abrir un *Pull Request* hacia `main`.

## Patrón de transacción (copiar tal cual)

```java
try (Connection cn = ds.getConnection()) {
    cn.setAutoCommit(false);                       // BEGIN TRANSACTION
    String idMongo = null;
    try {
        // (si aplica) idMongo = mongo.guardar("coleccion", documento);   ← primero MongoDB
        // INSERT 1 ... (Statement.RETURN_GENERATED_KEYS para obtener el id)
        // INSERT 2 ... usando el id anterior como FK
        // UPDATE ...
        cn.commit();                               // COMMIT: todo junto
        return resultado;
    } catch (SQLException | RuntimeException e) {
        cn.rollback();                             // ROLLBACK: nada a medias
        mongo.borrar("coleccion", idMongo);        // compensación en MongoDB
        throw e;
    }
}
```

## Para la sustentación

1. SSMS: ejecutar un SELECT de sus tablas **antes**.
2. Web: llenar su formulario → mensaje **COMMIT ✔** con los ids generados.
3. SSMS: el mismo SELECT **después** (se ven las filas nuevas y los UPDATE de estado).
4. Provocar un error de regla (CHECK/UNIQUE/trigger) → mensaje **ROLLBACK** y en SSMS no aparece nada.
5. MongoDB Compass: mostrar el documento creado y que su `_id` es el mismo que quedó en la columna `*_mongo_id`.
6. Diagrama en SSMS (Database Diagrams) solo con sus tablas, igual que `Flujo_Landing_Cita_Transaccional`.
