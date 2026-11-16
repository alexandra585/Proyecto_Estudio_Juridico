// =====================================================================
// ESTUDIO JURÍDICO MAGALLANES-MONTERO · BASE NO RELACIONAL (MongoDB)
// Script para mongosh / MongoDB Compass / MongoDB Atlas
// ---------------------------------------------------------------------
// CÓMO EJECUTARLO
//   MongoDB Compass: conectarse > pestaña "Mongosh" (abajo) > pegar todo > Enter.
//   Consola:  mongosh "mongodb+srv://<usuario>@<cluster>.mongodb.net" mongodb_colecciones.js
//
// QUÉ VA EN MONGODB Y QUÉ VA EN SQL SERVER
//   SQL Server guarda lo que necesita exactitud y relaciones obligatorias:
//   personas, casos, plazos, cuotas, comprobantes, pagos (36 tablas).
//   MongoDB guarda lo que cambia de forma o pesa mucho:
//     1. expedientes            → expediente digital de cada caso (bitácora, etiquetas, índice de archivos)
//     2. archivos               → cada escrito, resolución, contrato o acta con sus versiones
//     3. formularios_encuesta   → versiones del formulario de satisfacción (preguntas cambiantes)
//     4. encuestas              → respuestas completas de cada cliente
//
// CÓMO SE ENLAZAN LAS DOS BASES (columnas CHAR(24) en SQL Server)
//   dbo.caso.expediente_mongo_id          = expedientes._id
//   dbo.documento_legal.archivo_mongo_id  = archivos._id   (tipo ESCRITO)
//   dbo.resolucion.archivo_mongo_id       = archivos._id   (tipo RESOLUCION)
//   dbo.contrato.archivo_mongo_id         = archivos._id   (tipo CONTRATO)
//   dbo.audiencia.acta_mongo_id           = archivos._id   (tipo ACTA)
//   (los números de mongosh son Double; por eso el validador usa bsonType "number")
//   encuestas.id_encuesta                 = dbo.encuesta.id_encuesta
//   En sentido inverso, cada documento de Mongo guarda el id de SQL
//   (id_caso, id_documento, id_resolucion…) para poder volver a la tabla.
// =====================================================================

use("magallanes_montero");                       // Crea/usa la base de datos (se crea al insertar el primer documento).

// Borrar colecciones si ya existen (permite ejecutar el script varias veces)
["expedientes", "archivos", "formularios_encuesta", "encuestas"].forEach(c => db.getCollection(c).drop());

// ---------------------------------------------------------------------
// 1. EXPEDIENTES · un documento por caso
// ---------------------------------------------------------------------
db.createCollection("expedientes", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["id_caso", "codigo_interno", "materia", "creado_en"],
    properties: {
      id_caso:        { bsonType: "number",    description: "= dbo.caso.id_caso (obligatorio)" },
      codigo_interno: { bsonType: "string", pattern: "^EXP-[0-9]{4}-[0-9]{4}$", description: "= dbo.caso.codigo_interno" },
      materia:        { bsonType: "string" },
      resumen_hechos: { bsonType: "string", description: "Relato libre del caso; puede ser largo" },
      etiquetas:      { bsonType: "array", items: { bsonType: "string" } },
      archivos: { bsonType: "array", description: "Índice de archivos del expediente", items: {
        bsonType: "object", required: ["archivo_id", "tipo", "titulo"],
        properties: {
          archivo_id: { bsonType: "objectId", description: "= archivos._id" },
          tipo:       { enum: ["ESCRITO", "RESOLUCION", "CONTRATO", "ACTA", "ANEXO_CLIENTE"] },
          titulo:     { bsonType: "string" },
          subido_en:  { bsonType: "date" } } } },
      bitacora: { bsonType: "array", description: "Historial de movimientos (crece sin límite fijo)", items: {
        bsonType: "object", required: ["fecha", "evento"],
        properties: { fecha: { bsonType: "date" }, evento: { bsonType: "string" }, usuario: { bsonType: "string" }, detalle: { bsonType: "object" } } } },
      creado_en: { bsonType: "date" }
    } } }
});
db.expedientes.createIndex({ id_caso: 1 }, { unique: true });          // Un expediente digital por caso.
db.expedientes.createIndex({ codigo_interno: 1 }, { unique: true });
db.expedientes.createIndex({ etiquetas: 1 });                           // Búsqueda por etiquetas ("desalojo", "alimentos"…).

