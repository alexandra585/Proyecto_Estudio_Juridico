# Proyecto Estudio Jurídico Magallanes-Montero · Base de Datos II (UTP)

Base de datos híbrida (**SQL Server + MongoDB**) y sistema web para la gestión de consultas, expedientes y facturación
del Estudio Jurídico Magallanes-Montero. Incluye BPMN AS-IS/TO-BE, modelo conceptual (Chen), lógico y físico (36 tablas),
normalización, prototipo en Figma, dashboard gerencial y la aplicación web (Java Spring Boot).

* Prototipo en Figma: https://www.figma.com/design/JyHrpDAn41uGzJNggzBJsa/MM-Abogados---Prototipo-BD-v36
  (página «Prototipo · técnico (con campos BD)» y página «Prototipo · cliente (sin campos BD)»)
* Base de datos de trabajo: `magallanes_montero_prueba36` (SQL Server 2022 o superior) + MongoDB `magallanes_montero`

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `0_BPMN/AS-IS`, `0_BPMN/TO-BE` | Diagramas BPMN 2.0 (Bizagi) de los 3 procesos + imágenes. El TO-BE es el que va en el informe (sección 3.4). |
| `1_SQL_Server` | Script de creación v36 (36 tablas, 70 FK, 65 CHECK, 10 triggers, 13 índices, 6 vistas), datos de prueba, pruebas de reglas y **vistas del dashboard** (`magallanes_montero_vistas_dashboard.sql`). |
| `2_MongoDB` | `mongodb_colecciones.js`: colecciones `expedientes`, `archivos`, `formularios_encuesta`, `encuestas`. |
| `3_DER` | DER conceptual (Chen), lógico y físico (draw.io + PNG). |
| `4_Informe` | Informe final (Word y PDF) e **informe de relación web – base de datos** con capturas. |
| `5_Normalizacion` | Normalización 1FN–3FN de DOCUMENTO_LEGAL y COMPROBANTE. |
| `6_Mapa_Pantallas_Tablas` | Qué pantalla graba y lee cada tabla. |
| `7_Figma` | Secciones del prototipo exportadas (incluye la **8 · Dashboard gerencial**). |
| `8_Web_Landing_Panel/magallanes-web` | **Aplicación web**: Landing + panel + dashboard + módulos T2/T3/T4. Guías del equipo en `docs/`. |

## Instalación en una laptop nueva (paso a paso)

### 1. Requisitos

Revisar en una terminal (cmd o la terminal de VS Code):

```
java -version
mvn -v
git --version
```

Se necesita **Java 17 o superior**, **Maven**, **Git**, **SQL Server** y **SQL Server Management Studio (SSMS)**.
MongoDB (Community + Compass) se usa en W09, W11, W13, W21 y W22; si no está instalado la web arranca igual.

### 2. Descargar el proyecto (recomendado: con Git, para poder subir cambios)

```
cd %USERPROFILE%\Desktop
git clone https://github.com/alexandra585/Proyecto_Estudio_Juridico.git
cd Proyecto_Estudio_Juridico
```

Si se descarga como ZIP («Code → Download ZIP»), la carpeta se llama `Proyecto_Estudio_Juridico-main`; con el ZIP no se pueden subir cambios.

### 3. Crear la base de datos en SSMS

Abrir cada archivo y ejecutarlo con **F5**, en este orden:

| # | Archivo | Antes de ejecutar |
|---|---|---|
| 1 | `1_SQL_Server/magallanes_montero_sqlserver_v36.sql` | **Ctrl+H** → buscar `magallanes_montero` → reemplazar por `magallanes_montero_prueba36` → **Reemplazar todo** |
| 2 | `1_SQL_Server/magallanes_montero_datos_prueba_v36.sql` | El mismo **Ctrl+H** |
| 3 | `1_SQL_Server/magallanes_montero_vistas_dashboard.sql` | Nada |
| 4 | `1_SQL_Server/magallanes_montero_dashboard_filtros.sql` | Nada (funciones del filtro por periodo del dashboard) |
| 5 | `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql` | Nada (crea el usuario `app_magallanes` y las contraseñas de prueba) |
| 6 | `1_SQL_Server/magallanes_montero_validaciones.sql` | Nada (reglas de DNI, celular, nombres…) |
| 7 | `8_Web_Landing_Panel/magallanes-web/sql/05_roles_contrasenas_de_prueba.sql` | Nada (contraseñas de prueba por rol) |
| 8 | `1_SQL_Server/magallanes_montero_portal_firma.sql` | Nada (contrato pendiente de firma + cuentas del portal del cliente) |

> El reemplazo hace falta porque los scripts 1 y 2 crean la base como `magallanes_montero`, y la aplicación usa `magallanes_montero_prueba36`.

### 4. Conectar la aplicación a SQL Server (cambia en cada laptop)

1. **Autenticación mixta**: en SSMS, clic derecho en el servidor → *Properties* → *Security* →
   **SQL Server and Windows Authentication mode** → OK. Reiniciar el servicio de SQL Server.
2. **TCP/IP activado**: *SQL Server Configuration Manager* → *SQL Server Network Configuration* → *Protocols for (su instancia)* →
   **TCP/IP = Enabled**. Reiniciar el servicio.
3. **Puerto de la instancia**: en SSMS ejecutar

   ```sql
   EXEC xp_readerrorlog 0, 1, N'Server is listening on';
   ```

