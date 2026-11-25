-- =====================================================================
-- ESTUDIO JURÍDICO MAGALLANES-MONTERO · BASE DE DATOS (SQL Server / T-SQL)
-- Versión EXPLICADA y CORREGIDA (36 tablas): coincide con los diagramas físicos
-- P1, P2 y P3 corregidos. Cada línea lleva un comentario.
-- =====================================================================
-- CÓMO EJECUTARLO EN SQL SERVER MANAGEMENT STUDIO (SSMS)
--   1. Abrir SSMS y conectarse al servidor (por ejemplo: localhost o .\SQLEXPRESS,
--      con Autenticación de Windows).
--   2. Archivo > Abrir > Archivo... (Ctrl+O) y elegir este script.
--   3. Pulsar F5 o el botón "Ejecutar". Abajo, en "Mensajes", debe decir
--      "Base de datos magallanes_montero creada correctamente".
--   4. En el Explorador de objetos: clic derecho en "Bases de datos" > Actualizar.
--   5. Luego abrir y ejecutar datos_prueba_sqlserver.sql (datos de ejemplo).
--   Para ver el diagrama: expandir la base > "Diagramas de base de datos" >
--   clic derecho > "Nuevo diagrama" > agregar todas las tablas.
--
-- CÓMO LEER UN COMENTARIO
--   Todo lo que va después de dos guiones (--) es un comentario: SQL Server
--   lo ignora; solo sirve para explicar.
--
-- ¿QUÉ ES "GO"?
--   GO no es una instrucción SQL: es una orden de SSMS que significa
--   "envía al servidor todo lo escrito hasta aquí". Se usa porque algunas
--   instrucciones (CREATE DATABASE, USE, CREATE VIEW) deben ir en su propio lote.
--
-- CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR (30 tablas)
--   Tablas nuevas : ABOGADO, FERIADO, GASTO_CASO, SERIE_COMPROBANTE.
--   ABOGADO       : la colegiatura sale de EMPLEADO. CITA, PROPUESTA, LIQUIDACION, AUDIENCIA, CASO
--                   (abogado responsable), DOCUMENTO_LEGAL (revisor) y ABOGADO_MATERIA apuntan a ABOGADO.
--   CONTRATO      : + id_cliente (el cliente se define una sola vez).
--   CONSULTA      : + id_revisor_conflicto, fecha_revision_conflicto, detalle_conflicto.
--   CASO_PARTE    : la PK incluye id_rol (una persona puede tener varios roles en un caso).
--   CASO_ETAPA    : PK propia id_caso_etapa; una etapa puede repetirse; una sola etapa abierta por caso.
--   PLAZO         : - estado (lo calcula vw_plazo_estado); + responsable, días, tipo de cómputo, escrito de cumplimiento.
--   CUOTA         : el estado ya no admite VENCIDA (la calcula vw_cuota_estado).
--   PRESENTACION  : - monto_tasa (ahora los gastos van en GASTO_CASO y se pueden cobrar en un comprobante).
--   LIQUIDACION   : - monto_cuota_litis (lo calcula vw_liquidacion_cuota_litis).
--   COMPROBANTE   : - tipo_comprobante (sale de la serie), - aplica_detraccion, + moneda, + porcentaje_detraccion.
--   DETALLE_COMPROBANTE : + id_gasto (reembolso de gastos).
--   ENTIDAD       : UNIQUE (nombre, distrito_judicial) → índice único filtrado.
--   Llaves compuestas y triggers para exigir "mismo caso" y "cargo = ABOGADO" (sección 6).
--
-- CAMBIOS DE LA VERSIÓN 36 TABLAS (revisión del equipo, noviembre 2026)
--   Tablas nuevas : USUARIO (login del panel y del portal) y NOTIFICACION (avisos por WhatsApp, correo y panel).
--   PERSONA       : tipo_documento y nro_documento opcionales (una contraparte puede no tenerlos);
--                   un cliente sí debe tenerlos (triggers 9 y 10). El UNIQUE pasa a índice único filtrado.
--   CONSULTA      : id_secretaria → id_registrado_por (opcional: la consulta de la landing llega sin nadie que la registre);
--                   id_revisor_conflicto apunta a ABOGADO (solo un abogado revisa conflictos de intereses).
--   COMPROBANTE   : estado solo EMITIDO / ANULADO; PAGADO y PAGADO_PARCIAL se calculan en vw_comprobante_saldo.
--   Triggers      : correlativo sin saltos (6), sentencia solo sobre resolución final (7), coherencia de las líneas
--                   del comprobante (8), documento del cliente en contrato (9) y en comprobante (10).
--   FK compuestas : son 2 (plazo → resolución del mismo caso y escrito → escrito de origen del mismo caso).
--
-- ESTRUCTURA DEL SCRIPT
--   0. Crear la base de datos
--   1. Tablas maestras (persona, empleado, abogado, usuario, catálogos, feriado)
--   2. Tablas del Proceso 1 (consulta, cita, propuesta, contrato, cuota)
--   3. Tablas del Proceso 2 (caso, documentos, presentaciones, gastos, resoluciones, plazos, audiencias)
--   4. Tablas del Proceso 3 (sentencia, liquidación, series, comprobantes, pagos, devolución, encuesta)
--   4.1 Tabla transversal: notificación
--   5. Llave foránea pendiente (ALTER TABLE)
--   6. Triggers (reglas que un CHECK no puede expresar)
--   7. Índices únicos filtrados e índices de búsqueda
--   8. Vistas (totales, saldos, estados y alertas calculados)
--   9. Consultas de ejemplo
--
-- PALABRAS QUE SE REPITEN EN TODAS LAS TABLAS
--   dbo.tabla         → "dbo" es el esquema por defecto (como una carpeta dentro de la base).
--   NOT NULL          → el dato es obligatorio.     NULL → puede quedar vacío.
--   IDENTITY(1,1)     → SQL Server genera el número solo: empieza en 1 y suma 1.
--   PRIMARY KEY (PK)  → identifica cada fila; no se repite ni puede estar vacía.
--   FOREIGN KEY (FK)  → enlaza con otra tabla; impide datos "huérfanos".
--   UNIQUE            → el valor no se puede repetir en la tabla.
--   CHECK             → regla que SQL Server valida al insertar o modificar.
--   DEFAULT           → valor que se usa si no se envía ninguno.
--   CONSTRAINT nombre → le pone nombre a cada regla, para que los errores se entiendan
--                       (pk_ = llave primaria, fk_ = foránea, uq_ = única,
--                        ck_ = check, df_ = valor por defecto).
--
-- TIPOS DE DATOS USADOS (y su equivalente en MySQL)
--   SQL Server        MySQL                 Uso
--   INT               INT UNSIGNED          identificadores (id_...)
--   SMALLINT/TINYINT  SMALLINT/TINYINT      catálogos pequeños, versiones, notas
--   BIT               TINYINT(1)            sí/no (1 / 0)
--   NVARCHAR(n)       VARCHAR(n) utf8mb4    textos con tildes y ñ (la N = Unicode)
--   VARCHAR(n)+CHECK  ENUM(...)             listas cerradas (SQL Server no tiene ENUM)
--   CHAR(n)           CHAR(n)               longitud fija: DNI, serie, ObjectId de MongoDB
--   DECIMAL(p,s)      DECIMAL(p,s)          dinero
--   DATE              DATE                  fechas
--   DATETIME2(0)      DATETIME              fecha y hora
--   SYSDATETIME()     CURRENT_TIMESTAMP     fecha y hora actual
--   GETDATE()         NOW() / CURDATE()     hoy
--   Modern_Spanish_CI_AS  utf8mb4_spanish_ci  orden alfabético en español, sin
--                                             distinguir mayúsculas (CI)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. CREAR LA BASE DE DATOS
-- ---------------------------------------------------------------------
USE master;  -- Se trabaja desde la base del sistema, porque no se puede borrar la base en la que estás parado.
GO           -- Envía el lote.
IF DB_ID(N'magallanes_montero') IS NOT NULL  -- DB_ID devuelve el id de la base si existe (NULL si no existe).
BEGIN                                       -- Si existe:
    ALTER DATABASE magallanes_montero SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  -- Desconecta a cualquier usuario (incluida otra pestaña de SSMS).
    DROP DATABASE magallanes_montero;                     -- La borra para crearla limpia (permite ejecutar el script varias veces).
END
GO
CREATE DATABASE magallanes_montero COLLATE Modern_Spanish_CI_AS;  -- Crea la base con intercalación en español.
GO
USE magallanes_montero;  -- Desde aquí, todas las tablas se crean dentro de esta base.
GO

-- ---------------------------------------------------------------------
-- 1. TABLAS MAESTRAS Y CATÁLOGOS
-- ---------------------------------------------------------------------

-- ===== TABLA PERSONA =====
-- Qué guarda : Cliente, prospecto, contraparte o representante legal (natural, jurídica o entidad pública).
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.persona (  -- Crea la tabla persona en el esquema dbo (el esquema por defecto de SQL Server).
  id_persona INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio; Identificador
  tipo_persona VARCHAR(8) NOT NULL,  -- VARCHAR(8) + CHECK: solo acepta NATURAL, JURIDICA, PUBLICA; obligatorio; Tipo de cliente
  tipo_documento VARCHAR(9) NULL,  -- VARCHAR(9) + CHECK: DNI, CE, PASAPORTE o RUC; opcional SOLO para contrapartes sin documento (un cliente debe tenerlo: triggers 9 y 10)
  nro_documento NVARCHAR(15) NULL,  -- DNI 8 dígitos / RUC 11; opcional SOLO para contrapartes (va junto con tipo_documento)
  nombres NVARCHAR(80) NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; opcional; Solo persona natural
  apellidos NVARCHAR(80) NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; opcional; Solo persona natural
  razon_social NVARCHAR(150) NULL,  -- texto Unicode (tildes, ñ) de hasta 150 caracteres; opcional; Jurídica o entidad pública
  fecha_nacimiento DATE NULL,  -- fecha (año-mes-día); opcional
  estado_civil VARCHAR(11) NULL,  -- VARCHAR(11) + CHECK: solo acepta SOLTERO, CASADO, CONVIVIENTE, DIVORCIADO…; opcional
  ocupacion NVARCHAR(80) NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; opcional
  telefono NVARCHAR(20) NULL,  -- texto Unicode (tildes, ñ) de hasta 20 caracteres; opcional; WhatsApp
  email NVARCHAR(120) NULL,  -- texto Unicode (tildes, ñ) de hasta 120 caracteres; opcional
  direccion NVARCHAR(200) NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; opcional; Domicilio real o fiscal
  acepta_tratamiento_datos BIT NOT NULL CONSTRAINT df_persona_acepta_tratamiento_datos DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0; Ley 29733
  id_representante INT NULL,  -- FK → persona(id_persona): solo acepta valores que existan allí; número entero; opcional; Representante legal (R03)
  fecha_registro DATETIME2(0) NOT NULL CONSTRAINT df_persona_fecha_registro DEFAULT SYSDATETIME(),  -- fecha y hora (sin fracciones de segundo); obligatorio; si no se envía vale SYSDATETIME()
  CONSTRAINT pk_persona PRIMARY KEY (id_persona),  -- Llave primaria: id_persona identifica cada fila.
  CONSTRAINT ck_persona_tipo_persona CHECK (tipo_persona IN ('NATURAL', 'JURIDICA', 'PUBLICA')),  -- Reemplaza al ENUM de MySQL: tipo_persona solo acepta los valores de la lista.
  CONSTRAINT ck_persona_tipo_documento CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE', 'RUC')),  -- Reemplaza al ENUM de MySQL: tipo_documento solo acepta los valores de la lista.
  CONSTRAINT ck_persona_estado_civil CHECK (estado_civil IN ('SOLTERO', 'CASADO', 'CONVIVIENTE', 'DIVORCIADO', 'VIUDO')),  -- Reemplaza al ENUM de MySQL: estado_civil solo acepta los valores de la lista.
  CONSTRAINT ck_persona_1 CHECK ((tipo_persona = 'NATURAL' AND nombres IS NOT NULL AND apellidos IS NOT NULL) OR (tipo_persona <> 'NATURAL' AND razon_social IS NOT NULL AND (tipo_documento = 'RUC' OR tipo_documento IS NULL))),  -- Regla: natural → nombres y apellidos; empresa o entidad → razón social y, si tiene documento, RUC.
  CONSTRAINT ck_persona_documento CHECK ((tipo_documento IS NULL AND nro_documento IS NULL) OR (tipo_documento IS NOT NULL AND nro_documento IS NOT NULL)),  -- Regla: tipo y número de documento van juntos (los dos o ninguno).
  CONSTRAINT fk_persona_id_representante FOREIGN KEY (id_representante) REFERENCES dbo.persona(id_persona)  -- FK: id_representante debe existir en persona.id_persona (relación recursiva con la misma tabla).
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA EMPLEADO =====
-- Qué guarda : Personal del estudio: abogado, secretaria, practicante, administrador. Los abogados además tienen una fila en ABOGADO (ahí está su colegiatura).
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.empleado (  -- Crea la tabla empleado en el esquema dbo (el esquema por defecto de SQL Server).
  id_empleado INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  dni CHAR(8) NOT NULL,  -- texto de longitud fija (8 caracteres); obligatorio; no se puede repetir
  nombres NVARCHAR(80) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; obligatorio
  apellidos NVARCHAR(80) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; obligatorio
  cargo VARCHAR(13) NOT NULL,  -- VARCHAR(13) + CHECK: solo acepta ABOGADO, SECRETARIA, PRACTICANTE, ADMINISTRADOR; obligatorio; Carril del BPMN
  telefono NVARCHAR(20) NULL,  -- texto Unicode (tildes, ñ) de hasta 20 caracteres; opcional
  email NVARCHAR(120) NOT NULL,  -- Correo de trabajo; no se puede repetir (el login está en USUARIO)
  activo BIT NOT NULL CONSTRAINT df_empleado_activo DEFAULT 1,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 1
  CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),  -- Llave primaria: id_empleado identifica cada fila.
  CONSTRAINT uq_empleado_dni UNIQUE (dni),  -- UNIQUE: no pueden existir dos filas con el mismo dni.
  CONSTRAINT uq_empleado_email UNIQUE (email),  -- UNIQUE: no pueden existir dos filas con el mismo email.
  CONSTRAINT ck_empleado_cargo CHECK (cargo IN ('ABOGADO', 'SECRETARIA', 'PRACTICANTE', 'ADMINISTRADOR'))  -- Reemplaza al ENUM de MySQL: cargo solo acepta los valores de la lista.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ABOGADO =====
-- Qué guarda : Especialización 1:1 de EMPLEADO: solo los empleados con cargo ABOGADO. Aquí vive el número de colegiatura (CAL).
-- Proceso    : Tabla maestra (la usan los 3 procesos)
-- Se enlaza con: empleado
-- Por qué existe: cita, propuesta, liquidación, audiencia y el abogado responsable del caso apuntan a ABOGADO y no a EMPLEADO,
--                 así un practicante o una secretaria no pueden figurar como abogados. La colegiatura es obligatoria aquí y no
--                 queda como columna vacía en EMPLEADO.
CREATE TABLE dbo.abogado (  -- Crea la tabla abogado en el esquema dbo (el esquema por defecto de SQL Server).
  id_empleado INT NOT NULL,  -- parte de la PK y FK → empleado(id_empleado); número entero; obligatorio; Misma llave que el empleado (1:1)
  nro_colegiatura NVARCHAR(15) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 15 caracteres; obligatorio; no se puede repetir; Colegiatura CAL
  CONSTRAINT pk_abogado PRIMARY KEY (id_empleado),  -- Llave primaria: id_empleado identifica cada fila (es a la vez la FK hacia empleado).
  CONSTRAINT uq_abogado_nro_colegiatura UNIQUE (nro_colegiatura),  -- UNIQUE: dos abogados no pueden tener la misma colegiatura (aquí no hay NULL, así que basta un UNIQUE normal).
  CONSTRAINT fk_abogado_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- FK: id_empleado debe existir en empleado.id_empleado (el trigger trg_abogado_cargo exige además cargo = ABOGADO).
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.


-- ===== TABLA USUARIO =====  (NUEVA en la versión de 36 tablas)
-- Qué guarda : Las cuentas de acceso: el panel del estudio (un EMPLEADO) o el portal del cliente (una PERSONA).
-- Proceso    : Tabla maestra (inicio de sesión de los 3 procesos y del portal del cliente)
-- Se enlaza con: empleado, persona
-- Por qué así : el rol NO se guarda aquí; sale de empleado.cargo (panel) o de que sea una persona (portal).
--               Guardarlo otra vez sería un dato repetido (3FN). La contraseña nunca se guarda: solo su hash.
CREATE TABLE dbo.usuario (  -- Crea la tabla usuario.
  id_usuario INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1); obligatorio
  id_empleado INT NULL,  -- FK → empleado(id_empleado): cuenta del panel administrativo; opcional (único si existe)
  id_persona INT NULL,  -- FK → persona(id_persona): cuenta del portal del cliente; opcional (único si existe)
  email NVARCHAR(120) NOT NULL,  -- Correo con el que inicia sesión; obligatorio; no se puede repetir
  contrasena_hash VARCHAR(100) NOT NULL,  -- Hash (bcrypt) que genera la aplicación; nunca la contraseña en texto
  activo BIT NOT NULL CONSTRAINT df_usuario_activo DEFAULT 1,  -- 1 = puede ingresar; 0 = cuenta bloqueada
  ultimo_acceso DATETIME2(0) NULL,  -- Último inicio de sesión; opcional
  fecha_creacion DATETIME2(0) NOT NULL CONSTRAINT df_usuario_fecha_creacion DEFAULT SYSDATETIME(),  -- si no se envía vale SYSDATETIME()
  CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),  -- Llave primaria.
  CONSTRAINT uq_usuario_email UNIQUE (email),  -- UNIQUE: dos cuentas no pueden usar el mismo correo.
  CONSTRAINT ck_usuario_tipo CHECK ((id_empleado IS NOT NULL AND id_persona IS NULL) OR (id_empleado IS NULL AND id_persona IS NOT NULL)),  -- Regla: la cuenta es de un empleado O de un cliente, nunca de ambos ni de ninguno.
  CONSTRAINT fk_usuario_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado),  -- FK: el empleado debe existir.
  CONSTRAINT fk_usuario_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona)  -- FK: la persona (cliente) debe existir.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA MATERIA =====
