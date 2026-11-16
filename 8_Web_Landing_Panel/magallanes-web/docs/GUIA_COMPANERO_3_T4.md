# Compañero 3 · Transacción T4 · Cobranza y cierre

Estudio Jurídico Magallanes-Montero · Base de Datos II · UTP

**Pantallas de Figma:** W18 · Emitir comprobante (boleta/factura) → W19 · Registrar pago → W21 · Cierre del caso y envío de encuesta → W22 · Encuesta de satisfacción (portal).
**Proceso:** P3 · Resolución, facturación y cierre (TO-BE).
**Viene de:** las CUOTA del contrato (T2) y los GASTO_CASO (T3). **Alimenta:** casi todo el dashboard de Alexandra (ingresos, por cobrar, cuotas vencidas, satisfacción).

## Qué graba cada pantalla (en este orden)

| Pantalla | Tabla / colección | Operación | Regla / detalle |
|---|---|---|---|
| W18 | COMPROBANTE | INSERT | serie B001/F001/E001; `numero = serie_comprobante.ultimo_numero + 1` (lo valida `trg_comprobante_correlativo`); receptor con DNI/RUC |
| W18 | DETALLE_COMPROBANTE | INSERT (n) | una línea por cuota o gasto (`id_cuota` **o** `id_gasto`); `trg_detalle_comprobante_coherencia` |
| W18 | SERIE_COMPROBANTE | UPDATE (trigger) | lo hace el trigger: **no** programarlo en Java |
| W19 | PAGO | INSERT | `monto > 0` y ≤ saldo de `vw_comprobante_saldo`; `medio_pago` con CHECK |
| W19 | NOTIFICACION | INSERT | `tipo_evento = 'CONSTANCIA_PAGO'`, un destinatario, `id_caso` o `id_consulta` |
| W21 | CASO | UPDATE | `estado = 'CERRADO'`, `fecha_cierre` |
| W21 | ENCUESTA + NOTIFICACION | INSERT | 1 encuesta por caso (UNIQUE); `tipo_evento = 'ENVIO_ENCUESTA'` |
| W22 | ENCUESTA | UPDATE | `calificacion` 1–5, `nps` 0–10, `comentario`, `fecha_respuesta` |
| W22 | **encuestas (MongoDB)** | insert | `{ id_encuesta, id_caso, version_formulario, respuestas: { calificacion, nps, ...preguntas libres }, estado: 'RESPONDIDA' }` |

**Importante (3FN):** el total, el IGV, lo pagado y el saldo **no se guardan**: se leen de `vw_comprobante_total` y `vw_comprobante_saldo`.
**Se ve en el dashboard:** ingresos cobrados, por cobrar, cobranza mensual, ganancia por materia/abogado y satisfacción cambian al instante.

## Columnas de las tablas que graba (script v36)

**COMPROBANTE**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_comprobante` | INT | Sí |
| `id_persona` | INT | Sí |
| `id_emisor` | INT | Sí |
| `id_consulta` | INT | No |
| `serie` | CHAR(4) | Sí |
| `numero` | INT | Sí |
| `fecha_emision` | DATE | Sí |
| `fecha_vencimiento` | DATE | Sí |
| `moneda` | CHAR(3) | Sí |
| `tasa_igv` | DECIMAL(4,2) | Sí |
| `porcentaje_detraccion` | DECIMAL(4,2) | Sí |
| `fecha_conformidad` | DATE | No |
| `estado` | VARCHAR(8) | Sí |

**DETALLE_COMPROBANTE**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_comprobante` | INT | Sí |
| `nro_linea` | TINYINT | Sí |
| `id_cuota` | INT | No |
| `id_gasto` | INT | No |
| `descripcion` | NVARCHAR(200) | Sí |
| `cantidad` | DECIMAL(8,2) | Sí |
| `valor_unitario` | DECIMAL(12,2) | Sí |

**PAGO**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_pago` | INT | Sí |
| `id_comprobante` | INT | Sí |
| `id_empleado` | INT | Sí |
| `fecha_pago` | DATETIME | Sí |
| `monto` | DECIMAL(12,2) | Sí |
| `medio_pago` | VARCHAR(13) | Sí |
| `nro_operacion` | NVARCHAR(40) | No |

**ENCUESTA**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_encuesta` | INT | Sí |
| `id_caso` | INT | Sí |
| `fecha_envio` | DATETIME | Sí |
| `fecha_respuesta` | DATETIME | No |
| `calificacion` | TINYINT | No |
| `nps` | TINYINT | No |
| `comentario` | NVARCHAR(500) | No |

**NOTIFICACION**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_notificacion` | INT | Sí |
| `id_persona` | INT | No |
| `id_empleado` | INT | No |
| `id_consulta` | INT | No |
| `id_caso` | INT | No |
| `tipo_evento` | VARCHAR(21) | Sí |
| `canal` | VARCHAR(8) | Sí |
| `mensaje` | NVARCHAR(500) | Sí |
| `fecha_programada` | DATETIME | Sí |
| `fecha_envio` | DATETIME | No |
| `estado` | VARCHAR(9) | Sí |

## Cómo trabajar (igual para los tres)

1. **Clonar el repositorio** y abrir la carpeta `8_Web_Landing_Panel/magallanes-web` en VS Code.
2. Preparar la base: ejecutar en SSMS, en orden, `1_SQL_Server/magallanes_montero_sqlserver_v36.sql`, `..._datos_prueba_v36.sql`,
   `magallanes_montero_vistas_dashboard.sql` y `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql`
   (ajustar el nombre de la base si no es `magallanes_montero_prueba36`).
3. Revisar `src/main/resources/application.properties` (servidor, puerto, base, usuario `app_magallanes`).
4. MongoDB: instalar **MongoDB Community Server** y **MongoDB Compass**, abrir la pestaña *Mongosh* y ejecutar `2_MongoDB/mongodb_colecciones.js`.
5. Ejecutar `mvn spring-boot:run` y entrar a `http://localhost:8080/panel/login.html` (karen.paredes@mmabogados.pe / Secretaria2026!).
6. **Trabajar solo en su paquete y sus páginas** para no chocar con los demás:
   * Java: `src/main/java/pe/edu/utp/magallanes/web/t4/` (Controller + Repositorio ya creados con los SQL de ejemplo en comentarios).
   * Web: `src/main/resources/static/panel/t4-cobranza.html` (+ un `js/t4.js` propio). El menú (`js/menu.js`) y los estilos ya están.
7. **Modelo a copiar**: la pantalla *W04 · Bandeja y W06 · Cita*:
   * `static/panel/index.html` + `static/js/panel.js` → formulario, `fetch()` y mensajes COMMIT/ROLLBACK.
   * `repositorio/CitaRepositorio.java` → transacción completa con validaciones, `RETURN_GENERATED_KEYS` y `rollback()`.
8. Debajo de cada campo poner la etiqueta morada `<span class="bd">tabla.columna</span>` (igual que en Figma).
9. GitHub: crear una rama `t4-nombre`, hacer *commits* pequeños y abrir un *Pull Request* hacia `main`.

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