4. **Archivo `.env`** (los datos de SU computadora; no se sube a GitHub): en `8_Web_Landing_Panel/magallanes-web`

   ```
   copy .env.example .env
   ```

   y en `.env` cambiar `DB_PORT` por su puerto (1433 en la instancia por defecto, por ejemplo 55448 en una instancia con nombre).
   Ya **no** hay que modificar `application.properties`: lee los valores del `.env`.

### 5. MongoDB

Encender el servicio **MongoDB Server** y, en MongoDB Compass → pestaña *Mongosh*, pegar y ejecutar `2_MongoDB/mongodb_colecciones.js`.
Lo usan W09 (`expedientes`), W11/W13 (`archivos`) y W21/W22 (`encuestas`). Si MongoDB está apagado, la web funciona igual
y graba solo en SQL Server (la pantalla lo avisa).

### 6. Correr la aplicación

```
cd 8_Web_Landing_Panel\magallanes-web
mvn spring-boot:run
```

Abrir http://localhost:8080. La primera vez tarda porque Maven descarga las librerías (se necesita internet).

Ejecutar una vez en SSMS `8_Web_Landing_Panel/magallanes-web/sql/05_roles_contrasenas_de_prueba.sql` (contraseñas de prueba por rol).
El rol sale de `empleado.cargo` (sin tabla nueva): cada rol ve su menú y el servidor bloquea lo demás (403).

| Usuario del panel | Contraseña | Rol | Qué ve |
|---|---|---|---|
| `gabriela.montero@mmabogados.pe` | `Gerencia2026!` | ADMINISTRADOR (Gerencia) | Todo |
| `hector.magallanes@mmabogados.pe` | `Abogado2026!` | ABOGADO | Dashboard, consultas, propuestas, expediente nuevo, escritos y resoluciones |
| `karen.paredes@mmabogados.pe` | `Secretaria2026!` | SECRETARIA | Consultas y citas, contratos y cuotas, cobranza, cierre y encuestas |
| `miguel.rojas@mmabogados.pe` | `Practicante2026!` | PRACTICANTE | Consultas, escritos y resoluciones |

**Portal del cliente** (`http://localhost:8080/portal/index.html`, pensado para el celular): el cliente entra con su **DNI/RUC** (o correo)
y ve su caso (etapas, audiencias, línea de tiempo, documentos), sus cuotas, firma su contrato y responde la encuesta.
Cuentas de prueba (contraseña `Cliente2026!`, script 8):

| Cliente | Entra con | Para mostrar |
|---|---|---|
| María Elena Torres | DNI `40987123` | Contrato **pendiente de firma** (firma digital en el celular) + caso laboral en apelación |
| Juan Carlos Pérez | DNI `45123678` | Caso concluido y encuesta respondida |
| Rosa Marina Huamán | DNI `43215678` | Caso de alimentos en trámite, audiencia y cuota por vencer |

Un cliente nuevo recibe su cuenta al registrar su contrato (W08): usuario = su N.° de documento, contraseña inicial = ese mismo número.

Para detener la aplicación: **Ctrl+C** en la terminal. Si se cambia código Java, volver a ejecutar `mvn spring-boot:run`;
si se cambia HTML/CSS/JS, recargar el navegador con **Ctrl+F5**.

El botón **«Mostrar / Ocultar campos BD»** (abajo a la derecha) muestra de qué `tabla.columna` sale cada campo y los códigos
P1/T1/W04; oculto, el sistema se ve como lo usaría el estudio.

### 7. Subir cambios (cada integrante)

```
git pull
git add .
git commit -m "Compañero X: descripción del cambio"
git push
```

Hacer siempre `git pull` antes de empezar a trabajar. Para poder hacer `push`, la dueña del repositorio debe agregar a cada
integrante en **Settings → Collaborators → Add people**.

## Flujo que ya funciona en la web

Landing (W01) → Bandeja y cita (W04 · W06) → Propuesta (W07) → Contrato y cuotas (W08) → Expediente (W09) →
Escrito, presentación y resolución (W11–W13) → Comprobante y pago (W18 · W19) → Cierre y encuesta (W21 · W22) → Dashboard (W03, con filtro
Hoy / Semana / Mes / Trimestre / Año / 12 meses / Todo + calendario).

Informes en `4_Informe`:
* `Informe_Tecnico_MongoDB_Conexiones_Estructura.docx`: por qué MongoDB, cómo se conecta la app, el archivo `.env` y la estructura del código.
* `Informe_General_Proyecto_Magallanes_Montero.docx`: resumen de todo el proyecto.
* `Informe_Relacion_Web_BD_Magallanes_Montero.docx`: pantallas ↔ tablas con capturas.

## Equipo y reparto (sustentación)

Todos los módulos están programados; cada integrante explica el suyo. Guías en `8_Web_Landing_Panel/magallanes-web/docs/`.

| Integrante | Transacción | Pantallas | Estado |
|---|---|---|---|
| Alexandra | T1 + T2 (parte) + Dashboard | W01, W02, W04, W06, W07, W08, W03 con filtro | Funcionando |
| Compañero 1 | T2 | W09 Nuevo expediente (CASO + CASO_PARTE + CASO_ETAPA + MongoDB `expedientes`) | Funcionando · explicar |
| Compañero 2 | T3 | W11 Escrito, W12 Presentación, W13 Resolución y plazo (+ MongoDB `archivos`) | Funcionando · explicar |
| Compañero 3 | T4 | W18 Comprobante, W19 Pago, W21 Cierre, W22 Encuesta (+ MongoDB `encuestas`) | Funcionando · explicar |
