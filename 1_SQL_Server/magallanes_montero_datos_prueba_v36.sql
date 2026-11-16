-- =====================================================================
-- Estudio Jurídico Magallanes-Montero · DATOS DE PRUEBA (SQL Server / T-SQL)
-- Curso: Base de Datos II · UTP
-- Ejecutar DESPUÉS de magallanes_montero_sqlserver_v36_explicado.sql (versión de 36 tablas), sobre la base recién creada
-- (los ids se generan solos con IDENTITY y este script los da por 1, 2, 3…).
-- Si algo falla a medias, vuelve a ejecutar primero el script de la estructura para empezar limpio.
-- Todos los datos son ficticios. Los textos llevan prefijo N para guardar tildes y ñ.
-- Fechas RELATIVAS: algunos plazos, cuotas, citas, audiencias y notificaciones se calculan desde la fecha de hoy
-- (GETDATE()), así las alertas del panel siempre muestran casos «por vencer» el día que se ejecute el script.
-- =====================================================================
USE magallanes_montero;
GO
SET NOCOUNT ON;
GO

-- ---------------------------------------------------------------------
-- 1. TABLAS MAESTRAS Y CATÁLOGOS
-- ---------------------------------------------------------------------

-- PERSONA (21): clientes, contrapartes, representantes, empresas y entidades públicas.
-- La persona 21 es una contraparte SIN RUC: se permite porque no es cliente (un cliente sí necesita DNI o RUC).
-- id_representante se completa después con UPDATE (una fila no puede apuntar a otra aún no insertada).
INSERT INTO persona (tipo_persona, tipo_documento, nro_documento, nombres, apellidos, razon_social, fecha_nacimiento, estado_civil, ocupacion, telefono, email, direccion, acepta_tratamiento_datos, fecha_registro) VALUES
('NATURAL','DNI','45123678',N'Juan Carlos',N'Pérez Quispe',NULL,'1984-03-15','CASADO',N'Comerciante','987654321','juan.perez@example.com',N'Jr. Los Pinos 245, San Isidro',1,'2026-01-12 09:15:00'),
('NATURAL','DNI','40987123',N'María Elena',N'Torres Vargas',NULL,'1990-07-22','SOLTERO',N'Asistente administrativa','976543210','maria.torres@example.com',N'Av. Arequipa 1830, Lince',1,'2026-02-03 11:30:00'),
('NATURAL','DNI','46789012',N'Luis Fernando',N'Gutiérrez Rojas',NULL,'1978-11-02','CASADO',N'Ingeniero civil','965432109','luis.gutierrez@example.com',N'Calle Los Cedros 118, Santiago de Surco',1,'2026-03-05 10:20:00'),
('NATURAL','DNI','43215678',N'Rosa Marina',N'Huamán Flores',NULL,'1993-05-30','CONVIVIENTE',N'Costurera','954321098',NULL,N'Jr. Cusco 560, Comas',1,'2026-03-18 15:45:00'),
('NATURAL','DNI','47654321',N'Pedro Pablo',N'Castillo Mendoza',NULL,'1980-01-09','CASADO',N'Transportista',NULL,NULL,N'Av. Universitaria 1020, Los Olivos',0,'2026-01-12 09:30:00'),
('NATURAL','DNI','41234567',N'Ana Lucía',N'Salazar Díaz',NULL,'1985-09-12','DIVORCIADO',N'Docente','932109876','ana.salazar@example.com',N'Av. Brasil 2250, Jesús María',1,'2026-09-22 12:10:00'),
('NATURAL','DNI','44556677',N'Jorge Luis',N'Medina Paredes',NULL,'1975-06-18','SOLTERO',N'Empresario',NULL,NULL,NULL,0,'2026-03-05 10:30:00'),
('NATURAL','DNI','48990011',N'Carmen Rosa',N'Vilca Ccori',NULL,'1988-12-04','CASADO',N'Ama de casa','921098765',NULL,N'Jr. Huallaga 330, Rímac',1,'2026-10-20 09:00:00'),
('NATURAL','DNI','09876543',N'Ricardo Alonso',N'Benavides Luna',NULL,'1972-02-27','CASADO',N'Gerente general','912345678','ricardo.benavides@example.com',N'Av. Larco 1150, Miraflores',1,'2026-06-17 16:00:00'),
('JURIDICA','RUC','20512345678',NULL,NULL,N'Inversiones Andinas S.A.C.',NULL,NULL,NULL,'014567890','contacto@inversionesandinas.example.com',N'Av. Larco 1150, Of. 502, Miraflores',1,'2026-06-17 16:00:00'),
('JURIDICA','RUC','20601234567',NULL,NULL,N'Transportes Rápido del Sur E.I.R.L.',NULL,NULL,NULL,NULL,NULL,N'Av. Separadora Industrial 740, Ate',0,'2026-06-17 16:30:00'),
('PUBLICA','RUC','20999888771',NULL,NULL,N'Municipalidad Distrital de Villa Alegre',NULL,NULL,NULL,'013334455','legal@villaalegre.example.com',N'Plaza de Armas s/n, Villa Alegre',1,'2026-04-02 10:00:00'),
('NATURAL','DNI','42111222',N'Sofía Valentina',N'Cárdenas Ríos',NULL,'1996-04-08','SOLTERO',N'Diseñadora','945678123','sofia.cardenas@example.com',N'Calle Berlín 245, Miraflores',1,'2026-10-01 18:05:00'),
('NATURAL','CE','001234567',N'Andrés Felipe',N'Gómez Restrepo',NULL,'1991-08-19','SOLTERO',N'Ingeniero de sistemas','934567812','andres.gomez@example.com',N'Av. Petit Thouars 4200, Miraflores',1,'2026-10-28 14:30:00'),
('NATURAL','DNI','07765432',N'Hugo César',N'Maldonado Pinto',NULL,'1969-10-03','CASADO',N'Alcalde','913334455',NULL,NULL,1,'2026-04-02 10:00:00'),
('JURIDICA','RUC','20587654321',NULL,NULL,N'Constructora Pacífico S.A.C.',NULL,NULL,NULL,NULL,NULL,N'Av. Néstor Gambetta 3200, Callao',0,'2026-02-03 11:45:00'),
('NATURAL','DNI','40123987',N'Walter Eduardo',N'Quispe Lozano',NULL,'1982-02-14','SOLTERO',N'Obrero',NULL,NULL,NULL,0,'2026-03-18 16:00:00'),
('NATURAL','DNI','43876543',N'Teresa Ofelia',N'Gallardo Ñahui',NULL,'1970-09-25','VIUDO',N'Comerciante',NULL,NULL,NULL,0,'2026-09-22 12:30:00'),
('NATURAL','DNI','45678123',N'Marco Antonio',N'Delgado Pino',NULL,'1994-12-01','SOLTERO',N'Community manager',NULL,NULL,NULL,0,'2026-10-01 18:20:00'),
('PUBLICA','RUC','20444555666',NULL,NULL,N'Municipalidad Distrital de Santa Rosa del Valle',NULL,NULL,NULL,NULL,NULL,N'Av. Principal 100, Santa Rosa del Valle',0,'2026-10-28 14:40:00'),
('JURIDICA',NULL,NULL,NULL,NULL,N'Textiles Huallaga (RUC no informado por el cliente)',NULL,NULL,NULL,NULL,NULL,NULL,0,'2026-10-28 14:35:00');
GO

-- Representantes legales (relación recursiva de PERSONA).
UPDATE persona SET id_representante = (SELECT id_persona FROM persona WHERE tipo_documento = 'DNI' AND nro_documento = '09876543')
WHERE tipo_documento = 'RUC' AND nro_documento = '20512345678';  -- Ricardo Benavides representa a Inversiones Andinas.
UPDATE persona SET id_representante = (SELECT id_persona FROM persona WHERE tipo_documento = 'DNI' AND nro_documento = '07765432')
WHERE tipo_documento = 'RUC' AND nro_documento = '20999888771';  -- El alcalde representa a la Municipalidad de Villa Alegre.
GO

-- EMPLEADO (7): 3 abogados, 1 secretaria, 2 practicantes (uno inactivo), 1 administradora.
INSERT INTO empleado (dni, nombres, apellidos, cargo, telefono, email, activo) VALUES
('08123456',N'Héctor Manuel',N'Magallanes Vidal','ABOGADO','999111222','hector.magallanes@example.com',1),
('07234567',N'Lucía Beatriz',N'Montero Alarcón','ABOGADO','999222333','lucia.montero@example.com',1),
('70345678',N'Diego Alonso',N'Salinas Pinedo','ABOGADO','999333444','diego.salinas@example.com',1),
('72456789',N'Karen Milagros',N'Paredes Lazo','SECRETARIA','999444555','karen.paredes@example.com',1),
('74567890',N'Miguel Ángel',N'Rojas Cueva','PRACTICANTE','999555666','miguel.rojas@example.com',1),
('06678901',N'Gabriela Patricia',N'Montero Alarcón','ADMINISTRADOR','999666777','gabriela.montero@example.com',1),
('75678901',N'Renzo Iván',N'Ccama Torres','PRACTICANTE',NULL,'renzo.ccama@example.com',0);
GO