// ---------------------------------------------------------------------
// 2. ARCHIVOS · escritos, resoluciones, contratos y actas con versiones
// ---------------------------------------------------------------------
db.createCollection("archivos", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["tipo", "titulo", "versiones"],   // el contrato se sube antes de que exista el caso
    properties: {
      tipo:          { enum: ["ESCRITO", "RESOLUCION", "CONTRATO", "ACTA", "ANEXO_CLIENTE"] },
      id_caso:       { bsonType: "number", description: "= dbo.caso.id_caso" },
      id_sql:        { bsonType: "number", description: "id de la fila en SQL: id_documento, id_resolucion, id_contrato o id_audiencia" },
      titulo:        { bsonType: "string" },
      version_actual:{ bsonType: "number", minimum: 1 },
      versiones: { bsonType: "array", minItems: 1, items: {
        bsonType: "object", required: ["v", "autor", "fecha"],
        properties: {
          v:             { bsonType: "number" },
          autor:         { bsonType: "string" },
          fecha:         { bsonType: "date" },
          origen:        { enum: ["MANUAL", "PLANTILLA", "PLANTILLA_IA", "ESCANEO", "SINOE", "CLIENTE"] },
          observaciones: { bsonType: "string" },
          contenido_texto:{ bsonType: "string", description: "Texto del escrito para búsqueda" },
          archivo_gridfs: { bsonType: "objectId", description: "PDF guardado con GridFS (fs.files)" },
          tamano_kb:     { bsonType: "number" } } } },
      jurisprudencia_citada: { bsonType: "array", items: { bsonType: "string" } },
      firma: { bsonType: "object", properties: {
        modalidad: { enum: ["DIGITAL", "PRESENCIAL"] }, firmado_por: { bsonType: "string" }, fecha: { bsonType: "date" } } },
      metadatos: { bsonType: "object", description: "Campos libres según el tipo (juzgado, sala, asistentes del acta…)" }
    } } }
});
db.archivos.createIndex({ id_caso: 1, tipo: 1 });
db.archivos.createIndex({ titulo: "text", "versiones.contenido_texto": "text" }, { default_language: "spanish" }); // Buscador de texto.

// ---------------------------------------------------------------------
// 3. FORMULARIOS_ENCUESTA · las preguntas cambian sin tocar tablas
// ---------------------------------------------------------------------
db.createCollection("formularios_encuesta", {
  validator: { $jsonSchema: {
    bsonType: "object", required: ["version", "activo", "preguntas"],
    properties: {
      version: { bsonType: "number" }, activo: { bsonType: "bool" },
      preguntas: { bsonType: "array", items: { bsonType: "object", required: ["clave", "texto", "tipo"],
        properties: { clave: { bsonType: "string" }, texto: { bsonType: "string" },
                      tipo: { enum: ["ESTRELLAS_1_5", "NPS_0_10", "SI_NO", "TEXTO", "OPCION"] },
                      opciones: { bsonType: "array", items: { bsonType: "string" } } } } } } } }
});
db.formularios_encuesta.createIndex({ version: 1 }, { unique: true });

