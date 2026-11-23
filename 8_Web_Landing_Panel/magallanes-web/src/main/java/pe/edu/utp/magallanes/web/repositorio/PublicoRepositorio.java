package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.dto.Calificacion;
import pe.edu.utp.magallanes.web.dto.Materia;
import pe.edu.utp.magallanes.web.dto.Socio;

/** Lecturas de la Landing Page: áreas (MATERIA), socios (EMPLEADO/ABOGADO/ABOGADO_MATERIA) y satisfacción (ENCUESTA). */
@Repository
public class PublicoRepositorio {
    private final DataSource ds;

    public PublicoRepositorio(DataSource ds) { this.ds = ds; }

    public List<Materia> materias() throws SQLException {
        String sql = "SELECT id_materia, nombre, descripcion FROM dbo.materia ORDER BY id_materia";
        List<Materia> r = new ArrayList<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            while (rs.next()) r.add(new Materia(rs.getInt(1), rs.getString(2), rs.getString(3)));
        }
        return r;
    }

    public List<Socio> socios() throws SQLException {
        String sql = "SELECT e.id_empleado, e.nombres + ' ' + e.apellidos, "
                + "LEFT(e.nombres, 1) + LEFT(e.apellidos, 1), a.nro_colegiatura, "
                + "(SELECT STRING_AGG(m.nombre, ' · ') WITHIN GROUP (ORDER BY am.es_principal DESC, m.nombre) "
                + "   FROM dbo.abogado_materia am JOIN dbo.materia m ON m.id_materia = am.id_materia "
                + "  WHERE am.id_abogado = a.id_empleado) "
                + "FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado "
                + "WHERE e.activo = 1 ORDER BY e.id_empleado";
        List<Socio> r = new ArrayList<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            while (rs.next()) r.add(new Socio(rs.getInt(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5)));
        }
        return r;
    }

    public Calificacion calificacion() throws SQLException {
        String sql = "SELECT CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)), COUNT(calificacion) FROM dbo.encuesta";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            rs.next();
            return new Calificacion(rs.getBigDecimal(1), rs.getInt(2));
        }
    }

    /** Cifras de la landing calculadas en SQL Server (no se escriben a mano). */
    public java.util.Map<String, Object> cifras() throws SQLException {
        String sql = "SELECT (SELECT COUNT(*) FROM dbo.caso), (SELECT COUNT(*) FROM dbo.caso WHERE estado = 'CERRADO'), "
                + "(SELECT COUNT(DISTINCT k.id_cliente) FROM dbo.contrato k), (SELECT COUNT(*) FROM dbo.abogado a JOIN dbo.empleado e ON e.id_empleado = a.id_empleado WHERE e.activo = 1), "
                + "(SELECT CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)) FROM dbo.encuesta), (SELECT COUNT(calificacion) FROM dbo.encuesta), "
                + "(SELECT COUNT(*) FROM dbo.materia)";
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            rs.next();
            java.util.Map<String, Object> r = new java.util.LinkedHashMap<>();
            r.put("casos", rs.getInt(1)); r.put("cerrados", rs.getInt(2)); r.put("clientes", rs.getInt(3)); r.put("abogados", rs.getInt(4));
            r.put("promedio", rs.getBigDecimal(5)); r.put("respuestas", rs.getInt(6)); r.put("areas", rs.getInt(7));
            return r;
        }
    }
}
