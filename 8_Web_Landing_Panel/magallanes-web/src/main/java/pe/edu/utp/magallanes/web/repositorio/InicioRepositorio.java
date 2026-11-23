package pe.edu.utp.magallanes.web.repositorio;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.Datos;
import pe.edu.utp.magallanes.web.dto.SesionUsuario;

/**
 * Página de INICIO del panel: lo pendiente del día según el ROL (empleado.cargo).
 *   SECRETARIA    → consultas por atender, citas de hoy, cuotas vencidas y comprobantes por cobrar.
 *   ABOGADO       → SUS plazos por vencer (plazo.id_empleado_responsable), SUS citas y SUS casos activos.
 *   PRACTICANTE   → plazos del estudio por vencer y escritos en borrador.
 *   ADMINISTRADOR → resumen del mes (fn_dash_resumen) y alertas de todo el estudio.
 * Solo lee (SELECT); los números se calculan en SQL Server.
 */
@Repository
public class InicioRepositorio {
    private final DataSource ds;

    public InicioRepositorio(DataSource ds) { this.ds = ds; }

    public Map<String, Object> inicio(SesionUsuario u) throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("nombre", u.nombre());
        r.put("cargo", u.cargo());
        List<Map<String, Object>> kpis = new ArrayList<>();
        List<Map<String, Object>> listas = new ArrayList<>();
        int yo = u.idEmpleado();
        try (Connection cn = ds.getConnection()) {
            switch (u.cargo()) {
                case "SECRETARIA" -> {
                    kpis.add(kpi("Consultas por atender", uno(cn, "SELECT COUNT(*) FROM dbo.consulta WHERE estado = 'RECIBIDA'"),
                            uno(cn, "SELECT COUNT(*) FROM dbo.consulta WHERE estado = 'RECIBIDA' AND es_urgente = 1") + " urgente(s)", "oro", "index.html", "bandeja"));
                    kpis.add(kpi("Citas de hoy", uno(cn, "SELECT COUNT(*) FROM dbo.cita WHERE CAST(fecha_hora AS DATE) = CAST(GETDATE() AS DATE) AND estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA')"),
                            "programadas", "azul", "index.html", "calendario"));
                    kpis.add(kpi("Cuotas vencidas", uno(cn, "SELECT COUNT(*) FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA'"),
                            "S/ " + uno(cn, "SELECT FORMAT(COALESCE(SUM(monto), 0), 'N2') FROM dbo.vw_cuota_estado WHERE estado = 'VENCIDA'"), "rojo", "t4-cobranza.html", "alerta"));
                    kpis.add(kpi("Por cobrar", "S/ " + uno(cn, "SELECT FORMAT(COALESCE(SUM(saldo), 0), 'N2') FROM dbo.vw_comprobante_saldo WHERE estado_pago IN ('PENDIENTE','PAGADO_PARCIAL')"),
                            uno(cn, "SELECT COUNT(*) FROM dbo.vw_comprobante_saldo WHERE estado_pago IN ('PENDIENTE','PAGADO_PARCIAL')") + " comprobante(s)", "verde", "t4-cobranza.html", "dinero"));
                    listas.add(lista("Consultas nuevas", "index.html", List.of("N.°", "Cliente", "Materia", "Recibida", "Urgente"), filas(cn,
                            "SELECT TOP 6 c.id_consulta, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), m.nombre, FORMAT(c.fecha_hora_recepcion, 'dd/MM HH:mm'), "
                          + "CASE WHEN c.es_urgente = 1 THEN 'SÍ' ELSE '' END FROM dbo.consulta c JOIN dbo.persona p ON p.id_persona = c.id_persona "
                          + "JOIN dbo.materia m ON m.id_materia = c.id_materia WHERE c.estado = 'RECIBIDA' ORDER BY c.es_urgente DESC, c.fecha_hora_recepcion")));
                    listas.add(lista("Próximas citas", "index.html", List.of("Fecha y hora", "Cliente", "Abogado", "Modalidad"), filas(cn,
                            "SELECT TOP 6 FORMAT(ci.fecha_hora, 'dd/MM HH:mm'), COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), e.nombres + ' ' + e.apellidos, ci.modalidad "
                          + "FROM dbo.cita ci JOIN dbo.consulta c ON c.id_consulta = ci.id_consulta JOIN dbo.persona p ON p.id_persona = c.id_persona "
                          + "JOIN dbo.empleado e ON e.id_empleado = ci.id_abogado WHERE ci.fecha_hora >= CAST(GETDATE() AS DATE) "
                          + "AND ci.estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA') ORDER BY ci.fecha_hora")));
                }
                case "ABOGADO" -> {
                    kpis.add(kpi("Mis casos activos", uno(cn, "SELECT COUNT(*) FROM dbo.caso WHERE estado = 'ACTIVO' AND id_abogado_responsable = ?", yo),
                            "a mi cargo", "azul", "t3-expediente.html", "carpeta"));
                    kpis.add(kpi("Mis plazos (7 días)", uno(cn, "SELECT COUNT(*) FROM dbo.plazo WHERE fecha_cumplimiento IS NULL AND id_empleado_responsable = ? AND fecha_vencimiento <= DATEADD(DAY, 7, CAST(GETDATE() AS DATE))", yo),
                            uno(cn, "SELECT COUNT(*) FROM dbo.plazo WHERE fecha_cumplimiento IS NULL AND id_empleado_responsable = ? AND fecha_vencimiento < CAST(GETDATE() AS DATE)", yo) + " vencido(s)", "rojo", "t3-expediente.html", "reloj"));
                    kpis.add(kpi("Mis citas próximas", uno(cn, "SELECT COUNT(*) FROM dbo.cita WHERE id_abogado = ? AND fecha_hora >= CAST(GETDATE() AS DATE) AND estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA')", yo),
                            "desde hoy", "oro", "index.html", "calendario"));
                    kpis.add(kpi("Consultas por evaluar", uno(cn, "SELECT COUNT(*) FROM dbo.consulta WHERE estado IN ('AGENDADA','ATENDIDA')"),
                            "para propuesta", "verde", "propuesta.html", "documento"));
                    listas.add(lista("Mis plazos pendientes", "t3-expediente.html", List.of("Caso", "Plazo", "Vence", "Días"), filas(cn,
                            "SELECT TOP 8 c.codigo_interno, p.descripcion, FORMAT(p.fecha_vencimiento, 'dd/MM/yyyy'), DATEDIFF(DAY, CAST(GETDATE() AS DATE), p.fecha_vencimiento) "
                          + "FROM dbo.plazo p JOIN dbo.caso c ON c.id_caso = p.id_caso WHERE p.fecha_cumplimiento IS NULL AND p.id_empleado_responsable = ? ORDER BY p.fecha_vencimiento", yo)));
                    listas.add(lista("Mis próximas citas", "index.html", List.of("Fecha y hora", "Cliente", "Materia", "Modalidad"), filas(cn,
                            "SELECT TOP 6 FORMAT(ci.fecha_hora, 'dd/MM HH:mm'), COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos), m.nombre, ci.modalidad "
                          + "FROM dbo.cita ci JOIN dbo.consulta c ON c.id_consulta = ci.id_consulta JOIN dbo.persona p ON p.id_persona = c.id_persona "
                          + "JOIN dbo.materia m ON m.id_materia = c.id_materia WHERE ci.id_abogado = ? AND ci.fecha_hora >= CAST(GETDATE() AS DATE) "
                          + "AND ci.estado IN ('PROGRAMADA','CONFIRMADA','REPROGRAMADA') ORDER BY ci.fecha_hora", yo)));
                }
                case "PRACTICANTE" -> {
                    kpis.add(kpi("Plazos del estudio (7 días)", uno(cn, "SELECT COUNT(*) FROM dbo.vw_plazos_por_vencer WHERE dias_restantes <= 7"),
                            "por vencer o vencidos", "rojo", "t3-expediente.html", "reloj"));
                    kpis.add(kpi("Escritos en borrador", uno(cn, "SELECT COUNT(*) FROM dbo.documento_legal WHERE estado = 'BORRADOR'"),
                            "por revisar", "oro", "t3-expediente.html", "documento"));
                    kpis.add(kpi("Casos activos", uno(cn, "SELECT COUNT(*) FROM dbo.caso WHERE estado = 'ACTIVO'"), "en el estudio", "azul", "t3-expediente.html", "carpeta"));
                    listas.add(lista("Plazos por vencer", "t3-expediente.html", List.of("Caso", "Plazo", "Vence", "Responsable"), filas(cn,
                            "SELECT TOP 8 codigo_interno, descripcion, FORMAT(fecha_vencimiento, 'dd/MM/yyyy'), responsable FROM dbo.vw_plazos_por_vencer ORDER BY dias_restantes")));
                }
                default -> { // ADMINISTRADOR (gerencia)
                    Map<String, Object> mes = fila(cn, "SELECT * FROM dbo.fn_dash_resumen(DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1), CAST(GETDATE() AS DATE))");
                    kpis.add(kpi("Cobrado este mes", "S/ " + soles(mes.get("ingresos_cobrados")), "sin IGV", "verde", "dashboard.html", "dinero"));
                    kpis.add(kpi("Ganancia del mes", "S/ " + soles(mes.get("ganancia_neta")), "ingresos − gastos", "oro", "dashboard.html", "grafico"));
                    kpis.add(kpi("Consultas nuevas", String.valueOf(mes.getOrDefault("consultas_recibidas", 0)), "este mes", "azul", "index.html", "bandeja"));
                    kpis.add(kpi("Alertas", String.valueOf(mes.getOrDefault("plazos_por_vencer", 0)) + " plazos",
                            mes.getOrDefault("cuotas_vencidas", 0) + " cuota(s) vencida(s)", "rojo", "dashboard.html", "alerta"));
                    listas.add(lista("Plazos por vencer", "t3-expediente.html", List.of("Caso", "Plazo", "Vence", "Responsable"), filas(cn,
                            "SELECT TOP 6 codigo_interno, descripcion, FORMAT(fecha_vencimiento, 'dd/MM/yyyy'), responsable FROM dbo.vw_plazos_por_vencer ORDER BY dias_restantes")));
                    listas.add(lista("Últimas encuestas", "t4-cobranza.html", List.of("Caso", "★", "NPS", "Comentario"), filas(cn,
                            "SELECT TOP 6 c.codigo_interno, e.calificacion, e.nps, LEFT(COALESCE(e.comentario, ''), 80) FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso "
                          + "WHERE e.fecha_respuesta IS NOT NULL ORDER BY e.fecha_respuesta DESC")));
                }
            }
        }
        r.put("kpis", kpis);
        r.put("listas", listas);
        return r;
    }

    private static Map<String, Object> kpi(String titulo, Object valor, String detalle, String tono, String enlace, String icono) {
        Map<String, Object> k = new LinkedHashMap<>();
        k.put("titulo", titulo); k.put("valor", String.valueOf(valor)); k.put("detalle", detalle);
        k.put("tono", tono); k.put("enlace", enlace); k.put("icono", icono);
        return k;
    }

    private static Map<String, Object> lista(String titulo, String enlace, List<String> columnas, List<List<Object>> filas) {
        Map<String, Object> l = new LinkedHashMap<>();
        l.put("titulo", titulo); l.put("enlace", enlace); l.put("columnas", columnas); l.put("filas", filas);
        return l;
    }

    private static String soles(Object v) {
        return v == null ? "0.00" : String.format(java.util.Locale.US, "%,.2f", new java.math.BigDecimal(v.toString()));
    }

    private static Object uno(Connection cn, String sql, Object... p) throws SQLException {
        List<List<Object>> f = filas(cn, sql, p);
        return f.isEmpty() ? 0 : f.get(0).get(0);
    }

    private static Map<String, Object> fila(Connection cn, String sql) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement(sql)) {
            List<Map<String, Object>> f = Datos.filas(ps);
            return f.isEmpty() ? Map.of() : f.get(0);
        }
    }

    private static List<List<Object>> filas(Connection cn, String sql, Object... p) throws SQLException {
        List<List<Object>> r = new ArrayList<>();
        try (PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            try (java.sql.ResultSet rs = ps.executeQuery()) {     // por posición: las columnas calculadas no tienen nombre
                int n = rs.getMetaData().getColumnCount();
                while (rs.next()) {
                    List<Object> f = new ArrayList<>();
                    for (int i = 1; i <= n; i++) f.add(rs.getObject(i));
                    r.add(f);
                }
            }
        }
        return r;
    }
}