// ---------------------------------------------------------------------
// 4. ENCUESTAS · respuesta completa de cada cliente
// ---------------------------------------------------------------------
db.createCollection("encuestas", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["id_encuesta", "id_caso", "version_formulario"],   // las respuestas se agregan cuando el cliente contesta
    properties: {
      id_encuesta:        { bsonType: "number", description: "= dbo.encuesta.id_encuesta" },
      id_caso:            { bsonType: "number", description: "= dbo.caso.id_caso" },
      codigo_caso:        { bsonType: "string" },
      version_formulario: { bsonType: "number", description: "= formularios_encuesta.version" },
      canal:              { enum: ["WHATSAPP", "CORREO", "PORTAL"] },
      enviada:            { bsonType: "date" },
      respondida:         { bsonType: "date" },
      respuestas: { bsonType: "object", required: ["calificacion", "nps"],
        properties: { calificacion: { bsonType: "number", minimum: 1, maximum: 5 },
                      nps: { bsonType: "number", minimum: 0, maximum: 10 } } },   // el resto de claves es libre
      comentario: { bsonType: "string" },
      estado:     { enum: ["ENVIADA", "RESPONDIDA"] }
    } } }
});
db.encuestas.createIndex({ id_encuesta: 1 }, { unique: true });
db.encuestas.createIndex({ respondida: -1 });

// =====================================================================
// DATOS DE PRUEBA (el mismo caso de datos_prueba_sqlserver.sql)
// =====================================================================
const EXP1 = ObjectId("6729f1c2a4e8b31d9c0f4a11");   // expediente del caso 1
const ARC_DEMANDA = ObjectId("6729f1c2a4e8b31d9c0f4a12");
const ARC_RES1 = ObjectId("6729f1c2a4e8b31d9c0f4a13");
const ARC_CONTRATO = ObjectId("6729f1c2a4e8b31d9c0f4a14");

db.archivos.insertMany([
  { _id: ARC_CONTRATO, tipo: "CONTRATO", id_caso: 1, id_sql: 1, titulo: "Contrato de servicios CT-2026-001", version_actual: 1,
    versiones: [{ v: 1, autor: "Sistema", fecha: ISODate("2026-10-08T12:00:00Z"), origen: "PLANTILLA", tamano_kb: 184 }],
    firma: { modalidad: "DIGITAL", firmado_por: "Ana Pérez", fecha: ISODate("2026-10-08T12:30:00Z") } },
  { _id: ARC_DEMANDA, tipo: "ESCRITO", id_caso: 1, id_sql: 1, titulo: "Demanda de desalojo", version_actual: 2,
    versiones: [
      { v: 1, autor: "Luis Torres", fecha: ISODate("2026-10-09T15:00:00Z"), origen: "PLANTILLA_IA", contenido_texto: "SEÑOR JUEZ… solicito el desalojo por falta de pago…" },
      { v: 2, autor: "Carlos Magallanes", fecha: ISODate("2026-10-10T09:00:00Z"), origen: "MANUAL", observaciones: "Se agregó pretensión accesoria" } ],
    jurisprudencia_citada: ["Cas. 1234-2019-Lima"] },
  { _id: ARC_RES1, tipo: "RESOLUCION", id_caso: 1, id_sql: 1, titulo: "Resolución 1 – Admisorio", version_actual: 1,
    versiones: [{ v: 1, autor: "3er Juzgado Civil de Lima", fecha: ISODate("2026-11-05T10:00:00Z"), origen: "SINOE" }],
    metadatos: { juez: "Dra. M. Rojas", especialista: "J. Pérez" } }
]);

