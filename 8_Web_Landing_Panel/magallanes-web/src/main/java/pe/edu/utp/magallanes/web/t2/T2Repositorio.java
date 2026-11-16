package pe.edu.utp.magallanes.web.t2;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;

/**
 * TRANSACCIÓN T2 (COMPAÑERO 1). Copie el patrón de repositorio/CitaRepositorio.java:
 *   try (Connection cn = ds.getConnection()) { cn.setAutoCommit(false); try { ...INSERTs...; cn.commit(); }
 *   catch (SQLException | RuntimeException e) { cn.rollback(); throw e; } }
 */
@Repository
public class T2Repositorio {
    private final DataSource ds;
    private final MongoDocumentos mongo;

    public T2Repositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    public List<Map<String, Object>> consultasParaPropuesta() throws SQLException {
        String sql = "SELECT c.id_consulta, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, m.nombre AS materia, c.estado "
                + "FROM dbo.consulta c JOIN dbo.persona p ON p.id_persona = c.id_persona JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "WHERE c.estado IN ('AGENDADA', 'ATENDIDA') ORDER BY c.id_consulta DESC";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            return filas(rs);
        }
    }

    /*
     * W07 · PROPUESTA (TODO)
     *   INSERT INTO dbo.propuesta (id_consulta, id_abogado, version, monto_honorarios, porcentaje_cuota_litis, nro_cuotas, fecha_envio)
     *          VALUES (?, ?, ?, ?, ?, ?, CAST(GETDATE() AS DATE));            -- estado = 'ENVIADA' por DEFAULT
     *   UPDATE dbo.consulta SET estado = 'PROPUESTA' WHERE id_consulta = ?;
     *   Reglas: version = MAX(version)+1 de esa consulta (uq_propuesta_version); honorarios >= 0; % cuota litis 0..100.
     */
    public Map<String, Object> registrarPropuesta(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W07 pendiente: lo programa el Compañero 1 (ver docs/GUIA_COMPANERO_1_T2.md).");
    }

    /*
     * W08 · CONTRATO + CUOTA (TODO) — ya existe una versión de escritorio en 8_Java_Formularios (ContratoDAO): adaptarla.
     *   INSERT INTO dbo.contrato (id_propuesta, id_cliente, nro_contrato, fecha_firma, tipo_encargo, modalidad_pago, con_carta_poder, archivo_mongo_id) ...
     *   INSERT INTO dbo.cuota (id_contrato, nro_cuota, concepto, monto, fecha_vencimiento) ...   (n filas, en lote)
     *   UPDATE dbo.consulta SET estado = 'CONTRATADA' WHERE id_consulta = ?;
     */
    public Map<String, Object> registrarContrato(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W08 pendiente: lo programa el Compañero 1.");
    }

    /*
     * W09 · CASO + CASO_PARTE + CASO_ETAPA + MongoDB «expedientes» (TODO)
     *   1) String idMongo = mongo.guardar("expedientes", new Document("id_caso", null).append("codigo_interno", codigo)...);
     *   2) INSERT INTO dbo.caso (id_contrato, id_materia, id_abogado_responsable, codigo_interno, descripcion, fecha_apertura, expediente_mongo_id) ...
     *   3) INSERT INTO dbo.caso_parte (id_caso, id_persona, id_rol, tipo_parte) ...   (cliente y contrapartes)
     *   4) INSERT INTO dbo.caso_etapa (id_caso, id_etapa, fecha_inicio) ...           (primera etapa)
     *   5) commit; actualizar en Mongo el id_caso; si hay ROLLBACK → mongo.borrar("expedientes", idMongo).
     */
    public Map<String, Object> abrirCaso(Map<String, Object> d) throws SQLException {
        throw new ReglaNegocioException("W09 pendiente: lo programa el Compañero 1.");
    }

    public static List<Map<String, Object>> filasPublic(ResultSet rs) throws SQLException { return filas(rs); }

    static List<Map<String, Object>> filas(ResultSet rs) throws SQLException {
        List<Map<String, Object>> r = new ArrayList<>();
        ResultSetMetaData md = rs.getMetaData();
        while (rs.next()) {
            Map<String, Object> f = new LinkedHashMap<>();
            for (int i = 1; i <= md.getColumnCount(); i++) f.put(md.getColumnLabel(i), rs.getObject(i));
            r.add(f);
        }
        return r;
    }
}