-- Qué guarda : Rama del derecho: civil, penal, laboral, familia, etc.
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.materia (  -- Crea la tabla materia en el esquema dbo (el esquema por defecto de SQL Server).
  id_materia SMALLINT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  nombre NVARCHAR(60) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 60 caracteres; obligatorio; no se puede repetir; Civil, Penal, Laboral…
  descripcion NVARCHAR(200) NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; opcional
  CONSTRAINT pk_materia PRIMARY KEY (id_materia),  -- Llave primaria: id_materia identifica cada fila.
  CONSTRAINT uq_materia_nombre UNIQUE (nombre)  -- UNIQUE: no pueden existir dos filas con el mismo nombre.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ROL_PROCESAL =====
-- Qué guarda : Catálogo de los 24 roles (demandante, imputado, administrado…) agrupados por familia.
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.rol_procesal (  -- Crea la tabla rol_procesal en el esquema dbo (el esquema por defecto de SQL Server).
  id_rol SMALLINT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  nombre NVARCHAR(60) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 60 caracteres; obligatorio; no se puede repetir; Demandante, Imputado…
  familia VARCHAR(22) NOT NULL,  -- VARCHAR(22) + CHECK: solo acepta CIVIL_ACTIVA, CIVIL_PASIVA, PENAL_ACUSA, PENAL_INVESTIGADA…; obligatorio; 8 ramas del P2
  CONSTRAINT pk_rol_procesal PRIMARY KEY (id_rol),  -- Llave primaria: id_rol identifica cada fila.
  CONSTRAINT uq_rol_procesal_nombre UNIQUE (nombre),  -- UNIQUE: no pueden existir dos filas con el mismo nombre.
  CONSTRAINT ck_rol_procesal_familia CHECK (familia IN ('CIVIL_ACTIVA', 'CIVIL_PASIVA', 'PENAL_ACUSA', 'PENAL_INVESTIGADA', 'VIOLENCIA_30364', 'ADMINISTRATIVO', 'CONCILIACION_ARBITRAJE', 'TRAMITE'))  -- Reemplaza al ENUM de MySQL: familia solo acepta los valores de la lista.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ETAPA_PROCESAL =====
-- Qué guarda : Catálogo de etapas: consulta inicial, primera instancia, apelación, ejecución, cerrado…
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.etapa_procesal (  -- Crea la tabla etapa_procesal en el esquema dbo (el esquema por defecto de SQL Server).
  id_etapa SMALLINT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  nombre NVARCHAR(60) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 60 caracteres; obligatorio; no se puede repetir
  orden TINYINT NOT NULL,  -- entero pequeño 0 a 255; obligatorio; Secuencia sugerida
  CONSTRAINT pk_etapa_procesal PRIMARY KEY (id_etapa),  -- Llave primaria: id_etapa identifica cada fila.
  CONSTRAINT uq_etapa_procesal_nombre UNIQUE (nombre)  -- UNIQUE: no pueden existir dos filas con el mismo nombre.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ENTIDAD =====
-- Qué guarda : Juzgado, fiscalía, entidad administrativa o centro de conciliación/arbitraje.
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.entidad (  -- Crea la tabla entidad en el esquema dbo (el esquema por defecto de SQL Server).
  id_entidad INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  nombre NVARCHAR(150) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 150 caracteres; obligatorio
  tipo_entidad VARCHAR(19) NOT NULL,  -- VARCHAR(19) + CHECK: solo acepta JUZGADO, SALA, FISCALIA, ADMINISTRATIVA…; obligatorio
  distrito_judicial NVARCHAR(60) NULL,  -- texto Unicode (tildes, ñ) de hasta 60 caracteres; opcional
  direccion NVARCHAR(200) NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; opcional
  CONSTRAINT pk_entidad PRIMARY KEY (id_entidad),  -- Llave primaria: id_entidad identifica cada fila.
  CONSTRAINT ck_entidad_tipo_entidad CHECK (tipo_entidad IN ('JUZGADO', 'SALA', 'FISCALIA', 'ADMINISTRATIVA', 'CENTRO_CONCILIACION', 'TRIBUNAL_ARBITRAL', 'REGISTRAL_NOTARIAL'))  -- Reemplaza al ENUM de MySQL: tipo_entidad solo acepta los valores de la lista.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA JURISPRUDENCIA =====
-- Qué guarda : Leyes, casaciones y precedentes que se citan en los escritos.
-- Proceso    : Tabla maestra (la usan los 3 procesos)
-- Se enlaza con: materia
CREATE TABLE dbo.jurisprudencia (  -- Crea la tabla jurisprudencia en el esquema dbo (el esquema por defecto de SQL Server).
  id_jurisprudencia INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_materia SMALLINT NOT NULL,  -- FK → materia(id_materia): solo acepta valores que existan allí; entero hasta 32 767; obligatorio; R23
  tipo VARCHAR(10) NOT NULL,  -- VARCHAR(10) + CHECK: solo acepta LEY, CASACION, PRECEDENTE, PLENO…; obligatorio
  referencia NVARCHAR(80) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 80 caracteres; obligatorio; no se puede repetir; Ej.: Cas. 1234-2019-Lima
  titulo NVARCHAR(200) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; obligatorio
  fecha_publicacion DATE NULL,  -- fecha (año-mes-día); opcional
  url_fuente NVARCHAR(300) NULL,  -- texto Unicode (tildes, ñ) de hasta 300 caracteres; opcional
  CONSTRAINT pk_jurisprudencia PRIMARY KEY (id_jurisprudencia),  -- Llave primaria: id_jurisprudencia identifica cada fila.
  CONSTRAINT uq_jurisprudencia_referencia UNIQUE (referencia),  -- UNIQUE: no pueden existir dos filas con el mismo referencia.
  CONSTRAINT ck_jurisprudencia_tipo CHECK (tipo IN ('LEY', 'CASACION', 'PRECEDENTE', 'PLENO', 'DOCTRINA')),  -- Reemplaza al ENUM de MySQL: tipo solo acepta los valores de la lista.
  CONSTRAINT fk_jurisprudencia_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia)  -- FK: id_materia debe existir en materia.id_materia.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA FERIADO =====
-- Qué guarda : Feriados y días no laborables. Sirven para calcular el vencimiento de los plazos hábiles (PLAZO.tipo_computo = HABIL).
-- Proceso    : Tabla maestra (la usan los 3 procesos)
CREATE TABLE dbo.feriado (  -- Crea la tabla feriado en el esquema dbo (el esquema por defecto de SQL Server).
  fecha DATE NOT NULL,  -- PK; fecha (año-mes-día); obligatorio; Día feriado o no laborable
  descripcion NVARCHAR(100) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 100 caracteres; obligatorio; Ej.: Fiestas Patrias
  CONSTRAINT pk_feriado PRIMARY KEY (fecha)  -- Llave primaria: fecha identifica cada fila (un feriado por día).
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ---------------------------------------------------------------------
-- 2. PROCESO 1 · CAPTACIÓN, CONSULTA Y APERTURA
-- ---------------------------------------------------------------------

-- ===== TABLA CONSULTA =====
-- Qué guarda : Solicitud de asesoría que llega por WhatsApp, redes, landing o llamada.
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: empleado, materia, persona
CREATE TABLE dbo.consulta (  -- Crea la tabla consulta en el esquema dbo (el esquema por defecto de SQL Server).
  id_consulta INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_persona INT NOT NULL,  -- FK → persona(id_persona): solo acepta valores que existan allí; número entero; obligatorio; Quien consulta (R01)
  id_materia SMALLINT NOT NULL,  -- FK → materia(id_materia): solo acepta valores que existan allí; entero hasta 32 767; obligatorio; R05
  id_registrado_por INT NULL,  -- FK → empleado: quién la registró (secretaria); NULL si llegó sola por la landing (R04)
  canal VARCHAR(10) NOT NULL,  -- VARCHAR(10) + CHECK: solo acepta WHATSAPP, FACEBOOK, INSTAGRAM, LANDING…; obligatorio
  fecha_hora_recepcion DATETIME2(0) NOT NULL CONSTRAINT df_consulta_fecha_hora_recepcion DEFAULT SYSDATETIME(),  -- fecha y hora (sin fracciones de segundo); obligatorio; si no se envía vale SYSDATETIME()
  resumen NVARCHAR(500) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 500 caracteres; obligatorio; Tema de la consulta
  es_urgente BIT NOT NULL CONSTRAINT df_consulta_es_urgente DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  existe_conflicto BIT NULL,  -- sí/no (1 = sí, 0 = no); opcional; NULL = aún no revisado
  id_revisor_conflicto INT NULL,  -- FK → abogado: el abogado que revisó el conflicto de intereses; opcional
  fecha_revision_conflicto DATETIME2(0) NULL,  -- fecha y hora (sin fracciones de segundo); opcional; Cuándo se revisó
  detalle_conflicto NVARCHAR(500) NULL,  -- texto Unicode (tildes, ñ) de hasta 500 caracteres; opcional; Qué se encontró (obligatorio si existe conflicto)
  monto_consulta DECIMAL(10,2) NOT NULL CONSTRAINT df_consulta_monto_consulta DEFAULT 0.00,  -- número exacto con 2 decimales (hasta 8 enteros); ideal para dinero; obligatorio; si no se envía vale 0.00; Costo informado
  estado VARCHAR(13) NOT NULL CONSTRAINT df_consulta_estado DEFAULT 'RECIBIDA',  -- VARCHAR(13) + CHECK: solo acepta RECIBIDA, NO_ATENDIDA, AGENDADA, ATENDIDA…; obligatorio; si no se envía vale 'RECIBIDA'
  CONSTRAINT pk_consulta PRIMARY KEY (id_consulta),  -- Llave primaria: id_consulta identifica cada fila.
  CONSTRAINT ck_consulta_canal CHECK (canal IN ('WHATSAPP', 'FACEBOOK', 'INSTAGRAM', 'LANDING', 'LLAMADA', 'PRESENCIAL')),  -- Reemplaza al ENUM de MySQL: canal solo acepta los valores de la lista.
  CONSTRAINT ck_consulta_estado CHECK (estado IN ('RECIBIDA', 'NO_ATENDIDA', 'AGENDADA', 'ATENDIDA', 'CON_CONFLICTO', 'PROPUESTA', 'CONTRATADA', 'RECHAZADA', 'ARCHIVADA')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT ck_consulta_conflicto_revision CHECK (existe_conflicto IS NULL OR (id_revisor_conflicto IS NOT NULL AND fecha_revision_conflicto IS NOT NULL)),  -- Regla: si ya se revisó el conflicto (0 o 1), debe constar quién y cuándo.
  CONSTRAINT ck_consulta_conflicto_detalle CHECK (existe_conflicto IS NULL OR existe_conflicto = 0 OR detalle_conflicto IS NOT NULL),  -- Regla: si existe conflicto, debe describirse.
  CONSTRAINT fk_consulta_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),  -- FK: id_persona debe existir en persona.id_persona.
  CONSTRAINT fk_consulta_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia),  -- FK: id_materia debe existir en materia.id_materia.
  CONSTRAINT ck_consulta_registro CHECK (canal = 'LANDING' OR id_registrado_por IS NOT NULL),  -- Regla: si no llegó por la landing, alguien del estudio la registró.
  CONSTRAINT fk_consulta_id_registrado_por FOREIGN KEY (id_registrado_por) REFERENCES dbo.empleado(id_empleado),  -- FK: quien registra debe existir en empleado.
  CONSTRAINT fk_consulta_id_revisor_conflicto FOREIGN KEY (id_revisor_conflicto) REFERENCES dbo.abogado(id_empleado)  -- FK a ABOGADO: solo un abogado revisa conflictos.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CONSULTA_CONTRAPARTE =====
-- Qué guarda : Tabla intermedia: resuelve la relación M:N «una consulta menciona varias contrapartes y una persona puede ser contraparte en varias consultas».
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: consulta, persona
CREATE TABLE dbo.consulta_contraparte (  -- Crea la tabla consulta_contraparte en el esquema dbo (el esquema por defecto de SQL Server).
  id_consulta INT NOT NULL,  -- parte de la PK y FK → consulta(id_consulta); número entero; obligatorio
  id_persona INT NOT NULL,  -- parte de la PK y FK → persona(id_persona); número entero; obligatorio; Contraparte mencionada
  CONSTRAINT pk_consulta_contraparte PRIMARY KEY (id_consulta, id_persona),  -- Llave primaria compuesta: la combinación (id_consulta, id_persona) no se puede repetir.
  CONSTRAINT fk_consulta_contraparte_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),  -- FK: id_consulta debe existir en consulta.id_consulta.
  CONSTRAINT fk_consulta_contraparte_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona)  -- FK: id_persona debe existir en persona.id_persona.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CITA =====
-- Qué guarda : Reunión agendada para atender la consulta (incluye reprogramaciones).
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: consulta, abogado
CREATE TABLE dbo.cita (  -- Crea la tabla cita en el esquema dbo (el esquema por defecto de SQL Server).
  id_cita INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_consulta INT NOT NULL,  -- FK → consulta(id_consulta): solo acepta valores que existan allí; número entero; obligatorio; R06
  id_abogado INT NOT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R07
  fecha_hora DATETIME2(0) NOT NULL,  -- fecha y hora (sin fracciones de segundo); obligatorio
  modalidad VARCHAR(10) NOT NULL CONSTRAINT df_cita_modalidad DEFAULT 'PRESENCIAL',  -- VARCHAR(10) + CHECK: solo acepta PRESENCIAL, VIRTUAL; obligatorio; si no se envía vale 'PRESENCIAL'
  recordatorio_enviado BIT NOT NULL CONSTRAINT df_cita_recordatorio_enviado DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0; Recordatorio 1 día antes
  estado VARCHAR(12) NOT NULL CONSTRAINT df_cita_estado DEFAULT 'PROGRAMADA',  -- VARCHAR(12) + CHECK: solo acepta PROGRAMADA, CONFIRMADA, REPROGRAMADA, CANCELADA…; obligatorio; si no se envía vale 'PROGRAMADA'
  CONSTRAINT pk_cita PRIMARY KEY (id_cita),  -- Llave primaria: id_cita identifica cada fila.
  CONSTRAINT ck_cita_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL')),  -- Reemplaza al ENUM de MySQL: modalidad solo acepta los valores de la lista.
  CONSTRAINT ck_cita_estado CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'REPROGRAMADA', 'CANCELADA', 'ASISTIO', 'NO_ASISTIO')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT fk_cita_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),  -- FK: id_consulta debe existir en consulta.id_consulta.
  CONSTRAINT fk_cita_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)  -- FK: id_abogado debe existir en abogado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA PROPUESTA =====
-- Qué guarda : Propuesta de honorarios; puede tener varias versiones por negociación.
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: consulta, abogado
CREATE TABLE dbo.propuesta (  -- Crea la tabla propuesta en el esquema dbo (el esquema por defecto de SQL Server).
  id_propuesta INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_consulta INT NOT NULL,  -- FK → consulta(id_consulta): solo acepta valores que existan allí; número entero; obligatorio; R08
  id_abogado INT NOT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R09
  version TINYINT NOT NULL CONSTRAINT df_propuesta_version DEFAULT 1,  -- entero pequeño 0 a 255; obligatorio; si no se envía vale 1; Negociación
  monto_honorarios DECIMAL(12,2) NOT NULL,  -- número exacto con 2 decimales (hasta 10 enteros); ideal para dinero; obligatorio; 0 si es pro bono
  porcentaje_cuota_litis DECIMAL(5,2) NOT NULL CONSTRAINT df_propuesta_porcentaje_cuota_litis DEFAULT 0.00,  -- número exacto con 2 decimales (hasta 3 enteros); ideal para dinero; obligatorio; si no se envía vale 0.00; Honorario de éxito
  nro_cuotas TINYINT NOT NULL CONSTRAINT df_propuesta_nro_cuotas DEFAULT 1,  -- entero pequeño 0 a 255; obligatorio; si no se envía vale 1
  fecha_envio DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  fecha_respuesta DATE NULL,  -- fecha (año-mes-día); opcional
  estado VARCHAR(14) NOT NULL CONSTRAINT df_propuesta_estado DEFAULT 'ENVIADA',  -- VARCHAR(14) + CHECK: solo acepta ENVIADA, EN_NEGOCIACION, ACEPTADA, RECHAZADA…; obligatorio; si no se envía vale 'ENVIADA'
  CONSTRAINT pk_propuesta PRIMARY KEY (id_propuesta),  -- Llave primaria: id_propuesta identifica cada fila.
  CONSTRAINT uq_propuesta_version UNIQUE (id_consulta, version),  -- No pueden existir dos filas con la misma combinación (id_consulta, version).
  CONSTRAINT ck_propuesta_estado CHECK (estado IN ('ENVIADA', 'EN_NEGOCIACION', 'ACEPTADA', 'RECHAZADA', 'SIN_RESPUESTA')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT ck_propuesta_1 CHECK (porcentaje_cuota_litis BETWEEN 0 AND 100),  -- Regla: El porcentaje de cuota litis va de 0 a 100.
  CONSTRAINT ck_propuesta_2 CHECK (monto_honorarios >= 0),  -- Regla: Los honorarios no pueden ser negativos (0 = pro bono).
  CONSTRAINT fk_propuesta_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),  -- FK: id_consulta debe existir en consulta.id_consulta.
  CONSTRAINT fk_propuesta_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)  -- FK: id_abogado debe existir en abogado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CONTRATO =====
-- Qué guarda : Contrato de servicios firmado a partir de la propuesta aceptada.
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: propuesta, persona
CREATE TABLE dbo.contrato (  -- Crea la tabla contrato en el esquema dbo (el esquema por defecto de SQL Server).
  id_contrato INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_propuesta INT NOT NULL,  -- FK → propuesta(id_propuesta): solo acepta valores que existan allí; número entero; obligatorio; no se puede repetir; R10 (1:1)
  id_cliente INT NOT NULL,  -- FK → persona(id_persona): solo acepta valores que existan allí; número entero; obligatorio; Quién contrata: el cliente del caso (puede no ser quien hizo la consulta)
  nro_contrato NVARCHAR(20) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 20 caracteres; obligatorio; no se puede repetir
  fecha_firma DATE NULL,  -- fecha (año-mes-día); NULL = pendiente de firma del cliente en el portal
  modalidad_firma VARCHAR(10) NULL,  -- DIGITAL (firma en el portal) o PRESENCIAL (firma en el estudio); NULL mientras está pendiente
  tipo_encargo VARCHAR(14) NOT NULL,  -- VARCHAR(14) + CHECK: solo acepta PATROCINIO, REPRESENTACION, TRAMITE, PRO_BONO; obligatorio
  modalidad_pago VARCHAR(14) NOT NULL,  -- VARCHAR(14) + CHECK: solo acepta UNICO, CUOTAS, IGUALA_MENSUAL; obligatorio
  con_carta_poder BIT NOT NULL CONSTRAINT df_contrato_con_carta_poder DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  archivo_mongo_id CHAR(24) NULL,  -- texto fijo de 24 caracteres: ObjectId del documento en MongoDB; opcional; PDF firmado en MongoDB
  CONSTRAINT pk_contrato PRIMARY KEY (id_contrato),  -- Llave primaria: id_contrato identifica cada fila.
  CONSTRAINT uq_contrato_id_propuesta UNIQUE (id_propuesta),  -- UNIQUE: no pueden existir dos filas con el mismo id_propuesta.
  CONSTRAINT uq_contrato_nro_contrato UNIQUE (nro_contrato),  -- UNIQUE: no pueden existir dos filas con el mismo nro_contrato.
  CONSTRAINT ck_contrato_tipo_encargo CHECK (tipo_encargo IN ('PATROCINIO', 'REPRESENTACION', 'TRAMITE', 'PRO_BONO')),  -- Reemplaza al ENUM de MySQL: tipo_encargo solo acepta los valores de la lista.
  CONSTRAINT ck_contrato_modalidad_pago CHECK (modalidad_pago IN ('UNICO', 'CUOTAS', 'IGUALA_MENSUAL')),  -- Reemplaza al ENUM de MySQL: modalidad_pago solo acepta los valores de la lista.
  CONSTRAINT ck_contrato_modalidad_firma CHECK (modalidad_firma IS NULL OR modalidad_firma IN ('DIGITAL', 'PRESENCIAL')),  -- Firma en el portal o en el estudio.
  CONSTRAINT ck_contrato_firma_completa CHECK ((fecha_firma IS NULL AND modalidad_firma IS NULL) OR (fecha_firma IS NOT NULL AND modalidad_firma IS NOT NULL)),  -- Regla: firmado = fecha + modalidad; pendiente = ambos NULL.
  CONSTRAINT fk_contrato_id_propuesta FOREIGN KEY (id_propuesta) REFERENCES dbo.propuesta(id_propuesta),  -- FK: id_propuesta debe existir en propuesta.id_propuesta.
  CONSTRAINT fk_contrato_id_cliente FOREIGN KEY (id_cliente) REFERENCES dbo.persona(id_persona)  -- FK: id_cliente debe existir en persona.id_persona.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CUOTA =====
-- Qué guarda : Cronograma de cobro: adelanto, cuotas, saldo o cuota litis.
-- Proceso    : Proceso 1 · Captación, Consulta y Apertura
-- Se enlaza con: contrato, liquidacion
CREATE TABLE dbo.cuota (  -- Crea la tabla cuota en el esquema dbo (el esquema por defecto de SQL Server).
  id_cuota INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_contrato INT NOT NULL,  -- FK → contrato(id_contrato): solo acepta valores que existan allí; número entero; obligatorio; R11
  id_liquidacion INT NULL,  -- FK → liquidacion(id_liquidacion): solo acepta valores que existan allí; número entero; opcional; R37 (solo saldo / cuota litis)
  nro_cuota TINYINT NOT NULL,  -- entero pequeño 0 a 255; obligatorio
  concepto VARCHAR(11) NOT NULL,  -- VARCHAR(11) + CHECK: solo acepta ADELANTO, CUOTA, IGUALA, SALDO…; obligatorio
  monto DECIMAL(12,2) NOT NULL,  -- número exacto con 2 decimales (hasta 10 enteros); ideal para dinero; obligatorio
  fecha_vencimiento DATE NOT NULL,  -- fecha (año-mes-día); obligatorio; Dispara el recordatorio
  estado VARCHAR(14) NOT NULL CONSTRAINT df_cuota_estado DEFAULT 'PENDIENTE',  -- VARCHAR(14) + CHECK: solo acepta PENDIENTE, PAGADA_PARCIAL, PAGADA, FRACCIONADA; obligatorio; si no se envía vale 'PENDIENTE'; «Vencida» no se guarda: la calcula la vista vw_cuota_estado
  CONSTRAINT pk_cuota PRIMARY KEY (id_cuota),  -- Llave primaria: id_cuota identifica cada fila.
  CONSTRAINT uq_cuota_nro UNIQUE (id_contrato, nro_cuota),  -- No pueden existir dos filas con la misma combinación (id_contrato, nro_cuota).
  CONSTRAINT ck_cuota_concepto CHECK (concepto IN ('ADELANTO', 'CUOTA', 'IGUALA', 'SALDO', 'CUOTA_LITIS')),  -- Reemplaza al ENUM de MySQL: concepto solo acepta los valores de la lista.
  CONSTRAINT ck_cuota_estado CHECK (estado IN ('PENDIENTE', 'PAGADA_PARCIAL', 'PAGADA', 'FRACCIONADA')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista (VENCIDA se calcula con la fecha, no se guarda).
  CONSTRAINT ck_cuota_1 CHECK (monto > 0),  -- Regla: Toda cuota debe ser mayor a cero.
  CONSTRAINT fk_cuota_id_contrato FOREIGN KEY (id_contrato) REFERENCES dbo.contrato(id_contrato)  -- FK: id_contrato debe existir en contrato.id_contrato.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.
-- ---------------------------------------------------------------------
-- 3. PROCESO 2 · GESTIÓN DEL EXPEDIENTE
-- ---------------------------------------------------------------------

-- ===== TABLA CASO =====
-- Qué guarda : Expediente del cliente (interno y judicial).
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: contrato, abogado, materia
CREATE TABLE dbo.caso (  -- Crea la tabla caso en el esquema dbo (el esquema por defecto de SQL Server).
  id_caso INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_contrato INT NOT NULL,  -- FK → contrato(id_contrato): solo acepta valores que existan allí; número entero; obligatorio; no se puede repetir; R12 (1:1)
  id_materia SMALLINT NOT NULL,  -- FK → materia(id_materia): solo acepta valores que existan allí; entero hasta 32 767; obligatorio; R13
  id_abogado_responsable INT NOT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R14
  codigo_interno NVARCHAR(20) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 20 caracteres; obligatorio; no se puede repetir; Ej.: EXP-2026-0001
  nro_expediente_judicial NVARCHAR(40) NULL,  -- texto Unicode (tildes, ñ) de hasta 40 caracteres; opcional; Nro. de expediente o carpeta fiscal
  descripcion NVARCHAR(500) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 500 caracteres; obligatorio
  es_alta_complejidad BIT NOT NULL CONSTRAINT df_caso_es_alta_complejidad DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  estado VARCHAR(9) NOT NULL CONSTRAINT df_caso_estado DEFAULT 'ACTIVO',  -- VARCHAR(9) + CHECK: solo acepta ACTIVO, EN_ESPERA, CERRADO, ARCHIVADO; obligatorio; si no se envía vale 'ACTIVO'
  fecha_apertura DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  fecha_cierre DATE NULL,  -- fecha (año-mes-día); opcional
  expediente_mongo_id CHAR(24) NULL,  -- texto fijo de 24 caracteres: ObjectId del documento en MongoDB; opcional; Expediente digital (NoSQL)
  CONSTRAINT pk_caso PRIMARY KEY (id_caso),  -- Llave primaria: id_caso identifica cada fila.
  CONSTRAINT uq_caso_id_contrato UNIQUE (id_contrato),  -- UNIQUE: no pueden existir dos filas con el mismo id_contrato.
  CONSTRAINT uq_caso_codigo_interno UNIQUE (codigo_interno),  -- UNIQUE: no pueden existir dos filas con el mismo codigo_interno.
  CONSTRAINT ck_caso_estado CHECK (estado IN ('ACTIVO', 'EN_ESPERA', 'CERRADO', 'ARCHIVADO')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT ck_caso_1 CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura),  -- Regla: La fecha de cierre no puede ser anterior a la de apertura.
  CONSTRAINT fk_caso_id_contrato FOREIGN KEY (id_contrato) REFERENCES dbo.contrato(id_contrato),  -- FK: id_contrato debe existir en contrato.id_contrato.
  CONSTRAINT fk_caso_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia),  -- FK: id_materia debe existir en materia.id_materia.
  CONSTRAINT fk_caso_id_abogado_responsable FOREIGN KEY (id_abogado_responsable) REFERENCES dbo.abogado(id_empleado)  -- FK: id_abogado_responsable debe existir en abogado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ABOGADO_MATERIA =====
-- Qué guarda : Tabla intermedia: resuelve la M:N «un abogado domina varias materias y una materia tiene varios abogados».
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: abogado, materia
CREATE TABLE dbo.abogado_materia (  -- Crea la tabla abogado_materia en el esquema dbo (el esquema por defecto de SQL Server).
  id_abogado INT NOT NULL,  -- parte de la PK y FK → abogado(id_empleado); número entero; obligatorio
  id_materia SMALLINT NOT NULL,  -- parte de la PK y FK → materia(id_materia); entero hasta 32 767; obligatorio
  es_principal BIT NOT NULL CONSTRAINT df_abogado_materia_es_principal DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  CONSTRAINT pk_abogado_materia PRIMARY KEY (id_abogado, id_materia),  -- Llave primaria compuesta: la combinación (id_abogado, id_materia) no se puede repetir.
  CONSTRAINT fk_abogado_materia_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado),  -- FK: id_abogado debe existir en abogado.id_empleado.
  CONSTRAINT fk_abogado_materia_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia)  -- FK: id_materia debe existir en materia.id_materia.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CASO_PARTE =====
-- Qué guarda : Tabla intermedia de la relación ternaria CASO–PERSONA–ROL: quién participa en cada caso y con qué rol.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, persona, rol_procesal
CREATE TABLE dbo.caso_parte (  -- Crea la tabla caso_parte en el esquema dbo (el esquema por defecto de SQL Server).
  id_caso INT NOT NULL,  -- parte de la PK y FK → caso(id_caso); número entero; obligatorio
  id_persona INT NOT NULL,  -- parte de la PK y FK → persona(id_persona); número entero; obligatorio
  id_rol SMALLINT NOT NULL,  -- parte de la PK y FK → rol_procesal(id_rol); entero hasta 32 767; obligatorio; Rol en este caso (una persona puede tener varios roles)
  tipo_parte VARCHAR(11) NOT NULL,  -- VARCHAR(11) + CHECK: solo acepta CLIENTE, CONTRAPARTE, TERCERO; obligatorio
  abogado_externo NVARCHAR(120) NULL,  -- texto Unicode (tildes, ñ) de hasta 120 caracteres; opcional; Abogado de la contraparte
  CONSTRAINT pk_caso_parte PRIMARY KEY (id_caso, id_persona, id_rol),  -- Llave primaria compuesta: la combinación (id_caso, id_persona, id_rol) no se puede repetir; la misma persona puede tener dos roles en un caso (p. ej. agraviado y actor civil).
  CONSTRAINT ck_caso_parte_tipo_parte CHECK (tipo_parte IN ('CLIENTE', 'CONTRAPARTE', 'TERCERO')),  -- Reemplaza al ENUM de MySQL: tipo_parte solo acepta los valores de la lista.
  CONSTRAINT fk_caso_parte_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_caso_parte_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),  -- FK: id_persona debe existir en persona.id_persona.
  CONSTRAINT fk_caso_parte_id_rol FOREIGN KEY (id_rol) REFERENCES dbo.rol_procesal(id_rol)  -- FK: id_rol debe existir en rol_procesal.id_rol.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA CASO_ETAPA =====
-- Qué guarda : Tabla intermedia: historial de etapas por las que pasa cada caso (con fecha de inicio y fin). Una etapa puede repetirse (subsanación, nueva audiencia); solo hay una etapa abierta por caso.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, etapa_procesal
CREATE TABLE dbo.caso_etapa (  -- Crea la tabla caso_etapa en el esquema dbo (el esquema por defecto de SQL Server).
  id_caso_etapa INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio
  id_etapa SMALLINT NOT NULL,  -- FK → etapa_procesal(id_etapa): solo acepta valores que existan allí; entero hasta 32 767; obligatorio
  fecha_inicio DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  fecha_fin DATE NULL,  -- fecha (año-mes-día); opcional; NULL = etapa actual
  CONSTRAINT pk_caso_etapa PRIMARY KEY (id_caso_etapa),  -- Llave primaria: id_caso_etapa identifica cada fila (así una etapa se puede repetir en el mismo caso).
  CONSTRAINT uq_caso_etapa_inicio UNIQUE (id_caso, id_etapa, fecha_inicio),  -- No pueden existir dos filas con la misma combinación (id_caso, id_etapa, fecha_inicio): se puede volver a una etapa, pero no registrarla dos veces el mismo día.
  CONSTRAINT ck_caso_etapa_1 CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),  -- Regla: Una etapa no puede terminar antes de empezar.
  CONSTRAINT fk_caso_etapa_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_caso_etapa_id_etapa FOREIGN KEY (id_etapa) REFERENCES dbo.etapa_procesal(id_etapa)  -- FK: id_etapa debe existir en etapa_procesal.id_etapa.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA DOCUMENTO_LEGAL =====
-- Qué guarda : Escrito elaborado por el estudio: demanda, contestación, recurso, subsanación…
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, empleado, abogado (y consigo misma)
CREATE TABLE dbo.documento_legal (  -- Crea la tabla documento_legal en el esquema dbo (el esquema por defecto de SQL Server).
  id_documento INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; R18
  id_redactor INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R19
  id_revisor INT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; opcional; R20
  id_documento_origen INT NULL,  -- FK → documento_legal(id_documento): solo acepta valores que existan allí; número entero; opcional; R22 (subsana a; debe ser del mismo caso)
  tipo_documento VARCHAR(14) NOT NULL,  -- VARCHAR(14) + CHECK: solo acepta DEMANDA, CONTESTACION, DENUNCIA, DESCARGO…; obligatorio
  titulo NVARCHAR(200) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; obligatorio; Sumilla
  version TINYINT NOT NULL CONSTRAINT df_documento_legal_version DEFAULT 1,  -- entero pequeño 0 a 255; obligatorio; si no se envía vale 1
  elaborado_con_ia BIT NOT NULL CONSTRAINT df_documento_legal_elaborado_con_ia DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0; Borrador con ChatGPT
  requiere_firma_cliente BIT NOT NULL CONSTRAINT df_documento_legal_requiere_firma_cliente DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  fecha_creacion DATETIME2(0) NOT NULL CONSTRAINT df_documento_legal_fecha_creacion DEFAULT SYSDATETIME(),  -- fecha y hora (sin fracciones de segundo); obligatorio; si no se envía vale SYSDATETIME()
  fecha_aprobacion DATETIME2(0) NULL,  -- fecha y hora (sin fracciones de segundo); opcional
  estado VARCHAR(11) NOT NULL CONSTRAINT df_documento_legal_estado DEFAULT 'BORRADOR',  -- VARCHAR(11) + CHECK: solo acepta BORRADOR, EN_REVISION, OBSERVADO, APROBADO…; obligatorio; si no se envía vale 'BORRADOR'
  archivo_mongo_id CHAR(24) NULL,  -- texto fijo de 24 caracteres: ObjectId del documento en MongoDB; opcional; Contenido del escrito (NoSQL)
  CONSTRAINT pk_documento_legal PRIMARY KEY (id_documento),  -- Llave primaria: id_documento identifica cada fila.
  CONSTRAINT uq_documento_legal_caso UNIQUE (id_caso, id_documento),  -- Permite la llave foránea compuesta de abajo: un escrito solo puede subsanar a otro del mismo caso.
  CONSTRAINT ck_documento_legal_tipo_documento CHECK (tipo_documento IN ('DEMANDA', 'CONTESTACION', 'DENUNCIA', 'DESCARGO', 'RECURSO', 'SUBSANACION', 'ABSOLUCION', 'SOLICITUD', 'ESCRITO_SIMPLE')),  -- Reemplaza al ENUM de MySQL: tipo_documento solo acepta los valores de la lista.
  CONSTRAINT ck_documento_legal_estado CHECK (estado IN ('BORRADOR', 'EN_REVISION', 'OBSERVADO', 'APROBADO', 'PRESENTADO')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT fk_documento_legal_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_documento_legal_id_redactor FOREIGN KEY (id_redactor) REFERENCES dbo.empleado(id_empleado),  -- FK: id_redactor debe existir en empleado.id_empleado.
  CONSTRAINT fk_documento_legal_id_revisor FOREIGN KEY (id_revisor) REFERENCES dbo.abogado(id_empleado),  -- FK: id_revisor debe existir en abogado.id_empleado.
  CONSTRAINT fk_documento_legal_id_documento_origen FOREIGN KEY (id_caso, id_documento_origen) REFERENCES dbo.documento_legal(id_caso, id_documento)  -- FK compuesta: el escrito de origen debe existir y ser del mismo caso (relación recursiva); si id_documento_origen es NULL no se valida.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA DOCUMENTO_JURISPRUDENCIA =====
-- Qué guarda : Tabla intermedia: qué leyes o casaciones cita cada escrito y para qué.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: documento_legal, jurisprudencia
CREATE TABLE dbo.documento_jurisprudencia (  -- Crea la tabla documento_jurisprudencia en el esquema dbo (el esquema por defecto de SQL Server).
  id_documento INT NOT NULL,  -- parte de la PK y FK → documento_legal(id_documento); número entero; obligatorio
  id_jurisprudencia INT NOT NULL,  -- parte de la PK y FK → jurisprudencia(id_jurisprudencia); número entero; obligatorio
  nota NVARCHAR(300) NULL,  -- texto Unicode (tildes, ñ) de hasta 300 caracteres; opcional; Para qué se cita
  CONSTRAINT pk_documento_jurisprudencia PRIMARY KEY (id_documento, id_jurisprudencia),  -- Llave primaria compuesta: la combinación (id_documento, id_jurisprudencia) no se puede repetir.
  CONSTRAINT fk_documento_jurisprudencia_id_documento FOREIGN KEY (id_documento) REFERENCES dbo.documento_legal(id_documento),  -- FK: id_documento debe existir en documento_legal.id_documento.
  CONSTRAINT fk_documento_jurisprudencia_id_jurisprudencia FOREIGN KEY (id_jurisprudencia) REFERENCES dbo.jurisprudencia(id_jurisprudencia)  -- FK: id_jurisprudencia debe existir en jurisprudencia.id_jurisprudencia.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA PRESENTACION =====
-- Qué guarda : Ingreso de un escrito ante una entidad (física o electrónica), con su cargo.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: documento_legal, empleado, entidad
CREATE TABLE dbo.presentacion (  -- Crea la tabla presentacion en el esquema dbo (el esquema por defecto de SQL Server).
  id_presentacion INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_documento INT NOT NULL,  -- FK → documento_legal(id_documento): solo acepta valores que existan allí; número entero; obligatorio; R24
  id_entidad INT NOT NULL,  -- FK → entidad(id_entidad): solo acepta valores que existan allí; número entero; obligatorio; R25
  id_empleado INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R26
  fecha_hora DATETIME2(0) NOT NULL,  -- fecha y hora (sin fracciones de segundo); obligatorio
  modalidad VARCHAR(11) NOT NULL,  -- VARCHAR(11) + CHECK: solo acepta FISICA, ELECTRONICA; obligatorio
  nro_cargo NVARCHAR(40) NULL,  -- texto Unicode (tildes, ñ) de hasta 40 caracteres; opcional
  CONSTRAINT pk_presentacion PRIMARY KEY (id_presentacion),  -- Llave primaria: id_presentacion identifica cada fila.
  CONSTRAINT ck_presentacion_modalidad CHECK (modalidad IN ('FISICA', 'ELECTRONICA')),  -- Reemplaza al ENUM de MySQL: modalidad solo acepta los valores de la lista.
  CONSTRAINT fk_presentacion_id_documento FOREIGN KEY (id_documento) REFERENCES dbo.documento_legal(id_documento),  -- FK: id_documento debe existir en documento_legal.id_documento.
  CONSTRAINT fk_presentacion_id_entidad FOREIGN KEY (id_entidad) REFERENCES dbo.entidad(id_entidad),  -- FK: id_entidad debe existir en entidad.id_entidad.
  CONSTRAINT fk_presentacion_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- FK: id_empleado debe existir en empleado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA GASTO_CASO =====
-- Qué guarda : Gastos del caso: tasas judiciales, aranceles, peritajes, copias certificadas. Reemplaza a presentacion.monto_tasa y permite cobrarlos al cliente.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, presentacion, empleado
CREATE TABLE dbo.gasto_caso (  -- Crea la tabla gasto_caso en el esquema dbo (el esquema por defecto de SQL Server).
  id_gasto INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; A qué caso pertenece el gasto
  id_presentacion INT NULL,  -- FK → presentacion(id_presentacion): solo acepta valores que existan allí; número entero; opcional; Escrito que originó el gasto (p. ej. la tasa de la demanda)
  id_empleado INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; Quién registró o adelantó el gasto
  fecha DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  concepto NVARCHAR(100) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 100 caracteres; obligatorio; Ej.: Tasa judicial por apelación
  monto DECIMAL(10,2) NOT NULL,  -- número exacto con 2 decimales (hasta 8 enteros); ideal para dinero; obligatorio
  es_reembolsable BIT NOT NULL CONSTRAINT df_gasto_caso_es_reembolsable DEFAULT 1,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 1; 1 = el cliente debe reembolsarlo; 0 = lo asume el estudio
  CONSTRAINT pk_gasto_caso PRIMARY KEY (id_gasto),  -- Llave primaria: id_gasto identifica cada fila.
  CONSTRAINT ck_gasto_caso_1 CHECK (monto > 0),  -- Regla: todo gasto debe ser mayor a cero.
  CONSTRAINT fk_gasto_caso_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_gasto_caso_id_presentacion FOREIGN KEY (id_presentacion) REFERENCES dbo.presentacion(id_presentacion),  -- FK: id_presentacion debe existir en presentacion.id_presentacion (el trigger trg_gasto_caso_mismo_caso exige que sea del mismo caso).
  CONSTRAINT fk_gasto_caso_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- FK: id_empleado debe existir en empleado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.


-- ===== TABLA RESOLUCION =====
-- Qué guarda : Lo que notifica la entidad: admisorio, inadmisible, traslado, citación, sentencia…
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, entidad, presentacion
CREATE TABLE dbo.resolucion (  -- Crea la tabla resolucion en el esquema dbo (el esquema por defecto de SQL Server).
  id_resolucion INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; R27
  id_entidad INT NOT NULL,  -- FK → entidad(id_entidad): solo acepta valores que existan allí; número entero; obligatorio; R28
  id_presentacion INT NULL,  -- FK → presentacion(id_presentacion): solo acepta valores que existan allí; número entero; opcional; R29
  nro_resolucion NVARCHAR(30) NULL,  -- texto Unicode (tildes, ñ) de hasta 30 caracteres; opcional
  tipo_resolucion VARCHAR(17) NOT NULL,  -- VARCHAR(17) + CHECK: solo acepta ADMISORIO, INADMISIBLE, IMPROCEDENTE, TRASLADO…; obligatorio
  fecha_notificacion DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  medio_notificacion VARCHAR(22) NOT NULL,  -- VARCHAR(22) + CHECK: solo acepta SINOE, CEDULA, CASILLA_ADMINISTRATIVA, CORREO…; obligatorio
  sumilla NVARCHAR(300) NULL,  -- texto Unicode (tildes, ñ) de hasta 300 caracteres; opcional
  archivo_mongo_id CHAR(24) NULL,  -- texto fijo de 24 caracteres: ObjectId del documento en MongoDB; opcional; PDF de la resolución (NoSQL)
  CONSTRAINT pk_resolucion PRIMARY KEY (id_resolucion),  -- Llave primaria: id_resolucion identifica cada fila.
  CONSTRAINT uq_resolucion_caso UNIQUE (id_caso, id_resolucion),  -- Permite la llave foránea compuesta de PLAZO: un plazo solo puede apoyarse en una resolución de su mismo caso.
  CONSTRAINT ck_resolucion_tipo_resolucion CHECK (tipo_resolucion IN ('ADMISORIO', 'INADMISIBLE', 'IMPROCEDENTE', 'TRASLADO', 'REQUERIMIENTO', 'CITACION', 'DECRETO', 'ACTA_CONCILIACION', 'SENTENCIA', 'LAUDO', 'AUTO_FINAL')),  -- Reemplaza al ENUM de MySQL: tipo_resolucion solo acepta los valores de la lista.
  CONSTRAINT ck_resolucion_medio_notificacion CHECK (medio_notificacion IN ('SINOE', 'CEDULA', 'CASILLA_ADMINISTRATIVA', 'CORREO', 'CEJ')),  -- Reemplaza al ENUM de MySQL: medio_notificacion solo acepta los valores de la lista.
  CONSTRAINT fk_resolucion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_resolucion_id_entidad FOREIGN KEY (id_entidad) REFERENCES dbo.entidad(id_entidad),  -- FK: id_entidad debe existir en entidad.id_entidad.
  CONSTRAINT fk_resolucion_id_presentacion FOREIGN KEY (id_presentacion) REFERENCES dbo.presentacion(id_presentacion)  -- FK: id_presentacion debe existir en presentacion.id_presentacion.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA PLAZO =====
-- Qué guarda : Plazo procesal con fecha de vencimiento que el sistema alerta. El estado (pendiente / cumplido / vencido) NO se guarda: lo calcula vw_plazo_estado.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: caso, resolucion, empleado, presentacion
CREATE TABLE dbo.plazo (  -- Crea la tabla plazo en el esquema dbo (el esquema por defecto de SQL Server).
  id_plazo INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; R30
  id_resolucion INT NULL,  -- FK → resolucion(id_resolucion): solo acepta valores que existan allí; número entero; opcional; R31
  id_empleado_responsable INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; A quién se le envía la alerta
  id_presentacion_cumplimiento INT NULL,  -- FK → presentacion(id_presentacion): solo acepta valores que existan allí; número entero; opcional; Escrito con el que se cumplió el plazo (del mismo caso)
  descripcion NVARCHAR(200) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; obligatorio; Ej.: contestar demanda
  fecha_inicio DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  dias_plazo SMALLINT NOT NULL,  -- entero hasta 32 767; obligatorio; Cantidad de días del plazo (p. ej. 10)
  tipo_computo VARCHAR(10) NOT NULL,  -- VARCHAR(10) + CHECK: solo acepta HABIL, CALENDARIO; obligatorio; HABIL no cuenta sábados, domingos ni FERIADO
  fecha_vencimiento DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  fecha_cumplimiento DATE NULL,  -- fecha (año-mes-día); opcional
  CONSTRAINT pk_plazo PRIMARY KEY (id_plazo),  -- Llave primaria: id_plazo identifica cada fila.
  CONSTRAINT ck_plazo_tipo_computo CHECK (tipo_computo IN ('HABIL', 'CALENDARIO')),  -- Reemplaza al ENUM de MySQL: tipo_computo solo acepta los valores de la lista.
  CONSTRAINT ck_plazo_dias CHECK (dias_plazo > 0),  -- Regla: el plazo dura al menos un día.
  CONSTRAINT ck_plazo_calendario CHECK (tipo_computo <> 'CALENDARIO' OR fecha_vencimiento = DATEADD(DAY, dias_plazo, fecha_inicio)),  -- Regla: en un plazo calendario el vencimiento es exactamente inicio + días (el hábil necesita la tabla FERIADO y se calcula en la aplicación).
  CONSTRAINT ck_plazo_1 CHECK (fecha_vencimiento >= fecha_inicio),  -- Regla: El vencimiento no puede ser anterior al inicio del plazo.
  CONSTRAINT fk_plazo_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_plazo_id_resolucion FOREIGN KEY (id_caso, id_resolucion) REFERENCES dbo.resolucion(id_caso, id_resolucion),  -- FK compuesta: si hay resolución, debe ser del mismo caso del plazo (si id_resolucion es NULL no se valida).
  CONSTRAINT fk_plazo_id_empleado_responsable FOREIGN KEY (id_empleado_responsable) REFERENCES dbo.empleado(id_empleado),  -- FK: id_empleado_responsable debe existir en empleado.id_empleado.
  CONSTRAINT fk_plazo_id_presentacion_cumplimiento FOREIGN KEY (id_presentacion_cumplimiento) REFERENCES dbo.presentacion(id_presentacion)  -- FK: id_presentacion_cumplimiento debe existir en presentacion.id_presentacion (el trigger trg_plazo_mismo_caso exige que sea del mismo caso).
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA AUDIENCIA =====
-- Qué guarda : Audiencia (judicial o de conciliación) y sus reprogramaciones.
-- Proceso    : Proceso 2 · Gestión del Expediente
-- Se enlaza con: abogado, resolucion
CREATE TABLE dbo.audiencia (  -- Crea la tabla audiencia en el esquema dbo (el esquema por defecto de SQL Server).
  id_audiencia INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_resolucion INT NOT NULL,  -- FK → resolucion(id_resolucion): solo acepta valores que existan allí; número entero; obligatorio; R32 (citación)
  id_abogado INT NOT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R33
  fecha_hora DATETIME2(0) NOT NULL,  -- fecha y hora (sin fracciones de segundo); obligatorio
  modalidad VARCHAR(10) NOT NULL,  -- VARCHAR(10) + CHECK: solo acepta PRESENCIAL, VIRTUAL; obligatorio; Juzgado o Google Meet
  tipo_audiencia VARCHAR(14) NOT NULL,  -- VARCHAR(14) + CHECK: solo acepta JUDICIAL, CONCILIACION, ADMINISTRATIVA, ARBITRAL; obligatorio
  estado VARCHAR(12) NOT NULL CONSTRAINT df_audiencia_estado DEFAULT 'PROGRAMADA',  -- VARCHAR(12) + CHECK: solo acepta PROGRAMADA, REALIZADA, REPROGRAMADA, SUSPENDIDA; obligatorio; si no se envía vale 'PROGRAMADA'
  acta_mongo_id CHAR(24) NULL,  -- texto fijo de 24 caracteres: ObjectId del documento en MongoDB; opcional; Acta (NoSQL)
  CONSTRAINT pk_audiencia PRIMARY KEY (id_audiencia),  -- Llave primaria: id_audiencia identifica cada fila.
  CONSTRAINT ck_audiencia_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL')),  -- Reemplaza al ENUM de MySQL: modalidad solo acepta los valores de la lista.
  CONSTRAINT ck_audiencia_tipo_audiencia CHECK (tipo_audiencia IN ('JUDICIAL', 'CONCILIACION', 'ADMINISTRATIVA', 'ARBITRAL')),  -- Reemplaza al ENUM de MySQL: tipo_audiencia solo acepta los valores de la lista.
  CONSTRAINT ck_audiencia_estado CHECK (estado IN ('PROGRAMADA', 'REALIZADA', 'REPROGRAMADA', 'SUSPENDIDA')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT fk_audiencia_id_resolucion FOREIGN KEY (id_resolucion) REFERENCES dbo.resolucion(id_resolucion),  -- FK: id_resolucion debe existir en resolucion.id_resolucion.
  CONSTRAINT fk_audiencia_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)  -- FK: id_abogado debe existir en abogado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.
-- ---------------------------------------------------------------------
-- 4. PROCESO 3 · RESOLUCIÓN Y FACTURACIÓN
-- ---------------------------------------------------------------------

-- ===== TABLA SENTENCIA =====
-- Qué guarda : Resolución final del caso con su resultado (especialización de RESOLUCION). También se usa para laudo, acta de conciliación y auto final.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: resolucion
CREATE TABLE dbo.sentencia (  -- Crea la tabla sentencia en el esquema dbo (el esquema por defecto de SQL Server).
  id_resolucion INT NOT NULL,  -- parte de la PK y FK → resolucion(id_resolucion); número entero; obligatorio; Misma llave que la resolución
  instancia VARCHAR(8) NOT NULL,  -- VARCHAR(8) + CHECK: solo acepta PRIMERA, SEGUNDA, CASACION, UNICA; obligatorio
  resultado VARCHAR(12) NOT NULL,  -- VARCHAR(12) + CHECK: solo acepta FAVORABLE, PARCIAL, DESFAVORABLE; obligatorio
  monto_ordenado DECIMAL(14,2) NOT NULL CONSTRAINT df_sentencia_monto_ordenado DEFAULT 0.00,  -- número exacto con 2 decimales (hasta 12 enteros); ideal para dinero; obligatorio; si no se envía vale 0.00; Base de la cuota litis
  se_apela BIT NOT NULL CONSTRAINT df_sentencia_se_apela DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  fecha_firmeza DATE NULL,  -- fecha (año-mes-día); opcional; Consentida / ejecutoriada
  requiere_ejecucion BIT NOT NULL CONSTRAINT df_sentencia_requiere_ejecucion DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  CONSTRAINT pk_sentencia PRIMARY KEY (id_resolucion),  -- Llave primaria: id_resolucion identifica cada fila.
  CONSTRAINT ck_sentencia_instancia CHECK (instancia IN ('PRIMERA', 'SEGUNDA', 'CASACION', 'UNICA')),  -- Reemplaza al ENUM de MySQL: instancia solo acepta los valores de la lista.
  CONSTRAINT ck_sentencia_resultado CHECK (resultado IN ('FAVORABLE', 'PARCIAL', 'DESFAVORABLE')),  -- Reemplaza al ENUM de MySQL: resultado solo acepta los valores de la lista.
  CONSTRAINT fk_sentencia_id_resolucion FOREIGN KEY (id_resolucion) REFERENCES dbo.resolucion(id_resolucion)  -- FK: id_resolucion debe existir en resolucion.id_resolucion.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA LIQUIDACION =====
-- Qué guarda : Cálculo final de honorarios del caso (incluye cuota litis). El monto de la cuota litis NO se guarda aquí: se calcula en vw_liquidacion_cuota_litis y se cobra en CUOTA.monto.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: caso, abogado
CREATE TABLE dbo.liquidacion (  -- Crea la tabla liquidacion en el esquema dbo (el esquema por defecto de SQL Server).
  id_liquidacion INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; no se puede repetir; R35 (1:1)
  id_abogado INT NOT NULL,  -- FK → abogado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R36
  fecha_liquidacion DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  monto_obtenido DECIMAL(14,2) NOT NULL CONSTRAINT df_liquidacion_monto_obtenido DEFAULT 0.00,  -- número exacto con 2 decimales (hasta 12 enteros); ideal para dinero; obligatorio; si no se envía vale 0.00; Lo cobrado por el cliente
  estado VARCHAR(10) NOT NULL CONSTRAINT df_liquidacion_estado DEFAULT 'BORRADOR',  -- VARCHAR(10) + CHECK: solo acepta BORRADOR, COMUNICADA, ACEPTADA, OBSERVADA; obligatorio; si no se envía vale 'BORRADOR'
  CONSTRAINT pk_liquidacion PRIMARY KEY (id_liquidacion),  -- Llave primaria: id_liquidacion identifica cada fila.
  CONSTRAINT uq_liquidacion_id_caso UNIQUE (id_caso),  -- UNIQUE: no pueden existir dos filas con el mismo id_caso.
  CONSTRAINT ck_liquidacion_estado CHECK (estado IN ('BORRADOR', 'COMUNICADA', 'ACEPTADA', 'OBSERVADA')),  -- Reemplaza al ENUM de MySQL: estado solo acepta los valores de la lista.
  CONSTRAINT fk_liquidacion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_liquidacion_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)  -- FK: id_abogado debe existir en abogado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA SERIE_COMPROBANTE =====
-- Qué guarda : Series de numeración de los comprobantes: a qué tipo pertenece cada serie (B001 boleta, F001 factura, E001 recibo por honorarios) y cuál fue el último número emitido.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Por qué existe: el tipo de comprobante depende de la serie, no del comprobante (dependencia transitiva, 3FN). Por eso COMPROBANTE ya no tiene tipo_comprobante.
CREATE TABLE dbo.serie_comprobante (  -- Crea la tabla serie_comprobante en el esquema dbo (el esquema por defecto de SQL Server).
  serie CHAR(4) NOT NULL,  -- PK; texto de longitud fija (4 caracteres); obligatorio; B001 / F001 / E001
  tipo_comprobante VARCHAR(17) NOT NULL,  -- VARCHAR(17) + CHECK: solo acepta BOLETA, FACTURA, RECIBO_HONORARIOS; obligatorio; Cada serie pertenece a un solo tipo
  ultimo_numero INT NOT NULL CONSTRAINT df_serie_comprobante_ultimo_numero DEFAULT 0,  -- número entero; obligatorio; si no se envía vale 0; Último correlativo emitido (lo actualiza el trigger trg_comprobante_correlativo)
  CONSTRAINT pk_serie_comprobante PRIMARY KEY (serie),  -- Llave primaria: serie identifica cada fila.
  CONSTRAINT ck_serie_comprobante_tipo CHECK (tipo_comprobante IN ('BOLETA', 'FACTURA', 'RECIBO_HONORARIOS')),  -- Reemplaza al ENUM de MySQL: tipo_comprobante solo acepta los valores de la lista.
  CONSTRAINT ck_serie_comprobante_1 CHECK (ultimo_numero >= 0)  -- Regla: el correlativo no puede ser negativo.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.


-- ===== TABLA COMPROBANTE =====
-- Qué guarda : Boleta, factura o recibo emitido al cliente. El tipo (boleta / factura / recibo) se obtiene de la serie.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: consulta, empleado, persona, serie_comprobante
CREATE TABLE dbo.comprobante (  -- Crea la tabla comprobante en el esquema dbo (el esquema por defecto de SQL Server).
  id_comprobante INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_persona INT NOT NULL,  -- FK → persona(id_persona): solo acepta valores que existan allí; número entero; obligatorio; Receptor (R38)
  id_emisor INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R39
  id_consulta INT NULL,  -- FK → consulta(id_consulta): solo acepta valores que existan allí; número entero; opcional; no se puede repetir (índice filtrado, ver abajo); R41 (cobro de consulta)
  serie CHAR(4) NOT NULL,  -- FK → serie_comprobante(serie): solo acepta valores que existan allí; texto de longitud fija (4 caracteres); obligatorio; B001 / F001 / E001 (la serie define el tipo)
  numero INT NOT NULL,  -- número entero; obligatorio; Correlativo
  fecha_emision DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  fecha_vencimiento DATE NOT NULL,  -- fecha (año-mes-día); obligatorio
  moneda CHAR(3) NOT NULL CONSTRAINT df_comprobante_moneda DEFAULT 'PEN',  -- texto de longitud fija (3 caracteres); obligatorio; si no se envía vale 'PEN'; PEN = soles, USD = dólares
  tasa_igv DECIMAL(4,2) NOT NULL CONSTRAINT df_comprobante_tasa_igv DEFAULT 0.18,  -- número exacto con 2 decimales (hasta 2 enteros); ideal para dinero; obligatorio; si no se envía vale 0.18; 0.18 boleta/factura; 0.00 recibo
  porcentaje_detraccion DECIMAL(4,2) NOT NULL CONSTRAINT df_comprobante_porcentaje_detraccion DEFAULT 0.00,  -- número exacto con 2 decimales (hasta 2 enteros); ideal para dinero; obligatorio; si no se envía vale 0.00; 0.12 = 12 %; 0.00 = no aplica detracción
  fecha_conformidad DATE NULL,  -- fecha (año-mes-día); opcional; Solo entidad pública
  estado VARCHAR(8) NOT NULL CONSTRAINT df_comprobante_estado DEFAULT 'EMITIDO',  -- EMITIDO o ANULADO; si está pagado lo calcula vw_comprobante_saldo (no se guarda)
  CONSTRAINT pk_comprobante PRIMARY KEY (id_comprobante),  -- Llave primaria: id_comprobante identifica cada fila.
  CONSTRAINT uq_comprobante_serie UNIQUE (serie, numero),  -- No pueden existir dos filas con la misma combinación (serie, numero).
  CONSTRAINT ck_comprobante_moneda CHECK (moneda IN ('PEN', 'USD')),  -- Regla: la moneda es soles (PEN) o dólares (USD).
  CONSTRAINT ck_comprobante_estado CHECK (estado IN ('EMITIDO', 'ANULADO')),  -- Solo se guarda la anulación; el estado de pago es derivado.
  CONSTRAINT ck_comprobante_1 CHECK (fecha_vencimiento >= fecha_emision),  -- Regla: El comprobante no puede vencer antes de emitirse.
  CONSTRAINT ck_comprobante_2 CHECK (tasa_igv BETWEEN 0 AND 0.30),  -- Regla: La tasa de IGV va entre 0 y 0.30 (0.18 normal, 0 en recibo por honorarios).
  CONSTRAINT ck_comprobante_3 CHECK (porcentaje_detraccion BETWEEN 0 AND 0.15),  -- Regla: la detracción va de 0 a 0.15 (0.12 servicios gravados con IGV, 0 si no aplica).
  CONSTRAINT fk_comprobante_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),  -- FK: id_persona debe existir en persona.id_persona.
  CONSTRAINT fk_comprobante_id_emisor FOREIGN KEY (id_emisor) REFERENCES dbo.empleado(id_empleado),  -- FK: id_emisor debe existir en empleado.id_empleado.
  CONSTRAINT fk_comprobante_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),  -- FK: id_consulta debe existir en consulta.id_consulta.
  CONSTRAINT fk_comprobante_serie FOREIGN KEY (serie) REFERENCES dbo.serie_comprobante(serie)  -- FK: serie debe existir en serie_comprobante.serie.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA DETALLE_COMPROBANTE =====
-- Qué guarda : Tabla intermedia: las líneas de cada comprobante (resuelve la M:N comprobante–cuota) y los reembolsos de gastos (comprobante–gasto_caso).
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: comprobante, cuota, gasto_caso
CREATE TABLE dbo.detalle_comprobante (  -- Crea la tabla detalle_comprobante en el esquema dbo (el esquema por defecto de SQL Server).
  id_comprobante INT NOT NULL,  -- parte de la PK y FK → comprobante(id_comprobante); número entero; obligatorio
  nro_linea TINYINT NOT NULL,  -- parte de la PK compuesta; entero pequeño 0 a 255; obligatorio; Línea dentro del comprobante
  id_cuota INT NULL,  -- FK → cuota(id_cuota): solo acepta valores que existan allí; número entero; opcional; NULL en la línea de la consulta o de un gasto
  id_gasto INT NULL,  -- FK → gasto_caso(id_gasto): solo acepta valores que existan allí; número entero; opcional; Reembolso de un gasto (tasa, arancel…); NULL en las líneas de cuota o de la consulta
  descripcion NVARCHAR(200) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 200 caracteres; obligatorio
  cantidad DECIMAL(8,2) NOT NULL CONSTRAINT df_detalle_comprobante_cantidad DEFAULT 1.00,  -- número exacto con 2 decimales (hasta 6 enteros); ideal para dinero; obligatorio; si no se envía vale 1.00
  valor_unitario DECIMAL(12,2) NOT NULL,  -- número exacto con 2 decimales (hasta 10 enteros); ideal para dinero; obligatorio; Sin IGV
  CONSTRAINT pk_detalle_comprobante PRIMARY KEY (id_comprobante, nro_linea),  -- Llave primaria compuesta: la combinación (id_comprobante, nro_linea) no se puede repetir.
  CONSTRAINT ck_detalle_comprobante_1 CHECK (cantidad > 0),  -- Regla: La cantidad debe ser mayor a cero.
  CONSTRAINT ck_detalle_comprobante_2 CHECK (valor_unitario >= 0),  -- Regla: El valor unitario no puede ser negativo.
  CONSTRAINT ck_detalle_comprobante_3 CHECK (id_cuota IS NULL OR id_gasto IS NULL),  -- Regla: una línea cobra una cuota o un gasto, nunca ambos.
  CONSTRAINT fk_detalle_comprobante_id_comprobante FOREIGN KEY (id_comprobante) REFERENCES dbo.comprobante(id_comprobante),  -- FK: id_comprobante debe existir en comprobante.id_comprobante.
  CONSTRAINT fk_detalle_comprobante_id_cuota FOREIGN KEY (id_cuota) REFERENCES dbo.cuota(id_cuota),  -- FK: id_cuota debe existir en cuota.id_cuota.
  CONSTRAINT fk_detalle_comprobante_id_gasto FOREIGN KEY (id_gasto) REFERENCES dbo.gasto_caso(id_gasto)  -- FK: id_gasto debe existir en gasto_caso.id_gasto.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA PAGO =====
-- Qué guarda : Abono recibido contra un comprobante.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: comprobante, empleado
CREATE TABLE dbo.pago (  -- Crea la tabla pago en el esquema dbo (el esquema por defecto de SQL Server).
  id_pago INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_comprobante INT NOT NULL,  -- FK → comprobante(id_comprobante): solo acepta valores que existan allí; número entero; obligatorio; R42
  id_empleado INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; R43
  fecha_pago DATETIME2(0) NOT NULL CONSTRAINT df_pago_fecha_pago DEFAULT SYSDATETIME(),  -- fecha y hora (sin fracciones de segundo); obligatorio; si no se envía vale SYSDATETIME()
  monto DECIMAL(12,2) NOT NULL,  -- número exacto con 2 decimales (hasta 10 enteros); ideal para dinero; obligatorio
  medio_pago VARCHAR(13) NOT NULL,  -- VARCHAR(13) + CHECK: solo acepta EFECTIVO, YAPE, PLIN, TRANSFERENCIA…; obligatorio
  nro_operacion NVARCHAR(40) NULL,  -- texto Unicode (tildes, ñ) de hasta 40 caracteres; opcional
  CONSTRAINT pk_pago PRIMARY KEY (id_pago),  -- Llave primaria: id_pago identifica cada fila.
  CONSTRAINT ck_pago_medio_pago CHECK (medio_pago IN ('EFECTIVO', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'DEPOSITO', 'TARJETA')),  -- Reemplaza al ENUM de MySQL: medio_pago solo acepta los valores de la lista.
  CONSTRAINT ck_pago_1 CHECK (monto > 0),  -- Regla: Todo pago debe ser mayor a cero.
  CONSTRAINT fk_pago_id_comprobante FOREIGN KEY (id_comprobante) REFERENCES dbo.comprobante(id_comprobante),  -- FK: id_comprobante debe existir en comprobante.id_comprobante.
  CONSTRAINT fk_pago_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- FK: id_empleado debe existir en empleado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA DEVOLUCION =====
-- Qué guarda : Entrega de documentos originales al cliente con cargo firmado.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: caso, empleado, persona
CREATE TABLE dbo.devolucion (  -- Crea la tabla devolucion en el esquema dbo (el esquema por defecto de SQL Server).
  id_devolucion INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; R44
  id_persona INT NOT NULL,  -- FK → persona(id_persona): solo acepta valores que existan allí; número entero; obligatorio; Quien recibe (R45)
  id_empleado INT NOT NULL,  -- FK → empleado(id_empleado): solo acepta valores que existan allí; número entero; obligatorio; Quien entrega (R46)
  fecha_entrega DATETIME2(0) NOT NULL,  -- fecha y hora (sin fracciones de segundo); obligatorio
  descripcion_documentos NVARCHAR(500) NOT NULL,  -- texto Unicode (tildes, ñ) de hasta 500 caracteres; obligatorio
  cargo_firmado BIT NOT NULL CONSTRAINT df_devolucion_cargo_firmado DEFAULT 0,  -- sí/no (1 = sí, 0 = no); obligatorio; si no se envía vale 0
  CONSTRAINT pk_devolucion PRIMARY KEY (id_devolucion),  -- Llave primaria: id_devolucion identifica cada fila.
  CONSTRAINT fk_devolucion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),  -- FK: id_caso debe existir en caso.id_caso.
  CONSTRAINT fk_devolucion_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),  -- FK: id_persona debe existir en persona.id_persona.
  CONSTRAINT fk_devolucion_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- FK: id_empleado debe existir en empleado.id_empleado.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ===== TABLA ENCUESTA =====
-- Qué guarda : Encuesta de satisfacción al cerrar el caso.
-- Proceso    : Proceso 3 · Resolución y Facturación
-- Se enlaza con: caso
CREATE TABLE dbo.encuesta (  -- Crea la tabla encuesta en el esquema dbo (el esquema por defecto de SQL Server).
  id_encuesta INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1): SQL Server la numera solo (1, 2, 3…); obligatorio
  id_caso INT NOT NULL,  -- FK → caso(id_caso): solo acepta valores que existan allí; número entero; obligatorio; no se puede repetir; R47 (1:1)
  fecha_envio DATETIME2(0) NOT NULL,  -- fecha y hora (sin fracciones de segundo); obligatorio
  fecha_respuesta DATETIME2(0) NULL,  -- fecha y hora (sin fracciones de segundo); opcional
  calificacion TINYINT NULL,  -- entero pequeño 0 a 255; opcional; 1 a 5
  nps TINYINT NULL,  -- entero pequeño 0 a 255; opcional; 0 a 10
  comentario NVARCHAR(500) NULL,  -- texto Unicode (tildes, ñ) de hasta 500 caracteres; opcional
  CONSTRAINT pk_encuesta PRIMARY KEY (id_encuesta),  -- Llave primaria: id_encuesta identifica cada fila.
  CONSTRAINT uq_encuesta_id_caso UNIQUE (id_caso),  -- UNIQUE: no pueden existir dos filas con el mismo id_caso.
  CONSTRAINT ck_encuesta_1 CHECK (calificacion IS NULL OR calificacion BETWEEN 1 AND 5),  -- Regla: La calificación va de 1 a 5 estrellas (o vacía si no respondió).
  CONSTRAINT ck_encuesta_2 CHECK (nps IS NULL OR nps BETWEEN 0 AND 10),  -- Regla: El NPS va de 0 a 10 (o vacío si no respondió).
  CONSTRAINT fk_encuesta_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso)  -- FK: id_caso debe existir en caso.id_caso.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ---------------------------------------------------------------------
-- 4.1 TABLA TRANSVERSAL A LOS 3 PROCESOS
-- ---------------------------------------------------------------------

-- ===== TABLA NOTIFICACION =====  (NUEVA en la versión de 36 tablas)
-- Qué guarda : Cada aviso que envía el sistema por WhatsApp, correo o la campana del panel: confirmación de consulta,
--              recordatorio de cita, alerta de plazo, aviso de audiencia, recordatorio de cuota, constancia de pago,
--              envío de encuesta y pedido de firma. Es el carril «Sistema» de los diagramas TO-BE.
-- Proceso    : Transversal (P1, P2 y P3)
-- Se enlaza con: persona, empleado, consulta, caso
CREATE TABLE dbo.notificacion (  -- Crea la tabla notificacion.
  id_notificacion INT IDENTITY(1,1) NOT NULL,  -- PK con IDENTITY(1,1); obligatorio
  id_persona INT NULL,  -- FK → persona: el cliente que la recibe (o NULL si va a un empleado)
  id_empleado INT NULL,  -- FK → empleado: el empleado que la recibe (o NULL si va a un cliente)
  id_consulta INT NULL,  -- FK → consulta: la consulta que la originó (P1); opcional
  id_caso INT NULL,  -- FK → caso: el caso que la originó (P2 y P3); opcional
  tipo_evento VARCHAR(21) NOT NULL,  -- VARCHAR + CHECK: qué evento la dispara
  canal VARCHAR(8) NOT NULL,  -- VARCHAR + CHECK: WHATSAPP, CORREO o SISTEMA (campana del panel)
  mensaje NVARCHAR(500) NOT NULL,  -- Texto enviado
  fecha_programada DATETIME2(0) NOT NULL,  -- Cuándo debe salir (p. ej. 24 h antes de la cita)
  fecha_envio DATETIME2(0) NULL,  -- Cuándo salió de verdad; NULL = todavía no sale
  estado VARCHAR(9) NOT NULL CONSTRAINT df_notificacion_estado DEFAULT 'PENDIENTE',  -- PENDIENTE, ENVIADA o FALLIDA
  CONSTRAINT pk_notificacion PRIMARY KEY (id_notificacion),  -- Llave primaria.
  CONSTRAINT ck_notificacion_destinatario CHECK ((id_persona IS NOT NULL AND id_empleado IS NULL) OR (id_persona IS NULL AND id_empleado IS NOT NULL)),  -- Regla: un solo destinatario (cliente O empleado).
  CONSTRAINT ck_notificacion_origen CHECK (id_consulta IS NOT NULL OR id_caso IS NOT NULL),  -- Regla: toda notificación nace de una consulta o de un caso.
  CONSTRAINT ck_notificacion_tipo_evento CHECK (tipo_evento IN ('CONFIRMACION_CONSULTA', 'RECORDATORIO_CITA', 'ALERTA_PLAZO', 'AVISO_AUDIENCIA', 'RECORDATORIO_CUOTA', 'CONSTANCIA_PAGO', 'ENVIO_ENCUESTA', 'FIRMA_DOCUMENTO')),  -- Lista cerrada de eventos.
  CONSTRAINT ck_notificacion_canal CHECK (canal IN ('WHATSAPP', 'CORREO', 'SISTEMA')),  -- Lista cerrada de canales.
  CONSTRAINT ck_notificacion_estado CHECK (estado IN ('PENDIENTE', 'ENVIADA', 'FALLIDA')),  -- Lista cerrada de estados.
  CONSTRAINT ck_notificacion_envio CHECK ((estado = 'ENVIADA' AND fecha_envio IS NOT NULL) OR (estado <> 'ENVIADA' AND fecha_envio IS NULL)),  -- Regla: solo una enviada tiene fecha de envío.
  CONSTRAINT fk_notificacion_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),  -- FK: el cliente debe existir.
  CONSTRAINT fk_notificacion_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado),  -- FK: el empleado debe existir.
  CONSTRAINT fk_notificacion_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),  -- FK: la consulta debe existir.
  CONSTRAINT fk_notificacion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso)  -- FK: el caso debe existir.
);  -- Fin de la tabla.
GO  -- Ejecuta este lote antes de seguir.

-- ---------------------------------------------------------------------
-- 5. LLAVE FORÁNEA PENDIENTE
-- ---------------------------------------------------------------------
-- La tabla CUOTA se crea antes que LIQUIDACION (el contrato genera cuotas desde
-- el inicio), así que su FK hacia LIQUIDACION se agrega al final con ALTER TABLE.
ALTER TABLE dbo.cuota ADD CONSTRAINT fk_cuota_id_liquidacion FOREIGN KEY (id_liquidacion) REFERENCES dbo.liquidacion(id_liquidacion);  -- La cuota de saldo o cuota litis apunta a la liquidación que la generó.
GO

-- ---------------------------------------------------------------------
-- 6. TRIGGERS
-- ---------------------------------------------------------------------
-- Un trigger es código que SQL Server ejecuta solo, justo después de un INSERT o UPDATE.
-- Se usa para reglas que un CHECK no puede expresar porque miran OTRAS tablas.
-- "inserted" es una tabla temporal con las filas que se acaban de insertar o modificar.
-- Si la regla falla: se deshace la operación (ROLLBACK) y se lanza el error (THROW).

-- Trigger 1: solo un empleado con cargo ABOGADO puede estar en la tabla ABOGADO.
CREATE TRIGGER dbo.trg_abogado_cargo ON dbo.abogado  -- Crea el trigger sobre la tabla abogado.
AFTER INSERT, UPDATE  -- Se dispara después de insertar o modificar filas.
AS
BEGIN
    SET NOCOUNT ON;  -- No muestra el mensaje "n filas afectadas" dentro del trigger.
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.empleado e ON e.id_empleado = i.id_empleado WHERE e.cargo <> 'ABOGADO')  -- ¿Alguna fila apunta a un empleado que no es abogado?
    BEGIN
        ROLLBACK TRANSACTION;  -- Deshace la operación.
        THROW 50001, N'Solo un empleado con cargo ABOGADO puede registrarse en la tabla abogado.', 1;  -- Informa el motivo.
    END
END
GO

-- Trigger 2: no se puede cambiar el cargo de un abogado (porque dejaría de serlo y seguiría en ABOGADO).
CREATE TRIGGER dbo.trg_empleado_cargo ON dbo.empleado  -- Crea el trigger sobre la tabla empleado.
AFTER UPDATE  -- Solo al modificar.
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(cargo) AND EXISTS (SELECT 1 FROM inserted i JOIN dbo.abogado a ON a.id_empleado = i.id_empleado WHERE i.cargo <> 'ABOGADO')  -- ¿Se cambió el cargo de alguien que está en ABOGADO?
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, N'No se puede cambiar el cargo de un empleado que figura en la tabla abogado.', 1;
    END
END
GO

-- Trigger 3: la presentación que originó una resolución debe ser del mismo caso de la resolución.
CREATE TRIGGER dbo.trg_resolucion_mismo_caso ON dbo.resolucion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.presentacion p ON p.id_presentacion = i.id_presentacion  -- presentación a la que responde la resolución
               JOIN dbo.documento_legal d ON d.id_documento = p.id_documento     -- escrito presentado (de ahí sale su caso)
               WHERE d.id_caso <> i.id_caso)  -- ¿el caso del escrito es distinto del caso de la resolución?
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, N'La presentación de la resolución debe pertenecer al mismo caso.', 1;
    END
END
GO

-- Trigger 4: el escrito que cumplió un plazo debe ser del mismo caso del plazo.
CREATE TRIGGER dbo.trg_plazo_mismo_caso ON dbo.plazo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.presentacion p ON p.id_presentacion = i.id_presentacion_cumplimiento
               JOIN dbo.documento_legal d ON d.id_documento = p.id_documento
               WHERE d.id_caso <> i.id_caso)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, N'La presentación que cumple el plazo debe pertenecer al mismo caso.', 1;
    END
END
GO

-- Trigger 5: la presentación asociada a un gasto debe ser del mismo caso del gasto.
CREATE TRIGGER dbo.trg_gasto_caso_mismo_caso ON dbo.gasto_caso
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.presentacion p ON p.id_presentacion = i.id_presentacion
               JOIN dbo.documento_legal d ON d.id_documento = p.id_documento
               WHERE d.id_caso <> i.id_caso)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50005, N'La presentación del gasto debe pertenecer al mismo caso.', 1;
    END
END
GO

-- Trigger 6: el número del comprobante debe ser EXACTAMENTE el siguiente de su serie (sin saltos ni repetidos),
--            y una vez emitido no se puede cambiar su serie ni su número (se anula y se emite otro).
CREATE TRIGGER dbo.trg_comprobante_correlativo ON dbo.comprobante
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)  -- Si hay filas en «deleted», es un UPDATE.
    BEGIN
        IF UPDATE(serie) OR UPDATE(numero)  -- ¿Intentan cambiar la serie o el número?
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50007, N'La serie y el número de un comprobante emitido no se pueden modificar: anúlelo y emita otro.', 1;
        END
        RETURN;  -- Otros cambios (estado ANULADO, fechas) sí se permiten.
    END
    IF EXISTS (SELECT 1
               FROM (SELECT i.serie, i.numero,
                            ROW_NUMBER() OVER (PARTITION BY i.serie ORDER BY i.numero) AS orden  -- 1, 2, 3… dentro de cada serie
                     FROM inserted i) x
               JOIN dbo.serie_comprobante s ON s.serie = x.serie
               WHERE x.numero <> s.ultimo_numero + x.orden)  -- El 1.º nuevo debe ser último+1, el 2.º último+2…
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50008, N'El número del comprobante debe ser el siguiente de su serie (sin saltos ni repeticiones).', 1;
    END
    UPDATE s SET ultimo_numero = s.ultimo_numero + n.cantidad  -- Avanza el contador de la serie.
    FROM dbo.serie_comprobante s
    JOIN (SELECT serie, COUNT(*) AS cantidad FROM inserted GROUP BY serie) n ON n.serie = s.serie;
END
GO

-- Trigger 7: una SENTENCIA (especialización de RESOLUCION) solo puede colgar de una resolución final.
CREATE TRIGGER dbo.trg_sentencia_tipo ON dbo.sentencia
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.resolucion r ON r.id_resolucion = i.id_resolucion
               WHERE r.tipo_resolucion NOT IN ('SENTENCIA', 'LAUDO', 'ACTA_CONCILIACION', 'AUTO_FINAL'))
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50006, N'Una sentencia solo puede registrarse sobre una resolución SENTENCIA, LAUDO, ACTA_CONCILIACION o AUTO_FINAL.', 1;
    END
END
GO

-- Trigger 8: lo que se cobra en una línea debe ser del MISMO cliente del comprobante,
--            y un gasto solo se cobra si es reembolsable.
CREATE TRIGGER dbo.trg_detalle_comprobante_coherencia ON dbo.detalle_comprobante
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.comprobante c ON c.id_comprobante = i.id_comprobante
               JOIN dbo.cuota q       ON q.id_cuota = i.id_cuota
               JOIN dbo.contrato k    ON k.id_contrato = q.id_contrato
               WHERE k.id_cliente <> c.id_persona)  -- La cuota es de un contrato de otro cliente.
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50009, N'La cuota cobrada debe pertenecer a un contrato del mismo cliente del comprobante.', 1;
    END
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN dbo.comprobante c ON c.id_comprobante = i.id_comprobante
               JOIN dbo.gasto_caso g  ON g.id_gasto = i.id_gasto
               JOIN dbo.caso s        ON s.id_caso = g.id_caso
               JOIN dbo.contrato k    ON k.id_contrato = s.id_contrato
               WHERE g.es_reembolsable = 0 OR k.id_cliente <> c.id_persona)  -- Gasto no reembolsable o de otro cliente.
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50010, N'Solo se cobra un gasto reembolsable de un caso del mismo cliente del comprobante.', 1;
    END
END
GO

-- Trigger 9: quien firma un contrato debe tener DNI o RUC (una contraparte puede no tenerlo; un cliente, no).
CREATE TRIGGER dbo.trg_contrato_cliente_documento ON dbo.contrato
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.persona p ON p.id_persona = i.id_cliente WHERE p.nro_documento IS NULL)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50011, N'El cliente del contrato debe tener DNI o RUC registrado.', 1;
    END
