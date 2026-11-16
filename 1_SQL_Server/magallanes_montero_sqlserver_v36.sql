-- =====================================================================
-- Estudio Jurídico Magallanes-Montero · Modelo FÍSICO (SQL Server / T-SQL)
-- Curso: Base de Datos II · UTP
-- Ejecutar en SQL Server Management Studio (SSMS): abrir el archivo y pulsar F5.
-- Luego ejecutar magallanes_montero_datos_prueba_sqlserver.sql (datos de ejemplo).
-- 36 tablas · 10 triggers · 6 vistas · 13 índices
-- =====================================================================
-- ---------------------------------------------------------------------
-- 0. CREAR LA BASE DE DATOS
-- ---------------------------------------------------------------------
USE master;
GO
IF DB_ID(N'magallanes_montero') IS NOT NULL
BEGIN
    ALTER DATABASE magallanes_montero SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE magallanes_montero;
END
GO
CREATE DATABASE magallanes_montero COLLATE Modern_Spanish_CI_AS;
GO
USE magallanes_montero;
GO

-- ---------------------------------------------------------------------
-- 1. TABLAS MAESTRAS Y CATÁLOGOS
-- ---------------------------------------------------------------------

-- PERSONA  ·  Cliente, prospecto, contraparte o representante legal (natural, jurídica o entidad pública).
CREATE TABLE dbo.persona (
  id_persona INT IDENTITY(1,1) NOT NULL,  -- Identificador
  tipo_persona VARCHAR(8) NOT NULL,  -- Tipo de cliente
  tipo_documento VARCHAR(9) NULL,  -- VARCHAR(9) + CHECK: DNI, CE, PASAPORTE o RUC; opcional SOLO para contrapartes sin documento (un cliente debe tenerlo: triggers 9 y 10)
  nro_documento NVARCHAR(15) NULL,  -- DNI 8 dígitos / RUC 11; opcional SOLO para contrapartes (va junto con tipo_documento)
  nombres NVARCHAR(80) NULL,  -- Solo persona natural
  apellidos NVARCHAR(80) NULL,  -- Solo persona natural
  razon_social NVARCHAR(150) NULL,  -- Jurídica o entidad pública
  fecha_nacimiento DATE NULL,
  estado_civil VARCHAR(11) NULL,
  ocupacion NVARCHAR(80) NULL,
  telefono NVARCHAR(20) NULL,  -- WhatsApp
  email NVARCHAR(120) NULL,
  direccion NVARCHAR(200) NULL,  -- Domicilio real o fiscal
  acepta_tratamiento_datos BIT NOT NULL CONSTRAINT df_persona_acepta_tratamiento_datos DEFAULT 0,  -- Ley 29733
  id_representante INT NULL,  -- Representante legal (R03)
  fecha_registro DATETIME2(0) NOT NULL CONSTRAINT df_persona_fecha_registro DEFAULT SYSDATETIME(),
  CONSTRAINT pk_persona PRIMARY KEY (id_persona),
  CONSTRAINT ck_persona_tipo_persona CHECK (tipo_persona IN ('NATURAL', 'JURIDICA', 'PUBLICA')),
  CONSTRAINT ck_persona_tipo_documento CHECK (tipo_documento IN ('DNI', 'CE', 'PASAPORTE', 'RUC')),
  CONSTRAINT ck_persona_estado_civil CHECK (estado_civil IN ('SOLTERO', 'CASADO', 'CONVIVIENTE', 'DIVORCIADO', 'VIUDO')),
  CONSTRAINT ck_persona_1 CHECK ((tipo_persona = 'NATURAL' AND nombres IS NOT NULL AND apellidos IS NOT NULL) OR (tipo_persona <> 'NATURAL' AND razon_social IS NOT NULL AND (tipo_documento = 'RUC' OR tipo_documento IS NULL))),  -- Regla: natural → nombres y apellidos; empresa o entidad → razón social y, si tiene documento, RUC.
  CONSTRAINT ck_persona_documento CHECK ((tipo_documento IS NULL AND nro_documento IS NULL) OR (tipo_documento IS NOT NULL AND nro_documento IS NOT NULL)),  -- Regla: tipo y número de documento van juntos (los dos o ninguno).
  CONSTRAINT fk_persona_id_representante FOREIGN KEY (id_representante) REFERENCES dbo.persona(id_persona)  -- Relación recursiva con la misma tabla
);
GO

-- EMPLEADO  ·  Personal del estudio: abogado, secretaria, practicante, administrador. Los abogados además tienen una fila en ABOGADO (ahí está su colegiatura).
CREATE TABLE dbo.empleado (
  id_empleado INT IDENTITY(1,1) NOT NULL,
  dni CHAR(8) NOT NULL,
  nombres NVARCHAR(80) NOT NULL,
  apellidos NVARCHAR(80) NOT NULL,
  cargo VARCHAR(13) NOT NULL,  -- Carril del BPMN
  telefono NVARCHAR(20) NULL,
  email NVARCHAR(120) NOT NULL,  -- Correo de trabajo; no se puede repetir (el login está en USUARIO)
  activo BIT NOT NULL CONSTRAINT df_empleado_activo DEFAULT 1,
  CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
  CONSTRAINT uq_empleado_dni UNIQUE (dni),
  CONSTRAINT uq_empleado_email UNIQUE (email),
  CONSTRAINT ck_empleado_cargo CHECK (cargo IN ('ABOGADO', 'SECRETARIA', 'PRACTICANTE', 'ADMINISTRADOR'))
);
GO

-- ABOGADO  ·  Especialización 1:1 de EMPLEADO: solo los empleados con cargo ABOGADO. Aquí vive el número de colegiatura (CAL).
-- Nota: cita, propuesta, liquidación, audiencia y el abogado responsable del caso apuntan a ABOGADO y no a EMPLEADO, así un practicante o una secretaria no pueden figurar como abogados. La colegiatura es obligatoria aquí y no queda como columna vacía en EMPLEADO.
CREATE TABLE dbo.abogado (
  id_empleado INT NOT NULL,  -- Misma llave que el empleado (1:1)
  nro_colegiatura NVARCHAR(15) NOT NULL,  -- Colegiatura CAL
  CONSTRAINT pk_abogado PRIMARY KEY (id_empleado),
  CONSTRAINT uq_abogado_nro_colegiatura UNIQUE (nro_colegiatura),
  CONSTRAINT fk_abogado_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)  -- El trigger trg_abogado_cargo exige además cargo = ABOGADO
);
GO


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

-- MATERIA  ·  Rama del derecho: civil, penal, laboral, familia, etc.
CREATE TABLE dbo.materia (
  id_materia SMALLINT IDENTITY(1,1) NOT NULL,
  nombre NVARCHAR(60) NOT NULL,  -- Civil, Penal, Laboral…
  descripcion NVARCHAR(200) NULL,
  CONSTRAINT pk_materia PRIMARY KEY (id_materia),
  CONSTRAINT uq_materia_nombre UNIQUE (nombre)
);
GO

