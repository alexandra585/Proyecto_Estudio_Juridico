package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.dto.DetalleConsulta;
import pe.edu.utp.magallanes.web.dto.FilaBandeja;
import pe.edu.utp.magallanes.web.dto.FilaCita;
import pe.edu.utp.magallanes.web.dto.FilaNotificacion;
import pe.edu.utp.magallanes.web.dto.RespuestaConsulta;
import pe.edu.utp.magallanes.web.dto.SolicitudConsulta;

/**
 * TRANSACCIÓN T1 · Registrar consulta desde la Landing Page (W01).
 * PERSONA (si es nueva) → CONSULTA (canal LANDING, estado RECIBIDA) → CONSULTA_CONTRAPARTE → NOTIFICACION.
 * También las lecturas de la bandeja (W04).
 */
@Repository
public class ConsultaRepositorio {
    private final DataSource ds;

    public ConsultaRepositorio(DataSource ds) { this.ds = ds; }

    private static final String BUSCAR_PERSONA =
            "SELECT id_persona FROM dbo.persona WHERE tipo_documento = ? AND nro_documento = ?";
    private static final String INSERT_PERSONA =
            "INSERT INTO dbo.persona (tipo_persona, tipo_documento, nro_documento, nombres, apellidos, razon_social, "
          + "telefono, email, acepta_tratamiento_datos) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
    private static final String INSERT_CONSULTA =
            "INSERT INTO dbo.consulta (id_persona, id_materia, id_registrado_por, canal, resumen, es_urgente) "
          + "VALUES (?, ?, NULL, 'LANDING', ?, ?)";        // id_registrado_por NULL: llegó sola por la web (ck_consulta_registro)
    private static final String INSERT_CONTRAPARTE =
            "INSERT INTO dbo.consulta_contraparte (id_consulta, id_persona) VALUES (?, ?)";
    private static final String INSERT_NOTIFICACION =
            "INSERT INTO dbo.notificacion (id_persona, id_consulta, tipo_evento, canal, mensaje, fecha_programada) "
          + "VALUES (?, ?, 'CONFIRMACION_CONSULTA', ?, ?, SYSDATETIME())";