-- MATERIA (6)
INSERT INTO materia (nombre, descripcion) VALUES
(N'Civil',N'Obligaciones, contratos, propiedad, desalojos y responsabilidad civil'),
(N'Penal',N'Denuncias, investigaciones fiscales y procesos penales'),
(N'Laboral',N'Despidos, beneficios sociales y relaciones de trabajo'),
(N'Familia',N'Alimentos, tenencia, visitas y violencia familiar'),
(N'Administrativo',N'Procedimientos ante entidades públicas, multas y contrataciones'),
(N'Comercial',N'Contratos mercantiles, sociedades y arbitraje empresarial');
GO

-- ROL_PROCESAL (24 roles en 8 familias, 3 por familia)
INSERT INTO rol_procesal (nombre, familia) VALUES
(N'Demandante','CIVIL_ACTIVA'),(N'Reconviniente','CIVIL_ACTIVA'),(N'Solicitante','CIVIL_ACTIVA'),
(N'Demandado','CIVIL_PASIVA'),(N'Reconvenido','CIVIL_PASIVA'),(N'Emplazado','CIVIL_PASIVA'),
(N'Agraviado','PENAL_ACUSA'),(N'Actor civil','PENAL_ACUSA'),(N'Denunciante','PENAL_ACUSA'),
(N'Imputado','PENAL_INVESTIGADA'),(N'Investigado','PENAL_INVESTIGADA'),(N'Tercero civilmente responsable','PENAL_INVESTIGADA'),
(N'Víctima','VIOLENCIA_30364'),(N'Agresor denunciado','VIOLENCIA_30364'),(N'Persona protegida','VIOLENCIA_30364'),
(N'Administrado','ADMINISTRATIVO'),(N'Denunciante administrativo','ADMINISTRATIVO'),(N'Tercero administrado','ADMINISTRATIVO'),
(N'Solicitante de conciliación','CONCILIACION_ARBITRAJE'),(N'Invitado a conciliar','CONCILIACION_ARBITRAJE'),(N'Parte arbitral','CONCILIACION_ARBITRAJE'),
(N'Titular del trámite','TRAMITE'),(N'Apoderado','TRAMITE'),(N'Tercero interesado','TRAMITE');
GO

-- ETAPA_PROCESAL (9)
INSERT INTO etapa_procesal (nombre, orden) VALUES
(N'Consulta inicial',1),(N'Postulación',2),(N'Actuación probatoria',3),(N'Audiencia',4),(N'Sentencia de primera instancia',5),
(N'Apelación',6),(N'Casación',7),(N'Ejecución',8),(N'Cerrado',9);
GO

-- ENTIDAD (10): una sin distrito judicial (permitido por el índice filtrado).
INSERT INTO entidad (nombre, tipo_entidad, distrito_judicial, direccion) VALUES
(N'1.er Juzgado Civil de Lima','JUZGADO',N'Lima',N'Av. Abancay s/n, Cercado de Lima'),
(N'2.º Juzgado de Trabajo de Lima','JUZGADO',N'Lima',N'Av. Abancay s/n, Cercado de Lima'),
(N'Sala Civil de Lima','SALA',N'Lima',N'Av. Abancay s/n, Cercado de Lima'),
(N'5.ª Fiscalía Provincial Penal de Lima','FISCALIA',N'Lima',N'Jr. Cusco 120, Cercado de Lima'),
(N'3.er Juzgado de Familia de Lima','JUZGADO',N'Lima',N'Av. Abancay s/n, Cercado de Lima'),
(N'Órgano de Contrataciones de la Municipalidad de Villa Alegre','ADMINISTRATIVA',N'Lima',N'Plaza de Armas s/n, Villa Alegre'),
(N'Centro de Conciliación Paz y Justicia','CENTRO_CONCILIACION',N'Lima',N'Av. Wilson 1200, Cercado de Lima'),
(N'Centro de Arbitraje Empresarial Andino','TRIBUNAL_ARBITRAL',N'Lima',N'Av. Javier Prado Este 1500, San Isidro'),
(N'Oficina Registral de Lima','REGISTRAL_NOTARIAL',N'Lima',N'Av. Primavera 1878, Surco'),
(N'Comisión de Protección al Consumidor (Sede Lima Sur)','ADMINISTRATIVA',NULL,N'Calle De la Prosa 104, San Borja');
GO

-- JURISPRUDENCIA (10): leyes reales y casaciones marcadas como dato de ejemplo.
INSERT INTO jurisprudencia (id_materia, tipo, referencia, titulo, fecha_publicacion, url_fuente) VALUES
(1,'LEY',N'Código Procesal Civil, art. 424',N'Requisitos de la demanda',NULL,NULL),
(1,'CASACION',N'Cas. 1234-2019-Lima',N'Cobro de suma de dinero: acreditación del mutuo con documento privado (dato de ejemplo)',NULL,NULL),
(3,'LEY',N'D.S. 003-97-TR',N'TUO del D. Leg. 728 - Ley de Productividad y Competitividad Laboral','1997-03-27',NULL),
(3,'CASACION',N'Cas. Lab. 4567-2018-Lima',N'Despido arbitrario e indemnización: criterios de cálculo (dato de ejemplo)',NULL,NULL),
(4,'LEY',N'Ley 30364',N'Ley para prevenir, sancionar y erradicar la violencia contra las mujeres y los integrantes del grupo familiar','2015-11-23',NULL),
(4,'CASACION',N'Cas. 2890-2020-Lima Norte',N'Pensión de alimentos: prueba de los ingresos del obligado (dato de ejemplo)',NULL,NULL),
(2,'PLENO',N'Acuerdo Plenario 03-2025/CIJ-116',N'Elementos del delito de estafa y engaño idóneo (dato de ejemplo)',NULL,NULL),
(5,'LEY',N'Ley 29733',N'Ley de Protección de Datos Personales','2011-07-03',NULL),
(6,'LEY',N'D. Leg. 1071',N'Ley que norma el arbitraje','2008-06-28',NULL),
(5,'LEY',N'Ley 30225',N'Ley de Contrataciones del Estado','2014-07-11',NULL);
GO

-- ABOGADO (3): los tres empleados con cargo ABOGADO (ids 1, 2 y 3). La colegiatura vive aquí, no en EMPLEADO.
-- El trigger trg_abogado_cargo rechazaría a un empleado que no sea ABOGADO.
INSERT INTO abogado (id_empleado, nro_colegiatura) VALUES
(1,'CAL-38451'),(2,'CAL-41277'),(3,'CAL-62013');
GO

-- FERIADO (16): los 16 feriados nacionales de 2026 en Perú.
INSERT INTO feriado (fecha, descripcion) VALUES
('2026-01-01',N'Año Nuevo'),('2026-04-02',N'Jueves Santo'),('2026-04-03',N'Viernes Santo'),('2026-05-01',N'Día del Trabajo'),
('2026-06-07',N'Batalla de Arica y Día de la Bandera'),('2026-06-29',N'San Pedro y San Pablo'),('2026-07-23',N'Día de la Fuerza Aérea del Perú'),
('2026-07-28',N'Fiestas Patrias'),('2026-07-29',N'Fiestas Patrias'),('2026-08-06',N'Batalla de Junín'),('2026-08-30',N'Santa Rosa de Lima'),
('2026-10-08',N'Combate de Angamos'),('2026-11-01',N'Todos los Santos'),('2026-12-08',N'Inmaculada Concepción'),('2026-12-09',N'Batalla de Ayacucho'),
('2026-12-25',N'Navidad');
GO

-- ABOGADO_MATERIA: especialidades de cada abogado (una principal por abogado).
INSERT INTO abogado_materia (id_abogado, id_materia, es_principal) VALUES
(1,1,1),(1,6,0),(1,5,0),
(2,3,1),(2,4,0),
(3,2,1),(3,5,0);
GO

-- ---------------------------------------------------------------------
-- 2. PROCESO 1 · CAPTACIÓN, CONSULTA Y APERTURA
-- ---------------------------------------------------------------------

