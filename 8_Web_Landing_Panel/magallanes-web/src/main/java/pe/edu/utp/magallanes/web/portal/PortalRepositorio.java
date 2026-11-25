package pe.edu.utp.magallanes.web.portal;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import javax.sql.DataSource;
import org.bson.Document;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.Datos;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.expediente.NotificacionRepositorio;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;

/**
 * PORTAL DEL CLIENTE (TO-BE: «ver estado del caso, firmar, ver pagos, responder encuestas»).
 *   Ingreso ........ USUARIO (id_persona) + PERSONA · contraseña con hash BCrypt
 *   Mi resumen ..... CONTRATO, CASO, CASO_ETAPA, AUDIENCIA, vw_cuota_estado, ENCUESTA, NOTIFICACION
 *   Firma digital .. UPDATE CONTRATO (fecha_firma, modalidad_firma = 'DIGITAL') + MongoDB «archivos» (tipo CONTRATO, firma)
 *                    + NOTIFICACION (FIRMA_DOCUMENTO) al equipo y al cliente · una sola transacción
 * El cliente SOLO ve lo suyo: cada consulta filtra por contrato.id_cliente = la persona de la sesión.
 */
@Repository
public class PortalRepositorio {
    public record CuentaCliente(int idUsuario, String hash, boolean activo, int idPersona, String nombre, String documento, String email) { }

    private final DataSource ds;
    private final MongoDocumentos mongo;

