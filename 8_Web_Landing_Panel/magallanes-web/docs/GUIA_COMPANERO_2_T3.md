# Compañero 2 · Transacción T3 · Gestión del expediente

Estudio Jurídico Magallanes-Montero · Base de Datos II · UTP

**Pantallas de Figma:** W11 · Nuevo escrito (documento legal + jurisprudencia citada) → W12 · Registrar presentación (cargo de mesa de partes) → W13 · Registrar resolución y plazo.
**Proceso:** P2 · Gestión del expediente (TO-BE).
**Viene de:** el `CASO` abierto en W09 (Compañero 1). **Sigue en:** T4 usa la RESOLUCION final (SENTENCIA) y los GASTO_CASO.

## Qué graba cada pantalla (en este orden)

| Pantalla | Tabla / colección | Operación | Regla / detalle |
|---|---|---|---|
| W11 | **archivos (MongoDB)** | insert | `{ tipo: 'ESCRITO', id_caso, titulo, versiones: [{ v:1, autor, fecha, origen, contenido_texto }], jurisprudencia_citada[] }` |
| W11 | DOCUMENTO_LEGAL | INSERT | `tipo_documento` (DEMANDA, CONTESTACION, RECURSO…); estado BORRADOR; `archivo_mongo_id` = _id |
| W11 | DOCUMENTO_JURISPRUDENCIA | INSERT (n) | PK (id_documento, id_jurisprudencia) + `nota` (tabla intermedia M:N) |
| W12 | PRESENTACION | INSERT | `modalidad` FISICA / ELECTRONICA; `nro_cargo` del cargo de recepción |
| W12 | DOCUMENTO_LEGAL | UPDATE | `estado = 'PRESENTADO'` |
| W13 | archivos (MongoDB) | insert | `{ tipo: 'RESOLUCION', ... }` (PDF/texto de la resolución) |
| W13 | RESOLUCION | INSERT | `tipo_resolucion` y `medio_notificacion` con CHECK; `trg_resolucion_mismo_caso` |
| W13 | PLAZO | INSERT | `fecha_vencimiento`: HÁBIL = sin sábados, domingos ni FERIADO; CALENDARIO = inicio + días (`ck_plazo_calendario`); `trg_plazo_mismo_caso` |

**Se ve en el dashboard:** los plazos nuevos aparecen en «Plazos por vencer» (vw_plazos_por_vencer) y en la carga por abogado.
**Opcional (si alcanza el tiempo):** W14 · Programar audiencia (AUDIENCIA + NOTIFICACION) y W15 · Registrar gasto (GASTO_CASO).

## Columnas de las tablas que graba (script v36)

**DOCUMENTO_LEGAL**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_documento` | INT | Sí |
| `id_caso` | INT | Sí |
| `id_redactor` | INT | Sí |
| `id_revisor` | INT | No |
| `id_documento_origen` | INT | No |
| `tipo_documento` | VARCHAR(14) | Sí |
| `titulo` | NVARCHAR(200) | Sí |
| `version` | TINYINT | Sí |
| `elaborado_con_ia` | BIT | Sí |
| `requiere_firma_cliente` | BIT | Sí |
| `fecha_creacion` | DATETIME | Sí |
| `fecha_aprobacion` | DATETIME | No |
| `estado` | VARCHAR(11) | Sí |
| `archivo_mongo_id` | CHAR(24) | No |

**DOCUMENTO_JURISPRUDENCIA**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_documento` | INT | Sí |
| `id_jurisprudencia` | INT | Sí |
| `nota` | NVARCHAR(300) | No |

**PRESENTACION**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_presentacion` | INT | Sí |
| `id_documento` | INT | Sí |
| `id_entidad` | INT | Sí |
| `id_empleado` | INT | Sí |
| `fecha_hora` | DATETIME | Sí |
| `modalidad` | VARCHAR(11) | Sí |
| `nro_cargo` | NVARCHAR(40) | No |

**RESOLUCION**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_resolucion` | INT | Sí |
| `id_caso` | INT | Sí |
| `id_entidad` | INT | Sí |
| `id_presentacion` | INT | No |
| `nro_resolucion` | NVARCHAR(30) | No |
| `tipo_resolucion` | VARCHAR(17) | Sí |
| `fecha_notificacion` | DATE | Sí |
| `medio_notificacion` | VARCHAR(22) | Sí |
| `sumilla` | NVARCHAR(300) | No |
| `archivo_mongo_id` | CHAR(24) | No |

**PLAZO**

| Columna | Tipo | Obligatoria |
|---|---|---|
| `id_plazo` | INT | Sí |
| `id_caso` | INT | Sí |
| `id_resolucion` | INT | No |
| `id_empleado_responsable` | INT | Sí |
| `id_presentacion_cumplimiento` | INT | No |
| `descripcion` | NVARCHAR(200) | Sí |
| `fecha_inicio` | DATE | Sí |
| `dias_plazo` | SMALLINT | Sí |
| `tipo_computo` | VARCHAR(10) | Sí |
| `fecha_vencimiento` | DATE | Sí |
| `fecha_cumplimiento` | DATE | No |

## Cómo trabajar (igual para los tres)

1. **Clonar el repositorio** y abrir la carpeta `8_Web_Landing_Panel/magallanes-web` en VS Code.
2. Preparar la base: ejecutar en SSMS, en orden, `1_SQL_Server/magallanes_montero_sqlserver_v36.sql`, `..._datos_prueba_v36.sql`,
   `magallanes_montero_vistas_dashboard.sql` y `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql`
   (ajustar el nombre de la base si no es `magallanes_montero_prueba36`).
3. Revisar `src/main/resources/application.properties` (servidor, puerto, base, usuario `app_magallanes`).
4. MongoDB: instalar **MongoDB Community Server** y **MongoDB Compass**, abrir la pestaña *Mongosh* y ejecutar `2_MongoDB/mongodb_colecciones.js`.
5. Ejecutar `mvn spring-boot:run` y entrar a `http://localhost:8080/panel/login.html` (karen.paredes@mmabogados.pe / Secretaria2026!).
6. **Trabajar solo en su paquete y sus páginas** para no chocar con los demás:
   * Java: `src/main/java/pe/edu/utp/magallanes/web/t3/` (Controller + Repositorio ya creados con los SQL de ejemplo en comentarios).
   * Web: `src/main/resources/static/panel/t3-expediente.html` (+ un `js/t3.js` propio). El menú (`js/menu.js`) y los estilos ya están.
7. **Modelo a copiar**: la pantalla *W04 · Bandeja y W06 · Cita*:
   * `static/panel/index.html` + `static/js/panel.js` → formulario, `fetch()` y mensajes COMMIT/ROLLBACK.
   * `repositorio/CitaRepositorio.java` → transacción completa con validaciones, `RETURN_GENERATED_KEYS` y `rollback()`.
8. Debajo de cada campo poner la etiqueta morada `<span class="bd">tabla.columna</span>` (igual que en Figma).
9. GitHub: crear una rama `t3-nombre`, hacer *commits* pequeños y abrir un *Pull Request* hacia `main`.

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
