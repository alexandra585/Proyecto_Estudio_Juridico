# Landing Page + Panel del estudio (Java Spring Boot + HTML/CSS/JS + SQL Server)

Estudio Jurídico Magallanes-Montero · Base de Datos II · UTP

Aplicación web **funcional** que implementa el inicio del proceso P1 del prototipo de Figma:

| Pantalla (Figma) | Dirección | Qué hace | Tablas que GRABA | Tablas que LEE |
|---|---|---|---|---|
| **W01 · Landing Page** + formulario «Cuéntenos su caso» | `http://localhost:8080` | El cliente deja su consulta | **PERSONA** (si es nueva), **CONSULTA** (canal LANDING, estado RECIBIDA), **CONSULTA_CONTRAPARTE**, **NOTIFICACION** | MATERIA, EMPLEADO, ABOGADO, ABOGADO_MATERIA, ENCUESTA |
| **W02 · Inicio de sesión** (ícono del candado) | `/panel/login.html` | Valida la cuenta con BCrypt | USUARIO.ultimo_acceso (UPDATE) | USUARIO, EMPLEADO |
| **W04 · Bandeja de consultas** | `/panel/` | La secretaria ve lo que llegó por la web y revisa posibles conflictos | — | CONSULTA, PERSONA, MATERIA, CONSULTA_CONTRAPARTE, CASO_PARTE, CASO, CITA, NOTIFICACION |
| **W06 · Agendar cita** | `/panel/` | Agenda la cita con un abogado de esa materia | **CITA**, **CONSULTA** (estado AGENDADA), **NOTIFICACION** (cliente y abogado) | ABOGADO_MATERIA, FERIADO, CITA |

Cada grabación es **una transacción** en Java (`setAutoCommit(false)` → `commit()`; si algo falla → `rollback()`).
En las páginas, debajo de cada campo aparece la etiqueta morada **`tabla.columna`** donde se guarda (igual que en Figma);
el botón morado «Ocultar tablas de la BD» las esconde.


## Novedades (15/11/2026)

* **W03 · Dashboard gerencial** (`/panel/dashboard.html`): ganancias, cobranza mensual, ganancia por materia y por abogado,
  embudo comercial, canales, plazos, cuotas vencidas y satisfacción. Lee las vistas de
  `1_SQL_Server/magallanes_montero_vistas_dashboard.sql` (ejecútelo antes en SSMS).
* **Menú común** (`js/menu.js`) con los 4 módulos del equipo.
* **Módulos T2, T3 y T4** listos para que los programen los compañeros: paquetes `web/t2`, `web/t3`, `web/t4`
  y páginas `panel/t2-contratacion.html`, `panel/t3-expediente.html`, `panel/t4-cobranza.html`. Guías en `docs/`.
* **MongoDB** conectado (`spring.data.mongodb.uri` en `application.properties`) con la clase común `mongo/MongoDocumentos.java`.

## Estructura

```
magallanes-web/
├─ pom.xml                                   Spring Boot 3.3 (web + jdbc) + driver mssql-jdbc + BCrypt
├─ sql/
│  ├─ 00_probar_sentencias_con_rollback.sql  las mismas sentencias del código, con ROLLBACK (no cambia nada)
│  ├─ 01_preparar_base_para_la_web.sql       crea el usuario app_magallanes y claves de prueba del panel
│  └─ 02_ver_lo_que_grabo_la_web.sql         muestra las filas que grabaron la Landing y el panel
└─ src/main/
   ├─ resources/
   │  ├─ application.properties              conexión a SQL Server
   │  └─ static/                             FRONTEND (HTML + CSS + JavaScript)
   │     ├─ index.html                       W01 Landing Page con el formulario
   │     ├─ panel/login.html                 W02 Inicio de sesión
   │     ├─ panel/index.html                 W04 Bandeja + W06 Agendar cita
   │     ├─ css/estilos.css, css/panel.css   azul marino y dorado
   │     └─ js/landing.js, js/panel.js       llaman a la API con fetch()
   └─ java/pe/edu/utp/magallanes/web/        BACKEND (Java)
      ├─ MagallanesWebApplication.java       arranque
      ├─ controlador/                        API REST: PublicoController, AuthController, PanelController
      ├─ repositorio/                        JDBC + transacciones:
      │  ├─ ConsultaRepositorio.java         ← TRANSACCIÓN T1 (Landing) y bandeja
      │  ├─ CitaRepositorio.java             ← TRANSACCIÓN agendar cita (W06)
      │  ├─ UsuarioRepositorio.java          ← login (W02)
      │  └─ PublicoRepositorio.java          ← materias, socios, calificación
      ├─ dto/                                records con los datos que viajan en JSON
      └─ config/                             sesión del panel, BCrypt y errores
```

## Cómo ejecutarlo