-- CONSULTA (12): 7 terminan en contrato; el resto muestra otros estados del embudo.
-- Las consultas con existe_conflicto 0 o 1 ya fueron revisadas: constan el revisor (un abogado) y la fecha; si hay conflicto, también el detalle.
-- monto_consulta es el costo informado SIN IGV (el comprobante le suma 18 %).
-- id_registrado_por = 4 (la secretaria); las consultas 5 y 12 llegaron solas por la landing y quedan en NULL.
INSERT INTO consulta (id_persona, id_materia, id_registrado_por, canal, fecha_hora_recepcion, resumen, es_urgente, existe_conflicto, id_revisor_conflicto, fecha_revision_conflicto, detalle_conflicto, monto_consulta, estado) VALUES
(1, 1,4,'WHATSAPP',  '2026-01-12 09:15:00',N'Cobro de un préstamo de S/ 25,000 a un conocido que no devuelve el dinero',0,0,1,'2026-01-13 09:00:00',NULL,100.00,'CONTRATADA'),   -- 1
(2, 3,4,'LLAMADA',   '2026-02-03 11:30:00',N'Despido sin causa justa tras 6 años de trabajo',1,0,2,'2026-02-04 09:00:00',NULL,100.00,'CONTRATADA'),                            -- 2
(3, 2,4,'PRESENCIAL','2026-03-05 10:20:00',N'Estafa en la compra de un terreno: pagó el adelanto y el vendedor desapareció',0,0,3,'2026-03-06 09:00:00',NULL,100.00,'CONTRATADA'),-- 3
(4, 4,4,'FACEBOOK',  '2026-03-18 15:45:00',N'Pensión de alimentos para dos hijos menores',0,0,2,'2026-03-19 09:00:00',NULL,100.00,'CONTRATADA'),                               -- 4
(12,5,NULL,'LANDING',   '2026-04-02 10:00:00',N'Asesoría permanente en procesos de contratación y multas administrativas',0,0,1,'2026-04-03 09:00:00',NULL,0.00,'CONTRATADA'),    -- 5
(10,6,4,'LLAMADA',   '2026-06-17 16:00:00',N'Incumplimiento de un contrato de suministro con cláusula arbitral',0,0,1,'2026-06-18 09:00:00',NULL,100.00,'CONTRATADA'),          -- 6
(8, 4,4,'PRESENCIAL','2026-10-20 09:00:00',N'Violencia psicológica y física por parte de su pareja; pide medidas de protección',1,0,2,'2026-10-21 09:00:00',NULL,0.00,'CONTRATADA'),-- 7
(13,6,4,'INSTAGRAM', '2026-10-01 18:05:00',N'Contrato de diseño sin pagar y uso de su marca sin autorización',0,0,1,'2026-10-02 09:00:00',NULL,100.00,'PROPUESTA'),               -- 8
(14,3,4,'WHATSAPP',  '2026-10-28 14:30:00',N'Cese colectivo y falta de pago de beneficios sociales',0,0,2,'2026-10-29 09:00:00',NULL,0.00,'AGENDADA'),                        -- 9
(6, 1,4,'FACEBOOK',  '2026-09-22 12:15:00',N'Desalojo por ocupación precaria de un inmueble heredado',0,0,1,'2026-09-23 09:00:00',NULL,0.00,'RECHAZADA'),                      -- 10
(20,5,4,'LLAMADA',   '2026-10-28 14:45:00',N'Impugnación de multa; la contraparte es un cliente actual del estudio',0,1,3,'2026-10-29 09:00:00',N'La contraparte (Municipalidad Distrital de Villa Alegre) es cliente actual del estudio',0.00,'CON_CONFLICTO'),    -- 11
(19,6,NULL,'LANDING',   '2026-11-02 20:10:00',N'Consulta sobre la cesión de derechos de una marca',0,NULL,NULL,NULL,NULL,0.00,'NO_ATENDIDA');                       -- 12
GO

-- CONSULTA_CONTRAPARTE: personas mencionadas como contraparte en cada consulta.
INSERT INTO consulta_contraparte (id_consulta, id_persona) VALUES
(1,5),(2,16),(3,7),(4,17),(6,11),(8,19),(9,21),(10,18),(11,12),(12,13);  -- (9,21): contraparte sin RUC
GO

