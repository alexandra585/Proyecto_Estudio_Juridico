package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.dto.Abogado;
import pe.edu.utp.magallanes.web.dto.Disponibilidad;
import pe.edu.utp.magallanes.web.dto.FilaCita;
import pe.edu.utp.magallanes.web.dto.RespuestaCita;
import pe.edu.utp.magallanes.web.dto.SolicitudCita;

/**
 * TRANSACCIÓN · Agendar cita (W06, continúa el proceso P1 / T2).
 * CITA (INSERT) → CONSULTA (UPDATE estado = AGENDADA) → NOTIFICACION al cliente y NOTIFICACION al abogado.
 * Lee ABOGADO_MATERIA (qué abogado atiende la materia) y FERIADO (no se agenda en feriados).
 */
@Repository
public class CitaRepositorio {
    /** Horario de atención: 9:00 a 17:00, sin la hora de almuerzo. */
    public static final List<String> HORAS = List.of("09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00");
    private static final DateTimeFormatter F = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    static final String SELECT_CITAS =
            "SELECT ci.id_cita, ci.id_consulta, FORMAT(ci.fecha_hora, 'dd/MM/yyyy HH:mm'), "
          + "COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), e.nombres + ' ' + e.apellidos, ci.modalidad, ci.estado "
          + "FROM dbo.cita ci JOIN dbo.consulta c ON c.id_consulta = ci.id_consulta "
          + "JOIN dbo.persona p ON p.id_persona = c.id_persona "
          + "JOIN dbo.empleado e ON e.id_empleado = ci.id_abogado ";

    private final DataSource ds;

    public CitaRepositorio(DataSource ds) { this.ds = ds; }

    static FilaCita filaCita(ResultSet rs) throws SQLException {
        return new FilaCita(rs.getInt(1), rs.getInt(2), rs.getString(3), rs.getString(4), rs.getString(5), rs.getString(6), rs.getString(7));
    }