-- ROL_PROCESAL  ·  Catálogo de los 24 roles (demandante, imputado, administrado…) agrupados por familia.
CREATE TABLE dbo.rol_procesal (
  id_rol SMALLINT IDENTITY(1,1) NOT NULL,
  nombre NVARCHAR(60) NOT NULL,  -- Demandante, Imputado…
  familia VARCHAR(22) NOT NULL,  -- 8 ramas del P2
  CONSTRAINT pk_rol_procesal PRIMARY KEY (id_rol),
  CONSTRAINT uq_rol_procesal_nombre UNIQUE (nombre),
  CONSTRAINT ck_rol_procesal_familia CHECK (familia IN ('CIVIL_ACTIVA', 'CIVIL_PASIVA', 'PENAL_ACUSA', 'PENAL_INVESTIGADA', 'VIOLENCIA_30364', 'ADMINISTRATIVO', 'CONCILIACION_ARBITRAJE', 'TRAMITE'))
);
GO

-- ETAPA_PROCESAL  ·  Catálogo de etapas: consulta inicial, primera instancia, apelación, ejecución, cerrado…
CREATE TABLE dbo.etapa_procesal (
  id_etapa SMALLINT IDENTITY(1,1) NOT NULL,
  nombre NVARCHAR(60) NOT NULL,
  orden TINYINT NOT NULL,  -- Secuencia sugerida
  CONSTRAINT pk_etapa_procesal PRIMARY KEY (id_etapa),
  CONSTRAINT uq_etapa_procesal_nombre UNIQUE (nombre)
);
GO

-- ENTIDAD  ·  Juzgado, fiscalía, entidad administrativa o centro de conciliación/arbitraje.
CREATE TABLE dbo.entidad (
  id_entidad INT IDENTITY(1,1) NOT NULL,
  nombre NVARCHAR(150) NOT NULL,
  tipo_entidad VARCHAR(19) NOT NULL,
  distrito_judicial NVARCHAR(60) NULL,
  direccion NVARCHAR(200) NULL,
  CONSTRAINT pk_entidad PRIMARY KEY (id_entidad),
  CONSTRAINT ck_entidad_tipo_entidad CHECK (tipo_entidad IN ('JUZGADO', 'SALA', 'FISCALIA', 'ADMINISTRATIVA', 'CENTRO_CONCILIACION', 'TRIBUNAL_ARBITRAL', 'REGISTRAL_NOTARIAL'))
);
GO

-- JURISPRUDENCIA  ·  Leyes, casaciones y precedentes que se citan en los escritos.
CREATE TABLE dbo.jurisprudencia (
  id_jurisprudencia INT IDENTITY(1,1) NOT NULL,
  id_materia SMALLINT NOT NULL,  -- R23
  tipo VARCHAR(10) NOT NULL,
  referencia NVARCHAR(80) NOT NULL,  -- Ej.: Cas. 1234-2019-Lima
  titulo NVARCHAR(200) NOT NULL,
  fecha_publicacion DATE NULL,
  url_fuente NVARCHAR(300) NULL,
  CONSTRAINT pk_jurisprudencia PRIMARY KEY (id_jurisprudencia),
  CONSTRAINT uq_jurisprudencia_referencia UNIQUE (referencia),
  CONSTRAINT ck_jurisprudencia_tipo CHECK (tipo IN ('LEY', 'CASACION', 'PRECEDENTE', 'PLENO', 'DOCTRINA')),
  CONSTRAINT fk_jurisprudencia_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia)
);
GO

-- FERIADO  ·  Feriados y días no laborables. Sirven para calcular el vencimiento de los plazos hábiles (PLAZO.tipo_computo = HABIL).
CREATE TABLE dbo.feriado (
  fecha DATE NOT NULL,  -- Día feriado o no laborable
  descripcion NVARCHAR(100) NOT NULL,  -- Ej.: Fiestas Patrias
  CONSTRAINT pk_feriado PRIMARY KEY (fecha)
);
GO

-- ---------------------------------------------------------------------
-- 2. PROCESO 1 · CAPTACIÓN, CONSULTA Y APERTURA
-- ---------------------------------------------------------------------

-- CONSULTA  ·  Solicitud de asesoría que llega por WhatsApp, redes, landing o llamada.
CREATE TABLE dbo.consulta (
  id_consulta INT IDENTITY(1,1) NOT NULL,
  id_persona INT NOT NULL,  -- Quien consulta (R01)
  id_materia SMALLINT NOT NULL,  -- R05
  id_registrado_por INT NULL,  -- FK → empleado: quién la registró (secretaria); NULL si llegó sola por la landing (R04)
  canal VARCHAR(10) NOT NULL,
  fecha_hora_recepcion DATETIME2(0) NOT NULL CONSTRAINT df_consulta_fecha_hora_recepcion DEFAULT SYSDATETIME(),
  resumen NVARCHAR(500) NOT NULL,  -- Tema de la consulta
  es_urgente BIT NOT NULL CONSTRAINT df_consulta_es_urgente DEFAULT 0,
  existe_conflicto BIT NULL,  -- NULL = aún no revisado
  id_revisor_conflicto INT NULL,  -- FK → abogado: el abogado que revisó el conflicto de intereses; opcional
  fecha_revision_conflicto DATETIME2(0) NULL,  -- Cuándo se revisó
  detalle_conflicto NVARCHAR(500) NULL,  -- Qué se encontró (obligatorio si existe conflicto)
  monto_consulta DECIMAL(10,2) NOT NULL CONSTRAINT df_consulta_monto_consulta DEFAULT 0.00,  -- Costo informado
  estado VARCHAR(13) NOT NULL CONSTRAINT df_consulta_estado DEFAULT 'RECIBIDA',
  CONSTRAINT pk_consulta PRIMARY KEY (id_consulta),
  CONSTRAINT ck_consulta_canal CHECK (canal IN ('WHATSAPP', 'FACEBOOK', 'INSTAGRAM', 'LANDING', 'LLAMADA', 'PRESENCIAL')),
  CONSTRAINT ck_consulta_estado CHECK (estado IN ('RECIBIDA', 'NO_ATENDIDA', 'AGENDADA', 'ATENDIDA', 'CON_CONFLICTO', 'PROPUESTA', 'CONTRATADA', 'RECHAZADA', 'ARCHIVADA')),
  CONSTRAINT ck_consulta_conflicto_revision CHECK (existe_conflicto IS NULL OR (id_revisor_conflicto IS NOT NULL AND fecha_revision_conflicto IS NOT NULL)),  -- Regla: si ya se revisó el conflicto (0 o 1), debe constar quién y cuándo.
  CONSTRAINT ck_consulta_conflicto_detalle CHECK (existe_conflicto IS NULL OR existe_conflicto = 0 OR detalle_conflicto IS NOT NULL),  -- Regla: si existe conflicto, debe describirse.
  CONSTRAINT fk_consulta_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),
  CONSTRAINT fk_consulta_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia),
  CONSTRAINT ck_consulta_registro CHECK (canal = 'LANDING' OR id_registrado_por IS NOT NULL),  -- Regla: si no llegó por la landing, alguien del estudio la registró.
  CONSTRAINT fk_consulta_id_registrado_por FOREIGN KEY (id_registrado_por) REFERENCES dbo.empleado(id_empleado),  -- FK: quien registra debe existir en empleado.
  CONSTRAINT fk_consulta_id_revisor_conflicto FOREIGN KEY (id_revisor_conflicto) REFERENCES dbo.abogado(id_empleado)  -- FK a ABOGADO: solo un abogado revisa conflictos.
);
GO

-- CONSULTA_CONTRAPARTE  ·  Tabla intermedia: resuelve la relación M:N «una consulta menciona varias contrapartes y una persona puede ser contraparte en varias consultas».
CREATE TABLE dbo.consulta_contraparte (
  id_consulta INT NOT NULL,
  id_persona INT NOT NULL,  -- Contraparte mencionada
  CONSTRAINT pk_consulta_contraparte PRIMARY KEY (id_consulta, id_persona),
  CONSTRAINT fk_consulta_contraparte_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),
  CONSTRAINT fk_consulta_contraparte_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona)
);
GO

