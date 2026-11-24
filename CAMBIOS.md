# Registro de cambios

## 23/11/2026 (noche) · Validación de datos en 3 niveles y ayudas al escribir
- **Base de datos** (`1_SQL_Server/magallanes_montero_validaciones.sql`): CHECK nuevos en PERSONA, EMPLEADO, CONSULTA y CASO
  - DNI 8 dígitos · RUC 11 (10/20) · CE 9-12 dígitos · Pasaporte 6-12 letras/números
  - Celular 9 dígitos que empieza en 9 (o +51) · correo nombre@dominio.ext · nombres y apellidos solo letras (mín. 2)
  - Razón social mín. 3 · relato de la consulta mín. 15 · código del caso EXP-AAAA-NNNN
  - El script revisa primero los datos existentes: WITH CHECK si todos cumplen, WITH NOCHECK (solo datos nuevos) si no, y lista las filas a corregir.
- **Servidor Java** (`config/Validar.java`): las mismas reglas con mensajes claros; limpia espacios y deja el celular sin espacios.
- **Landing**: el DNI y el celular no aceptan letras, los nombres no aceptan números, límite de dígitos según el tipo de documento, contador «5 / 8» y marca verde/roja al salir del campo.
- **Panel** (`js/ayudas.js`): ejemplos dentro de los campos, texto de ayuda debajo, sugerencias frecuentes (sumillas, plazos, resoluciones, etiquetas) y contador con el máximo de la columna.

## 23/11/2026 (tarde) · Conexión más robusta y bandeja
- `MagallanesWebApplication` lee `.env.example` y `.env` desde la carpeta `magallanes-web` aunque VS Code ejecute desde otra carpeta
  (antes, al abrir el proyecto desde la carpeta de arriba, no encontraba la contraseña y SQL Server respondía «Login failed»).
- Bandeja de consultas (W04): se quedaba en «Cargando…» con el menú nuevo; corregido (`js/panel.js`).
- Si el login `app_magallanes` quedó **bloqueado** por muchos intentos fallidos (política de contraseñas de Windows), en SSMS:
  `ALTER LOGIN app_magallanes WITH PASSWORD = N'Magallanes2026!' UNLOCK;`

## 23/11/2026 · Sistema completo, roles, landing renovada y encuestas

### Aplicación web (`8_Web_Landing_Panel/magallanes-web`)
- **Módulos terminados**
  - W09 · Apertura del expediente: CASO + CASO_PARTE + CASO_ETAPA + MongoDB `expedientes`.
  - W11–W13 · Escrito, presentación y resolución, con el plazo calculado en días hábiles y feriados (+ MongoDB `archivos`).
  - W18–W22 · Comprobante (IGV, detracción, serie correlativa), pago, cierre del caso y encuesta (+ MongoDB `encuestas`).
- **Plazos**: se cumplen al presentar el escrito (W12) o con «Ver plazos pendientes → Marcar cumplido» en el cierre (W21). Antes no se podía cerrar un caso.
- **Roles** (sin tabla nueva: salen de `empleado.cargo`)
  - Gerencia (ADMINISTRADOR), Abogado, Secretaría y Practicante.
  - Cada rol ve su menú; el servidor bloquea lo demás con 403 (`config/Roles.java` + `SesionInterceptor`).
  - Contraseñas de prueba: `sql/05_roles_contrasenas_de_prueba.sql`.
- **Inicio por rol** (`panel/inicio.html`): pendientes del día calculados en SQL Server (`InicioRepositorio`).
- **Panel con estilo nuevo**: barra superior con buscador en las tablas, íconos en el menú, tarjetas y pestañas más limpias, menú lateral en celular.
- **Encuestas**
  - Permiso del cliente para publicar su comentario y cómo firma (nombre e inicial / iniciales / anónimo). Se guarda solo en MongoDB `encuestas.publicacion`, sin cambiar tablas.
  - Pestaña «Resultados de encuestas»: promedio, distribución de estrellas, NPS y comentarios.
- **Landing renovada**: cifras reales de la base, áreas con íconos, pasos, equipo, testimonios autorizados (MongoDB), preguntas frecuentes, formulario T1 y botón de WhatsApp.
- **Dashboard con filtro por periodo**: Hoy / Semana / Mes / Trimestre / Año / 12 meses / Todo + calendario Desde–Hasta.
- **MongoDB**: la aplicación crea sola las 4 colecciones con su validador `$jsonSchema`, índices y formulario de encuesta (`mongo/MongoEsquema.java`).
- **Archivo `.env`**: datos de conexión de cada PC (copiar `.env.example` como `.env`). `.env` está en `.gitignore`.
- El navegador ya no guarda versiones viejas de JS/CSS (`spring.web.resources.cache.cachecontrol.no-cache=true`).

### Base de datos
- `1_SQL_Server/magallanes_montero_dashboard_filtros.sql`: vista `vw_dash_cobro_linea` y funciones `fn_dash_*(@desde, @hasta)` del filtro del dashboard. Ejecutar después de `magallanes_montero_vistas_dashboard.sql`.

### Documentos
- `4_Informe/Informe_Tecnico_MongoDB_Conexiones_Estructura.docx` (y PDF): por qué MongoDB, conexiones, `.env`, estructura del código y roles.
- `4_Informe/Informe_General_Proyecto_Magallanes_Montero.docx` (y PDF): resumen de todo el proyecto.
- `7_Figma/v2_web/`: capturas de las pantallas nuevas (landing, inicio por rol, resultados de encuestas, módulos).