db.expedientes.insertOne({
  _id: EXP1, id_caso: 1, codigo_interno: "EXP-2026-0001", materia: "Civil",
  resumen_hechos: "La inquilina dejó de pagar 4 meses de alquiler; se demanda desalojo y pago de arriendos.",
  etiquetas: ["desalojo", "falta de pago", "arrendamiento"],
  archivos: [
    { archivo_id: ARC_CONTRATO, tipo: "CONTRATO", titulo: "Contrato de servicios CT-2026-001", subido_en: ISODate("2026-10-08T12:30:00Z") },
    { archivo_id: ARC_DEMANDA, tipo: "ESCRITO", titulo: "Demanda de desalojo", subido_en: ISODate("2026-10-10T09:00:00Z") },
    { archivo_id: ARC_RES1, tipo: "RESOLUCION", titulo: "Resolución 1 – Admisorio", subido_en: ISODate("2026-11-05T10:00:00Z") } ],
  bitacora: [
    { fecha: ISODate("2026-10-08T12:30:00Z"), evento: "Expediente creado desde el contrato CT-2026-001", usuario: "rquispe" },
    { fecha: ISODate("2026-10-10T09:00:00Z"), evento: "Demanda presentada (electrónica)", usuario: "cmagallanes" },
    { fecha: ISODate("2026-11-05T10:00:00Z"), evento: "Resolución 1 registrada; plazo de 3 días creado", usuario: "ltorres", detalle: { id_plazo: 1 } } ],
  creado_en: ISODate("2026-10-08T12:30:00Z")
});

db.formularios_encuesta.insertOne({
  version: 2, activo: true,
  preguntas: [
    { clave: "calificacion", texto: "Califique la atención recibida", tipo: "ESTRELLAS_1_5" },
    { clave: "nps", texto: "¿Qué tan probable es que nos recomiende?", tipo: "NPS_0_10" },
    { clave: "explico_etapas", texto: "¿El abogado le explicó cada etapa?", tipo: "SI_NO" },
    { clave: "avisos_audiencia", texto: "¿Recibió avisos de sus audiencias?", tipo: "SI_NO" } ]
});

db.encuestas.insertOne({
  id_encuesta: 1, id_caso: 1, codigo_caso: "EXP-2026-0001", version_formulario: 2, canal: "WHATSAPP", estado: "RESPONDIDA",
  enviada: ISODate("2027-04-02T10:00:00Z"), respondida: ISODate("2027-04-02T19:42:00Z"),
  respuestas: { calificacion: 5, nps: 10, explico_etapas: "Sí", avisos_audiencia: "Sí" },
  comentario: "Me explicaron cada paso y siempre sabía en qué etapa iba mi caso."
});

// Enlazar con SQL Server (ejecutar en SSMS después de cargar datos_prueba_sqlserver.sql):
//   UPDATE dbo.caso            SET expediente_mongo_id = '6729f1c2a4e8b31d9c0f4a11' WHERE id_caso = 1;
//   UPDATE dbo.documento_legal SET archivo_mongo_id    = '6729f1c2a4e8b31d9c0f4a12' WHERE id_documento = 1;
//   UPDATE dbo.resolucion      SET archivo_mongo_id    = '6729f1c2a4e8b31d9c0f4a13' WHERE id_resolucion = 1;
//   UPDATE dbo.contrato        SET archivo_mongo_id    = '6729f1c2a4e8b31d9c0f4a14' WHERE id_contrato = 1;

// =====================================================================
// CONSULTAS DE EJEMPLO
// =====================================================================
// a) Promedio y NPS para el dashboard:
printjson(db.encuestas.aggregate([
  { $group: { _id: null,
      promedio:    { $avg: "$respuestas.calificacion" },
      promotores:  { $sum: { $cond: [{ $gte: ["$respuestas.nps", 9] }, 1, 0] } },
      detractores: { $sum: { $cond: [{ $lte: ["$respuestas.nps", 6] }, 1, 0] } },
      total:       { $sum: 1 } } },
  { $project: { _id: 0, promedio: 1, total: 1,
      nps: { $round: [{ $multiply: [{ $divide: [{ $subtract: ["$promotores", "$detractores"] }, "$total"] }, 100] }, 0] } } }
]).toArray());
// b) Expediente digital completo de un caso (lo que abre la pestaña "Documentos"):
printjson(db.expedientes.findOne({ id_caso: 1 }, { bitacora: { $slice: -5 } }));
// c) Buscar escritos que mencionen "desalojo":
printjson(db.archivos.find({ $text: { $search: "desalojo" } }, { titulo: 1, tipo: 1 }).toArray());