-- CITA  ·  Reunión agendada para atender la consulta (incluye reprogramaciones).
CREATE TABLE dbo.cita (
  id_cita INT IDENTITY(1,1) NOT NULL,
  id_consulta INT NOT NULL,  -- R06
  id_abogado INT NOT NULL,  -- R07
  fecha_hora DATETIME2(0) NOT NULL,
  modalidad VARCHAR(10) NOT NULL CONSTRAINT df_cita_modalidad DEFAULT 'PRESENCIAL',
  recordatorio_enviado BIT NOT NULL CONSTRAINT df_cita_recordatorio_enviado DEFAULT 0,  -- Recordatorio 1 día antes
  estado VARCHAR(12) NOT NULL CONSTRAINT df_cita_estado DEFAULT 'PROGRAMADA',
  CONSTRAINT pk_cita PRIMARY KEY (id_cita),
  CONSTRAINT ck_cita_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL')),
  CONSTRAINT ck_cita_estado CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'REPROGRAMADA', 'CANCELADA', 'ASISTIO', 'NO_ASISTIO')),
  CONSTRAINT fk_cita_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),
  CONSTRAINT fk_cita_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)
);
GO

-- PROPUESTA  ·  Propuesta de honorarios; puede tener varias versiones por negociación.
CREATE TABLE dbo.propuesta (
  id_propuesta INT IDENTITY(1,1) NOT NULL,
  id_consulta INT NOT NULL,  -- R08
  id_abogado INT NOT NULL,  -- R09
  version TINYINT NOT NULL CONSTRAINT df_propuesta_version DEFAULT 1,  -- Negociación
  monto_honorarios DECIMAL(12,2) NOT NULL,  -- 0 si es pro bono
  porcentaje_cuota_litis DECIMAL(5,2) NOT NULL CONSTRAINT df_propuesta_porcentaje_cuota_litis DEFAULT 0.00,  -- Honorario de éxito
  nro_cuotas TINYINT NOT NULL CONSTRAINT df_propuesta_nro_cuotas DEFAULT 1,
  fecha_envio DATE NOT NULL,
  fecha_respuesta DATE NULL,
  estado VARCHAR(14) NOT NULL CONSTRAINT df_propuesta_estado DEFAULT 'ENVIADA',
  CONSTRAINT pk_propuesta PRIMARY KEY (id_propuesta),
  CONSTRAINT uq_propuesta_version UNIQUE (id_consulta, version),
  CONSTRAINT ck_propuesta_estado CHECK (estado IN ('ENVIADA', 'EN_NEGOCIACION', 'ACEPTADA', 'RECHAZADA', 'SIN_RESPUESTA')),
  CONSTRAINT ck_propuesta_1 CHECK (porcentaje_cuota_litis BETWEEN 0 AND 100),  -- Regla: El porcentaje de cuota litis va de 0 a 100.
  CONSTRAINT ck_propuesta_2 CHECK (monto_honorarios >= 0),  -- Regla: Los honorarios no pueden ser negativos (0 = pro bono).
  CONSTRAINT fk_propuesta_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),
  CONSTRAINT fk_propuesta_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)
);
GO

-- CONTRATO  ·  Contrato de servicios firmado a partir de la propuesta aceptada.
CREATE TABLE dbo.contrato (
  id_contrato INT IDENTITY(1,1) NOT NULL,
  id_propuesta INT NOT NULL,  -- R10 (1:1)
  id_cliente INT NOT NULL,  -- Quién contrata: el cliente del caso (puede no ser quien hizo la consulta)
  nro_contrato NVARCHAR(20) NOT NULL,
  fecha_firma DATE NOT NULL,
  tipo_encargo VARCHAR(14) NOT NULL,
  modalidad_pago VARCHAR(14) NOT NULL,
  con_carta_poder BIT NOT NULL CONSTRAINT df_contrato_con_carta_poder DEFAULT 0,
  archivo_mongo_id CHAR(24) NULL,  -- PDF firmado en MongoDB
  CONSTRAINT pk_contrato PRIMARY KEY (id_contrato),
  CONSTRAINT uq_contrato_id_propuesta UNIQUE (id_propuesta),
  CONSTRAINT uq_contrato_nro_contrato UNIQUE (nro_contrato),
  CONSTRAINT ck_contrato_tipo_encargo CHECK (tipo_encargo IN ('PATROCINIO', 'REPRESENTACION', 'TRAMITE', 'PRO_BONO')),
  CONSTRAINT ck_contrato_modalidad_pago CHECK (modalidad_pago IN ('UNICO', 'CUOTAS', 'IGUALA_MENSUAL')),
  CONSTRAINT fk_contrato_id_propuesta FOREIGN KEY (id_propuesta) REFERENCES dbo.propuesta(id_propuesta),
  CONSTRAINT fk_contrato_id_cliente FOREIGN KEY (id_cliente) REFERENCES dbo.persona(id_persona)
);
GO

-- CUOTA  ·  Cronograma de cobro: adelanto, cuotas, saldo o cuota litis.
CREATE TABLE dbo.cuota (
  id_cuota INT IDENTITY(1,1) NOT NULL,
  id_contrato INT NOT NULL,  -- R11
  id_liquidacion INT NULL,  -- R37 (solo saldo / cuota litis)
  nro_cuota TINYINT NOT NULL,
  concepto VARCHAR(11) NOT NULL,
  monto DECIMAL(12,2) NOT NULL,
  fecha_vencimiento DATE NOT NULL,  -- Dispara el recordatorio
  estado VARCHAR(14) NOT NULL CONSTRAINT df_cuota_estado DEFAULT 'PENDIENTE',  -- «Vencida» no se guarda: la calcula la vista vw_cuota_estado
  CONSTRAINT pk_cuota PRIMARY KEY (id_cuota),
  CONSTRAINT uq_cuota_nro UNIQUE (id_contrato, nro_cuota),
  CONSTRAINT ck_cuota_concepto CHECK (concepto IN ('ADELANTO', 'CUOTA', 'IGUALA', 'SALDO', 'CUOTA_LITIS')),
  CONSTRAINT ck_cuota_estado CHECK (estado IN ('PENDIENTE', 'PAGADA_PARCIAL', 'PAGADA', 'FRACCIONADA')),
  CONSTRAINT ck_cuota_1 CHECK (monto > 0),  -- Regla: Toda cuota debe ser mayor a cero.
  CONSTRAINT fk_cuota_id_contrato FOREIGN KEY (id_contrato) REFERENCES dbo.contrato(id_contrato)
);
GO
-- ---------------------------------------------------------------------
-- 3. PROCESO 2 · GESTIÓN DEL EXPEDIENTE
-- ---------------------------------------------------------------------