    public RespuestaConsulta registrarDesdeLanding(SolicitudConsulta s) throws SQLException {
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // 1) PERSONA: se busca por documento (uq_persona_documento); si no existe, se inserta
                Integer idPersona = buscarPersona(cn, s.tipoDocumento(), s.nroDocumento().trim());
                boolean nueva = idPersona == null;
                if (nueva) {
                    idPersona = insertarPersona(cn, "NATURAL", s.tipoDocumento(), s.nroDocumento().trim(),
                            s.nombres().trim(), s.apellidos().trim(), null,
                            Jdbc.vacioANull(s.telefono()), Jdbc.vacioANull(s.email()), s.aceptaDatos());
                }

                // 2) CONSULTA
                int idConsulta;
                try (PreparedStatement ps = cn.prepareStatement(INSERT_CONSULTA, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idPersona);
                    ps.setInt(2, s.idMateria());
                    ps.setString(3, s.resumen().trim());
                    ps.setBoolean(4, s.esUrgente());
                    ps.executeUpdate();
                    idConsulta = Jdbc.idGenerado(ps);
                }

                // 3) CONSULTA_CONTRAPARTE (opcional): la contraparte se registra como PERSONA sin documento
                Integer idContraparte = null;
                if (s.contraparteTipo() != null && !s.contraparteTipo().isBlank()) {
                    boolean natural = "NATURAL".equals(s.contraparteTipo());
                    idContraparte = insertarPersona(cn, natural ? "NATURAL" : "JURIDICA", null, null,
                            natural ? s.contraparteNombres().trim() : null, natural ? s.contraparteApellidos().trim() : null,
                            natural ? null : s.contraparteRazonSocial().trim(), null, null, false);
                    try (PreparedStatement ps = cn.prepareStatement(INSERT_CONTRAPARTE)) {
                        ps.setInt(1, idConsulta);
                        ps.setInt(2, idContraparte);
                        ps.executeUpdate();
                    }
                }

                // 4) NOTIFICACION de confirmación al cliente
                int idNotificacion;
                String canal = Jdbc.vacioANull(s.telefono()) != null ? "WHATSAPP" : "CORREO";
                String mensaje = "Hola " + s.nombres().trim() + ", recibimos su consulta N.° " + idConsulta
                        + ". Un abogado de Magallanes-Montero le escribirá en menos de 24 horas.";
                try (PreparedStatement ps = cn.prepareStatement(INSERT_NOTIFICACION, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idPersona);
                    ps.setInt(2, idConsulta);
                    ps.setString(3, canal);
                    ps.setString(4, mensaje);
                    ps.executeUpdate();
                    idNotificacion = Jdbc.idGenerado(ps);
                }

                cn.commit();                                           // COMMIT: las 4 tablas juntas
                return new RespuestaConsulta(idConsulta, idPersona, nueva, idContraparte, idNotificacion, mensaje);
            } catch (SQLException | RuntimeException e) {
                cn.rollback();                                         // ROLLBACK: no queda nada a medias
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W04 · Bandeja
    private static final String SELECT_BANDEJA =
            "SELECT c.id_consulta, FORMAT(c.fecha_hora_recepcion, 'dd/MM/yyyy HH:mm'), "
          + "COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), "
          + "COALESCE(p.tipo_documento + ' ' + p.nro_documento, '—'), p.telefono, m.id_materia, m.nombre, c.canal, c.estado, c.es_urgente, "
          + "(SELECT COUNT(*) FROM dbo.consulta_contraparte cc WHERE cc.id_consulta = c.id_consulta), "
          + "(SELECT TOP 1 FORMAT(ci.fecha_hora, 'dd/MM/yyyy HH:mm') FROM dbo.cita ci "
          + "  WHERE ci.id_consulta = c.id_consulta AND ci.estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA') ORDER BY ci.fecha_hora DESC) "
          + "FROM dbo.consulta c JOIN dbo.persona p ON p.id_persona = c.id_persona "
          + "JOIN dbo.materia m ON m.id_materia = c.id_materia ";

    public List<FilaBandeja> bandeja(String estado, String canal) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT_BANDEJA).append("WHERE 1 = 1 ");
        List<String> params = new ArrayList<>();
        if (estado != null && !estado.isBlank()) { sql.append("AND c.estado = ? "); params.add(estado); }
        if (canal != null && !canal.isBlank()) { sql.append("AND c.canal = ? "); params.add(canal); }
        sql.append("ORDER BY CASE WHEN c.estado IN ('RECIBIDA','NO_ATENDIDA') THEN 0 ELSE 1 END, c.es_urgente DESC, c.id_consulta DESC");
        List<FilaBandeja> r = new ArrayList<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) ps.setString(i + 1, params.get(i));
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) r.add(fila(rs));
            }
        }
        return r;
    }

    public DetalleConsulta detalle(int idConsulta) throws SQLException {
        try (Connection cn = ds.getConnection()) {
            FilaBandeja f;
            String resumen, email;
            Boolean conflicto;
            try (PreparedStatement ps = cn.prepareStatement(SELECT_BANDEJA + "WHERE c.id_consulta = ?")) {
                ps.setInt(1, idConsulta);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) throw new ReglaNegocioException("No existe la consulta N.° " + idConsulta);
                    f = fila(rs);
                }
            }
            try (PreparedStatement ps = cn.prepareStatement(
                    "SELECT c.resumen, p.email, c.existe_conflicto FROM dbo.consulta c "
                  + "JOIN dbo.persona p ON p.id_persona = c.id_persona WHERE c.id_consulta = ?")) {
                ps.setInt(1, idConsulta);
                try (ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    resumen = rs.getString(1);
                    email = rs.getString(2);
                    boolean b = rs.getBoolean(3);
                    conflicto = rs.wasNull() ? null : b;
                }
            }
            List<String> contrapartes = textos(cn,
                    "SELECT COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) "
                  + "+ COALESCE(' (' + p.tipo_documento + ' ' + p.nro_documento + ')', ' (sin documento)') "
                  + "FROM dbo.consulta_contraparte cc JOIN dbo.persona p ON p.id_persona = cc.id_persona WHERE cc.id_consulta = ?",
                    idConsulta);
            // Apoyo a la revisión de conflicto (W05): ¿la contraparte ya es CLIENTE del estudio en algún caso?
            List<String> conflictos = textos(cn,
                    "SELECT DISTINCT COALESCE(p2.razon_social, p2.nombres + ' ' + p2.apellidos) + ' es CLIENTE en el caso ' + ca.codigo_interno "
                  + "FROM dbo.consulta_contraparte cc "
                  + "JOIN dbo.persona p1 ON p1.id_persona = cc.id_persona "
                  + "JOIN dbo.persona p2 ON (p2.id_persona = p1.id_persona "
                  + "     OR (p1.nro_documento IS NULL AND p2.razon_social = p1.razon_social) "
                  + "     OR (p1.nro_documento IS NULL AND p2.nombres = p1.nombres AND p2.apellidos = p1.apellidos)) "
                  + "JOIN dbo.caso_parte cp ON cp.id_persona = p2.id_persona AND cp.tipo_parte = 'CLIENTE' "
                  + "JOIN dbo.caso ca ON ca.id_caso = cp.id_caso "
                  + "WHERE cc.id_consulta = ?", idConsulta);
            List<FilaCita> citas = new ArrayList<>();
            try (PreparedStatement ps = cn.prepareStatement(CitaRepositorio.SELECT_CITAS + "WHERE ci.id_consulta = ? ORDER BY ci.fecha_hora")) {
                ps.setInt(1, idConsulta);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) citas.add(CitaRepositorio.filaCita(rs));
                }
            }
            List<FilaNotificacion> notifs = new ArrayList<>();
            try (PreparedStatement ps = cn.prepareStatement(
                    "SELECT n.id_notificacion, "
                  + "COALESCE(COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) + ' (cliente)', e.nombres + ' ' + e.apellidos + ' (' + LOWER(e.cargo) + ')'), "
                  + "n.tipo_evento, n.canal, n.estado, FORMAT(n.fecha_programada, 'dd/MM/yyyy HH:mm'), n.mensaje "
                  + "FROM dbo.notificacion n LEFT JOIN dbo.persona p ON p.id_persona = n.id_persona "
                  + "LEFT JOIN dbo.empleado e ON e.id_empleado = n.id_empleado "
                  + "WHERE n.id_consulta = ? ORDER BY n.id_notificacion")) {
                ps.setInt(1, idConsulta);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) notifs.add(new FilaNotificacion(rs.getInt(1), rs.getString(2), rs.getString(3),
                            rs.getString(4), rs.getString(5), rs.getString(6), rs.getString(7)));
                }
            }
            return new DetalleConsulta(f, resumen, email, conflicto, contrapartes, conflictos, citas, notifs);
        }
    }

    // ------------------------------------------------------------------ auxiliares
    private static FilaBandeja fila(ResultSet rs) throws SQLException {
        return new FilaBandeja(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5),
                rs.getInt(6), rs.getString(7), rs.getString(8), rs.getString(9), rs.getBoolean(10), rs.getInt(11), rs.getString(12));
    }

    private static List<String> textos(Connection cn, String sql, int id) throws SQLException {
        List<String> r = new ArrayList<>();
        try (PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) r.add(rs.getString(1));
            }
        }
        return r;
    }

    private static Integer buscarPersona(Connection cn, String tipoDoc, String nroDoc) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(BUSCAR_PERSONA)) {
            ps.setString(1, tipoDoc);
            ps.setString(2, nroDoc);
            try (ResultSet rs = ps.executeQuery()) { return rs.next() ? rs.getInt(1) : null; }
        }
    }

    private static int insertarPersona(Connection cn, String tipoPersona, String tipoDoc, String nroDoc, String nombres,
                                       String apellidos, String razonSocial, String telefono, String email,
                                       boolean acepta) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(INSERT_PERSONA, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, tipoPersona);
            ps.setString(2, tipoDoc);
            ps.setString(3, nroDoc);
            ps.setString(4, nombres);
            ps.setString(5, apellidos);
            ps.setString(6, razonSocial);
            ps.setString(7, telefono);
            ps.setString(8, email);
            ps.setBoolean(9, acepta);
            ps.executeUpdate();
            return Jdbc.idGenerado(ps);
        }
    }
}
