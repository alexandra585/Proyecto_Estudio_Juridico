package pe.edu.utp.magallanes.web.repositorio;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/** Utilidades JDBC comunes. */
final class Jdbc {
    private Jdbc() { }

    /** Devuelve el IDENTITY generado por el último INSERT (Statement.RETURN_GENERATED_KEYS). */
    static int idGenerado(PreparedStatement ps) throws SQLException {
        try (ResultSet k = ps.getGeneratedKeys()) {
            if (!k.next()) throw new SQLException("SQL Server no devolvió el id generado (IDENTITY).");
            return k.getInt(1);
        }
    }

    static String vacioANull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