-- CASO  ·  Expediente del cliente (interno y judicial).
CREATE TABLE dbo.caso (
  id_caso INT IDENTITY(1,1) NOT NULL,
  id_contrato INT NOT NULL,  -- R12 (1:1)
  id_materia SMALLINT NOT NULL,  -- R13
  id_abogado_responsable INT NOT NULL,  -- R14
  codigo_interno NVARCHAR(20) NOT NULL,  -- Ej.: EXP-2026-0001
  nro_expediente_judicial NVARCHAR(40) NULL,  -- Nro. de expediente o carpeta fiscal
  descripcion NVARCHAR(500) NOT NULL,
  es_alta_complejidad BIT NOT NULL CONSTRAINT df_caso_es_alta_complejidad DEFAULT 0,
  estado VARCHAR(9) NOT NULL CONSTRAINT df_caso_estado DEFAULT 'ACTIVO',
  fecha_apertura DATE NOT NULL,
  fecha_cierre DATE NULL,
  expediente_mongo_id CHAR(24) NULL,  -- Expediente digital (NoSQL)
  CONSTRAINT pk_caso PRIMARY KEY (id_caso),
  CONSTRAINT uq_caso_id_contrato UNIQUE (id_contrato),
  CONSTRAINT uq_caso_codigo_interno UNIQUE (codigo_interno),
  CONSTRAINT ck_caso_estado CHECK (estado IN ('ACTIVO', 'EN_ESPERA', 'CERRADO', 'ARCHIVADO')),
  CONSTRAINT ck_caso_1 CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura),  -- Regla: La fecha de cierre no puede ser anterior a la de apertura.
  CONSTRAINT fk_caso_id_contrato FOREIGN KEY (id_contrato) REFERENCES dbo.contrato(id_contrato),
  CONSTRAINT fk_caso_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia),
  CONSTRAINT fk_caso_id_abogado_responsable FOREIGN KEY (id_abogado_responsable) REFERENCES dbo.abogado(id_empleado)
);
GO

-- ABOGADO_MATERIA  ·  Tabla intermedia: resuelve la M:N «un abogado domina varias materias y una materia tiene varios abogados».
CREATE TABLE dbo.abogado_materia (
  id_abogado INT NOT NULL,
  id_materia SMALLINT NOT NULL,
  es_principal BIT NOT NULL CONSTRAINT df_abogado_materia_es_principal DEFAULT 0,
  CONSTRAINT pk_abogado_materia PRIMARY KEY (id_abogado, id_materia),
  CONSTRAINT fk_abogado_materia_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado),
  CONSTRAINT fk_abogado_materia_id_materia FOREIGN KEY (id_materia) REFERENCES dbo.materia(id_materia)
);
GO

-- CASO_PARTE  ·  Tabla intermedia de la relación ternaria CASO–PERSONA–ROL: quién participa en cada caso y con qué rol.
CREATE TABLE dbo.caso_parte (
  id_caso INT NOT NULL,
  id_persona INT NOT NULL,
  id_rol SMALLINT NOT NULL,  -- Rol en este caso (una persona puede tener varios roles)
  tipo_parte VARCHAR(11) NOT NULL,
  abogado_externo NVARCHAR(120) NULL,  -- Abogado de la contraparte
  CONSTRAINT pk_caso_parte PRIMARY KEY (id_caso, id_persona, id_rol),  -- la misma persona puede tener dos roles en un caso (p. ej. agraviado y actor civil).
  CONSTRAINT ck_caso_parte_tipo_parte CHECK (tipo_parte IN ('CLIENTE', 'CONTRAPARTE', 'TERCERO')),
  CONSTRAINT fk_caso_parte_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_caso_parte_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),
  CONSTRAINT fk_caso_parte_id_rol FOREIGN KEY (id_rol) REFERENCES dbo.rol_procesal(id_rol)
);
GO

-- CASO_ETAPA  ·  Tabla intermedia: historial de etapas por las que pasa cada caso (con fecha de inicio y fin). Una etapa puede repetirse (subsanación, nueva audiencia); solo hay una etapa abierta por caso.
CREATE TABLE dbo.caso_etapa (
  id_caso_etapa INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,
  id_etapa SMALLINT NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NULL,  -- NULL = etapa actual
  CONSTRAINT pk_caso_etapa PRIMARY KEY (id_caso_etapa),
  CONSTRAINT uq_caso_etapa_inicio UNIQUE (id_caso, id_etapa, fecha_inicio),
  CONSTRAINT ck_caso_etapa_1 CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),  -- Regla: Una etapa no puede terminar antes de empezar.
  CONSTRAINT fk_caso_etapa_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_caso_etapa_id_etapa FOREIGN KEY (id_etapa) REFERENCES dbo.etapa_procesal(id_etapa)
);
GO

-- DOCUMENTO_LEGAL  ·  Escrito elaborado por el estudio: demanda, contestación, recurso, subsanación…
CREATE TABLE dbo.documento_legal (
  id_documento INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R18
  id_redactor INT NOT NULL,  -- R19
  id_revisor INT NULL,  -- R20
  id_documento_origen INT NULL,  -- R22 (subsana a; debe ser del mismo caso)
  tipo_documento VARCHAR(14) NOT NULL,
  titulo NVARCHAR(200) NOT NULL,  -- Sumilla
  version TINYINT NOT NULL CONSTRAINT df_documento_legal_version DEFAULT 1,
  elaborado_con_ia BIT NOT NULL CONSTRAINT df_documento_legal_elaborado_con_ia DEFAULT 0,  -- Borrador con ChatGPT
  requiere_firma_cliente BIT NOT NULL CONSTRAINT df_documento_legal_requiere_firma_cliente DEFAULT 0,
  fecha_creacion DATETIME2(0) NOT NULL CONSTRAINT df_documento_legal_fecha_creacion DEFAULT SYSDATETIME(),
  fecha_aprobacion DATETIME2(0) NULL,
  estado VARCHAR(11) NOT NULL CONSTRAINT df_documento_legal_estado DEFAULT 'BORRADOR',
  archivo_mongo_id CHAR(24) NULL,  -- Contenido del escrito (NoSQL)
  CONSTRAINT pk_documento_legal PRIMARY KEY (id_documento),
  CONSTRAINT uq_documento_legal_caso UNIQUE (id_caso, id_documento),  -- Permite la llave foránea compuesta de abajo: un escrito solo puede subsanar a otro del mismo caso.
  CONSTRAINT ck_documento_legal_tipo_documento CHECK (tipo_documento IN ('DEMANDA', 'CONTESTACION', 'DENUNCIA', 'DESCARGO', 'RECURSO', 'SUBSANACION', 'ABSOLUCION', 'SOLICITUD', 'ESCRITO_SIMPLE')),
  CONSTRAINT ck_documento_legal_estado CHECK (estado IN ('BORRADOR', 'EN_REVISION', 'OBSERVADO', 'APROBADO', 'PRESENTADO')),
  CONSTRAINT fk_documento_legal_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_documento_legal_id_redactor FOREIGN KEY (id_redactor) REFERENCES dbo.empleado(id_empleado),
  CONSTRAINT fk_documento_legal_id_revisor FOREIGN KEY (id_revisor) REFERENCES dbo.abogado(id_empleado),
  CONSTRAINT fk_documento_legal_id_documento_origen FOREIGN KEY (id_caso, id_documento_origen) REFERENCES dbo.documento_legal(id_caso, id_documento)  -- FK compuesta: el escrito de origen debe existir y ser del mismo caso (relación recursiva); si id_documento_origen es NULL no se valida.
);
GO

