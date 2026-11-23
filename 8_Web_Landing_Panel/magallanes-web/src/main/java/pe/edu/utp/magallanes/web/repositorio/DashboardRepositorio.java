package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;

/**
 * W03 · Dashboard gerencial. Solo LEE: los indicadores se calculan en SQL Server, no se guardan (3FN).
 *
 * Filtro por periodo (desde / hasta): se envía a las FUNCIONES CON PARÁMETROS de SQL Server
 * (script 1_SQL_Server/magallanes_montero_dashboard_filtros.sql), por ejemplo:
 *     SELECT * FROM dbo.fn_dash_resumen(?, ?)
 * Lo que es "foto del día de hoy" (plazos por vencer, cuotas vencidas, carga) no depende del filtro.
 */
@Repository
public class DashboardRepositorio {
    private final DataSource ds;

    public DashboardRepositorio(DataSource ds) { this.ds = ds; }

    /** Todos los indicadores del dashboard para el periodo [desde, hasta] en un solo objeto JSON. */
    public Map<String, Object> todo(LocalDate desde, LocalDate hasta) throws SQLException {
        Date d = Date.valueOf(desde), h = Date.valueOf(hasta);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("desde", desde.toString());
        r.put("hasta", hasta.toString());
        try (Connection cn = ds.getConnection()) {
            List<Map<String, Object>> resumen = filas(cn, "SELECT * FROM dbo.fn_dash_resumen(?, ?)", d, h);
            r.put("resumen", resumen.isEmpty() ? Map.of() : resumen.get(0));
            r.put("cobranza", filas(cn, "SELECT granularidad, periodo, cobrado_sin_igv, pagos FROM dbo.fn_dash_cobranza(?, ?) ORDER BY periodo", d, h));
            r.put("materias", filas(cn, "SELECT materia, ingresos, gastos, ganancia, casos FROM dbo.fn_dash_rentabilidad_materia(?, ?) ORDER BY ganancia DESC", d, h));
            r.put("abogados", filas(cn, "SELECT r.abogado, r.ingresos, r.gastos, r.ganancia, c.casos_activos, c.plazos_pendientes, c.audiencias_proximas "
                    + "FROM dbo.fn_dash_rentabilidad_abogado(?, ?) r JOIN dbo.vw_dash_carga_abogado c ON c.id_abogado = r.id_abogado "
                    + "ORDER BY r.ganancia DESC", d, h));
            r.put("embudo", filas(cn, "SELECT etapa, cantidad FROM dbo.fn_dash_embudo(?, ?) ORDER BY orden", d, h));
            r.put("canales", filas(cn, "SELECT canal, consultas, contratadas FROM dbo.fn_dash_consultas_canal(?, ?) ORDER BY consultas DESC", d, h));
            List<Map<String, Object>> sat = filas(cn, "SELECT * FROM dbo.fn_dash_satisfaccion(?, ?)", d, h);
            r.put("satisfaccion", sat.isEmpty() ? Map.of() : sat.get(0));
            // Al día de hoy (no dependen del filtro)
            r.put("plazos", filas(cn, "SELECT codigo_interno, descripcion, FORMAT(fecha_vencimiento, 'dd/MM/yyyy') AS vence, dias_restantes, responsable "
                    + "FROM dbo.vw_plazos_por_vencer ORDER BY dias_restantes"));
            r.put("cuotasVencidas", filas(cn, "SELECT TOP 8 v.id_cuota, k.nro_contrato, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                    + "v.concepto, v.monto, FORMAT(v.fecha_vencimiento, 'dd/MM/yyyy') AS vence "
                    + "FROM dbo.vw_cuota_estado v JOIN dbo.contrato k ON k.id_contrato = v.id_contrato "
                    + "JOIN dbo.persona p ON p.id_persona = k.id_cliente WHERE v.estado = 'VENCIDA' ORDER BY v.fecha_vencimiento"));
        }
        return r;
    }

    /** Convierte cualquier SELECT (con parámetros ?) en una lista de filas {columna: valor} lista para JSON. */
    private static List<Map<String, Object>> filas(Connection cn, String sql, Object... params) throws SQLException {
        List<Map<String, Object>> r = new ArrayList<>();
        try (PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) ps.setObject(i + 1, params[i]);
            try (ResultSet rs = ps.executeQuery()) {
                ResultSetMetaData md = rs.getMetaData();
                while (rs.next()) {
                    Map<String, Object> f = new LinkedHashMap<>();
                    for (int i = 1; i <= md.getColumnCount(); i++) f.put(md.getColumnLabel(i), rs.getObject(i));
                    r.add(f);
                }
            }
        }
        return r;
    }
}
