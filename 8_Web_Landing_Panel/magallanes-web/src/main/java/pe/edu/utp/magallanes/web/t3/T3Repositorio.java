package pe.edu.utp.magallanes.web.t3;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;
import pe.edu.utp.magallanes.web.t2.T2Repositorio;

/** TRANSACCIÓN T3 (COMPAÑERO 2). Mismo patrón de transacción que repositorio/CitaRepositorio.java. */
@Repository
public class T3Repositorio {
    private final DataSource ds;
    private final MongoDocumentos mongo;

    public T3Repositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    public List<Map<String, Object>> casosActivos() throws SQLException {
        String sql = "SELECT c.id_caso, c.codigo_interno, m.nombre AS materia, e.nombres + ' ' + e.apellidos AS abogado "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable WHERE c.estado = 'ACTIVO' ORDER BY c.codigo_interno";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            return T2Repositorio.filasPublic(rs);
        }
    }

    /*
     * W11 · DOCUMENTO_LEGAL + DOCUMENTO_JURISPRUDENCIA + MongoDB «archivos» (TODO)
     *   1) String idMongo = mongo.guardar("archivos", new Document("tipo", "ESCRITO").append("titulo", titulo)
     *          .append("versiones", List.of(new Document("v", 1).append("autor", autor).append("fecha", new Date()).append("contenido_texto", texto))));
     *   2) INSERT INTO dbo.documento_legal (id_caso, id_redactor, tipo_documento, titulo, archivo_mongo_id) ...   (estado BORRADOR, version 1)
     *   3) INSERT INTO dbo.documento_jurisprudencia (id_documento, id_jurisprudencia, nota) ...  (n filas)
     *   4) commit; si ROLLBACK → mongo.borrar("archivos", idMongo)
     */
    public Map<String, Object> registrarEscrito(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W11 pendiente: lo programa el Compañero 2 (ver docs/GUIA_COMPANERO_2_T3.md).");
    }

    /*
     * W12 · PRESENTACION (TODO)
     *   INSERT INTO dbo.presentacion (id_documento, id_entidad, id_empleado, fecha_hora, modalidad, nro_cargo) ...
     *   UPDATE dbo.documento_legal SET estado = 'PRESENTADO' WHERE id_documento = ?;
     */
    public Map<String, Object> registrarPresentacion(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W12 pendiente: lo programa el Compañero 2.");
    }

    /*
     * W13 · RESOLUCION + PLAZO (+ PDF en «archivos») (TODO)
     *   INSERT INTO dbo.resolucion (id_caso, id_entidad, id_presentacion, nro_resolucion, tipo_resolucion, fecha_notificacion, medio_notificacion, sumilla, archivo_mongo_id) ...
     *   INSERT INTO dbo.plazo (id_caso, id_resolucion, id_empleado_responsable, descripcion, fecha_inicio, dias_plazo, tipo_computo, fecha_vencimiento) ...
     *   fecha_vencimiento: HABIL = sin sábados, domingos ni FERIADO; CALENDARIO = fecha_inicio + dias_plazo (ck_plazo_calendario).
     *   Trigger trg_resolucion_mismo_caso / trg_plazo_mismo_caso: la presentación debe ser del mismo caso.
     */
    public Map<String, Object> registrarResolucion(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W13 pendiente: lo programa el Compañero 2.");
    }
}