-- DOCUMENTO_JURISPRUDENCIA  ·  Tabla intermedia: qué leyes o casaciones cita cada escrito y para qué.
CREATE TABLE dbo.documento_jurisprudencia (
  id_documento INT NOT NULL,
  id_jurisprudencia INT NOT NULL,
  nota NVARCHAR(300) NULL,  -- Para qué se cita
  CONSTRAINT pk_documento_jurisprudencia PRIMARY KEY (id_documento, id_jurisprudencia),
  CONSTRAINT fk_documento_jurisprudencia_id_documento FOREIGN KEY (id_documento) REFERENCES dbo.documento_legal(id_documento),
  CONSTRAINT fk_documento_jurisprudencia_id_jurisprudencia FOREIGN KEY (id_jurisprudencia) REFERENCES dbo.jurisprudencia(id_jurisprudencia)
);
GO

-- PRESENTACION  ·  Ingreso de un escrito ante una entidad (física o electrónica), con su cargo.
CREATE TABLE dbo.presentacion (
  id_presentacion INT IDENTITY(1,1) NOT NULL,
  id_documento INT NOT NULL,  -- R24
  id_entidad INT NOT NULL,  -- R25
  id_empleado INT NOT NULL,  -- R26
  fecha_hora DATETIME2(0) NOT NULL,
  modalidad VARCHAR(11) NOT NULL,
  nro_cargo NVARCHAR(40) NULL,
  CONSTRAINT pk_presentacion PRIMARY KEY (id_presentacion),
  CONSTRAINT ck_presentacion_modalidad CHECK (modalidad IN ('FISICA', 'ELECTRONICA')),
  CONSTRAINT fk_presentacion_id_documento FOREIGN KEY (id_documento) REFERENCES dbo.documento_legal(id_documento),
  CONSTRAINT fk_presentacion_id_entidad FOREIGN KEY (id_entidad) REFERENCES dbo.entidad(id_entidad),
  CONSTRAINT fk_presentacion_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)
);
GO

-- GASTO_CASO  ·  Gastos del caso: tasas judiciales, aranceles, peritajes, copias certificadas. Reemplaza a presentacion.monto_tasa y permite cobrarlos al cliente.
CREATE TABLE dbo.gasto_caso (
  id_gasto INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- A qué caso pertenece el gasto
  id_presentacion INT NULL,  -- Escrito que originó el gasto (p. ej. la tasa de la demanda)
  id_empleado INT NOT NULL,  -- Quién registró o adelantó el gasto
  fecha DATE NOT NULL,
  concepto NVARCHAR(100) NOT NULL,  -- Ej.: Tasa judicial por apelación
  monto DECIMAL(10,2) NOT NULL,
  es_reembolsable BIT NOT NULL CONSTRAINT df_gasto_caso_es_reembolsable DEFAULT 1,  -- 1 = el cliente debe reembolsarlo; 0 = lo asume el estudio
  CONSTRAINT pk_gasto_caso PRIMARY KEY (id_gasto),
  CONSTRAINT ck_gasto_caso_1 CHECK (monto > 0),  -- Regla: todo gasto debe ser mayor a cero.
  CONSTRAINT fk_gasto_caso_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_gasto_caso_id_presentacion FOREIGN KEY (id_presentacion) REFERENCES dbo.presentacion(id_presentacion),  -- El trigger trg_gasto_caso_mismo_caso exige que sea del mismo caso
  CONSTRAINT fk_gasto_caso_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)
);
GO


-- RESOLUCION  ·  Lo que notifica la entidad: admisorio, inadmisible, traslado, citación, sentencia…
CREATE TABLE dbo.resolucion (
  id_resolucion INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R27
  id_entidad INT NOT NULL,  -- R28
  id_presentacion INT NULL,  -- R29
  nro_resolucion NVARCHAR(30) NULL,
  tipo_resolucion VARCHAR(17) NOT NULL,
  fecha_notificacion DATE NOT NULL,
  medio_notificacion VARCHAR(22) NOT NULL,
  sumilla NVARCHAR(300) NULL,
  archivo_mongo_id CHAR(24) NULL,  -- PDF de la resolución (NoSQL)
  CONSTRAINT pk_resolucion PRIMARY KEY (id_resolucion),
  CONSTRAINT uq_resolucion_caso UNIQUE (id_caso, id_resolucion),  -- Permite la llave foránea compuesta de PLAZO: un plazo solo puede apoyarse en una resolución de su mismo caso.
  CONSTRAINT ck_resolucion_tipo_resolucion CHECK (tipo_resolucion IN ('ADMISORIO', 'INADMISIBLE', 'IMPROCEDENTE', 'TRASLADO', 'REQUERIMIENTO', 'CITACION', 'DECRETO', 'ACTA_CONCILIACION', 'SENTENCIA', 'LAUDO', 'AUTO_FINAL')),
  CONSTRAINT ck_resolucion_medio_notificacion CHECK (medio_notificacion IN ('SINOE', 'CEDULA', 'CASILLA_ADMINISTRATIVA', 'CORREO', 'CEJ')),
  CONSTRAINT fk_resolucion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_resolucion_id_entidad FOREIGN KEY (id_entidad) REFERENCES dbo.entidad(id_entidad),
  CONSTRAINT fk_resolucion_id_presentacion FOREIGN KEY (id_presentacion) REFERENCES dbo.presentacion(id_presentacion)
);
GO

-- PLAZO  ·  Plazo procesal con fecha de vencimiento que el sistema alerta. El estado (pendiente / cumplido / vencido) NO se guarda: lo calcula vw_plazo_estado.
CREATE TABLE dbo.plazo (
  id_plazo INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R30
  id_resolucion INT NULL,  -- R31
  id_empleado_responsable INT NOT NULL,  -- A quién se le envía la alerta
  id_presentacion_cumplimiento INT NULL,  -- Escrito con el que se cumplió el plazo (del mismo caso)
  descripcion NVARCHAR(200) NOT NULL,  -- Ej.: contestar demanda
  fecha_inicio DATE NOT NULL,
  dias_plazo SMALLINT NOT NULL,  -- Cantidad de días del plazo (p. ej. 10)
  tipo_computo VARCHAR(10) NOT NULL,  -- HABIL no cuenta sábados, domingos ni FERIADO
  fecha_vencimiento DATE NOT NULL,
  fecha_cumplimiento DATE NULL,
  CONSTRAINT pk_plazo PRIMARY KEY (id_plazo),
  CONSTRAINT ck_plazo_tipo_computo CHECK (tipo_computo IN ('HABIL', 'CALENDARIO')),
  CONSTRAINT ck_plazo_dias CHECK (dias_plazo > 0),  -- Regla: el plazo dura al menos un día.
  CONSTRAINT ck_plazo_calendario CHECK (tipo_computo <> 'CALENDARIO' OR fecha_vencimiento = DATEADD(DAY, dias_plazo, fecha_inicio)),  -- Regla: en un plazo calendario el vencimiento es exactamente inicio + días (el hábil necesita la tabla FERIADO y se calcula en la aplicación).
  CONSTRAINT ck_plazo_1 CHECK (fecha_vencimiento >= fecha_inicio),  -- Regla: El vencimiento no puede ser anterior al inicio del plazo.
  CONSTRAINT fk_plazo_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_plazo_id_resolucion FOREIGN KEY (id_caso, id_resolucion) REFERENCES dbo.resolucion(id_caso, id_resolucion),  -- FK compuesta: si hay resolución, debe ser del mismo caso del plazo (si id_resolucion es NULL no se valida).
  CONSTRAINT fk_plazo_id_empleado_responsable FOREIGN KEY (id_empleado_responsable) REFERENCES dbo.empleado(id_empleado),
  CONSTRAINT fk_plazo_id_presentacion_cumplimiento FOREIGN KEY (id_presentacion_cumplimiento) REFERENCES dbo.presentacion(id_presentacion)  -- El trigger trg_plazo_mismo_caso exige que sea del mismo caso
);
GO