END
GO

-- Trigger 10: el receptor de un comprobante debe tener DNI o RUC (lo exige SUNAT).
CREATE TRIGGER dbo.trg_comprobante_receptor_documento ON dbo.comprobante
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.persona p ON p.id_persona = i.id_persona WHERE p.nro_documento IS NULL)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50012, N'El receptor del comprobante debe tener DNI o RUC registrado.', 1;
    END
END
GO

-- ---------------------------------------------------------------------
-- 7. ÍNDICES
-- ---------------------------------------------------------------------
-- 7.1 Únicos filtrados. En SQL Server una restricción UNIQUE solo permite UN valor
--     NULL en toda la tabla. Para columnas opcionales que no deben repetirse, o para
--     reglas que solo valen en algunas filas, se usa un índice único con WHERE:
--     las filas que no cumplen el filtro no cuentan, las que lo cumplen no se repiten.
CREATE UNIQUE INDEX uq_entidad_nombre ON dbo.entidad (nombre, distrito_judicial) WHERE distrito_judicial IS NOT NULL;  -- Una entidad no se repite dentro de un distrito judicial; las que no tienen distrito quedan fuera de la regla.
CREATE UNIQUE INDEX uq_comprobante_id_consulta ON dbo.comprobante (id_consulta) WHERE id_consulta IS NOT NULL;  -- Una consulta se cobra en un solo comprobante; los comprobantes de cuotas lo dejan vacío.
CREATE UNIQUE INDEX uq_caso_etapa_abierta ON dbo.caso_etapa (id_caso) WHERE fecha_fin IS NULL;  -- Cada caso tiene a lo sumo UNA etapa abierta (fecha_fin vacía) a la vez.
CREATE UNIQUE INDEX uq_detalle_comprobante_gasto ON dbo.detalle_comprobante (id_gasto) WHERE id_gasto IS NOT NULL;  -- Un gasto se reembolsa en una sola línea de comprobante.
CREATE UNIQUE INDEX uq_persona_documento ON dbo.persona (tipo_documento, nro_documento) WHERE nro_documento IS NOT NULL;  -- Un documento no se repite; las contrapartes sin documento quedan fuera de la regla.
CREATE UNIQUE INDEX uq_usuario_empleado ON dbo.usuario (id_empleado) WHERE id_empleado IS NOT NULL;  -- Un empleado tiene a lo sumo una cuenta.
CREATE UNIQUE INDEX uq_usuario_persona ON dbo.usuario (id_persona) WHERE id_persona IS NOT NULL;  -- Un cliente tiene a lo sumo una cuenta del portal.
GO

