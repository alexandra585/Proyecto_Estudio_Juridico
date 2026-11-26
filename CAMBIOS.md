# Registro de cambios

## 25/11/2026 · Portal del cliente, firma del contrato, expediente y campana de avisos (alineado al TO-BE)
- **Portal del cliente** (`/portal/index.html`, responsive para celular): ingreso con DNI/RUC o correo (tabla USUARIO con `id_persona`,
  que ya existía en el modelo de 36 tablas). Muestra tareas pendientes, sus casos con la barra de etapas, audiencias, línea de tiempo y
  documentos presentados, sus cuotas (pagadas / por pagar / vencidas) y los avisos del estudio.
- **Firma del contrato**: en W08 la secretaria elige *Digital* (el contrato queda **pendiente de firma** y el cliente lo firma en el portal
  dibujando su firma) o *Presencial* (firmó en el estudio). La firma digital se guarda en MongoDB `archivos` (tipo CONTRATO, `firma.imagen_png`).
  Hasta que el contrato esté firmado no se facturan sus cuotas ni se abre el expediente (W09).
  - Único cambio en la base: `contrato.fecha_firma` admite NULL + columna nueva `contrato.modalidad_firma` (DIGITAL/PRESENCIAL) + 2 CHECK
    (`1_SQL_Server/magallanes_montero_portal_firma.sql`; también actualizados el script v36, el explicado y los datos de prueba). Siguen siendo 36 tablas.
  - Si el cliente no tenía cuenta del portal, se crea al registrar su contrato (usuario = N.° de documento).
- **Encuesta**: al cerrar el caso le llega al cliente y la responde **él** en su portal (antes la llenaba la secretaria). En el panel,
  la pestaña *Encuestas enviadas* solo hace el seguimiento.
- **Expediente** (Escritos y resoluciones): ficha nueva con barra de etapas, semáforo de plazos, próximas audiencias, partes,
  línea de tiempo, documentos con sus versiones de MongoDB y bitácora interna. El portal usa la misma ficha sin datos internos.
- **Campana de avisos** en el panel (tabla NOTIFICACION, canal SISTEMA): firma del cliente, nueva consulta desde la web,
  encuesta respondida y plazos a su cargo que vencen en 3 días.
- Landing: botón «Soy cliente» y enlace al portal; login del panel con enlace al portal.

## 24/11/2026 · Informes actualizados
- Informe técnico: nueva lectura del `.env` (MagallanesWebApplication), login bloqueado, creación automática de colecciones MongoDB,
  validación de datos en 3 niveles (sección 12), diagramas y compatibilidad SSMS 20 / SQL Server 2025 (sección 13), estructura con archivos nuevos.
- Informe general: validaciones, ayudas al escribir y orden de scripts de instalación (incluye validaciones y roles).

## 23/11/2026 (noche) · Validación de datos en 3 niveles y ayudas al escribir
- **Base de datos** (`1_SQL_Server/magallanes_montero_validaciones.sql`): CHECK nuevos en PERSONA, EMPLEADO, CONSULTA y CASO
  - DNI 8 dígitos · RUC 11 (10/20) · CE 9-12 dígitos · Pasaporte 6-12 letras/números
  - Celular: exactamente 9 dígitos que empieza en 9 · correo nombre@dominio.ext · nombres y apellidos solo letras (mín. 2)
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

## 26/11/2026 · Ajustes finales v38
- Ficha del expediente: «Consulta inicial» se muestra como HECHA (con la fecha de la consulta); las etapas anteriores a la apertura salen como PREVIA (gris, sin tachar).
- W09: al abrir el expediente el cliente recibe en su portal el aviso APERTURA_EXPEDIENTE (NOTIFICACION). El CHECK `ck_notificacion_tipo_evento` suma ese evento (`magallanes_montero_portal_firma.sql`, paso 4b). Siguen siendo 36 tablas.
- BPMN TO-BE P1 y P3 alineados con el sistema (acceso al portal al enviar el contrato, aviso de apertura, encuesta en el portal, nota de firma pendiente).
- `0_BPMN/Matriz_Bizagi_Pantallas_Tablas.docx/.pdf`: cada tarea TO-BE con su pantalla, tablas y estado.
- `7_Figma/seccion10_portal_v38.svg`: tablero 10 del prototipo (portal del cliente y firma).
- `1_SQL_Server/Demo_sustentacion_selects.sql`: consultas para mostrar en la sustentación qué se guarda.
- Informes v38, técnico y general: mencionan el nuevo evento de NOTIFICACION.