-- AUDIENCIA  ·  Audiencia (judicial o de conciliación) y sus reprogramaciones.
CREATE TABLE dbo.audiencia (
  id_audiencia INT IDENTITY(1,1) NOT NULL,
  id_resolucion INT NOT NULL,  -- R32 (citación)
  id_abogado INT NOT NULL,  -- R33
  fecha_hora DATETIME2(0) NOT NULL,
  modalidad VARCHAR(10) NOT NULL,  -- Juzgado o Google Meet
  tipo_audiencia VARCHAR(14) NOT NULL,
  estado VARCHAR(12) NOT NULL CONSTRAINT df_audiencia_estado DEFAULT 'PROGRAMADA',
  acta_mongo_id CHAR(24) NULL,  -- Acta (NoSQL)
  CONSTRAINT pk_audiencia PRIMARY KEY (id_audiencia),
  CONSTRAINT ck_audiencia_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL')),
  CONSTRAINT ck_audiencia_tipo_audiencia CHECK (tipo_audiencia IN ('JUDICIAL', 'CONCILIACION', 'ADMINISTRATIVA', 'ARBITRAL')),
  CONSTRAINT ck_audiencia_estado CHECK (estado IN ('PROGRAMADA', 'REALIZADA', 'REPROGRAMADA', 'SUSPENDIDA')),
  CONSTRAINT fk_audiencia_id_resolucion FOREIGN KEY (id_resolucion) REFERENCES dbo.resolucion(id_resolucion),
  CONSTRAINT fk_audiencia_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)
);
GO
-- ---------------------------------------------------------------------
-- 4. PROCESO 3 · RESOLUCIÓN Y FACTURACIÓN
-- ---------------------------------------------------------------------

-- SENTENCIA  ·  Resolución final del caso con su resultado (especialización de RESOLUCION). También se usa para laudo, acta de conciliación y auto final.
CREATE TABLE dbo.sentencia (
  id_resolucion INT NOT NULL,  -- Misma llave que la resolución
  instancia VARCHAR(8) NOT NULL,
  resultado VARCHAR(12) NOT NULL,
  monto_ordenado DECIMAL(14,2) NOT NULL CONSTRAINT df_sentencia_monto_ordenado DEFAULT 0.00,  -- Base de la cuota litis
  se_apela BIT NOT NULL CONSTRAINT df_sentencia_se_apela DEFAULT 0,
  fecha_firmeza DATE NULL,  -- Consentida / ejecutoriada
  requiere_ejecucion BIT NOT NULL CONSTRAINT df_sentencia_requiere_ejecucion DEFAULT 0,
  CONSTRAINT pk_sentencia PRIMARY KEY (id_resolucion),
  CONSTRAINT ck_sentencia_instancia CHECK (instancia IN ('PRIMERA', 'SEGUNDA', 'CASACION', 'UNICA')),
  CONSTRAINT ck_sentencia_resultado CHECK (resultado IN ('FAVORABLE', 'PARCIAL', 'DESFAVORABLE')),
  CONSTRAINT fk_sentencia_id_resolucion FOREIGN KEY (id_resolucion) REFERENCES dbo.resolucion(id_resolucion)
);
GO

-- LIQUIDACION  ·  Cálculo final de honorarios del caso (incluye cuota litis). El monto de la cuota litis NO se guarda aquí: se calcula en vw_liquidacion_cuota_litis y se cobra en CUOTA.monto.
CREATE TABLE dbo.liquidacion (
  id_liquidacion INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R35 (1:1)
  id_abogado INT NOT NULL,  -- R36
  fecha_liquidacion DATE NOT NULL,
  monto_obtenido DECIMAL(14,2) NOT NULL CONSTRAINT df_liquidacion_monto_obtenido DEFAULT 0.00,  -- Lo cobrado por el cliente
  estado VARCHAR(10) NOT NULL CONSTRAINT df_liquidacion_estado DEFAULT 'BORRADOR',
  CONSTRAINT pk_liquidacion PRIMARY KEY (id_liquidacion),
  CONSTRAINT uq_liquidacion_id_caso UNIQUE (id_caso),
  CONSTRAINT ck_liquidacion_estado CHECK (estado IN ('BORRADOR', 'COMUNICADA', 'ACEPTADA', 'OBSERVADA')),
  CONSTRAINT fk_liquidacion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_liquidacion_id_abogado FOREIGN KEY (id_abogado) REFERENCES dbo.abogado(id_empleado)
);
GO

-- SERIE_COMPROBANTE  ·  Series de numeración de los comprobantes: a qué tipo pertenece cada serie (B001 boleta, F001 factura, E001 recibo por honorarios) y cuál fue el último número emitido.
-- Nota: el tipo de comprobante depende de la serie, no del comprobante (dependencia transitiva, 3FN). Por eso COMPROBANTE ya no tiene tipo_comprobante.
CREATE TABLE dbo.serie_comprobante (
  serie CHAR(4) NOT NULL,  -- B001 / F001 / E001
  tipo_comprobante VARCHAR(17) NOT NULL,  -- Cada serie pertenece a un solo tipo
  ultimo_numero INT NOT NULL CONSTRAINT df_serie_comprobante_ultimo_numero DEFAULT 0,  -- Último correlativo emitido (lo actualiza el trigger trg_comprobante_correlativo)
  CONSTRAINT pk_serie_comprobante PRIMARY KEY (serie),
  CONSTRAINT ck_serie_comprobante_tipo CHECK (tipo_comprobante IN ('BOLETA', 'FACTURA', 'RECIBO_HONORARIOS')),
  CONSTRAINT ck_serie_comprobante_1 CHECK (ultimo_numero >= 0)  -- Regla: el correlativo no puede ser negativo.
);
GO


-- COMPROBANTE  ·  Boleta, factura o recibo emitido al cliente. El tipo (boleta / factura / recibo) se obtiene de la serie.
CREATE TABLE dbo.comprobante (
  id_comprobante INT IDENTITY(1,1) NOT NULL,
  id_persona INT NOT NULL,  -- Receptor (R38)
  id_emisor INT NOT NULL,  -- R39
  id_consulta INT NULL,  -- no se puede repetir (índice filtrado, ver abajo); R41 (cobro de consulta)
  serie CHAR(4) NOT NULL,  -- B001 / F001 / E001 (la serie define el tipo)
  numero INT NOT NULL,  -- Correlativo
  fecha_emision DATE NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  moneda CHAR(3) NOT NULL CONSTRAINT df_comprobante_moneda DEFAULT 'PEN',  -- PEN = soles, USD = dólares
  tasa_igv DECIMAL(4,2) NOT NULL CONSTRAINT df_comprobante_tasa_igv DEFAULT 0.18,  -- 0.18 boleta/factura; 0.00 recibo
  porcentaje_detraccion DECIMAL(4,2) NOT NULL CONSTRAINT df_comprobante_porcentaje_detraccion DEFAULT 0.00,  -- 0.12 = 12 %; 0.00 = no aplica detracción
  fecha_conformidad DATE NULL,  -- Solo entidad pública
  estado VARCHAR(8) NOT NULL CONSTRAINT df_comprobante_estado DEFAULT 'EMITIDO',  -- EMITIDO o ANULADO; si está pagado lo calcula vw_comprobante_saldo (no se guarda)
  CONSTRAINT pk_comprobante PRIMARY KEY (id_comprobante),
  CONSTRAINT uq_comprobante_serie UNIQUE (serie, numero),
  CONSTRAINT ck_comprobante_moneda CHECK (moneda IN ('PEN', 'USD')),  -- Regla: la moneda es soles (PEN) o dólares (USD).
  CONSTRAINT ck_comprobante_estado CHECK (estado IN ('EMITIDO', 'ANULADO')),  -- Solo se guarda la anulación; el estado de pago es derivado.
  CONSTRAINT ck_comprobante_1 CHECK (fecha_vencimiento >= fecha_emision),  -- Regla: El comprobante no puede vencer antes de emitirse.
  CONSTRAINT ck_comprobante_2 CHECK (tasa_igv BETWEEN 0 AND 0.30),  -- Regla: La tasa de IGV va entre 0 y 0.30 (0.18 normal, 0 en recibo por honorarios).
  CONSTRAINT ck_comprobante_3 CHECK (porcentaje_detraccion BETWEEN 0 AND 0.15),  -- Regla: la detracción va de 0 a 0.15 (0.12 servicios gravados con IGV, 0 si no aplica).
  CONSTRAINT fk_comprobante_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),
  CONSTRAINT fk_comprobante_id_emisor FOREIGN KEY (id_emisor) REFERENCES dbo.empleado(id_empleado),
  CONSTRAINT fk_comprobante_id_consulta FOREIGN KEY (id_consulta) REFERENCES dbo.consulta(id_consulta),
  CONSTRAINT fk_comprobante_serie FOREIGN KEY (serie) REFERENCES dbo.serie_comprobante(serie)
);
GO

