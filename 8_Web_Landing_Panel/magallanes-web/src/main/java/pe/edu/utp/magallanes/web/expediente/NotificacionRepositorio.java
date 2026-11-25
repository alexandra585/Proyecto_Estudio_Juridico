package pe.edu.utp.magallanes.web.expediente;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.Datos;

/**
 * CAMPANA DE AVISOS (panel y portal) sobre la tabla NOTIFICACION, que ya existía en el modelo de 36 tablas
 * (carril «Sistema» del TO-BE). Canal SISTEMA = aviso dentro del sistema; WHATSAPP / CORREO = aviso externo.
 * Lo «leído» no se guarda en la base: cada navegador recuerda la fecha del último aviso que vio.
 */
@Repository
public class NotificacionRepositorio {
    private final DataSource ds;

    public NotificacionRepositorio(DataSource ds) { this.ds = ds; }

    /** Avisos de un empleado + plazos a su cargo que vencen en 3 días o menos (vw_plazo_estado). */
    public Map<String, Object> delEmpleado(int idEmpleado) throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("avisos", q("SELECT TOP 20 n.id_notificacion, n.tipo_evento, n.canal, n.mensaje, "
                + "CONVERT(VARCHAR(19), n.fecha_programada, 126) AS fecha, c.codigo_interno, n.id_caso, n.id_consulta "
                + "FROM dbo.notificacion n LEFT JOIN dbo.caso c ON c.id_caso = n.id_caso "
                + "WHERE n.id_empleado = ? AND n.fecha_programada <= SYSDATETIME() ORDER BY n.fecha_programada DESC, n.id_notificacion DESC", idEmpleado));
        r.put("plazos", q("SELECT v.id_plazo, v.id_caso, c.codigo_interno, v.descripcion, FORMAT(v.fecha_vencimiento, 'dd/MM/yyyy') AS vence, v.estado, "
                + "DATEDIFF(DAY, CAST(GETDATE() AS DATE), v.fecha_vencimiento) AS dias_restantes "
                + "FROM dbo.vw_plazo_estado v JOIN dbo.caso c ON c.id_caso = v.id_caso "
                + "WHERE v.id_empleado_responsable = ? AND v.estado <> 'CUMPLIDO' AND c.estado = 'ACTIVO' "
                + "AND v.fecha_vencimiento <= DATEADD(DAY, 3, CAST(GETDATE() AS DATE)) ORDER BY v.fecha_vencimiento", idEmpleado));
        return r;
    }

    /** Avisos que recibió el cliente (portal). */
    public List<Map<String, Object>> delCliente(int idPersona) throws SQLException {
        return q("SELECT TOP 20 n.id_notificacion, n.tipo_evento, n.canal, n.mensaje, CONVERT(VARCHAR(19), n.fecha_programada, 126) AS fecha, c.codigo_interno "
                + "FROM dbo.notificacion n LEFT JOIN dbo.caso c ON c.id_caso = n.id_caso "
                + "WHERE n.id_persona = ? AND n.fecha_programada <= SYSDATETIME() ORDER BY n.fecha_programada DESC, n.id_notificacion DESC", idPersona);
    }

    /**
     * Aviso dentro del sistema (canal SISTEMA, ya ENVIADO) a todos los empleados activos con alguno de esos cargos
     * y, si se indica, a un empleado concreto (p. ej. el abogado del caso). Se ejecuta dentro de la transacción del llamador.
     */
    public static int avisarEquipo(Connection cn, List<String> cargos, Integer idEmpleadoExtra, Integer idConsulta, Integer idCaso,
                                   String tipoEvento, String mensaje) throws SQLException {
        StringBuilder in = new StringBuilder();
        for (int i = 0; i < cargos.size(); i++) in.append(i == 0 ? "?" : ", ?");
        String sql = "INSERT INTO dbo.notificacion (id_empleado, id_consulta, id_caso, tipo_evento, canal, mensaje, fecha_programada, fecha_envio, estado) "
                + "SELECT e.id_empleado, ?, ?, ?, 'SISTEMA', ?, SYSDATETIME(), SYSDATETIME(), 'ENVIADA' FROM dbo.empleado e "
                + "WHERE e.activo = 1 AND (e.cargo IN (" + (cargos.isEmpty() ? "''" : in) + ") OR e.id_empleado = ?)";
        try (PreparedStatement ps = cn.prepareStatement(sql)) {
            int i = 1;
            if (idConsulta == null) ps.setNull(i++, Types.INTEGER); else ps.setInt(i++, idConsulta);
            if (idCaso == null) ps.setNull(i++, Types.INTEGER); else ps.setInt(i++, idCaso);
            ps.setString(i++, tipoEvento);
            ps.setString(i++, mensaje);
            for (String c : cargos) ps.setString(i++, c);
            if (idEmpleadoExtra == null) ps.setNull(i, Types.INTEGER); else ps.setInt(i, idEmpleadoExtra);
            return ps.executeUpdate();
        }
    }

    /** Aviso dentro del sistema al cliente (lo ve en su portal). */
    public static void avisarCliente(Connection cn, int idPersona, Integer idConsulta, Integer idCaso, String tipoEvento, String mensaje) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(
                "INSERT INTO dbo.notificacion (id_persona, id_consulta, id_caso, tipo_evento, canal, mensaje, fecha_programada, fecha_envio, estado) "
              + "VALUES (?, ?, ?, ?, 'SISTEMA', ?, SYSDATETIME(), SYSDATETIME(), 'ENVIADA')")) {
            ps.setInt(1, idPersona);
            if (idConsulta == null) ps.setNull(2, Types.INTEGER); else ps.setInt(2, idConsulta);
            if (idCaso == null) ps.setNull(3, Types.INTEGER); else ps.setInt(3, idCaso);
            ps.setString(4, tipoEvento);
            ps.setString(5, mensaje);
            ps.executeUpdate();
        }
    }

    private List<Map<String, Object>> q(String sql, Object... p) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            return Datos.filas(ps);
        }
    }
}