    public PortalRepositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    /** Busca la cuenta del portal por correo o por N.° de documento (DNI, RUC o CE). */
    public Optional<CuentaCliente> buscarCuenta(String dato) throws SQLException {
        boolean esCorreo = dato.contains("@");
        String sql = "SELECT u.id_usuario, u.contrasena_hash, u.activo, p.id_persona, "
                + "COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), p.tipo_documento + ' ' + p.nro_documento, u.email "
                + "FROM dbo.usuario u JOIN dbo.persona p ON p.id_persona = u.id_persona "     // solo cuentas de clientes
                + (esCorreo ? "WHERE u.email = ?" : "WHERE p.nro_documento = ?");
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setString(1, esCorreo ? dato.toLowerCase() : dato.toUpperCase());
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return Optional.empty();
                return Optional.of(new CuentaCliente(rs.getInt(1), rs.getString(2), rs.getBoolean(3), rs.getInt(4), rs.getString(5), rs.getString(6), rs.getString(7)));
            }
        }
    }

    public void registrarAcceso(int idUsuario) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement("UPDATE dbo.usuario SET ultimo_acceso = SYSDATETIME() WHERE id_usuario = ?")) {
            ps.setInt(1, idUsuario); ps.executeUpdate();
        }
    }

    // ------------------------------------------------------------------ MI RESUMEN
    public Map<String, Object> resumen(int idPersona) throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("contratos", q("SELECT k.id_contrato, k.nro_contrato, k.tipo_encargo, k.modalidad_pago, k.modalidad_firma, "
                + "FORMAT(k.fecha_firma, 'dd/MM/yyyy') AS fecha_firma, CASE WHEN k.fecha_firma IS NULL THEN 1 ELSE 0 END AS pendiente_firma, "
                + "p.monto_honorarios, p.porcentaje_cuota_litis, m.nombre AS materia, e.nombres + ' ' + e.apellidos AS abogado, "
                + "CAST(c.resumen AS NVARCHAR(500)) AS asunto, (SELECT x.id_caso FROM dbo.caso x WHERE x.id_contrato = k.id_contrato) AS id_caso "
                + "FROM dbo.contrato k JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta JOIN dbo.consulta c ON c.id_consulta = p.id_consulta "
                + "JOIN dbo.materia m ON m.id_materia = c.id_materia JOIN dbo.empleado e ON e.id_empleado = p.id_abogado "
                + "WHERE k.id_cliente = ? ORDER BY CASE WHEN k.fecha_firma IS NULL THEN 0 ELSE 1 END, k.id_contrato DESC", idPersona));
        r.put("casos", q("SELECT c.id_caso, c.codigo_interno, c.nro_expediente_judicial, c.descripcion, c.estado, m.nombre AS materia, "
                + "FORMAT(c.fecha_apertura, 'dd/MM/yyyy') AS apertura, e.nombres + ' ' + e.apellidos AS abogado, "
                + "(SELECT TOP 1 ep.nombre FROM dbo.caso_etapa ce JOIN dbo.etapa_procesal ep ON ep.id_etapa = ce.id_etapa "
                + "   WHERE ce.id_caso = c.id_caso ORDER BY CASE WHEN ce.fecha_fin IS NULL THEN 0 ELSE 1 END, ce.fecha_inicio DESC) AS etapa, "
                + "(SELECT TOP 1 ep.orden FROM dbo.caso_etapa ce JOIN dbo.etapa_procesal ep ON ep.id_etapa = ce.id_etapa "
                + "   WHERE ce.id_caso = c.id_caso ORDER BY CASE WHEN ce.fecha_fin IS NULL THEN 0 ELSE 1 END, ce.fecha_inicio DESC) AS orden_etapa, "
                + "(SELECT COUNT(*) FROM dbo.etapa_procesal) AS total_etapas, "
                + "(SELECT TOP 1 FORMAT(a.fecha_hora, 'dd/MM/yyyy HH:mm') + ' · ' + LOWER(a.modalidad) FROM dbo.audiencia a JOIN dbo.resolucion r ON r.id_resolucion = a.id_resolucion "
                + "   WHERE r.id_caso = c.id_caso AND a.fecha_hora >= SYSDATETIME() AND a.estado IN ('PROGRAMADA','REPROGRAMADA') ORDER BY a.fecha_hora) AS proxima_audiencia "
                + "FROM dbo.caso c JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable WHERE k.id_cliente = ? "
                + "ORDER BY CASE c.estado WHEN 'ACTIVO' THEN 0 ELSE 1 END, c.id_caso DESC", idPersona));
        r.put("cuotas", q("SELECT v.id_cuota, k.nro_contrato, v.nro_cuota, v.concepto, v.monto, FORMAT(v.fecha_vencimiento, 'dd/MM/yyyy') AS vence, v.estado, "
                + "DATEDIFF(DAY, CAST(GETDATE() AS DATE), v.fecha_vencimiento) AS dias, CASE WHEN k.fecha_firma IS NULL THEN 1 ELSE 0 END AS pendiente_firma "
                + "FROM dbo.vw_cuota_estado v JOIN dbo.contrato k ON k.id_contrato = v.id_contrato WHERE k.id_cliente = ? "
                + "ORDER BY CASE v.estado WHEN 'VENCIDA' THEN 0 WHEN 'PENDIENTE' THEN 1 WHEN 'PAGADA_PARCIAL' THEN 1 ELSE 2 END, v.fecha_vencimiento", idPersona));
        r.put("encuestas", q("SELECT e.id_encuesta, c.codigo_interno, m.nombre AS materia, FORMAT(e.fecha_envio, 'dd/MM/yyyy') AS enviada, "
                + "FORMAT(e.fecha_respuesta, 'dd/MM/yyyy') AS respondida, e.calificacion, e.nps "
                + "FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso JOIN dbo.contrato k ON k.id_contrato = c.id_contrato "
                + "JOIN dbo.materia m ON m.id_materia = c.id_materia WHERE k.id_cliente = ? ORDER BY CASE WHEN e.fecha_respuesta IS NULL THEN 0 ELSE 1 END, e.id_encuesta DESC", idPersona));
        List<Map<String, Object>> per = q("SELECT tipo_persona, tipo_documento, nro_documento, COALESCE(razon_social, nombres + ' ' + apellidos) AS nombre, "
                + "nombres, telefono, email, direccion FROM dbo.persona WHERE id_persona = ?", idPersona);
        r.put("persona", per.isEmpty() ? Map.of() : per.get(0));
        return r;
    }

    /** El caso es de este cliente (para que no vea casos ajenos cambiando el número en la URL). */
    public void verificarCaso(int idCaso, int idPersona) throws SQLException {
        if (q("SELECT 1 AS ok FROM dbo.caso c JOIN dbo.contrato k ON k.id_contrato = c.id_contrato WHERE c.id_caso = ? AND k.id_cliente = ?", idCaso, idPersona).isEmpty())
            throw new ReglaNegocioException("Ese caso no pertenece a su cuenta.");
    }

    public void verificarEncuesta(int idEncuesta, int idPersona) throws SQLException {
        if (q("SELECT 1 AS ok FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso JOIN dbo.contrato k ON k.id_contrato = c.id_contrato "
                + "WHERE e.id_encuesta = ? AND k.id_cliente = ?", idEncuesta, idPersona).isEmpty())
            throw new ReglaNegocioException("Esa encuesta no pertenece a su cuenta.");
    }

    // ------------------------------------------------------------------ CONTRATO PARA FIRMAR
    public Map<String, Object> contrato(int idContrato, int idPersona) throws SQLException {
        List<Map<String, Object>> f = q("SELECT k.id_contrato, k.nro_contrato, k.tipo_encargo, k.modalidad_pago, k.con_carta_poder, k.modalidad_firma, "
                + "FORMAT(k.fecha_firma, 'dd/MM/yyyy') AS fecha_firma, p.monto_honorarios, p.porcentaje_cuota_litis, m.nombre AS materia, "
                + "CAST(c.resumen AS NVARCHAR(500)) AS asunto, e.nombres + ' ' + e.apellidos AS abogado, a.nro_colegiatura, "
                + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, pe.tipo_documento + ' ' + pe.nro_documento AS documento, pe.direccion, "
                + "k.archivo_mongo_id FROM dbo.contrato k JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta "
                + "JOIN dbo.consulta c ON c.id_consulta = p.id_consulta JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.empleado e ON e.id_empleado = p.id_abogado LEFT JOIN dbo.abogado a ON a.id_empleado = p.id_abogado "
                + "JOIN dbo.persona pe ON pe.id_persona = k.id_cliente WHERE k.id_contrato = ? AND k.id_cliente = ?", idContrato, idPersona);
        if (f.isEmpty()) throw new ReglaNegocioException("Ese contrato no pertenece a su cuenta.");
        Map<String, Object> k = f.get(0);
        List<Map<String, Object>> cuotas = q("SELECT nro_cuota, concepto, monto, FORMAT(fecha_vencimiento, 'dd/MM/yyyy') AS vence, estado "
                + "FROM dbo.vw_cuota_estado WHERE id_contrato = ? ORDER BY nro_cuota", idContrato);
        k.put("cuotas", cuotas);
        k.put("clausulas", clausulas(k, cuotas));
        // Firma guardada en MongoDB (si ya firmó digitalmente)
        Object idMongo = k.remove("archivo_mongo_id");
        if (idMongo != null && mongo.disponible()) {
            try {
                Document a = mongo.buscar("archivos", idMongo.toString());
                if (a != null && a.get("firma") instanceof Document fd) k.put("firma", Map.of("modalidad", String.valueOf(fd.get("modalidad")),
                        "firmado_por", String.valueOf(fd.get("firmado_por")), "imagen_png", String.valueOf(fd.getOrDefault("imagen_png", ""))));
            } catch (RuntimeException ignorada) { /* id de ejemplo */ }
        }
        return k;
    }

    /** Texto del contrato (plantilla con los datos de la propuesta aceptada). Se guarda también en MongoDB al firmar. */
    private static List<String> clausulas(Map<String, Object> k, List<Map<String, Object>> cuotas) {
        BigDecimal hon = (BigDecimal) k.get("monto_honorarios");
        BigDecimal litis = (BigDecimal) k.get("porcentaje_cuota_litis");
        List<String> c = new ArrayList<>();
        c.add("PRIMERA · OBJETO. EL ESTUDIO JURÍDICO MAGALLANES-MONTERO asume el " + String.valueOf(k.get("tipo_encargo")).toLowerCase()
                + " de EL CLIENTE en materia " + k.get("materia") + ": «" + k.get("asunto") + "».");
        c.add("SEGUNDA · ABOGADO RESPONSABLE. El caso estará a cargo de " + k.get("abogado")
                + (k.get("nro_colegiatura") != null ? " (" + k.get("nro_colegiatura") + ")" : "") + ", quien informará a EL CLIENTE de cada etapa a través del portal.");
        if (hon != null && hon.signum() == 0) c.add("TERCERA · HONORARIOS. El servicio se presta PRO BONO: EL CLIENTE no paga honorarios.");
        else {
            StringBuilder s = new StringBuilder("TERCERA · HONORARIOS. EL CLIENTE pagará S/ " + hon + " en " + cuotas.size() + " pago(s): ");
            for (int i = 0; i < cuotas.size(); i++) {
                Map<String, Object> q = cuotas.get(i);
                s.append(i == 0 ? "" : "; ").append(String.valueOf(q.get("concepto")).toLowerCase()).append(" de S/ ").append(q.get("monto")).append(" al ").append(q.get("vence"));
            }
            c.add(s.append(".").toString());
        }
        if (litis != null && litis.signum() > 0) c.add("CUARTA · CUOTA LITIS. Además, EL CLIENTE pagará el " + litis + " % de lo que efectivamente obtenga al final del proceso.");
        c.add("QUINTA · OBLIGACIONES DEL CLIENTE. Entregar la documentación que se le solicite por el portal y comunicar cualquier cambio de domicilio o teléfono.");
        if (Boolean.TRUE.equals(k.get("con_carta_poder"))) c.add("SEXTA · CARTA PODER. EL CLIENTE otorga carta poder al abogado responsable para actuar en su nombre ante la entidad competente.");
        c.add("FIRMA. El presente contrato se firma de forma digital en el portal del cliente o de forma presencial en el estudio; ambas tienen la misma validez entre las partes.");
        // Numeración correlativa de las cláusulas (PRIMERA, SEGUNDA…) según las que apliquen
        String[] ord = {"PRIMERA", "SEGUNDA", "TERCERA", "CUARTA", "QUINTA", "SEXTA", "SÉPTIMA", "OCTAVA"};
        List<String> r = new ArrayList<>();
        for (int i = 0; i < c.size(); i++) {
            String t = c.get(i).replaceFirst("^(PRIMERA|SEGUNDA|TERCERA|CUARTA|QUINTA|SEXTA|SÉPTIMA) · ", "");
            r.add(ord[i] + " · " + t);
        }
        return r;
    }

    // ------------------------------------------------------------------ FIRMA DIGITAL (una sola transacción)
    public Map<String, Object> firmar(int idContrato, SesionCliente cli, String imagenPng, String ip) throws SQLException {
        if (imagenPng == null || !imagenPng.startsWith("data:image/png;base64,")) throw new ReglaNegocioException("Dibuje su firma en el recuadro.");
        if (imagenPng.length() > 400_000) throw new ReglaNegocioException("La imagen de la firma es demasiado grande.");
        Map<String, Object> datos = contrato(idContrato, cli.idPersona());   // valida que sea suyo
        String idMongo = null;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                int idConsulta, idAbogado;
                String nro;
                // 1) Releer con UPDLOCK: el contrato debe seguir pendiente de firma
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT k.fecha_firma, k.nro_contrato, p.id_consulta, p.id_abogado FROM dbo.contrato k WITH (UPDLOCK) "
                      + "JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta WHERE k.id_contrato = ? AND k.id_cliente = ?")) {
                    ps.setInt(1, idContrato); ps.setInt(2, cli.idPersona());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("Ese contrato no pertenece a su cuenta.");
                        if (rs.getDate(1) != null) throw new ReglaNegocioException("El contrato ya está firmado.");
                        nro = rs.getString(2); idConsulta = rs.getInt(3); idAbogado = rs.getInt(4);
                    }
                }
                // 2) UPDATE CONTRATO: firmado hoy, en forma DIGITAL (CHECK ck_contrato_firma_completa: fecha + modalidad)
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.contrato SET fecha_firma = CAST(GETDATE() AS DATE), modalidad_firma = 'DIGITAL' WHERE id_contrato = ?")) {
                    ps.setInt(1, idContrato); ps.executeUpdate();
                }
                // 3) MongoDB «archivos»: el contrato firmado (texto + imagen de la firma) → contrato.archivo_mongo_id
                String aviso = null;
                if (mongo.disponible()) {
                    @SuppressWarnings("unchecked") List<String> cl = (List<String>) datos.get("clausulas");
                    java.util.Date ahora = new java.util.Date();
                    Document doc = new Document("tipo", "CONTRATO").append("id_sql", idContrato).append("titulo", "Contrato de servicios " + nro)
                            .append("version_actual", 1)
                            .append("versiones", List.of(new Document("v", 1).append("autor", "Sistema").append("fecha", ahora).append("origen", "PLANTILLA")
                                    .append("contenido_texto", String.join("\n", cl))))
                            .append("firma", new Document("modalidad", "DIGITAL").append("firmado_por", cli.nombre()).append("fecha", ahora)
                                    .append("documento", cli.documento()).append("ip", ip).append("imagen_png", imagenPng));
                    idMongo = mongo.guardar("archivos", doc);
                    try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.contrato SET archivo_mongo_id = ? WHERE id_contrato = ?")) {
                        ps.setString(1, idMongo); ps.setInt(2, idContrato); ps.executeUpdate();
                    }
                } else aviso = "MongoDB no está encendido: la firma quedó registrada en SQL Server, pero no se guardó la imagen.";
                // 4) NOTIFICACION: al equipo (secretaría, gerencia y el abogado) y al cliente
                NotificacionRepositorio.avisarEquipo(cn, List.of("SECRETARIA", "ADMINISTRADOR"), idAbogado, idConsulta, null, "FIRMA_DOCUMENTO",
                        cli.nombre() + " firmó digitalmente el contrato " + nro + ". Ya se puede emitir el comprobante del adelanto y abrir el expediente.");
                NotificacionRepositorio.avisarCliente(cn, cli.idPersona(), idConsulta, null, "FIRMA_DOCUMENTO",
                        "Firmó su contrato " + nro + ". Le enviaremos el comprobante del adelanto y le avisaremos cuando se abra su expediente.");
                cn.commit();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idContrato", idContrato); r.put("nroContrato", nro); r.put("archivoMongoId", idMongo); r.put("aviso", aviso);
                r.put("mensaje", "Contrato " + nro + " firmado digitalmente.");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                mongo.borrar("archivos", idMongo);                       // compensación
                throw e;
            }
        }
    }

    /** Después de que el cliente responde la encuesta: aviso a gerencia y al abogado del caso. */
    public void avisarEncuestaRespondida(int idEncuesta, String cliente, int calificacion) throws SQLException {
        try (Connection cn = ds.getConnection()) {
            Integer idCaso = null, idAbogado = null; String codigo = "";
            try (PreparedStatement ps = cn.prepareStatement("SELECT c.id_caso, c.id_abogado_responsable, c.codigo_interno FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso WHERE e.id_encuesta = ?")) {
                ps.setInt(1, idEncuesta);
                try (ResultSet rs = ps.executeQuery()) { if (rs.next()) { idCaso = rs.getInt(1); idAbogado = rs.getInt(2); codigo = rs.getString(3); } }
            }
            if (idCaso == null) return;
            NotificacionRepositorio.avisarEquipo(cn, List.of("ADMINISTRADOR"), idAbogado, null, idCaso, "ENVIO_ENCUESTA",
                    cliente + " respondió la encuesta del caso " + codigo + ": " + "★".repeat(Math.max(0, Math.min(5, calificacion))) + " (" + calificacion + "/5).");
        }
    }

    private List<Map<String, Object>> q(String sql, Object... p) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            return Datos.filas(ps);
        }
    }
}