-- DETALLE_COMPROBANTE  ·  Tabla intermedia: las líneas de cada comprobante (resuelve la M:N comprobante–cuota) y los reembolsos de gastos (comprobante–gasto_caso).
CREATE TABLE dbo.detalle_comprobante (
  id_comprobante INT NOT NULL,
  nro_linea TINYINT NOT NULL,  -- Línea dentro del comprobante
  id_cuota INT NULL,  -- NULL en la línea de la consulta o de un gasto
  id_gasto INT NULL,  -- Reembolso de un gasto (tasa, arancel…); NULL en las líneas de cuota o de la consulta
  descripcion NVARCHAR(200) NOT NULL,
  cantidad DECIMAL(8,2) NOT NULL CONSTRAINT df_detalle_comprobante_cantidad DEFAULT 1.00,
  valor_unitario DECIMAL(12,2) NOT NULL,  -- Sin IGV
  CONSTRAINT pk_detalle_comprobante PRIMARY KEY (id_comprobante, nro_linea),
  CONSTRAINT ck_detalle_comprobante_1 CHECK (cantidad > 0),  -- Regla: La cantidad debe ser mayor a cero.
  CONSTRAINT ck_detalle_comprobante_2 CHECK (valor_unitario >= 0),  -- Regla: El valor unitario no puede ser negativo.
  CONSTRAINT ck_detalle_comprobante_3 CHECK (id_cuota IS NULL OR id_gasto IS NULL),  -- Regla: una línea cobra una cuota o un gasto, nunca ambos.
  CONSTRAINT fk_detalle_comprobante_id_comprobante FOREIGN KEY (id_comprobante) REFERENCES dbo.comprobante(id_comprobante),
  CONSTRAINT fk_detalle_comprobante_id_cuota FOREIGN KEY (id_cuota) REFERENCES dbo.cuota(id_cuota),
  CONSTRAINT fk_detalle_comprobante_id_gasto FOREIGN KEY (id_gasto) REFERENCES dbo.gasto_caso(id_gasto)
);
GO

-- PAGO  ·  Abono recibido contra un comprobante.
CREATE TABLE dbo.pago (
  id_pago INT IDENTITY(1,1) NOT NULL,
  id_comprobante INT NOT NULL,  -- R42
  id_empleado INT NOT NULL,  -- R43
  fecha_pago DATETIME2(0) NOT NULL CONSTRAINT df_pago_fecha_pago DEFAULT SYSDATETIME(),
  monto DECIMAL(12,2) NOT NULL,
  medio_pago VARCHAR(13) NOT NULL,
  nro_operacion NVARCHAR(40) NULL,
  CONSTRAINT pk_pago PRIMARY KEY (id_pago),
  CONSTRAINT ck_pago_medio_pago CHECK (medio_pago IN ('EFECTIVO', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'DEPOSITO', 'TARJETA')),
  CONSTRAINT ck_pago_1 CHECK (monto > 0),  -- Regla: Todo pago debe ser mayor a cero.
  CONSTRAINT fk_pago_id_comprobante FOREIGN KEY (id_comprobante) REFERENCES dbo.comprobante(id_comprobante),
  CONSTRAINT fk_pago_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)
);
GO

-- DEVOLUCION  ·  Entrega de documentos originales al cliente con cargo firmado.
CREATE TABLE dbo.devolucion (
  id_devolucion INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R44
  id_persona INT NOT NULL,  -- Quien recibe (R45)
  id_empleado INT NOT NULL,  -- Quien entrega (R46)
  fecha_entrega DATETIME2(0) NOT NULL,
  descripcion_documentos NVARCHAR(500) NOT NULL,
  cargo_firmado BIT NOT NULL CONSTRAINT df_devolucion_cargo_firmado DEFAULT 0,
  CONSTRAINT pk_devolucion PRIMARY KEY (id_devolucion),
  CONSTRAINT fk_devolucion_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso),
  CONSTRAINT fk_devolucion_id_persona FOREIGN KEY (id_persona) REFERENCES dbo.persona(id_persona),
  CONSTRAINT fk_devolucion_id_empleado FOREIGN KEY (id_empleado) REFERENCES dbo.empleado(id_empleado)
);
GO

-- ENCUESTA  ·  Encuesta de satisfacción al cerrar el caso.
CREATE TABLE dbo.encuesta (
  id_encuesta INT IDENTITY(1,1) NOT NULL,
  id_caso INT NOT NULL,  -- R47 (1:1)
  fecha_envio DATETIME2(0) NOT NULL,
  fecha_respuesta DATETIME2(0) NULL,
  calificacion TINYINT NULL,  -- 1 a 5
  nps TINYINT NULL,  -- 0 a 10
  comentario NVARCHAR(500) NULL,
  CONSTRAINT pk_encuesta PRIMARY KEY (id_encuesta),
  CONSTRAINT uq_encuesta_id_caso UNIQUE (id_caso),
  CONSTRAINT ck_encuesta_1 CHECK (calificacion IS NULL OR calificacion BETWEEN 1 AND 5),  -- Regla: La calificación va de 1 a 5 estrellas (o vacía si no respondió).
  CONSTRAINT ck_encuesta_2 CHECK (nps IS NULL OR nps BETWEEN 0 AND 10),  -- Regla: El NPS va de 0 a 10 (o vacío si no respondió).
  CONSTRAINT fk_encuesta_id_caso FOREIGN KEY (id_caso) REFERENCES dbo.caso(id_caso)
);
GO

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
-- CUOTA se crea antes que LIQUIDACION: su FK hacia LIQUIDACION se agrega al final.
ALTER TABLE dbo.cuota ADD CONSTRAINT fk_cuota_id_liquidacion FOREIGN KEY (id_liquidacion) REFERENCES dbo.liquidacion(id_liquidacion);  -- La cuota de saldo o cuota litis apunta a la liquidación que la generó.
GO