    /** Abogados que atienden la materia de la consulta (el principal primero). */
    public List<Abogado> abogadosPorMateria(int idMateria) throws SQLException {
        String sql = "SELECT a.id_empleado, e.nombres + ' ' + e.apellidos, a.nro_colegiatura, am.es_principal "
                + "FROM dbo.abogado_materia am JOIN dbo.abogado a ON a.id_empleado = am.id_abogado "
                + "JOIN dbo.empleado e ON e.id_empleado = a.id_empleado "
                + "WHERE am.id_materia = ? AND e.activo = 1 ORDER BY am.es_principal DESC, e.nombres";
        List<Abogado> r = new ArrayList<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setInt(1, idMateria);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) r.add(new Abogado(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getBoolean(4)));
            }
        }
        return r;
    }

    /** Horas ocupadas del abogado en la fecha y si la fecha es feriado (tabla FERIADO). */
    public Disponibilidad disponibilidad(int idAbogado, LocalDate fecha) throws SQLException {
        try (Connection cn = ds.getConnection()) {
            String feriado = feriado(cn, fecha);
            List<String> ocupadas = new ArrayList<>();
            try (PreparedStatement ps = cn.prepareStatement(
                    "SELECT FORMAT(fecha_hora, 'HH:mm') FROM dbo.cita WHERE id_abogado = ? "
                  + "AND CAST(fecha_hora AS DATE) = ? AND estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA')")) {
                ps.setInt(1, idAbogado);
                ps.setDate(2, Date.valueOf(fecha));
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) ocupadas.add(rs.getString(1));
                }
            }
            return new Disponibilidad(fecha.toString(), feriado, fecha.getDayOfWeek() == DayOfWeek.SUNDAY, HORAS, ocupadas);
        }
    }

    public RespuestaCita agendar(SolicitudCita s) throws SQLException {
        LocalDate fecha;
        LocalTime hora;
        try {
            fecha = LocalDate.parse(s.fecha());
            hora = LocalTime.parse(s.hora());
        } catch (Exception e) {
            throw new ReglaNegocioException("Fecha u hora no válidas.");
        }
        if (!HORAS.contains(s.hora())) throw new ReglaNegocioException("La hora debe estar en el horario de atención.");
        LocalDateTime fechaHora = LocalDateTime.of(fecha, hora);
        if (!fechaHora.isAfter(LocalDateTime.now())) throw new ReglaNegocioException("La cita debe ser en una fecha y hora futuras.");
        if (fecha.getDayOfWeek() == DayOfWeek.SUNDAY) throw new ReglaNegocioException("El estudio no atiende los domingos.");
        String modalidad = "VIRTUAL".equals(s.modalidad()) ? "VIRTUAL" : "PRESENCIAL";

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // Bloquea la consulta (UPDLOCK) para que dos secretarias no la agenden a la vez
                int idPersona, idMateria;
                String nombreCliente, telefono;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT c.estado, c.existe_conflicto, c.id_persona, c.id_materia, "
                      + "COALESCE(p.razon_social, p.nombres), p.telefono "
                      + "FROM dbo.consulta c WITH (UPDLOCK, ROWLOCK) JOIN dbo.persona p ON p.id_persona = c.id_persona "
                      + "WHERE c.id_consulta = ?")) {
                    ps.setInt(1, s.idConsulta());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("No existe la consulta N.° " + s.idConsulta());
                        String estado = rs.getString(1);
                        boolean conflicto = rs.getBoolean(2) && !rs.wasNull();
                        if (!estado.equals("RECIBIDA") && !estado.equals("NO_ATENDIDA"))
                            throw new ReglaNegocioException("La consulta está en estado " + estado + "; solo se agenda si está RECIBIDA o NO_ATENDIDA.");
                        if (conflicto) throw new ReglaNegocioException("La consulta tiene conflicto de interés: no se puede agendar.");
                        idPersona = rs.getInt(3);
                        idMateria = rs.getInt(4);
                        nombreCliente = rs.getString(5);
                        telefono = rs.getString(6);
                    }
                }
                // El abogado debe atender la materia (ABOGADO_MATERIA)
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT COUNT(*) FROM dbo.abogado_materia WHERE id_abogado = ? AND id_materia = ?")) {
                    ps.setInt(1, s.idAbogado());
                    ps.setInt(2, idMateria);
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        if (rs.getInt(1) == 0) throw new ReglaNegocioException("El abogado elegido no atiende la materia de la consulta.");
                    }
                }
                // No se agenda en feriados (tabla FERIADO)
                String feriado = feriado(cn, fecha);
                if (feriado != null) throw new ReglaNegocioException("El " + fecha + " es feriado: " + feriado + ".");
                // El abogado no puede tener otra cita a la misma hora
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT COUNT(*) FROM dbo.cita WITH (UPDLOCK, HOLDLOCK) WHERE id_abogado = ? AND fecha_hora = ? "
                      + "AND estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA')")) {
                    ps.setInt(1, s.idAbogado());
                    ps.setTimestamp(2, Timestamp.valueOf(fechaHora));
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        if (rs.getInt(1) > 0) throw new ReglaNegocioException("El abogado ya tiene una cita a esa hora. Elija otra.");
                    }
                }

                // 1) CITA
                int idCita;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.cita (id_consulta, id_abogado, fecha_hora, modalidad) VALUES (?, ?, ?, ?)",
                        Statement.RETURN_GENERATED_KEYS)) {            // estado = PROGRAMADA por DEFAULT
                    ps.setInt(1, s.idConsulta());
                    ps.setInt(2, s.idAbogado());
                    ps.setTimestamp(3, Timestamp.valueOf(fechaHora));
                    ps.setString(4, modalidad);
                    ps.executeUpdate();
                    idCita = Jdbc.idGenerado(ps);
                }
                // 2) CONSULTA pasa a AGENDADA
                try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.consulta SET estado = 'AGENDADA' WHERE id_consulta = ?")) {
                    ps.setInt(1, s.idConsulta());
                    ps.executeUpdate();
                }
                // 3) NOTIFICACION al cliente: recordatorio 1 día antes (o ahora si la cita es mañana)
                LocalDateTime aviso = fechaHora.minusDays(1);
                if (aviso.isBefore(LocalDateTime.now())) aviso = LocalDateTime.now();
                String texto = "Hola " + nombreCliente + ", su cita con Magallanes-Montero es el " + F.format(fechaHora)
                        + (modalidad.equals("VIRTUAL") ? " (virtual, le enviaremos el enlace)." : " en Av. Arequipa 1830, Lince.");
                int idNotCliente = insertarNotificacion(cn, idPersona, null, s.idConsulta(),
                        telefono != null ? "WHATSAPP" : "CORREO", texto, aviso);
                // 4) NOTIFICACION al abogado (campana del panel)
                int idNotAbogado = insertarNotificacion(cn, null, s.idAbogado(), s.idConsulta(), "SISTEMA",
                        "Nueva cita " + F.format(fechaHora) + " con " + nombreCliente + " (consulta N.° " + s.idConsulta() + ").",
                        LocalDateTime.now());

                cn.commit();                                           // COMMIT
                return new RespuestaCita(idCita, F.format(fechaHora), idNotCliente, idNotAbogado,
                        "Cita N.° " + idCita + " agendada para el " + F.format(fechaHora) + ".");
            } catch (SQLException | RuntimeException e) {
                cn.rollback();                                         // ROLLBACK
                throw e;
            }
        }
    }

    /** Agenda: citas desde hoy. */
    public List<FilaCita> proximas() throws SQLException {
        List<FilaCita> r = new ArrayList<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(
                SELECT_CITAS + "WHERE ci.fecha_hora >= CAST(GETDATE() AS DATE) ORDER BY ci.fecha_hora");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) r.add(filaCita(rs));
        }
        return r;
    }

    private static String feriado(Connection cn, LocalDate fecha) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement("SELECT descripcion FROM dbo.feriado WHERE fecha = ?")) {
            ps.setDate(1, Date.valueOf(fecha));
            try (ResultSet rs = ps.executeQuery()) { return rs.next() ? rs.getString(1) : null; }
        }
    }

    private static int insertarNotificacion(Connection cn, Integer idPersona, Integer idEmpleado, int idConsulta,
                                            String canal, String mensaje, LocalDateTime programada) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(
                "INSERT INTO dbo.notificacion (id_persona, id_empleado, id_consulta, tipo_evento, canal, mensaje, fecha_programada) "
              + "VALUES (?, ?, ?, 'RECORDATORIO_CITA', ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
            if (idPersona == null) ps.setNull(1, java.sql.Types.INTEGER); else ps.setInt(1, idPersona);
            if (idEmpleado == null) ps.setNull(2, java.sql.Types.INTEGER); else ps.setInt(2, idEmpleado);
            ps.setInt(3, idConsulta);
            ps.setString(4, canal);
            ps.setString(5, mensaje);
            ps.setTimestamp(6, Timestamp.valueOf(programada));
            ps.executeUpdate();
            return Jdbc.idGenerado(ps);
        }
    }
}