-- 7.2 Índices de búsqueda. Funcionan como el índice de un libro: SQL Server encuentra
--     las filas sin revisar toda la tabla. Van en las columnas que más filtra el panel.
CREATE INDEX ix_consulta_estado     ON dbo.consulta (estado, fecha_hora_recepcion);  -- Bandeja de consultas por estado y fecha.
CREATE INDEX ix_caso_estado         ON dbo.caso (estado);  -- Casos activos / cerrados del dashboard.
CREATE INDEX ix_plazo_vencimiento   ON dbo.plazo (fecha_vencimiento) WHERE fecha_cumplimiento IS NULL;  -- Alertas de plazos por vencer (índice filtrado: solo los plazos aún no cumplidos).
CREATE INDEX ix_cuota_vencimiento   ON dbo.cuota (estado, fecha_vencimiento);  -- Recordatorios de cuotas por vencer.
CREATE INDEX ix_audiencia_fecha     ON dbo.audiencia (fecha_hora);  -- Agenda de audiencias.
CREATE INDEX ix_notificacion_pendiente ON dbo.notificacion (fecha_programada) WHERE estado = 'PENDIENTE';  -- Cola de avisos por enviar.
GO

-- ---------------------------------------------------------------------
-- 8. VISTAS
-- ---------------------------------------------------------------------
-- Una vista es una consulta guardada con nombre: se usa como si fuera una tabla,
-- pero sus datos se calculan en el momento. Así cumplimos la 3FN: el total, el
-- saldo, el estado de un plazo o de una cuota y la cuota litis NO se guardan
-- (son datos derivados). En SQL Server cada CREATE VIEW debe ser la primera
-- instrucción de su lote, por eso va un GO antes de cada una.

