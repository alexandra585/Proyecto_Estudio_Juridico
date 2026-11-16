package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;

/** W02 · Inicio de sesión: USUARIO (cuenta) + EMPLEADO (nombre y cargo). */
@Repository
public class UsuarioRepositorio {

    /** Datos de la cuenta, incluido el hash para compararlo con BCrypt. */
    public record CuentaPanel(int idUsuario, String hash, boolean activo, int idEmpleado, String nombre, String cargo, String email) { }

    private final DataSource ds;

    public UsuarioRepositorio(DataSource ds) { this.ds = ds; }

    public Optional<CuentaPanel> buscarCuentaDelPanel(String email) throws SQLException {
        String sql = "SELECT u.id_usuario, u.contrasena_hash, u.activo, e.id_empleado, e.nombres + ' ' + e.apellidos, e.cargo, u.email "
                + "FROM dbo.usuario u JOIN dbo.empleado e ON e.id_empleado = u.id_empleado "   // solo cuentas de empleados (no del portal)
                + "WHERE u.email = ?";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return Optional.empty();
                return Optional.of(new CuentaPanel(rs.getInt(1), rs.getString(2), rs.getBoolean(3), rs.getInt(4),
                        rs.getString(5), rs.getString(6), rs.getString(7)));
            }
        }
    }

    /** Guarda la fecha del último ingreso (usuario.ultimo_acceso). */
    public void registrarAcceso(int idUsuario) throws SQLException {
        try (Connection cn = ds.getConnection();
             PreparedStatement ps = cn.prepareStatement("UPDATE dbo.usuario SET ultimo_acceso = SYSDATETIME() WHERE id_usuario = ?")) {
            ps.setInt(1, idUsuario);
            ps.executeUpdate();
        }
    }
}