-- CITA (12): asistidas, reprogramada, programada a futuro y cancelada.
INSERT INTO cita (id_consulta, id_abogado, fecha_hora, modalidad, recordatorio_enviado, estado) VALUES
(1, 1,'2026-01-14 10:00:00','PRESENCIAL',1,'ASISTIO'),       -- 1
(2, 2,'2026-02-05 15:00:00','PRESENCIAL',1,'ASISTIO'),       -- 2
(3, 3,'2026-03-07 11:00:00','PRESENCIAL',1,'ASISTIO'),       -- 3
(4, 2,'2026-03-19 09:30:00','VIRTUAL',   1,'ASISTIO'),       -- 4
(5, 1,'2026-04-04 10:00:00','PRESENCIAL',1,'ASISTIO'),       -- 5
(6, 1,'2026-06-19 16:00:00','VIRTUAL',   1,'ASISTIO'),       -- 6
(7, 2,'2026-10-21 10:00:00','PRESENCIAL',1,'ASISTIO'),       -- 7
(8, 1,'2026-10-02 17:00:00','VIRTUAL',   1,'REPROGRAMADA'),  -- 8 (la clienta pidió moverla)
(8, 1,'2026-10-05 11:00:00','VIRTUAL',   1,'ASISTIO'),       -- 9
(9, 2,DATEADD(HOUR, 10, CAST(DATEADD(DAY, 1, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),'PRESENCIAL',0,'PROGRAMADA'),    -- 10 MAÑANA a las 10:00 (fecha relativa; el recordatorio está en NOTIFICACION)
(10,1,'2026-09-24 12:00:00','PRESENCIAL',1,'ASISTIO'),       -- 11
(11,3,'2026-10-30 09:00:00','PRESENCIAL',0,'CANCELADA');     -- 12 (cancelada por conflicto de intereses)
GO

-- PROPUESTA (11): negociaciones con varias versiones, una rechazada y una sin respuesta.
INSERT INTO propuesta (id_consulta, id_abogado, version, monto_honorarios, porcentaje_cuota_litis, nro_cuotas, fecha_envio, fecha_respuesta, estado) VALUES
(1, 1,1,3500.00,20.00,3,'2026-01-15','2026-01-18','ACEPTADA'),        -- 1
(2, 2,1,2000.00,15.00,2,'2026-02-06','2026-02-10','ACEPTADA'),        -- 2
(3, 3,1,6000.00, 0.00,4,'2026-03-08','2026-03-10','EN_NEGOCIACION'),  -- 3 (v1: el cliente pidió rebaja)
(3, 3,2,5000.00, 0.00,4,'2026-03-12','2026-03-14','ACEPTADA'),        -- 4 (v2 aceptada)
(4, 2,1,1800.00,10.00,2,'2026-03-20','2026-03-22','ACEPTADA'),        -- 5
(5, 1,1,4500.00, 0.00,5,'2026-06-20','2026-06-30','ACEPTADA'),        -- 6 (iguala mensual de 5 × 900)
(6, 1,1,15000.00,10.00,5,'2026-06-20','2026-06-25','ACEPTADA'),       -- 7
(7, 2,1,0.00,    0.00,1,'2026-10-22','2026-10-22','ACEPTADA'),        -- 8 (pro bono)
(8, 1,1,3000.00, 0.00,2,'2026-10-05','2026-10-08','EN_NEGOCIACION'),  -- 9
(8, 1,2,2600.00, 0.00,2,'2026-10-12',NULL,        'ENVIADA'),         -- 10 (sin respuesta aún)
(10,1,1,2500.00, 0.00,1,'2026-09-25','2026-10-02','RECHAZADA');       -- 11
GO

-- CONTRATO (7): uno por cada propuesta aceptada (relación 1:1). Los ObjectId son de ejemplo.
-- id_cliente = quien contrata; aquí coincide con la persona que hizo la consulta.
INSERT INTO contrato (id_propuesta, id_cliente, nro_contrato, fecha_firma, tipo_encargo, modalidad_pago, con_carta_poder, archivo_mongo_id) VALUES
(1,1,'CT-2026-0001','2026-01-20','PATROCINIO',    'CUOTAS',        1,'65a1b2c3d4e5f60718293a01'),  -- 1
(2,2,'CT-2026-0002','2026-02-12','PATROCINIO',    'CUOTAS',        1,'65a1b2c3d4e5f60718293a02'),  -- 2
(4,3,'CT-2026-0003','2026-03-16','PATROCINIO',    'CUOTAS',        1,'65a1b2c3d4e5f60718293a03'),  -- 3
(5,4,'CT-2026-0004','2026-03-25','PATROCINIO',    'CUOTAS',        1,'65a1b2c3d4e5f60718293a04'),  -- 4
(6,12,'CT-2026-0005','2026-07-01','REPRESENTACION','IGUALA_MENSUAL',0,'65a1b2c3d4e5f60718293a05'),  -- 5
(7,10,'CT-2026-0006','2026-06-28','PATROCINIO',    'CUOTAS',        1,'65a1b2c3d4e5f60718293a06'),  -- 6
(8,8,'CT-2026-0007','2026-10-22','PRO_BONO',      'UNICO',         1,'65a1b2c3d4e5f60718293a07');  -- 7 (sin cuotas)
GO

-- CUOTA (22): cronogramas de cobro. «Vencida» no se guarda: las cuotas 10 y 22 quedan PENDIENTE y vw_cuota_estado las muestra como VENCIDA. La cuota litis (id 4) se vincula a su liquidación más abajo.
INSERT INTO cuota (id_contrato, id_liquidacion, nro_cuota, concepto, monto, fecha_vencimiento, estado) VALUES
-- Contrato 1: adelanto + 2 cuotas + cuota litis (20 % de S/ 26,000 = S/ 5,200)
(1,NULL,1,'ADELANTO',   1500.00,'2026-01-20','PAGADA'),   -- 1
(1,NULL,2,'CUOTA',      1000.00,'2026-02-20','PAGADA'),   -- 2
(1,NULL,3,'CUOTA',      1000.00,'2026-03-20','PAGADA'),   -- 3
(1,NULL,4,'CUOTA_LITIS',5200.00,'2026-10-30','PAGADA'),   -- 4
-- Contrato 2
(2,NULL,1,'ADELANTO',   1000.00,'2026-02-12','PAGADA'),   -- 5
(2,NULL,2,'CUOTA',      1000.00,'2026-03-12','PAGADA'),   -- 6
-- Contrato 3 (la cuota 4 está vencida y sin pagar)
(3,NULL,1,'ADELANTO',   1250.00,'2026-03-16','PAGADA'),   -- 7
(3,NULL,2,'CUOTA',      1250.00,'2026-04-16','PAGADA'),   -- 8
(3,NULL,3,'CUOTA',      1250.00,'2026-05-16','PAGADA'),   -- 9
(3,NULL,4,'CUOTA',      1250.00,'2026-06-16','PENDIENTE'),  -- 10
-- Contrato 4 (la cuota 2 vence pronto)
(4,NULL,1,'ADELANTO',    900.00,'2026-03-25','PAGADA'),   -- 11
(4,NULL,2,'CUOTA',       900.00,DATEADD(DAY, 4, CAST(GETDATE() AS DATE)),'PENDIENTE'),-- 12 vence en 4 días (fecha relativa)
-- Contrato 5: iguala mensual de S/ 900 (entidad pública)
(5,NULL,1,'IGUALA',      900.00,'2026-07-31','PAGADA'),   -- 13
(5,NULL,2,'IGUALA',      900.00,'2026-08-31','PAGADA'),   -- 14
(5,NULL,3,'IGUALA',      900.00,'2026-09-30','PAGADA'),   -- 15
(5,NULL,4,'IGUALA',      900.00,'2026-10-31','PAGADA_PARCIAL'), -- 16
(5,NULL,5,'IGUALA',      900.00,DATEADD(DAY, 20, CAST(GETDATE() AS DATE)),'PENDIENTE'),-- 17 vence en 20 días (fecha relativa)
-- Contrato 6: arbitraje (la cuota 5 está vencida)
(6,NULL,1,'ADELANTO',   3000.00,'2026-06-28','PAGADA'),   -- 18
(6,NULL,2,'CUOTA',      3000.00,'2026-07-28','PAGADA'),   -- 19
(6,NULL,3,'CUOTA',      3000.00,'2026-08-28','PAGADA'),   -- 20
(6,NULL,4,'CUOTA',      3000.00,'2026-09-28','PAGADA'),   -- 21
(6,NULL,5,'CUOTA',      3000.00,'2026-10-28','PENDIENTE');  -- 22
GO

-- ---------------------------------------------------------------------
-- 3. PROCESO 2 · GESTIÓN DEL EXPEDIENTE
-- ---------------------------------------------------------------------

-- CASO (7): uno por contrato (1:1). El caso 1 ya está cerrado; los demás siguen activos.
INSERT INTO caso (id_contrato, id_materia, id_abogado_responsable, codigo_interno, nro_expediente_judicial, descripcion, es_alta_complejidad, estado, fecha_apertura, fecha_cierre, expediente_mongo_id) VALUES
(1,1,1,'EXP-2026-0001','00123-2026-0-1801-JR-CI-01',N'Obligación de dar suma de dinero: préstamo de S/ 25,000',0,'CERRADO','2026-01-22','2026-10-15','65b1c2d3e4f5a60718293b01'),  -- 1
(2,3,2,'EXP-2026-0002','04567-2026-0-1801-JR-LA-02',N'Indemnización por despido arbitrario y beneficios sociales',0,'ACTIVO','2026-02-14',NULL,'65b1c2d3e4f5a60718293b02'),  -- 2
(3,2,3,'EXP-2026-0003','506015500-2026-318-0',N'Denuncia por estafa agravada en la venta de un terreno',1,'ACTIVO','2026-03-18',NULL,'65b1c2d3e4f5a60718293b03'),      -- 3
(4,4,2,'EXP-2026-0004','08910-2026-0-1801-JR-FC-03',N'Pensión de alimentos a favor de dos menores',0,'ACTIVO','2026-03-27',NULL,'65b1c2d3e4f5a60718293b04'),        -- 4
(5,5,1,'EXP-2026-0005',NULL,N'Asesoría permanente a la Municipalidad en contrataciones y multas',0,'ACTIVO','2026-07-02',NULL,'65b1c2d3e4f5a60718293b05'),   -- 5
(6,6,1,'EXP-2026-0006','ARB-2026-014',N'Arbitraje por incumplimiento de contrato de suministro',1,'ACTIVO','2026-06-30',NULL,'65b1c2d3e4f5a60718293b06'),     -- 6
(7,4,2,'EXP-2026-0007','11234-2026-0-1801-JR-FC-03',N'Medidas de protección por violencia familiar (Ley 30364), pro bono',0,'ACTIVO','2026-10-23',NULL,'65b1c2d3e4f5a60718293b07'); -- 7
GO

-- CASO_PARTE: quién participa en cada caso y con qué rol (cliente, contraparte, tercero).
INSERT INTO caso_parte (id_caso, id_persona, id_rol, tipo_parte, abogado_externo) VALUES
(1, 1, 1,'CLIENTE',NULL),
(1, 5, 4,'CONTRAPARTE',N'Dr. Raúl Ortiz Becerra'),
(2, 2, 1,'CLIENTE',NULL),
(2,16, 4,'CONTRAPARTE',N'Estudio Valdez & Asociados'),
(3, 3, 7,'CLIENTE',NULL),
(3, 7,10,'CONTRAPARTE',N'Dr. Franco Linares'),
(4, 4, 1,'CLIENTE',NULL),
(4,17, 4,'CONTRAPARTE',NULL),
(5,12,16,'CLIENTE',NULL),
(5,15,23,'TERCERO',NULL),
(6,10,21,'CLIENTE',NULL),
(6,11,21,'CONTRAPARTE',N'Estudio Ramos Lazo'),
(7, 8,13,'CLIENTE',NULL);
GO

-- CASO_ETAPA: historial de etapas (fecha_fin NULL = etapa actual).
-- Etapas: 1 Consulta inicial, 2 Postulación, 3 Actuación probatoria, 4 Audiencia, 5 Sentencia 1.ª instancia, 6 Apelación, 8 Ejecución, 9 Cerrado.
INSERT INTO caso_etapa (id_caso, id_etapa, fecha_inicio, fecha_fin) VALUES
(1,1,'2026-01-22','2026-02-10'),(1,2,'2026-02-10','2026-05-12'),(1,4,'2026-05-12','2026-06-10'),(1,5,'2026-06-10','2026-08-20'),(1,8,'2026-08-20','2026-10-15'),(1,9,'2026-10-15',NULL),
(2,1,'2026-02-14','2026-02-28'),(2,2,'2026-02-28','2026-04-18'),(2,3,'2026-04-18','2026-09-15'),(2,5,'2026-09-15','2026-09-26'),(2,6,'2026-09-26',NULL),
(3,1,'2026-03-18','2026-03-25'),(3,2,'2026-03-25',NULL),
(4,1,'2026-03-27','2026-04-02'),(4,2,'2026-04-02','2026-10-20'),(4,4,'2026-10-20',NULL),
(5,1,'2026-07-02','2026-10-05'),(5,2,'2026-10-05',NULL),
(6,1,'2026-06-30','2026-07-08'),(6,2,'2026-07-08','2026-10-10'),(6,4,'2026-10-10',NULL),
(7,1,'2026-10-23','2026-10-24'),(7,2,'2026-10-24','2026-10-30'),(7,4,'2026-10-30',NULL);
GO

-- DOCUMENTO_LEGAL (13): escritos en distintos estados; el 8 subsana al 7 (relación recursiva).
INSERT INTO documento_legal (id_caso, id_redactor, id_revisor, id_documento_origen, tipo_documento, titulo, version, elaborado_con_ia, requiere_firma_cliente, fecha_creacion, fecha_aprobacion, estado, archivo_mongo_id) VALUES
(1,5,1,NULL,'DEMANDA',N'Demanda de obligación de dar suma de dinero',1,1,1,'2026-02-03 10:00:00','2026-02-08 17:00:00','PRESENTADO','65c1d2e3f4a5b60718293c01'),   -- 1
(1,1,NULL,NULL,'ABSOLUCION',N'Absolución de excepción de incompetencia',1,0,0,'2026-04-01 09:00:00','2026-04-01 12:00:00','PRESENTADO','65c1d2e3f4a5b60718293c02'), -- 2
(2,2,1,NULL,'DEMANDA',N'Demanda de indemnización por despido arbitrario',1,0,1,'2026-02-25 10:00:00','2026-02-27 16:00:00','PRESENTADO','65c1d2e3f4a5b60718293c03'),   -- 3
(2,2,1,NULL,'RECURSO',N'Recurso de apelación contra la sentencia',1,0,0,'2026-09-20 10:00:00','2026-09-25 15:00:00','PRESENTADO','65c1d2e3f4a5b60718293c04'),     -- 4
(3,3,1,NULL,'DENUNCIA',N'Denuncia penal por estafa agravada',1,1,1,'2026-03-20 10:00:00','2026-03-24 17:00:00','PRESENTADO','65c1d2e3f4a5b60718293c05'),        -- 5
(3,5,3,NULL,'ESCRITO_SIMPLE',N'Solicitud de copias de la carpeta fiscal',1,0,0,'2026-10-01 09:00:00','2026-10-01 11:00:00','PRESENTADO','65c1d2e3f4a5b60718293c06'), -- 6
(4,2,1,NULL,'DEMANDA',N'Demanda de alimentos',1,1,1,'2026-04-01 10:00:00','2026-04-02 09:00:00','PRESENTADO','65c1d2e3f4a5b60718293c07'),                   -- 7
(4,5,2,7,'SUBSANACION',N'Subsanación: se adjuntan partidas de nacimiento',1,0,0,'2026-04-20 10:00:00','2026-04-21 12:00:00','PRESENTADO','65c1d2e3f4a5b60718293c08'), -- 8
(5,1,3,NULL,'DESCARGO',N'Descargo contra la multa administrativa',1,0,0,'2026-10-05 10:00:00','2026-10-07 16:00:00','PRESENTADO','65c1d2e3f4a5b60718293c09'),      -- 9
(6,1,2,NULL,'SOLICITUD',N'Solicitud de arbitraje',1,0,1,'2026-07-08 10:00:00','2026-07-10 17:00:00','PRESENTADO','65c1d2e3f4a5b60718293c0a'),                    -- 10
(6,1,2,NULL,'CONTESTACION',N'Contestación a la reconvención',1,1,0,'2026-10-20 10:00:00',NULL,'EN_REVISION','65c1d2e3f4a5b60718293c0b'),                          -- 11
(7,2,1,NULL,'SOLICITUD',N'Solicitud de medidas de protección',1,0,1,'2026-10-23 09:00:00','2026-10-23 12:00:00','PRESENTADO','65c1d2e3f4a5b60718293c0c'),         -- 12
(4,5,NULL,NULL,'ESCRITO_SIMPLE',N'Escrito de alegatos para la audiencia',1,0,0,'2026-11-02 10:00:00',NULL,'BORRADOR',NULL);                                         -- 13
GO

-- DOCUMENTO_JURISPRUDENCIA: normas y casaciones citadas en cada escrito.
INSERT INTO documento_jurisprudencia (id_documento, id_jurisprudencia, nota) VALUES
(1,1,N'Requisitos formales de la demanda'),
(1,2,N'Acreditación del préstamo con documento privado'),
(3,3,N'Base legal del despido arbitrario'),
(3,4,N'Criterios de cálculo de la indemnización'),
(5,7,N'Elementos del engaño en la estafa'),
(7,6,N'Prueba de los ingresos del obligado'),
(9,8,N'Tratamiento de datos en el procedimiento'),
(9,10,N'Régimen de contrataciones del Estado'),
(10,9,N'Marco legal del arbitraje'),
(12,5,N'Medidas de protección de la Ley 30364');
GO

-- PRESENTACION (11): ingreso de los escritos ante cada entidad. Las tasas ya no son una columna: se registran en GASTO_CASO.
INSERT INTO presentacion (id_documento, id_entidad, id_empleado, fecha_hora, modalidad, nro_cargo) VALUES
(1, 1,4,'2026-02-10 10:30:00','ELECTRONICA',N'2026-00123-SINOE'),   -- 1
(2, 1,4,'2026-04-02 09:00:00','ELECTRONICA',N'2026-00456-SINOE'),     -- 2
(3, 2,5,'2026-02-28 11:00:00','ELECTRONICA',N'CARGO-LAB-0456'),       -- 3
(4, 2,5,'2026-09-26 10:00:00','ELECTRONICA',N'2026-04567-SINOE-APEL'), -- 4
(5, 4,5,'2026-03-25 09:30:00','FISICA',N'MP-FPL-2026-318'),           -- 5
(6, 4,5,'2026-10-02 10:00:00','FISICA',N'MP-FPL-2026-1450'),          -- 6
(7, 5,4,'2026-04-02 12:00:00','FISICA',N'JFC-3-2026-0891'),           -- 7
(8, 5,5,'2026-04-22 09:00:00','ELECTRONICA',N'JFC-3-2026-0891-S1'),   -- 8
(9, 6,4,'2026-10-08 10:00:00','FISICA',N'MVA-OC-2026-077'),           -- 9
(10,8,4,'2026-07-12 11:00:00','FISICA',N'CAEA-2026-014-S1'),        -- 10
(12,5,5,'2026-10-23 13:00:00','FISICA',N'JFC-3-2026-1123');           -- 11
GO

-- GASTO_CASO (5): tasas y otros gastos del caso (reemplaza a PRESENTACION.monto_tasa).
-- Los gastos 1 y 3 se reembolsan al cliente en comprobantes (DETALLE_COMPROBANTE.id_gasto); el 2 y el 4 siguen pendientes de cobro; el 5 lo asume el estudio.
-- El trigger trg_gasto_caso_mismo_caso exige que la presentación sea del mismo caso del gasto.
INSERT INTO gasto_caso (id_caso, id_presentacion, id_empleado, fecha, concepto, monto, es_reembolsable) VALUES
(1, 1,   4,'2026-02-10',N'Tasa judicial: demanda de obligación de dar suma de dinero',180.00,1),  -- 1
(2, 4,   5,'2026-09-26',N'Tasa judicial: recurso de apelación',215.00,1),                         -- 2
(6,10,   4,'2026-07-12',N'Tasa arbitral: solicitud de arbitraje',350.00,1),                       -- 3
(3, 6,   5,'2026-10-02',N'Copias certificadas de la carpeta fiscal',45.00,1),                     -- 4
(5,NULL, 4,'2026-10-06',N'Fotocopias y movilidad para el trámite del expediente',60.00,0);        -- 5
GO

-- RESOLUCION (18): lo que notifica cada entidad (id_presentacion NULL si no responde a un escrito nuestro).
INSERT INTO resolucion (id_caso, id_entidad, id_presentacion, nro_resolucion, tipo_resolucion, fecha_notificacion, medio_notificacion, sumilla, archivo_mongo_id) VALUES
(1,1,1,   N'Resolución 1',N'ADMISORIO','2026-02-17','SINOE',N'Se admite a trámite la demanda y se corre traslado','65d1e2f3a4b5c60718293d01'),               -- 1
(1,1,NULL,N'Resolución 5',N'CITACION','2026-05-12','SINOE',N'Se cita a audiencia única','65d1e2f3a4b5c60718293d02'),                                -- 2
(1,1,NULL,N'Sentencia 45-2026',N'SENTENCIA','2026-07-02','SINOE',N'Fundada la demanda; se ordena pagar S/ 26,000','65d1e2f3a4b5c60718293d03'),     -- 3
(1,1,NULL,N'Resolución 12',N'DECRETO','2026-08-20','SINOE',N'Se declara consentida la sentencia','65d1e2f3a4b5c60718293d04'),                        -- 4
(2,2,3,   N'Resolución 1',N'ADMISORIO','2026-03-05','SINOE',N'Se admite la demanda laboral','65d1e2f3a4b5c60718293d05'),                            -- 5
(2,2,NULL,N'Resolución 4',N'CITACION','2026-04-18','SINOE',N'Se cita a audiencia de conciliación y juzgamiento','65d1e2f3a4b5c60718293d06'),        -- 6
(2,2,NULL,N'Sentencia 118-2026',N'SENTENCIA','2026-09-15','SINOE',N'Fundada en parte; se ordena pagar S/ 18,500','65d1e2f3a4b5c60718293d07'),      -- 7
(3,4,5,   N'Disposición 1',N'REQUERIMIENTO','2026-04-02','CORREO',N'Se requiere acreditar los pagos realizados','65d1e2f3a4b5c60718293d08'),     -- 8
(3,4,6,   N'Disposición 8',N'REQUERIMIENTO','2026-10-28','CEDULA',N'Se requiere presentar el contrato de compraventa original','65d1e2f3a4b5c60718293d09'), -- 9
(4,5,7,   N'Resolución 1',N'INADMISIBLE','2026-04-15','SINOE',N'Se otorgan 5 días para subsanar la demanda','65d1e2f3a4b5c60718293d0a'),          -- 10
(4,5,8,   N'Resolución 2',N'ADMISORIO','2026-05-06','SINOE',N'Se admite la demanda de alimentos','65d1e2f3a4b5c60718293d0b'),                       -- 11
(4,5,NULL,N'Resolución 7',N'CITACION','2026-10-20','SINOE',N'Audiencia única el 12 de noviembre de 2026','65d1e2f3a4b5c60718293d0c'),              -- 12
(5,6,9,   N'Resolución Gerencial 211-2026',N'TRASLADO','2026-10-30','CASILLA_ADMINISTRATIVA',N'Se corre traslado del informe técnico','65d1e2f3a4b5c60718293d0d'), -- 13
(6,8,10,  N'Orden Procesal 1',N'ADMISORIO','2026-07-20','CORREO',N'Se admite la solicitud de arbitraje','65d1e2f3a4b5c60718293d0e'),                   -- 14
(6,8,NULL,N'Orden Procesal 3',N'CITACION','2026-10-10','CORREO',N'Audiencia de instalación y puntos controvertidos','65d1e2f3a4b5c60718293d0f'),  -- 15
(6,8,NULL,N'Orden Procesal 4',N'TRASLADO','2026-10-14','CORREO',N'Traslado de la reconvención por 10 días hábiles','65d1e2f3a4b5c60718293d10'),    -- 16
(7,5,11,  N'Resolución 1',N'DECRETO','2026-10-25','SINOE',N'Se otorgan medidas de protección provisionales','65d1e2f3a4b5c60718293d11'),         -- 17
(7,5,NULL,N'Resolución 2',N'CITACION','2026-10-30','CEDULA',N'Audiencia de ratificación de medidas el 19 de noviembre','65d1e2f3a4b5c60718293d12'); -- 18
GO

-- PLAZO (10): el estado NO se guarda; lo calcula vw_plazo_estado (hay cumplidos, vencidos y pendientes).
-- dias_plazo + tipo_computo explican el vencimiento: en los CALENDARIO, vencimiento = inicio + días (lo exige un CHECK);
-- en los HABIL se descuentan sábados, domingos y los días de FERIADO. Los que vencen en ≤ 5 días aparecen en vw_plazos_por_vencer.
-- id_presentacion_cumplimiento es el escrito con el que se cumplió el plazo (solo en los cumplidos con escrito).
INSERT INTO plazo (id_caso, id_resolucion, id_empleado_responsable, id_presentacion_cumplimiento, descripcion, fecha_inicio, dias_plazo, tipo_computo, fecha_vencimiento, fecha_cumplimiento) VALUES
(1,1,   1,2,   N'Absolver la excepción propuesta por el demandado','2026-03-26', 8,'CALENDARIO','2026-04-03','2026-04-02'),   -- 1
(1,3,   1,NULL,N'Esperar el vencimiento del plazo de apelación','2026-07-03',15,'HABIL','2026-07-24','2026-07-24'),            -- 2
(2,7,   2,4,   N'Interponer apelación contra la sentencia','2026-09-15',10,'HABIL','2026-09-29','2026-09-26'),                 -- 3
(2,NULL,2,NULL,N'Absolver los agravios de la apelación del demandado',DATEADD(DAY, -14, CAST(GETDATE() AS DATE)),17,'CALENDARIO',DATEADD(DAY, 3, CAST(GETDATE() AS DATE)),NULL),         -- 4 vence en 3 días
(3,9,   3,NULL,N'Presentar el contrato de compraventa original','2026-10-28', 7,'HABIL','2026-11-06',NULL),                    -- 5
(4,10,  2,8,   N'Subsanar la demanda (5 días)','2026-04-15', 5,'HABIL','2026-04-22','2026-04-22'),                             -- 6
(4,12,  2,NULL,N'Presentar alegatos antes de la audiencia',DATEADD(DAY, -21, CAST(GETDATE() AS DATE)),22,'CALENDARIO',DATEADD(DAY, 1, CAST(GETDATE() AS DATE)),NULL),                    -- 7 vence MAÑANA
(5,13,  1,NULL,N'Absolver el traslado del informe técnico','2026-10-30',10,'HABIL','2026-11-13',NULL),                         -- 8
(6,16,  1,NULL,N'Contestar la reconvención','2026-10-14',26,'CALENDARIO','2026-11-09',NULL),                                   -- 9
(7,17,  5,NULL,N'Acreditar el domicilio de la persona protegida',DATEADD(DAY, -9, CAST(GETDATE() AS DATE)), 7,'CALENDARIO',DATEADD(DAY, -2, CAST(GETDATE() AS DATE)),NULL);              -- 10 VENCIDO hace 2 días
GO

-- AUDIENCIA (6): una reprogramada, dos realizadas y tres programadas a futuro.
INSERT INTO audiencia (id_resolucion, id_abogado, fecha_hora, modalidad, tipo_audiencia, estado, acta_mongo_id) VALUES
(2, 1,'2026-05-28 09:00:00','PRESENCIAL','JUDICIAL','REPROGRAMADA',NULL),                          -- 1
(2, 1,'2026-06-10 09:00:00','PRESENCIAL','JUDICIAL','REALIZADA','65e1f2a3b4c5d60718293e01'),       -- 2
(6, 2,'2026-05-20 10:00:00','PRESENCIAL','JUDICIAL','REALIZADA','65e1f2a3b4c5d60718293e02'),       -- 3
(12,2,DATEADD(HOUR, 10, CAST(DATEADD(DAY, 2, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),'VIRTUAL',   'JUDICIAL','PROGRAMADA',NULL),                          -- 4 en 2 días
(15,1,DATEADD(HOUR, 15, CAST(DATEADD(DAY, 7, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),'VIRTUAL',   'ARBITRAL','PROGRAMADA',NULL),                          -- 5 en 7 días
(18,2,DATEADD(HOUR, 9, CAST(DATEADD(DAY, 8, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),'PRESENCIAL','JUDICIAL','PROGRAMADA',NULL);                          -- 6 en 8 días
GO

-- ---------------------------------------------------------------------
-- 4. PROCESO 3 · RESOLUCIÓN Y FACTURACIÓN
-- ---------------------------------------------------------------------

-- SENTENCIA (2): especialización 1:1 de RESOLUCION (misma llave). Las resoluciones 3 y 7 son de tipo SENTENCIA.
INSERT INTO sentencia (id_resolucion, instancia, resultado, monto_ordenado, se_apela, fecha_firmeza, requiere_ejecucion) VALUES
(3,'PRIMERA','FAVORABLE',26000.00,0,'2026-08-20',1),   -- caso 1: consentida
(7,'PRIMERA','PARCIAL',   18500.00,1,NULL,        0);   -- caso 2: se apeló, aún sin firmeza
GO

-- LIQUIDACION (1): caso 1. La cuota litis (20 % de lo obtenido: 26,000 × 0.20 = 5,200) no se guarda aquí: la calcula vw_liquidacion_cuota_litis y se cobra en la cuota 4.
INSERT INTO liquidacion (id_caso, id_abogado, fecha_liquidacion, monto_obtenido, estado) VALUES
(1,1,'2026-10-10',26000.00,'ACEPTADA');
GO

-- La cuota litis (id 4) se vincula ahora a la liquidación que la generó.
UPDATE cuota SET id_liquidacion = 1 WHERE id_cuota = 4;
GO

-- SERIE_COMPROBANTE (3): cada serie pertenece a un tipo de comprobante. ultimo_numero arranca en 0 y lo sube solo el trigger
-- trg_comprobante_correlativo al insertar comprobantes, que además exige que el número sea el siguiente (al final: B001 = 16, F001 = 10, E001 = 0).
INSERT INTO serie_comprobante (serie, tipo_comprobante) VALUES
('B001','BOLETA'),('F001','FACTURA'),('E001','RECIBO_HONORARIOS');
GO

-- COMPROBANTE (26): 1-6 cobran consultas; 7-26 cobran cuotas. El tipo (boleta/factura) sale de la serie. moneda = soles (PEN).
-- estado solo guarda EMITIDO o ANULADO: si está pagado, parcial o pendiente lo calcula vw_comprobante_saldo con los pagos.
-- El número es el correlativo de cada serie en orden de fecha de emisión (el trigger 6 exige que no haya saltos).
-- Las facturas a la municipalidad y a la empresa llevan detracción de 12 % (porcentaje_detraccion = 0.12); las de la municipalidad, además, fecha de conformidad (entidad pública).
INSERT INTO comprobante (id_persona, id_emisor, id_consulta, serie, numero, fecha_emision, fecha_vencimiento, moneda, tasa_igv, porcentaje_detraccion, fecha_conformidad, estado) VALUES
(1,4,1,'B001',1,'2026-01-12','2026-01-12','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 1  consulta 1
(2,4,2,'B001',3,'2026-02-03','2026-02-03','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 2  consulta 2
(3,4,3,'B001',6,'2026-03-05','2026-03-05','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 3  consulta 3
(4,4,4,'B001',10,'2026-03-18','2026-03-18','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 4  consulta 4
(10,4,6,'F001',1,'2026-06-17','2026-06-17','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 5  consulta 6 (empresa)
(13,4,8,'B001',15,'2026-10-01','2026-10-08','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 6  consulta 8 (sin pagar)
(1,6,NULL,'B001',2,'2026-01-20','2026-01-20','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 7  cuota 1
(1,6,NULL,'B001',4,'2026-02-10','2026-02-20','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 8  cuota 2
(1,6,NULL,'B001',8,'2026-03-10','2026-03-20','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 9  cuota 3
(1,6,NULL,'B001',16,'2026-10-20','2026-10-30','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 10 cuota litis
(2,6,NULL,'B001',5,'2026-02-12','2026-02-12','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 11 cuota 5
(2,6,NULL,'B001',7,'2026-03-05','2026-03-12','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 12 cuota 6
(3,6,NULL,'B001',9,'2026-03-16','2026-03-16','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 13 cuota 7
(3,6,NULL,'B001',12,'2026-04-06','2026-04-16','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 14 cuota 8
(3,6,NULL,'B001',13,'2026-05-06','2026-05-16','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 15 cuota 9
(3,6,NULL,'B001',14,'2026-06-06','2026-06-16','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 16 cuota 10 (vencida)
(4,6,NULL,'B001',11,'2026-03-25','2026-03-25','PEN',0.18,0.00,NULL,'EMITIDO'),  -- 17 cuota 11
(12,6,NULL,'F001',4,'2026-07-20','2026-07-31','PEN',0.18,0.12,'2026-07-25','EMITIDO'),  -- 18 cuota 13
(12,6,NULL,'F001',6,'2026-08-20','2026-08-31','PEN',0.18,0.12,'2026-08-25','EMITIDO'),  -- 19 cuota 14
(12,6,NULL,'F001',8,'2026-09-20','2026-09-30','PEN',0.18,0.12,'2026-09-25','EMITIDO'),  -- 20 cuota 15
(12,6,NULL,'F001',10,'2026-10-20','2026-10-31','PEN',0.18,0.12,'2026-10-27','EMITIDO'),  -- 21 cuota 16
(10,6,NULL,'F001',2,'2026-06-28','2026-06-28','PEN',0.18,0.12,NULL,'EMITIDO'),  -- 22 cuota 18
(10,6,NULL,'F001',3,'2026-07-18','2026-07-28','PEN',0.18,0.12,NULL,'EMITIDO'),  -- 23 cuota 19
(10,6,NULL,'F001',5,'2026-08-18','2026-08-28','PEN',0.18,0.12,NULL,'EMITIDO'),  -- 24 cuota 20
(10,6,NULL,'F001',7,'2026-09-18','2026-09-28','PEN',0.18,0.12,NULL,'EMITIDO'),  -- 25 cuota 21
(10,6,NULL,'F001',9,'2026-10-18','2026-10-28','PEN',0.18,0.12,NULL,'EMITIDO');  -- 26 cuota 22 (vencida)
GO

-- DETALLE_COMPROBANTE (28): una línea por comprobante, más 2 líneas que reembolsan gastos (id_gasto: en una línea va id_cuota o id_gasto, nunca ambos). valor_unitario va SIN IGV (el total lo calcula la vista).
INSERT INTO detalle_comprobante (id_comprobante, nro_linea, id_cuota, id_gasto, descripcion, cantidad, valor_unitario) VALUES
( 1,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 2,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 3,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 4,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 5,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 6,1,NULL,NULL,N'Consulta jurídica inicial',1.00,100.00),
( 7,1, 1,NULL,N'Honorarios: adelanto',1.00,1500.00),
( 8,1, 2,NULL,N'Honorarios: cuota 2',1.00,1000.00),
( 9,1, 3,NULL,N'Honorarios: cuota 3',1.00,1000.00),
(10,1, 4,NULL,N'Honorarios: cuota litis 20 %',1.00,5200.00),
(11,1, 5,NULL,N'Honorarios: adelanto',1.00,1000.00),
(12,1, 6,NULL,N'Honorarios: cuota 2',1.00,1000.00),
(13,1, 7,NULL,N'Honorarios: adelanto',1.00,1250.00),
(14,1, 8,NULL,N'Honorarios: cuota 2',1.00,1250.00),
(15,1, 9,NULL,N'Honorarios: cuota 3',1.00,1250.00),
(16,1,10,NULL,N'Honorarios: cuota 4',1.00,1250.00),
(17,1,11,NULL,N'Honorarios: adelanto',1.00,900.00),
(18,1,13,NULL,N'Iguala mensual: julio 2026',1.00,900.00),
(19,1,14,NULL,N'Iguala mensual: agosto 2026',1.00,900.00),
(20,1,15,NULL,N'Iguala mensual: setiembre 2026',1.00,900.00),
(21,1,16,NULL,N'Iguala mensual: octubre 2026',1.00,900.00),
(22,1,18,NULL,N'Honorarios arbitraje: adelanto',1.00,3000.00),
(23,1,19,NULL,N'Honorarios arbitraje: cuota 2',1.00,3000.00),
(24,1,20,NULL,N'Honorarios arbitraje: cuota 3',1.00,3000.00),
(25,1,21,NULL,N'Honorarios arbitraje: cuota 4',1.00,3000.00),
(26,1,22,NULL,N'Honorarios arbitraje: cuota 5',1.00,3000.00),
(10,2,NULL,1,N'Reembolso de tasa judicial (demanda)',1.00,180.00),   -- gasto 1 reembolsado junto con la cuota litis
(26,2,NULL,3,N'Reembolso de tasa arbitral',1.00,350.00);                     -- gasto 3 reembolsado en la factura de la cuota 22
GO

-- PAGO: los comprobantes ya cobrados se pagan completos (monto = total de la vista) el día que se emiten.
-- Quedan sin pagar el 6 (consulta), el 16 y el 26 (cuotas vencidas); el 21 tiene un pago parcial.
INSERT INTO pago (id_comprobante, id_empleado, fecha_pago, monto, medio_pago, nro_operacion)
SELECT c.id_comprobante, 4,
       DATEADD(HOUR, 10, CAST(c.fecha_emision AS DATETIME2(0))),
       t.total,
       CASE c.id_comprobante % 4 WHEN 0 THEN 'EFECTIVO' WHEN 1 THEN 'YAPE' WHEN 2 THEN 'TRANSFERENCIA' ELSE 'DEPOSITO' END,
       CASE WHEN c.id_comprobante % 4 = 0 THEN NULL ELSE CONCAT('OP-', RIGHT(CONCAT('000000', c.id_comprobante), 6)) END
FROM comprobante c
JOIN vw_comprobante_total t ON t.id_comprobante = c.id_comprobante
WHERE c.id_comprobante NOT IN (6, 16, 21, 26);
GO

-- Pago parcial del comprobante 21 (total 1,062.00: la municipalidad abonó 500.00 y queda saldo).
INSERT INTO pago (id_comprobante, id_empleado, fecha_pago, monto, medio_pago, nro_operacion) VALUES
(21, 4, '2026-10-29 11:00:00', 500.00, 'TRANSFERENCIA', N'OP-000021');
GO

-- DEVOLUCION (1) y ENCUESTA (1): cierre del caso 1.
INSERT INTO devolucion (id_caso, id_persona, id_empleado, fecha_entrega, descripcion_documentos, cargo_firmado) VALUES
(1, 1, 4, '2026-10-16 11:00:00', N'Contrato de mutuo original, pagaré y copia certificada de la sentencia', 1);
INSERT INTO encuesta (id_caso, fecha_envio, fecha_respuesta, calificacion, nps, comentario) VALUES
(1, '2026-10-16 15:00:00', '2026-10-17 09:30:00', 5, 10, N'Excelente atención y comunicación constante durante todo el proceso');
GO


-- USUARIO (11): cuentas del panel (7 empleados; el practicante inactivo queda bloqueado) y del portal (4 clientes).
-- contrasena_hash es un hash bcrypt DE EJEMPLO: la aplicación lo genera; la contraseña nunca se guarda.
INSERT INTO usuario (id_empleado, id_persona, email, contrasena_hash, activo, ultimo_acceso) VALUES
(1,NULL,N'hector.magallanes@mmabogados.pe','$2b$12$Q9v1Hh3b8m0kz7YlT1dWzO8kqk1r0d9mFQm2pX7aT3sV5nB6cD8eG',1,DATEADD(HOUR,-2,SYSDATETIME())),
(2,NULL,N'lucia.montero@mmabogados.pe','$2b$12$A1b2C3d4E5f6G7h8I9j0KuLmNoPqRsTuVwXyZaBcDeFgHiJkLmNoP',1,DATEADD(HOUR,-5,SYSDATETIME())),
(3,NULL,N'diego.salinas@mmabogados.pe','$2b$12$Z9y8X7w6V5u4T3s2R1q0PoNmLkJiHgFeDcBaZyXwVuTsRqPoNmLkJ',1,DATEADD(DAY,-1,SYSDATETIME())),
(4,NULL,N'karen.paredes@mmabogados.pe','$2b$12$M1n2B3v4C5x6Z7l8K9j0HgFdSaPoIuYtReWqAsDfGhJkLzXcVbNmQ',1,DATEADD(MINUTE,-30,SYSDATETIME())),
(5,NULL,N'miguel.rojas@mmabogados.pe','$2b$12$P0o9I8u7Y6t5R4e3W2q1AsDfGhJkLzXcVbNmQwErTyUiOpAsDfGhJ',1,DATEADD(DAY,-2,SYSDATETIME())),
(6,NULL,N'gabriela.montero@mmabogados.pe','$2b$12$L1k2J3h4G5f6D7s8A9p0OiUyTrEwQaSdFgHjKlZxCvBnMqWeRtYuI',1,DATEADD(DAY,-3,SYSDATETIME())),
(7,NULL,N'renzo.ccama@mmabogados.pe','$2b$12$R1e2N3z4O5c6C7a8M9a0TqWeRtYuIoPaSdFgHjKlZxCvBnMqWeRtY',0,'2026-08-31 18:00:00'),
(NULL,1,N'juan.perez@example.com','$2b$12$J1u2A3n4P5e6R7e8Z9q0UiSpOrTaLcLiEnTeAbCdEfGhIjKlMnOpQ',1,DATEADD(DAY,-4,SYSDATETIME())),
(NULL,2,N'maria.torres@example.com','$2b$12$M1a2R3i4A5t6O7r8R9e0SpOrTaLcLiEnTeAbCdEfGhIjKlMnOpQrS',1,NULL),
(NULL,4,N'rosa.huaman.portal@example.com','$2b$12$R1o2S3a4H5u6A7m8A9n0PoRtAlClIeNtEaBcDeFgHiJkLmNoPqRsT',1,DATEADD(DAY,-1,SYSDATETIME())),
(NULL,10,N'contacto@inversionesandinas.example.com','$2b$12$I1n2V3e4R5s6I7o8N9e0SaNdInAsPoRtAlAbCdEfGhIjKlMnOpQrS',1,DATEADD(DAY,-6,SYSDATETIME()));
GO

-- NOTIFICACION (12): avisos del carril «Sistema» del TO-BE. Las PENDIENTE salen en las próximas horas (fechas relativas).
INSERT INTO notificacion (id_persona, id_empleado, id_consulta, id_caso, tipo_evento, canal, mensaje, fecha_programada, fecha_envio, estado) VALUES
(1, NULL, 1, NULL,'CONFIRMACION_CONSULTA','WHATSAPP',N'Recibimos su consulta. Le escribiremos para agendar su cita.','2026-01-12 09:16:00','2026-01-12 09:16:00','ENVIADA'),
(19,NULL,12, NULL,'CONFIRMACION_CONSULTA','CORREO',  N'Recibimos su consulta desde nuestra web.','2026-11-02 20:11:00','2026-11-02 20:11:00','ENVIADA'),
(NULL,4, 12, NULL,'CONFIRMACION_CONSULTA','SISTEMA', N'Nueva consulta desde la landing: cesión de derechos de marca.','2026-11-02 20:11:00','2026-11-02 20:11:00','ENVIADA'),
(14,NULL, 9, NULL,'RECORDATORIO_CITA',    'WHATSAPP',N'Le recordamos su cita de mañana a las 10:00 con la Dra. Montero.',DATEADD(HOUR, 10, CAST(DATEADD(DAY, 0, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'PENDIENTE'),
(NULL,2, NULL,2,  'ALERTA_PLAZO',         'SISTEMA', N'EXP-2026-0002: vence en 3 días el plazo para absolver los agravios.',DATEADD(HOUR, 8, CAST(DATEADD(DAY, 0, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'PENDIENTE'),
(NULL,2, NULL,4,  'ALERTA_PLAZO',         'CORREO',  N'EXP-2026-0004: mañana vence el plazo para presentar alegatos.',DATEADD(HOUR, 8, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),DATEADD(HOUR, 8, CAST(DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),'ENVIADA'),
(NULL,5, NULL,7,  'ALERTA_PLAZO',         'CORREO',  N'EXP-2026-0007: plazo vencido para acreditar el domicilio.',DATEADD(HOUR, 8, CAST(DATEADD(DAY, -2, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'FALLIDA'),
(4, NULL,NULL,4,  'AVISO_AUDIENCIA',      'WHATSAPP',N'Su audiencia única es en 2 días (virtual). Le enviaremos el enlace.',DATEADD(HOUR, 9, CAST(DATEADD(DAY, 0, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'PENDIENTE'),
(4, NULL,NULL,4,  'RECORDATORIO_CUOTA',   'WHATSAPP',N'Su cuota 2 de S/ 900.00 vence en 4 días.',DATEADD(HOUR, 9, CAST(DATEADD(DAY, 1, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'PENDIENTE'),
(12,NULL,NULL,5,  'CONSTANCIA_PAGO',      'CORREO',  N'Recibimos su abono de S/ 500.00 a la factura F001.','2026-10-29 11:05:00','2026-10-29 11:05:00','ENVIADA'),
(1, NULL,NULL,1,  'ENVIO_ENCUESTA',       'WHATSAPP',N'Su caso concluyó. ¿Nos ayuda con una encuesta de 1 minuto?','2026-10-16 15:00:00','2026-10-16 15:00:00','ENVIADA'),
(10,NULL,NULL,6,  'FIRMA_DOCUMENTO',      'CORREO',  N'Tiene un escrito pendiente de firma en el portal del cliente.',DATEADD(HOUR, 12, CAST(DATEADD(DAY, 0, CAST(GETDATE() AS DATE)) AS DATETIME2(0))),NULL,'PENDIENTE');
GO

-- ---------------------------------------------------------------------
-- 5. VERIFICACIÓN RÁPIDA (conteos esperados y vistas)
-- ---------------------------------------------------------------------
SELECT 'persona' AS tabla, COUNT(*) AS filas, 21 AS esperado FROM persona UNION ALL
SELECT 'empleado',COUNT(*),7 FROM empleado UNION ALL SELECT 'abogado',COUNT(*),3 FROM abogado UNION ALL SELECT 'feriado',COUNT(*),16 FROM feriado UNION ALL
SELECT 'serie_comprobante',COUNT(*),3 FROM serie_comprobante UNION ALL SELECT 'gasto_caso',COUNT(*),5 FROM gasto_caso UNION ALL
SELECT 'materia',COUNT(*),6 FROM materia UNION ALL
SELECT 'rol_procesal',COUNT(*),24 FROM rol_procesal UNION ALL SELECT 'etapa_procesal',COUNT(*),9 FROM etapa_procesal UNION ALL
SELECT 'entidad',COUNT(*),10 FROM entidad UNION ALL SELECT 'jurisprudencia',COUNT(*),10 FROM jurisprudencia UNION ALL
SELECT 'consulta',COUNT(*),12 FROM consulta UNION ALL SELECT 'consulta_contraparte',COUNT(*),10 FROM consulta_contraparte UNION ALL
SELECT 'cita',COUNT(*),12 FROM cita UNION ALL SELECT 'propuesta',COUNT(*),11 FROM propuesta UNION ALL
SELECT 'contrato',COUNT(*),7 FROM contrato UNION ALL SELECT 'cuota',COUNT(*),22 FROM cuota UNION ALL
SELECT 'caso',COUNT(*),7 FROM caso UNION ALL SELECT 'abogado_materia',COUNT(*),7 FROM abogado_materia UNION ALL
SELECT 'caso_parte',COUNT(*),13 FROM caso_parte UNION ALL SELECT 'caso_etapa',COUNT(*),24 FROM caso_etapa UNION ALL
SELECT 'documento_legal',COUNT(*),13 FROM documento_legal UNION ALL SELECT 'documento_jurisprudencia',COUNT(*),10 FROM documento_jurisprudencia UNION ALL
SELECT 'presentacion',COUNT(*),11 FROM presentacion UNION ALL SELECT 'resolucion',COUNT(*),18 FROM resolucion UNION ALL
SELECT 'plazo',COUNT(*),10 FROM plazo UNION ALL SELECT 'audiencia',COUNT(*),6 FROM audiencia UNION ALL
SELECT 'sentencia',COUNT(*),2 FROM sentencia UNION ALL SELECT 'liquidacion',COUNT(*),1 FROM liquidacion UNION ALL
SELECT 'comprobante',COUNT(*),26 FROM comprobante UNION ALL SELECT 'detalle_comprobante',COUNT(*),28 FROM detalle_comprobante UNION ALL
SELECT 'pago',COUNT(*),23 FROM pago UNION ALL SELECT 'devolucion',COUNT(*),1 FROM devolucion UNION ALL
SELECT 'encuesta',COUNT(*),1 FROM encuesta UNION ALL
SELECT 'usuario',COUNT(*),11 FROM usuario UNION ALL SELECT 'notificacion',COUNT(*),12 FROM notificacion;
GO

SELECT serie, numero, total, pagado, saldo, estado_pago FROM vw_comprobante_saldo WHERE saldo > 0 ORDER BY serie, numero;  -- Con saldo: 3 PENDIENTE y 1 PAGADO_PARCIAL.
GO
SELECT codigo_interno, descripcion, fecha_vencimiento, dias_restantes FROM vw_plazos_por_vencer ORDER BY dias_restantes;  -- Plazos que vencen pronto.
GO
SELECT id_caso, descripcion, tipo_computo, fecha_vencimiento, estado FROM vw_plazo_estado ORDER BY fecha_vencimiento;  -- Estado calculado de cada plazo.
GO
SELECT id_contrato, nro_cuota, monto, fecha_vencimiento FROM vw_cuota_estado WHERE estado = 'VENCIDA';  -- Cuotas vencidas (calculadas).
GO
SELECT id_caso, monto_obtenido, porcentaje_cuota_litis, monto_cuota_litis FROM vw_liquidacion_cuota_litis;  -- Cuota litis calculada.
GO
SELECT serie, tipo_comprobante, ultimo_numero FROM serie_comprobante ORDER BY serie;  -- Correlativos (B001 = 16, F001 = 10, E001 = 0).
GO
SELECT tipo_evento, canal, estado, fecha_programada FROM notificacion WHERE estado = 'PENDIENTE' ORDER BY fecha_programada;  -- Cola de avisos.
GO
SELECT c.codigo_interno, g.concepto, g.monto FROM gasto_caso g JOIN caso c ON c.id_caso = g.id_caso
WHERE g.es_reembolsable = 1 AND NOT EXISTS (SELECT 1 FROM detalle_comprobante d WHERE d.id_gasto = g.id_gasto);  -- Gastos reembolsables aún sin cobrar (gastos 2 y 4).
GO