-- Vista 1: total de cada comprobante = suma de sus líneas + IGV (y monto de detracción).
CREATE VIEW dbo.vw_comprobante_total AS  -- Crea la vista con ese nombre.
SELECT c.id_comprobante, s.tipo_comprobante, c.serie, c.numero, c.id_persona, c.moneda,  -- Columnas que mostrará (el tipo sale de la serie).
       ROUND(SUM(d.cantidad * d.valor_unitario), 2)                    AS subtotal,  -- Suma cantidad × valor de cada línea.
       ROUND(SUM(d.cantidad * d.valor_unitario) * c.tasa_igv, 2)       AS igv,  -- IGV = subtotal × tasa (0.18).
       ROUND(SUM(d.cantidad * d.valor_unitario) * (1 + c.tasa_igv), 2) AS total,  -- Total = subtotal + IGV.
       ROUND(SUM(d.cantidad * d.valor_unitario) * (1 + c.tasa_igv) * c.porcentaje_detraccion, 2) AS detraccion  -- Parte del total que va a la cuenta de detracciones (0 si no aplica).
FROM dbo.comprobante c  -- Tabla principal: el comprobante.
JOIN dbo.serie_comprobante s ON s.serie = c.serie  -- Une cada comprobante con su serie para saber el tipo.
JOIN dbo.detalle_comprobante d ON d.id_comprobante = c.id_comprobante  -- Une cada comprobante con sus líneas.
GROUP BY c.id_comprobante, s.tipo_comprobante, c.serie, c.numero, c.id_persona, c.moneda, c.tasa_igv, c.porcentaje_detraccion;  -- Agrupa para sumar las líneas de cada comprobante.
GO

