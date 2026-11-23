package pe.edu.utp.magallanes.web.config;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Utilidades comunes de los repositorios: leer los datos JSON que envía la pantalla
 * (Map clave → valor) validando su tipo, y convertir un ResultSet en filas para JSON.
 * Si un dato falta o tiene mal formato se lanza ReglaNegocioException (HTTP 400 con el mensaje).
 */
public final class Datos {
    private Datos() { }

    public static Object requerido(Map<String, Object> d, String k) {
        Object v = d.get(k);
        if (v == null || v.toString().isBlank()) throw new ReglaNegocioException("Falta el dato: " + k);
        return v;
    }
    public static boolean tiene(Map<String, Object> d, String k) {
        Object v = d.get(k);
        return v != null && !v.toString().isBlank();
    }
    public static int entero(Map<String, Object> d, String k) {
        try { return new BigDecimal(requerido(d, k).toString()).intValueExact(); }
        catch (ArithmeticException | NumberFormatException e) { throw new ReglaNegocioException("Número no válido en " + k); }
    }
    public static Integer enteroOpcional(Map<String, Object> d, String k) { return tiene(d, k) ? entero(d, k) : null; }
    public static BigDecimal decimal(Map<String, Object> d, String k) {
        try { return new BigDecimal(requerido(d, k).toString()).setScale(2, RoundingMode.HALF_UP); }
        catch (NumberFormatException e) { throw new ReglaNegocioException("Monto no válido en " + k); }
    }
    public static String texto(Map<String, Object> d, String k) { return requerido(d, k).toString().trim(); }
    public static String textoOpcional(Map<String, Object> d, String k) { return tiene(d, k) ? d.get(k).toString().trim() : null; }
    public static boolean booleano(Map<String, Object> d, String k) { return Boolean.TRUE.equals(d.get(k)) || "true".equals(String.valueOf(d.get(k))); }
    public static LocalDate fecha(Map<String, Object> d, String k) {
        try { return LocalDate.parse(texto(d, k)); }
        catch (DateTimeParseException e) { throw new ReglaNegocioException("Fecha no válida en " + k); }
    }
    @SuppressWarnings("unchecked")
    public static List<Map<String, Object>> lista(Map<String, Object> d, String k) {
        Object v = d.get(k);
        return v instanceof List<?> l ? (List<Map<String, Object>>) l : List.of();
    }
    @SuppressWarnings("unchecked")
    public static List<Object> valores(Map<String, Object> d, String k) {
        Object v = d.get(k);
        return v instanceof List<?> l ? (List<Object>) l : List.of();
    }

    /** setInt que acepta null (columna opcional). */
    public static void setEnteroONull(PreparedStatement ps, int i, Integer v) throws SQLException {
        if (v == null) ps.setNull(i, Types.INTEGER); else ps.setInt(i, v);
    }
    public static void setTextoONull(PreparedStatement ps, int i, String v) throws SQLException {
        if (v == null) ps.setNull(i, Types.NVARCHAR); else ps.setString(i, v);
    }

    /** IDENTITY generado por el último INSERT (Statement.RETURN_GENERATED_KEYS). */
    public static int idGenerado(PreparedStatement ps) throws SQLException {
        try (ResultSet k = ps.getGeneratedKeys()) {
            if (!k.next()) throw new SQLException("SQL Server no devolvió el id generado (IDENTITY).");
            return k.getInt(1);
        }
    }

    /** Ejecuta un SELECT con parámetros y devuelve las filas como {columna: valor}. */
    public static List<Map<String, Object>> filas(PreparedStatement ps) throws SQLException {
        List<Map<String, Object>> r = new ArrayList<>();
        try (ResultSet rs = ps.executeQuery()) {
            ResultSetMetaData md = rs.getMetaData();
            while (rs.next()) {
                Map<String, Object> f = new LinkedHashMap<>();
                for (int i = 1; i <= md.getColumnCount(); i++) f.put(md.getColumnLabel(i), rs.getObject(i));
                r.add(f);
            }
        }
        return r;
    }
}
