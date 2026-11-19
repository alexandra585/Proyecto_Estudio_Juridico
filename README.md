# Proyecto Estudio Jurídico Magallanes-Montero · Base de Datos II (UTP)

Base de datos híbrida (**SQL Server + MongoDB**) y sistema web para la gestión de consultas, expedientes y facturación
del Estudio Jurídico Magallanes-Montero. Incluye BPMN AS-IS/TO-BE, modelo conceptual (Chen), lógico y físico (36 tablas),
normalización, prototipo en Figma, dashboard gerencial y la aplicación web (Java Spring Boot).

* Prototipo en Figma: https://www.figma.com/design/JyHrpDAn41uGzJNggzBJsa/MM-Abogados---Prototipo-BD-v36
  (página «Prototipo · técnico (con campos BD)» y página «Prototipo · cliente (sin campos BD)»)
* Base de datos de trabajo: `magallanes_montero_prueba36` (SQL Server 2022)

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
MongoDB (Community + Compass) es opcional: la web arranca aunque no esté instalado.

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
| 4 | `8_Web_Landing_Panel/magallanes-web/sql/01_preparar_base_para_la_web.sql` | Nada (crea el usuario `app_magallanes` y las contraseñas de prueba) |

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

   y poner ese número en lugar de `55448` en
   `8_Web_Landing_Panel/magallanes-web/src/main/resources/application.properties`:

   ```
   spring.datasource.url=jdbc:sqlserver://localhost:PUERTO;databaseName=magallanes_montero_prueba36;encrypt=true;trustServerCertificate=true
   ```

4. Para que Git no suba su puerto y les cambie la configuración a los demás:

   ```
   git update-index --assume-unchanged 8_Web_Landing_Panel/magallanes-web/src/main/resources/application.properties
   ```

### 5. MongoDB (opcional)

MongoDB Compass → pestaña *Mongosh* → pegar y ejecutar `2_MongoDB/mongodb_colecciones.js`.

### 6. Correr la aplicación

```
cd 8_Web_Landing_Panel\magallanes-web
mvn spring-boot:run
```

Abrir http://localhost:8080. La primera vez tarda porque Maven descarga las librerías (se necesita internet).

| Usuario del panel | Contraseña | Rol |
|---|---|---|
| `karen.paredes@mmabogados.pe` | `Secretaria2026!` | Secretaria |
| `hector.magallanes@mmabogados.pe` | `Abogado2026!` | Abogado |

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

Landing (W01) → Bandeja y cita (W04 · W06) → Propuesta (W07) → Contrato y cuotas (W08) → Dashboard (W03).
El estado de la consulta pasa por RECIBIDA → AGENDADA → PROPUESTA → CONTRATADA. Explicación y demostración:
`8_Web_Landing_Panel/magallanes-web/docs/W08_CONTRATO_Y_CUOTAS.md` y `4_Informe/Informe_Relacion_Web_BD_Magallanes_Montero.docx`.

## Equipo y reparto

Ver `8_Web_Landing_Panel/magallanes-web/docs/ORGANIZACION_EQUIPO.md`.

| Integrante | Transacción | Pantallas | Estado |
|---|---|---|---|
| Alexandra | T1 + T2 (parte) + Dashboard | W01 Landing, W02 Login, W04 Bandeja, W06 Cita, W07 Propuesta, W08 Contrato y cuotas, W03 Dashboard | Funcionando |
| Compañero 1 | T2 | W09 Nuevo expediente (CASO + CASO_PARTE + CASO_ETAPA + MongoDB `expedientes`) | Pendiente |
| Compañero 2 | T3 | W11 Escrito, W12 Presentación, W13 Resolución y plazo | Pendiente |
| Compañero 3 | T4 | W18 Comprobante, W19 Pago, W21 Cierre, W22 Encuesta | Pendiente |