**Una sola vez**

1. Requisitos: **JDK 17+**, **Maven** y **VS Code** con *Extension Pack for Java*. Puede comprobarlo con `java -version` y `mvn -v`.
2. SQL Server con la base creada: ejecute en SSMS `magallanes_montero_sqlserver_v36.sql` y luego `magallanes_montero_datos_prueba_v36.sql`.
3. En SSMS ejecute **`sql/01_preparar_base_para_la_web.sql`**: crea el usuario `app_magallanes` y pone claves de prueba al panel.
4. Habilite la conexión por red (JDBC no entra con la ventana de SSMS):
   * Servidor → **Properties → Security** → *SQL Server and Windows Authentication mode* → reiniciar.
   * **SQL Server Configuration Manager** → *Protocols for MSSQLSERVER01* → **TCP/IP = Enabled**.
   * *SQL Server Services* → **SQL Server Browser** → Start Mode **Automatic** → **Start**.
   * Reinicie **SQL Server (MSSQLSERVER01)**.
5. Revise `src/main/resources/application.properties` (nombre de la base, usuario y clave).

**Cada vez**

```
cd magallanes-web
mvn spring-boot:run
```

Cuando aparezca `Started MagallanesWebApplication`, abra **http://localhost:8080** en el navegador.
(La primera vez Maven descarga Spring Boot y el driver; necesita internet.)

## Cuentas de prueba del panel

| Correo | Contraseña | Cargo |
|---|---|---|
| karen.paredes@mmabogados.pe | Secretaria2026! | SECRETARIA |
| hector.magallanes@mmabogados.pe | Abogado2026! | ABOGADO |

## Guion para la sustentación

1. **Landing (W01)**: muestre que las áreas, los socios y la calificación vienen de la BD (MATERIA, ABOGADO_MATERIA, ENCUESTA).
2. Llene el formulario «Cuéntenos su caso» (DNI nuevo, materia Familia, una contraparte persona) → **Enviar consulta**.
   Aparece el `COMMIT ✔` con los ids de PERSONA, CONSULTA, CONSULTA_CONTRAPARTE y NOTIFICACION.
3. En SSMS ejecute `sql/02_ver_lo_que_grabo_la_web.sql`: se ven las 4 tablas con la consulta nueva (canal LANDING, estado RECIBIDA).
4. Clic en el **candado dorado** → login con la secretaria → **Bandeja**: la consulta aparece arriba con la etiqueta LANDING.
5. Selecciónela: se ve el detalle, la contraparte y la revisión de conflicto (CONSULTA_CONTRAPARTE × CASO_PARTE).
6. **W06 Agendar cita**: abogado (solo los de esa materia), fecha (los feriados de la tabla FERIADO se bloquean),
   hora (las horas tachadas ya tienen otra cita) → **Agendar cita y notificar**.
   La consulta pasa a AGENDADA y aparecen la CITA y las 2 NOTIFICACIONES.
7. Vuelva a ejecutar `sql/02_ver_lo_que_grabo_la_web.sql` para mostrar la CITA.
8. **Regla en acción**: elija una fecha feriado (por ejemplo 08/12/2026, si está en la tabla FERIADO) → el sistema no deja agendar.

## Si algo falla

| Mensaje | Solución |
|---|---|
| `The connection to the host localhost, named instance mssqlserver01 failed` | Inicie **SQL Server Browser** y habilite **TCP/IP** (paso 4). O use la URL con `:1433` del `application.properties`. |
| `Login failed for user 'app_magallanes'` | Active el modo mixto y reinicie; ejecute `sql/01_preparar_base_para_la_web.sql`. |
| `Cannot open database "magallanes_montero"` | Su base tiene otro nombre: cámbielo en `application.properties` y en los scripts `sql/`. |
| `Port 8080 was already in use` | Cierre la otra ejecución o cambie `server.port` en `application.properties`. |
| `Correo o contraseña incorrectos` | Ejecute `sql/01_preparar_base_para_la_web.sql` (los hashes de los datos de prueba son de ejemplo). |


## Novedades (18/11/2026)

- **W08 · Contrato y cuotas** funcionando (`panel/contrato.html`): transacción CONTRATO + CUOTA (n) + UPDATE CONSULTA. Ver `docs/W08_CONTRATO_Y_CUOTAS.md` y `sql/04_ver_lo_que_grabo_w08.sql`.
- **Botón «Mostrar / Ocultar campos BD»** en todas las pantallas (`js/bd.js`): arranca oculto y recuerda tu elección.
- **W07 · Propuesta de honorarios** funcionando (`panel/propuesta.html`): el flujo ya va completo Landing → Cita → Propuesta → Contrato.
- Menú y títulos con **nombre simple** (vista cliente) o **código técnico** P1/T1/W04 (con «Mostrar campos BD»).