-- Vista 2: saldo y ESTADO DE PAGO de cada comprobante (el estado de pago ya no se guarda: se calcula aquí).
CREATE VIEW dbo.vw_comprobante_saldo AS  -- Crea la vista del saldo.
SELECT t.id_comprobante, t.serie, t.numero, t.total,
       COALESCE(p.pagado, 0)           AS pagado,  -- COALESCE (o ISNULL): si no hay pagos, usa 0.
       t.total - COALESCE(p.pagado, 0) AS saldo,  -- Lo que falta cobrar.
       CASE WHEN c.estado = 'ANULADO'             THEN 'ANULADO'  -- Lo único que sí se guarda es la anulación.
            WHEN COALESCE(p.pagado, 0) >= t.total THEN 'PAGADO'
            WHEN COALESCE(p.pagado, 0) > 0        THEN 'PAGADO_PARCIAL'
            ELSE 'PENDIENTE' END AS estado_pago  -- Calculado con los pagos: nunca queda desactualizado.
FROM dbo.vw_comprobante_total t  -- Usa la vista 1 (una vista puede usar otra).
JOIN dbo.comprobante c ON c.id_comprobante = t.id_comprobante  -- Para saber si está anulado.
LEFT JOIN (SELECT id_comprobante, SUM(monto) AS pagado  -- Subconsulta: total pagado por comprobante.
           FROM dbo.pago GROUP BY id_comprobante) p
       ON p.id_comprobante = t.id_comprobante;  -- LEFT JOIN: también muestra comprobantes sin pagos.