-- ---------------------------------------------------------------------
-- 6. TRIGGERS
-- ---------------------------------------------------------------------
-- Reglas que un CHECK no puede expresar porque miran otras tablas.
-- Si la regla falla: se deshace la operación (ROLLBACK) y se lanza el error (THROW).

-- Trigger 1: solo un empleado con cargo ABOGADO puede estar en la tabla ABOGADO.
CREATE TRIGGER dbo.trg_abogado_cargo ON dbo.abogado
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.empleado e ON e.id_empleado = i.id_empleado WHERE e.cargo <> 'ABOGADO')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, N'Solo un empleado con cargo ABOGADO puede registrarse en la tabla abogado.', 1;
    END
END
GO

-- Trigger 2: no se puede cambiar el cargo de un abogado (porque dejaría de serlo y seguiría en ABOGADO).
CREATE TRIGGER dbo.trg_empleado_cargo ON dbo.empleado
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(cargo) AND EXISTS (SELECT 1 FROM inserted i JOIN dbo.abogado a ON a.id_empleado = i.id_empleado WHERE i.cargo <> 'ABOGADO')
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
               JOIN dbo.presentacion p ON p.id_presentacion = i.id_presentacion
               JOIN dbo.documento_legal d ON d.id_documento = p.id_documento
               WHERE d.id_caso <> i.id_caso)
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
-- UNIQUE sobre columnas opcionales o reglas parciales: índice único filtrado (permite varios NULL)
CREATE UNIQUE INDEX uq_entidad_nombre ON dbo.entidad (nombre, distrito_judicial) WHERE distrito_judicial IS NOT NULL;  -- Una entidad no se repite dentro de un distrito judicial; las que no tienen distrito quedan fuera de la regla.
CREATE UNIQUE INDEX uq_comprobante_id_consulta ON dbo.comprobante (id_consulta) WHERE id_consulta IS NOT NULL;  -- Una consulta se cobra en un solo comprobante; los comprobantes de cuotas lo dejan vacío.
CREATE UNIQUE INDEX uq_caso_etapa_abierta ON dbo.caso_etapa (id_caso) WHERE fecha_fin IS NULL;  -- Cada caso tiene a lo sumo UNA etapa abierta (fecha_fin vacía) a la vez.
CREATE UNIQUE INDEX uq_detalle_comprobante_gasto ON dbo.detalle_comprobante (id_gasto) WHERE id_gasto IS NOT NULL;  -- Un gasto se reembolsa en una sola línea de comprobante.
CREATE UNIQUE INDEX uq_persona_documento ON dbo.persona (tipo_documento, nro_documento) WHERE nro_documento IS NOT NULL;  -- Un documento no se repite; las contrapartes sin documento quedan fuera de la regla.
CREATE UNIQUE INDEX uq_usuario_empleado ON dbo.usuario (id_empleado) WHERE id_empleado IS NOT NULL;  -- Un empleado tiene a lo sumo una cuenta.
CREATE UNIQUE INDEX uq_usuario_persona ON dbo.usuario (id_persona) WHERE id_persona IS NOT NULL;  -- Un cliente tiene a lo sumo una cuenta del portal.
GO

-- Índices de apoyo para las consultas del panel administrativo
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
-- Los totales, saldos y estados son DERIVADOS, no se almacenan (3FN)

-- Vista 1: total de cada comprobante = suma de sus líneas + IGV (y monto de detracción).
CREATE VIEW dbo.vw_comprobante_total AS
SELECT c.id_comprobante, s.tipo_comprobante, c.serie, c.numero, c.id_persona, c.moneda,
       ROUND(SUM(d.cantidad * d.valor_unitario), 2)                    AS subtotal,
       ROUND(SUM(d.cantidad * d.valor_unitario) * c.tasa_igv, 2)       AS igv,
       ROUND(SUM(d.cantidad * d.valor_unitario) * (1 + c.tasa_igv), 2) AS total,
       ROUND(SUM(d.cantidad * d.valor_unitario) * (1 + c.tasa_igv) * c.porcentaje_detraccion, 2) AS detraccion
FROM dbo.comprobante c
JOIN dbo.serie_comprobante s ON s.serie = c.serie
JOIN dbo.detalle_comprobante d ON d.id_comprobante = c.id_comprobante
GROUP BY c.id_comprobante, s.tipo_comprobante, c.serie, c.numero, c.id_persona, c.moneda, c.tasa_igv, c.porcentaje_detraccion;
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
CREATE VIEW dbo.vw_plazo_estado AS
SELECT p.id_plazo, p.id_caso, p.id_resolucion, p.id_empleado_responsable, p.descripcion,
       p.fecha_inicio, p.dias_plazo, p.tipo_computo, p.fecha_vencimiento, p.fecha_cumplimiento,
       CASE WHEN p.fecha_cumplimiento IS NOT NULL THEN 'CUMPLIDO'
            WHEN p.fecha_vencimiento < CAST(GETDATE() AS DATE) THEN 'VENCIDO'
            ELSE 'PENDIENTE' END AS estado
FROM dbo.plazo p;
GO

-- Vista 4: plazos pendientes que vencen en 5 días o menos (alertas del panel).
CREATE VIEW dbo.vw_plazos_por_vencer AS
SELECT p.id_plazo, p.id_caso, c.codigo_interno, c.nro_expediente_judicial, p.descripcion, p.fecha_vencimiento,
       e.nombres + N' ' + e.apellidos AS responsable,
       DATEDIFF(DAY, CAST(GETDATE() AS DATE), p.fecha_vencimiento) AS dias_restantes
FROM dbo.plazo p JOIN dbo.caso c ON c.id_caso = p.id_caso
JOIN dbo.empleado e ON e.id_empleado = p.id_empleado_responsable
WHERE p.fecha_cumplimiento IS NULL
  AND p.fecha_vencimiento <= DATEADD(DAY, 5, CAST(GETDATE() AS DATE));
GO

-- Vista 5: estado de cada cuota; «VENCIDA» se calcula (no se guarda).
CREATE VIEW dbo.vw_cuota_estado AS
SELECT q.id_cuota, q.id_contrato, q.nro_cuota, q.concepto, q.monto, q.fecha_vencimiento,
       CASE WHEN q.estado IN ('PENDIENTE', 'PAGADA_PARCIAL') AND q.fecha_vencimiento < CAST(GETDATE() AS DATE)
            THEN 'VENCIDA' ELSE q.estado END AS estado
FROM dbo.cuota q;
GO

-- Vista 6: cuota litis de cada liquidación = monto obtenido × porcentaje pactado en la propuesta.
CREATE VIEW dbo.vw_liquidacion_cuota_litis AS
SELECT l.id_liquidacion, l.id_caso, l.monto_obtenido, pr.porcentaje_cuota_litis,
       ROUND(l.monto_obtenido * pr.porcentaje_cuota_litis / 100, 2) AS monto_cuota_litis
FROM dbo.liquidacion l
JOIN dbo.caso c ON c.id_caso = l.id_caso
JOIN dbo.contrato k ON k.id_contrato = c.id_contrato
JOIN dbo.propuesta pr ON pr.id_propuesta = k.id_propuesta;
GO

PRINT 'Base de datos magallanes_montero creada correctamente (36 tablas, 10 triggers, 6 vistas).';
GO

-- ---------------------------------------------------------------------
-- 9. CONSULTAS DE EJEMPLO (comentadas: quitar -- y pulsar F5 tras cargar los datos de prueba)
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


