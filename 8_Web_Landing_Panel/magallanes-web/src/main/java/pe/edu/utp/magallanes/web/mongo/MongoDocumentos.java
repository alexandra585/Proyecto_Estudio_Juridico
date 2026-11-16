package pe.edu.utp.magallanes.web.mongo;

import java.util.Date;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Component;

/**
 * Ayuda común para la parte NO relacional (MongoDB). La usan los tres módulos:
 *  - T2 (W09): crea el documento en «expedientes» y guarda su _id en caso.expediente_mongo_id
 *  - T3 (W11/W13): guarda escritos y resoluciones en «archivos» (_id → documento_legal / resolucion.archivo_mongo_id)
 *  - T4 (W22): guarda la respuesta completa en «encuestas» (id_encuesta = encuesta.id_encuesta)
 *
 * Regla de consistencia entre las dos bases (no hay transacción común SQL Server + MongoDB):
 *   1) se inserta primero el documento en MongoDB y se obtiene su _id (24 caracteres hex = CHAR(24) en SQL);
 *   2) se hace la transacción en SQL Server guardando ese _id;
 *   3) si SQL Server hace ROLLBACK, se borra el documento de MongoDB (compensación) con borrar().
 */
@Component
public class MongoDocumentos {
    private final MongoTemplate mongo;

    public MongoDocumentos(MongoTemplate mongo) { this.mongo = mongo; }

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

    /** Compensación: borra el documento si la transacción de SQL Server falló. */
    public void borrar(String coleccion, String id) {
        if (id != null) mongo.remove(new org.springframework.data.mongodb.core.query.Query(
                org.springframework.data.mongodb.core.query.Criteria.where("_id").is(new ObjectId(id))), coleccion);
    }
}
