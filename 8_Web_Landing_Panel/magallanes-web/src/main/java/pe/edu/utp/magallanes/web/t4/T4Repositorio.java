package pe.edu.utp.magallanes.web.t4;

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

/** TRANSACCIÓN T4 (COMPAÑERO 3). Mismo patrón de transacción que repositorio/CitaRepositorio.java. */
@Repository
public class T4Repositorio {
    private final DataSource ds;
    private final MongoDocumentos mongo;

    public T4Repositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    public List<Map<String, Object>> comprobantes() throws SQLException {
        String sql = "SELECT s.id_comprobante, s.serie, s.numero, s.total, s.pagado, s.saldo, s.estado_pago "
                + "FROM dbo.vw_comprobante_saldo s ORDER BY s.id_comprobante DESC";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            return T2Repositorio.filasPublic(rs);
        }
    }

    /*
     * W18 · COMPROBANTE + DETALLE_COMPROBANTE (TODO)
     *   numero = serie_comprobante.ultimo_numero + 1   (el trigger trg_comprobante_correlativo lo valida y avanza la serie)
     *   INSERT INTO dbo.comprobante (id_persona, id_emisor, id_consulta, serie, numero, fecha_emision, fecha_vencimiento, tasa_igv, porcentaje_detraccion) ...
     *   INSERT INTO dbo.detalle_comprobante (id_comprobante, nro_linea, id_cuota, id_gasto, descripcion, cantidad, valor_unitario) ...  (n líneas)
     *   trg_detalle_comprobante_coherencia: la cuota/gasto debe ser del mismo cliente; el gasto debe ser reembolsable.
     *   El total, el IGV y el saldo NO se guardan: se leen de vw_comprobante_total y vw_comprobante_saldo.
     */
    public Map<String, Object> emitirComprobante(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W18 pendiente: lo programa el Compañero 3 (ver docs/GUIA_COMPANERO_3_T4.md).");
    }

    /*
     * W19 · PAGO + NOTIFICACION (TODO)
     *   INSERT INTO dbo.pago (id_comprobante, id_empleado, monto, medio_pago, nro_operacion) ...   (fecha_pago por DEFAULT)
     *   Validar: monto <= saldo de vw_comprobante_saldo.
     *   UPDATE dbo.cuota SET estado = 'PAGADA' | 'PAGADA_PARCIAL' (cuotas del comprobante) — opcional.
     *   INSERT INTO dbo.notificacion (id_persona, id_caso o id_consulta, tipo_evento = 'CONSTANCIA_PAGO', canal, mensaje, fecha_programada) ...
     */
    public Map<String, Object> registrarPago(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W19 pendiente: lo programa el Compañero 3.");
    }

    /*
     * W21 · cierre: UPDATE dbo.caso SET estado = 'CERRADO', fecha_cierre = ...; INSERT dbo.encuesta (id_caso, fecha_envio);
     *       INSERT dbo.notificacion (tipo_evento = 'ENVIO_ENCUESTA')
     * W22 · respuesta: UPDATE dbo.encuesta SET fecha_respuesta, calificacion (1-5), nps (0-10), comentario
     *       + mongo.guardar("encuestas", new Document("id_encuesta", id).append("id_caso", idCaso)
     *              .append("version_formulario", 1).append("respuestas", respuestasCompletas).append("estado", "RESPONDIDA"))
     */
    public Map<String, Object> responderEncuesta(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W21/W22 pendiente: lo programa el Compañero 3.");
    }
}
