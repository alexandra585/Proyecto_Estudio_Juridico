package pe.edu.utp.magallanes.web.mongo;

import java.util.List;
import java.util.Map;
import org.bson.Document;

/**
 * Esquema de la base MongoDB «magallanes_montero» (el mismo de 2_MongoDB/mongodb_colecciones.js).
 * La aplicación lo crea sola la primera vez que encuentra MongoDB encendido: colecciones con su validador
 * $jsonSchema, índices y el formulario de encuesta activo. Así no hace falta ejecutar el script a mano.
 */
final class MongoEsquema {
    private MongoEsquema() { }

    /** Colección → validador $jsonSchema. */
    static final Map<String, String> VALIDADORES = Map.of(
        "expedientes", """
            {"$jsonSchema": {"bsonType": "object", "required": ["id_caso", "codigo_interno", "materia", "creado_en"], "properties": {"id_caso": {"bsonType": "number", "description": "= dbo.caso.id_caso (obligatorio)"}, "codigo_interno": {"bsonType": "string", "pattern": "^EXP-[0-9]{4}-[0-9]{4}$", "description": "= dbo.caso.codigo_interno"}, "materia": {"bsonType": "string"}, "resumen_hechos": {"bsonType": "string", "description": "Relato libre del caso; puede ser largo"}, "etiquetas": {"bsonType": "array", "items": {"bsonType": "string"}}, "archivos": {"bsonType": "array", "description": "Índice de archivos del expediente", "items": {"bsonType": "object", "required": ["archivo_id", "tipo", "titulo"], "properties": {"archivo_id": {"bsonType": "objectId", "description": "= archivos._id"}, "tipo": {"enum": ["ESCRITO", "RESOLUCION", "CONTRATO", "ACTA", "ANEXO_CLIENTE"]}, "titulo": {"bsonType": "string"}, "subido_en": {"bsonType": "date"}}}}, "bitacora": {"bsonType": "array", "description": "Historial de movimientos (crece sin límite fijo)", "items": {"bsonType": "object", "required": ["fecha", "evento"], "properties": {"fecha": {"bsonType": "date"}, "evento": {"bsonType": "string"}, "usuario": {"bsonType": "string"}, "detalle": {"bsonType": "object"}}}}, "creado_en": {"bsonType": "date"}}}}""",
        "archivos", """
            {"$jsonSchema": {"bsonType": "object", "required": ["tipo", "titulo", "versiones"], "properties": {"tipo": {"enum": ["ESCRITO", "RESOLUCION", "CONTRATO", "ACTA", "ANEXO_CLIENTE"]}, "id_caso": {"bsonType": "number", "description": "= dbo.caso.id_caso"}, "id_sql": {"bsonType": "number", "description": "id de la fila en SQL: id_documento, id_resolucion, id_contrato o id_audiencia"}, "titulo": {"bsonType": "string"}, "version_actual": {"bsonType": "number", "minimum": 1}, "versiones": {"bsonType": "array", "minItems": 1, "items": {"bsonType": "object", "required": ["v", "autor", "fecha"], "properties": {"v": {"bsonType": "number"}, "autor": {"bsonType": "string"}, "fecha": {"bsonType": "date"}, "origen": {"enum": ["MANUAL", "PLANTILLA", "PLANTILLA_IA", "ESCANEO", "SINOE", "CLIENTE"]}, "observaciones": {"bsonType": "string"}, "contenido_texto": {"bsonType": "string", "description": "Texto del escrito para búsqueda"}, "archivo_gridfs": {"bsonType": "objectId", "description": "PDF guardado con GridFS (fs.files)"}, "tamano_kb": {"bsonType": "number"}}}}, "jurisprudencia_citada": {"bsonType": "array", "items": {"bsonType": "string"}}, "firma": {"bsonType": "object", "properties": {"modalidad": {"enum": ["DIGITAL", "PRESENCIAL"]}, "firmado_por": {"bsonType": "string"}, "fecha": {"bsonType": "date"}}}, "metadatos": {"bsonType": "object", "description": "Campos libres según el tipo (juzgado, sala, asistentes del acta…)"}}}}""",
        "formularios_encuesta", """
            {"$jsonSchema": {"bsonType": "object", "required": ["version", "activo", "preguntas"], "properties": {"version": {"bsonType": "number"}, "activo": {"bsonType": "bool"}, "preguntas": {"bsonType": "array", "items": {"bsonType": "object", "required": ["clave", "texto", "tipo"], "properties": {"clave": {"bsonType": "string"}, "texto": {"bsonType": "string"}, "tipo": {"enum": ["ESTRELLAS_1_5", "NPS_0_10", "SI_NO", "TEXTO", "OPCION"]}, "opciones": {"bsonType": "array", "items": {"bsonType": "string"}}}}}}}}""",
        "encuestas", """
            {"$jsonSchema": {"bsonType": "object", "required": ["id_encuesta", "id_caso", "version_formulario"], "properties": {"id_encuesta": {"bsonType": "number", "description": "= dbo.encuesta.id_encuesta"}, "id_caso": {"bsonType": "number", "description": "= dbo.caso.id_caso"}, "codigo_caso": {"bsonType": "string"}, "version_formulario": {"bsonType": "number", "description": "= formularios_encuesta.version"}, "canal": {"enum": ["WHATSAPP", "CORREO", "PORTAL"]}, "enviada": {"bsonType": "date"}, "respondida": {"bsonType": "date"}, "respuestas": {"bsonType": "object", "required": ["calificacion", "nps"], "properties": {"calificacion": {"bsonType": "number", "minimum": 1, "maximum": 5}, "nps": {"bsonType": "number", "minimum": 0, "maximum": 10}}}, "comentario": {"bsonType": "string"}, "estado": {"enum": ["ENVIADA", "RESPONDIDA"]}}}}""");

