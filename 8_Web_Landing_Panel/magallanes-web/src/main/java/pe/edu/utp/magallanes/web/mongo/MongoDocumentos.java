package pe.edu.utp.magallanes.web.mongo;

import java.util.Date;
import java.util.Map;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Component;

/**
 * Acceso a la parte NO relacional (MongoDB, base «magallanes_montero»). La usan los módulos:
 *  - W09: colección «expedientes» (_id → caso.expediente_mongo_id)
 *  - W11 / W13: colección «archivos» (_id → documento_legal.archivo_mongo_id / resolucion.archivo_mongo_id)
 *  - W21 / W22: colección «encuestas» (id_encuesta = encuesta.id_encuesta)
 *
 * No existe una transacción común entre SQL Server y MongoDB. Regla que usa todo el proyecto:
 *   1) dentro de la transacción de SQL Server se hacen los INSERT y se obtiene el id (id_caso, id_documento…);
 *   2) se inserta el documento en MongoDB con ese id y se guarda su _id (24 caracteres = CHAR(24)) en SQL;
 *   3) COMMIT en SQL Server. Si algo falla después de insertar en MongoDB, se hace ROLLBACK en SQL Server
 *      y se BORRA el documento de MongoDB (compensación) con borrar().
 * Si MongoDB está apagado, la operación de SQL Server se graba igual y el _id queda NULL
 * (la pantalla lo avisa): el negocio no se detiene por la parte documental.
 */
@Component
public class MongoDocumentos {
    private final MongoTemplate mongo;

    public MongoDocumentos(MongoTemplate mongo) { this.mongo = mongo; }

    /** ¿Responde MongoDB? (comando ping; tarda como máximo serverSelectionTimeoutMS). */
    public boolean disponible() {
        try {
            mongo.executeCommand(new Document("ping", 1));
        } catch (RuntimeException e) {
            System.err.println("MongoDB no responde: " + e.getMessage());
            return false;
        }
        // Si MongoDB responde, un error al preparar el esquema no debe marcarlo como "apagado".
        if (!preparada) {
            try { prepararColecciones(); }
            catch (RuntimeException e) { System.err.println("MongoDB: no se pudo preparar el esquema: " + e.getMessage()); }
        }
        return true;
    }

    private volatile boolean preparada;

    /**
     * La primera vez que MongoDB responde, crea lo que falte del esquema (mismo contenido que
     * 2_MongoDB/mongodb_colecciones.js): las 4 colecciones con su validador $jsonSchema, sus índices
     * y el formulario de encuesta activo. Si ya existen, no cambia nada.
     */
    private synchronized void prepararColecciones() {
        if (preparada) return;
        MongoEsquema.VALIDADORES.forEach((coleccion, validador) -> {
            if (!mongo.collectionExists(coleccion)) {
                try {
                    mongo.executeCommand(new Document("create", coleccion).append("validator", MongoEsquema.json(validador)));
                } catch (RuntimeException sinValidador) {
                    // Azure DocumentDB (y otros servicios compatibles) pueden no aceptar validadores $jsonSchema:
                    // en ese caso la colección se crea sin validador.
                    System.err.println("MongoDB: " + coleccion + " se crea sin validador ($jsonSchema no soportado): " + sinValidador.getMessage());
                    mongo.executeCommand(new Document("create", coleccion));
                }
            }
        });
        for (String indice : MongoEsquema.INDICES) {
            try { mongo.executeCommand(MongoEsquema.json(indice)); }
            catch (RuntimeException yaExiste) { /* índice ya creado con otras opciones */ }
        }
        if (mongo.findOne(new Query(Criteria.where("activo").is(true)), Document.class, "formularios_encuesta") == null)
            mongo.insert(MongoEsquema.json(MongoEsquema.FORMULARIO), "formularios_encuesta");
        preparada = true;
    }

    /** Inserta el documento en la colección y devuelve su _id como texto de 24 caracteres. */
    public String guardar(String coleccion, Document doc) {
        if (!doc.containsKey("creado_en")) doc.append("creado_en", new Date());
        Document guardado = mongo.insert(doc, coleccion);
        return guardado.getObjectId("_id").toHexString();
    }

    /** Busca un documento por su _id (para mostrarlo en la pantalla). */
    public Document buscar(String coleccion, String id) {
        return mongo.findById(new ObjectId(id), Document.class, coleccion);
    }

    /** Busca el primer documento cuyo campo tenga ese valor (p. ej. id_caso = 3). */
    public Document buscarPor(String coleccion, String campo, Object valor) {
        return mongo.findOne(new Query(Criteria.where(campo).is(valor)), Document.class, coleccion);
    }

    /**
     * Testimonios para la página web: encuestas RESPONDIDAS cuyo cliente AUTORIZÓ publicar su comentario
     * (publicacion.autoriza = true) y con 4 o 5 estrellas, de la más reciente a la más antigua.
     */
    public java.util.List<Document> testimonios(int maximo) {
        Query q = new Query(Criteria.where("publicacion.autoriza").is(true).and("respuestas.calificacion").gte(4))
                .with(org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "respondida")).limit(maximo);
        return mongo.find(q, Document.class, "encuestas");
    }

    /** Cambia campos de un documento ($set). */
    public void actualizar(String coleccion, String id, Map<String, Object> campos) {
        Update u = new Update();
        campos.forEach(u::set);
        mongo.updateFirst(new Query(Criteria.where("_id").is(new ObjectId(id))), u, coleccion);
    }

    /** Agrega un evento a la bitácora del expediente digital del caso (si existe). */
    public void anotarEnExpediente(int idCaso, String evento, String usuario, Document detalle) {
        mongo.updateFirst(new Query(Criteria.where("id_caso").is(idCaso)),
                new Update().push("bitacora", new Document("fecha", new Date()).append("evento", evento)
                        .append("usuario", usuario).append("detalle", detalle)),
                "expedientes");
    }

    /** Agrega un archivo al índice del expediente digital del caso. */
    public void indexarArchivo(int idCaso, String archivoId, String tipo, String titulo) {
        mongo.updateFirst(new Query(Criteria.where("id_caso").is(idCaso)),
                new Update().push("archivos", new Document("archivo_id", new ObjectId(archivoId)).append("tipo", tipo)
                        .append("titulo", titulo).append("subido_en", new Date())),
                "expedientes");
    }

    /** Compensación: borra el documento si la transacción de SQL Server falló. */
    public void borrar(String coleccion, String id) {
        if (id != null) mongo.remove(new Query(Criteria.where("_id").is(new ObjectId(id))), coleccion);
    }
}