GO

-- Vista 3: estado de cada plazo, calculado con la fecha de hoy (el estado no se guarda).
CREATE VIEW dbo.vw_plazo_estado AS  -- Crea la vista del estado de los plazos.
SELECT p.id_plazo, p.id_caso, p.id_resolucion, p.id_empleado_responsable, p.descripcion,
       p.fecha_inicio, p.dias_plazo, p.tipo_computo, p.fecha_vencimiento, p.fecha_cumplimiento,  -- Datos del plazo tal como están guardados.
       CASE WHEN p.fecha_cumplimiento IS NOT NULL THEN 'CUMPLIDO'  -- Si tiene fecha de cumplimiento, está cumplido.
            WHEN p.fecha_vencimiento < CAST(GETDATE() AS DATE) THEN 'VENCIDO'  -- Sin cumplir y con fecha pasada: vencido.
            ELSE 'PENDIENTE' END AS estado  -- En cualquier otro caso: pendiente.
FROM dbo.plazo p;  -- Una fila por plazo.
GO

-- Vista 4: plazos pendientes que vencen en 5 días o menos (alertas del panel).
CREATE VIEW dbo.vw_plazos_por_vencer AS  -- Crea la vista de alertas.
SELECT p.id_plazo, p.id_caso, c.codigo_interno, c.nro_expediente_judicial, p.descripcion, p.fecha_vencimiento,
       e.nombres + N' ' + e.apellidos AS responsable,  -- A quién se le avisa.
       DATEDIFF(DAY, CAST(GETDATE() AS DATE), p.fecha_vencimiento) AS dias_restantes  -- DATEDIFF(DAY, desde, hasta): días que faltan desde hoy.