    /** Índices: {createIndexes: colección, indexes: [...]} listos para executeCommand. */
    static final List<String> INDICES = List.of(
        """
            {"createIndexes": "expedientes", "indexes": [{"key": {"id_caso": 1}, "name": "id_caso_1", "unique": true}]}""",
        """
            {"createIndexes": "expedientes", "indexes": [{"key": {"codigo_interno": 1}, "name": "codigo_interno_1", "unique": true}]}""",
        """
            {"createIndexes": "expedientes", "indexes": [{"key": {"etiquetas": 1}, "name": "etiquetas_1"}]}""",
        """
            {"createIndexes": "archivos", "indexes": [{"key": {"id_caso": 1, "tipo": 1}, "name": "id_caso_1_tipo_1"}]}""",
        """
            {"createIndexes": "archivos", "indexes": [{"key": {"titulo": "text", "versiones.contenido_texto": "text"}, "name": "titulo_text_versiones.contenido_texto_text", "default_language": "spanish"}]}""",
        """
            {"createIndexes": "formularios_encuesta", "indexes": [{"key": {"version": 1}, "name": "version_1", "unique": true}]}""",
        """
            {"createIndexes": "encuestas", "indexes": [{"key": {"id_encuesta": 1}, "name": "id_encuesta_1", "unique": true}]}""",
        """
            {"createIndexes": "encuestas", "indexes": [{"key": {"respondida": -1}, "name": "respondida_-1"}]}""");

    /** Formulario de encuesta activo (versión 2). */
    static final String FORMULARIO = """
            {"version": 2, "activo": true, "preguntas": [{"clave": "calificacion", "texto": "Califique la atención recibida", "tipo": "ESTRELLAS_1_5"}, {"clave": "nps", "texto": "¿Qué tan probable es que nos recomiende?", "tipo": "NPS_0_10"}, {"clave": "explico_etapas", "texto": "¿El abogado le explicó cada etapa?", "tipo": "SI_NO"}, {"clave": "avisos_audiencia", "texto": "¿Recibió avisos de sus audiencias?", "tipo": "SI_NO"}]}""";

    static Document json(String s) { return Document.parse(s); }
}