FROM dbo.plazo p JOIN dbo.caso c ON c.id_caso = p.id_caso  -- Une el plazo con su caso para mostrar el expediente.
JOIN dbo.empleado e ON e.id_empleado = p.id_empleado_responsable  -- Une con el empleado responsable.
WHERE p.fecha_cumplimiento IS NULL  -- Solo plazos no cumplidos...
  AND p.fecha_vencimiento <= DATEADD(DAY, 5, CAST(GETDATE() AS DATE));  -- ...que vencen dentro de 5 días (DATEADD suma días a hoy).
GO

-- Vista 5: estado de cada cuota; «VENCIDA» se calcula (no se guarda).
CREATE VIEW dbo.vw_cuota_estado AS  -- Crea la vista del estado de las cuotas.
SELECT q.id_cuota, q.id_contrato, q.nro_cuota, q.concepto, q.monto, q.fecha_vencimiento,  -- Datos de la cuota.
       CASE WHEN q.estado IN ('PENDIENTE', 'PAGADA_PARCIAL') AND q.fecha_vencimiento < CAST(GETDATE() AS DATE)  -- Debe algo y ya pasó la fecha...
            THEN 'VENCIDA' ELSE q.estado END AS estado  -- ...entonces está vencida; si no, se muestra el estado guardado.
FROM dbo.cuota q;  -- Una fila por cuota.
GO

-- Vista 6: cuota litis de cada liquidación = monto obtenido × porcentaje pactado en la propuesta.
CREATE VIEW dbo.vw_liquidacion_cuota_litis AS  -- Crea la vista de la cuota litis calculada.
SELECT l.id_liquidacion, l.id_caso, l.monto_obtenido, pr.porcentaje_cuota_litis,  -- Lo obtenido y el porcentaje pactado.
       ROUND(l.monto_obtenido * pr.porcentaje_cuota_litis / 100, 2) AS monto_cuota_litis  -- Cuota litis = obtenido × % / 100.
FROM dbo.liquidacion l  -- Tabla principal: la liquidación.
JOIN dbo.caso c ON c.id_caso = l.id_caso  -- Del caso...
JOIN dbo.contrato k ON k.id_contrato = c.id_contrato  -- ...al contrato...
JOIN dbo.propuesta pr ON pr.id_propuesta = k.id_propuesta;  -- ...a la propuesta aceptada, donde está el porcentaje.
GO

PRINT 'Base de datos magallanes_montero creada correctamente (36 tablas, 10 triggers, 6 vistas).';  -- Mensaje en la pestaña "Mensajes".
GO

-- ---------------------------------------------------------------------
-- 9. CONSULTAS DE EJEMPLO (están comentadas; selecciónalas sin los -- y pulsa F5
--    después de ejecutar datos_prueba_sqlserver.sql. En SSMS, si seleccionas
--    un trozo de texto, F5 ejecuta solo ese trozo.)
-- ---------------------------------------------------------------------
-- a) Saldo pendiente de cada comprobante:
-- SELECT serie, numero, total, pagado, saldo, estado_pago FROM dbo.vw_comprobante_saldo;
--
-- b) Plazos que vencen pronto (alerta del dashboard):
-- SELECT codigo_interno, descripcion, fecha_vencimiento, dias_restantes
-- FROM dbo.vw_plazos_por_vencer ORDER BY dias_restantes;
--
-- c) Casos activos por abogado (gráfico del dashboard):
-- SELECT e.nombres + N' ' + e.apellidos AS abogado, COUNT(*) AS casos_activos
-- FROM dbo.caso c JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable
-- WHERE c.estado = 'ACTIVO'
-- GROUP BY e.nombres, e.apellidos ORDER BY casos_activos DESC;
--
-- d) Conversión de consultas a contratos:
-- SELECT COUNT(*) AS consultas,
--        SUM(CASE WHEN estado = 'CONTRATADA' THEN 1 ELSE 0 END) AS contratadas,
--        CAST(100.0 * SUM(CASE WHEN estado = 'CONTRATADA' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS conversion_pct
-- FROM dbo.consulta;
--
-- e) Partes de un caso con su rol:
-- SELECT COALESCE(p.razon_social, p.nombres + N' ' + p.apellidos) AS persona, cp.tipo_parte, r.nombre AS rol
-- FROM dbo.caso_parte cp
-- JOIN dbo.persona p ON p.id_persona = cp.id_persona
-- JOIN dbo.rol_procesal r ON r.id_rol = cp.id_rol
-- WHERE cp.id_caso = 1;
--
-- f) Ver todas las tablas creadas:
-- SELECT name FROM sys.tables ORDER BY name;
--
-- g) Estado calculado de cada plazo (pendiente / cumplido / vencido):
-- SELECT id_caso, descripcion, fecha_vencimiento, estado FROM dbo.vw_plazo_estado ORDER BY fecha_vencimiento;
--
-- h) Gastos reembolsables que todavía no se cobraron al cliente:
-- SELECT c.codigo_interno, g.concepto, g.monto
-- FROM dbo.gasto_caso g JOIN dbo.caso c ON c.id_caso = g.id_caso
-- WHERE g.es_reembolsable = 1
--   AND NOT EXISTS (SELECT 1 FROM dbo.detalle_comprobante d WHERE d.id_gasto = g.id_gasto);
--
-- i) Empleados con cargo ABOGADO que aún no tienen su fila en ABOGADO (no pueden asignarse a casos):
-- SELECT e.id_empleado, e.nombres, e.apellidos
-- FROM dbo.empleado e LEFT JOIN dbo.abogado a ON a.id_empleado = e.id_empleado
-- WHERE e.cargo = 'ABOGADO' AND a.id_empleado IS NULL;
--
-- j) Cuotas vencidas (calculadas):
-- SELECT id_contrato, nro_cuota, monto, fecha_vencimiento FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA';
--
-- k) Cuota litis calculada de cada liquidación:
-- SELECT id_caso, monto_obtenido, porcentaje_cuota_litis, monto_cuota_litis FROM dbo.vw_liquidacion_cuota_litis;

