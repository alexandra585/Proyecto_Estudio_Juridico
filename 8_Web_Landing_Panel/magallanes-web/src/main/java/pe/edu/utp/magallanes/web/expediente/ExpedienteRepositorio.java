package pe.edu.utp.magallanes.web.expediente;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.sql.DataSource;
import org.bson.Document;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.Datos;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;

/**
 * FICHA DEL EXPEDIENTE (solo lectura): reúne en una sola respuesta todo lo que se sabe de un caso.
 * La usan dos pantallas:
 *   - Panel · «Escritos y resoluciones» (vista INTERNA: todo, incluida la bitácora de MongoDB y los borradores)
 *   - Portal del cliente · «Mi caso»     (vista CLIENTE: sin borradores, sin bitácora interna ni responsables)
 *
 * Tablas: CASO, CASO_ETAPA + ETAPA_PROCESAL (barra de etapas), CASO_PARTE + ROL_PROCESAL, DOCUMENTO_LEGAL, PRESENTACION,
 *         RESOLUCION, AUDIENCIA, vw_plazo_estado (semáforo), vw_cuota_estado · MongoDB: expedientes (bitácora), archivos (versiones).
 */
@Repository
public class ExpedienteRepositorio {
    private final DataSource ds;
    private final MongoDocumentos mongo;

    public ExpedienteRepositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    public Map<String, Object> ficha(int idCaso, boolean vistaCliente) throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        List<Map<String, Object>> c = q("SELECT c.id_caso, c.codigo_interno, c.nro_expediente_judicial, c.descripcion, c.estado, c.es_alta_complejidad, "
                + "FORMAT(c.fecha_apertura, 'dd/MM/yyyy') AS apertura, FORMAT(c.fecha_cierre, 'dd/MM/yyyy') AS cierre, "
                + "DATEDIFF(DAY, c.fecha_apertura, COALESCE(c.fecha_cierre, CAST(GETDATE() AS DATE))) AS dias, "
                + "m.nombre AS materia, e.nombres + ' ' + e.apellidos AS abogado, e.email AS abogado_email, e.telefono AS abogado_telefono, "
                + "k.nro_contrato, k.id_cliente, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, c.expediente_mongo_id "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona p ON p.id_persona = k.id_cliente WHERE c.id_caso = ?", idCaso);
        if (c.isEmpty()) throw new ReglaNegocioException("El caso " + idCaso + " no existe.");
        Map<String, Object> caso = c.get(0);
        r.put("caso", caso);

        // ---- Barra de etapas: catálogo completo + lo que el caso ya recorrió (fecha_fin NULL = etapa actual)
        List<Map<String, Object>> etapas = q("SELECT ep.id_etapa, ep.orden, ep.nombre, "
                + "FORMAT(MIN(ce.fecha_inicio), 'dd/MM/yyyy') AS inicio, FORMAT(MAX(ce.fecha_fin), 'dd/MM/yyyy') AS fin, "
                + "CASE WHEN SUM(CASE WHEN ce.id_caso_etapa IS NOT NULL AND ce.fecha_fin IS NULL THEN 1 ELSE 0 END) > 0 THEN 'ACTUAL' "
                + "     WHEN COUNT(ce.id_caso_etapa) > 0 THEN 'HECHA' ELSE 'PENDIENTE' END AS estado "
                + "FROM dbo.etapa_procesal ep LEFT JOIN dbo.caso_etapa ce ON ce.id_etapa = ep.id_etapa AND ce.id_caso = ? "
                + "GROUP BY ep.id_etapa, ep.orden, ep.nombre ORDER BY ep.orden", idCaso);
        int ordenActual = 0, ordenInicio = Integer.MAX_VALUE;
        for (Map<String, Object> e : etapas) {
            int orden = ((Number) e.get("orden")).intValue();
            if ("ACTUAL".equals(e.get("estado"))) ordenActual = orden;
            if (!"PENDIENTE".equals(e.get("estado"))) ordenInicio = Math.min(ordenInicio, orden);
        }
        // Fecha de la consulta de origen: la «Consulta inicial» siempre ocurrió (todo caso nace de una consulta → propuesta → contrato)
        List<Map<String, Object>> fc = q("SELECT FORMAT(co.fecha_hora_recepcion, 'dd/MM/yyyy') AS f FROM dbo.caso c "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.propuesta pr ON pr.id_propuesta = k.id_propuesta "
                + "JOIN dbo.consulta co ON co.id_consulta = pr.id_consulta WHERE c.id_caso = ?", idCaso);
        for (Map<String, Object> e : etapas) {
            if (!"PENDIENTE".equals(e.get("estado"))) continue;
            int orden = ((Number) e.get("orden")).intValue();
            if (orden == 1) {                                   // Consulta inicial → hecha en el proceso de captación (P1)
                e.put("estado", "HECHA");
                if (!fc.isEmpty()) e.put("inicio", fc.get(0).get("f"));
            } else if (orden < ordenInicio) e.put("estado", "PREVIA");     // ocurrió antes de que el estudio tomara el caso
            else if (orden < ordenActual) e.put("estado", "OMITIDA");     // el caso se la saltó después de abrirse
        }
        if ("CERRADO".equals(caso.get("estado")))
            for (Map<String, Object> e : etapas) if ("ACTUAL".equals(e.get("estado"))) e.put("estado", "HECHA");
        r.put("etapas", etapas);

        // ---- Partes del caso
        r.put("partes", q("SELECT cp.tipo_parte, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS nombre, rp.nombre AS rol, cp.abogado_externo "
                + "FROM dbo.caso_parte cp JOIN dbo.persona p ON p.id_persona = cp.id_persona JOIN dbo.rol_procesal rp ON rp.id_rol = cp.id_rol "
                + "WHERE cp.id_caso = ? ORDER BY CASE cp.tipo_parte WHEN 'CLIENTE' THEN 0 WHEN 'CONTRAPARTE' THEN 1 ELSE 2 END", idCaso));

        // ---- Semáforo de plazos (el estado y los días restantes se calculan; no se guardan)
        r.put("plazos", q("SELECT v.id_plazo, v.descripcion, FORMAT(v.fecha_vencimiento, 'dd/MM/yyyy') AS vence, v.estado, "
                + "DATEDIFF(DAY, CAST(GETDATE() AS DATE), v.fecha_vencimiento) AS dias_restantes, "
                + "FORMAT(v.fecha_cumplimiento, 'dd/MM/yyyy') AS cumplido, e.nombres + ' ' + e.apellidos AS responsable "
                + "FROM dbo.vw_plazo_estado v JOIN dbo.empleado e ON e.id_empleado = v.id_empleado_responsable WHERE v.id_caso = ? "
                + "ORDER BY CASE v.estado WHEN 'VENCIDO' THEN 0 WHEN 'PENDIENTE' THEN 1 ELSE 2 END, v.fecha_vencimiento", idCaso));

        // ---- Audiencias (vienen de una resolución de citación)
        r.put("audiencias", q("SELECT a.id_audiencia, FORMAT(a.fecha_hora, 'dd/MM/yyyy HH:mm') AS fecha, a.modalidad, a.tipo_audiencia, a.estado, "
                + "en.nombre AS entidad, CASE WHEN a.fecha_hora >= SYSDATETIME() THEN 1 ELSE 0 END AS proxima, "
                + "DATEDIFF(DAY, CAST(GETDATE() AS DATE), CAST(a.fecha_hora AS DATE)) AS dias "
                + "FROM dbo.audiencia a JOIN dbo.resolucion r ON r.id_resolucion = a.id_resolucion JOIN dbo.entidad en ON en.id_entidad = r.id_entidad "
                + "WHERE r.id_caso = ? ORDER BY a.fecha_hora DESC", idCaso));

        // ---- Documentos del expediente (+ versiones guardadas en MongoDB «archivos»)
        String filtroDocs = vistaCliente ? " AND d.estado IN ('APROBADO', 'PRESENTADO')" : "";
        List<Map<String, Object>> docs = q("SELECT d.id_documento, d.tipo_documento, d.titulo, d.version, d.estado, d.requiere_firma_cliente, d.elaborado_con_ia, "
                + "FORMAT(d.fecha_creacion, 'dd/MM/yyyy') AS creado, FORMAT(d.fecha_aprobacion, 'dd/MM/yyyy') AS aprobado, "
                + "e.nombres + ' ' + e.apellidos AS redactor, d.archivo_mongo_id, "
                + "(SELECT TOP 1 FORMAT(p.fecha_hora, 'dd/MM/yyyy') FROM dbo.presentacion p WHERE p.id_documento = d.id_documento ORDER BY p.fecha_hora DESC) AS presentado "
                + "FROM dbo.documento_legal d JOIN dbo.empleado e ON e.id_empleado = d.id_redactor WHERE d.id_caso = ?" + filtroDocs
                + " ORDER BY d.fecha_creacion DESC", idCaso);
        boolean hayMongo = mongo.disponible();
        for (Map<String, Object> d : docs) {
            Object id = d.get("archivo_mongo_id");
            d.put("versiones", null);
            if (hayMongo && id != null && id.toString().matches("[0-9a-fA-F]{24}")) {
                try {
                    Document a = mongo.buscar("archivos", id.toString());
                    if (a != null && a.get("versiones") instanceof List<?> vs) {
                        List<Map<String, Object>> lista = new ArrayList<>();
                        for (Object o : vs) if (o instanceof Document v) {
                            Map<String, Object> m = new LinkedHashMap<>();
                            m.put("v", v.get("v")); m.put("autor", v.get("autor")); m.put("fecha", v.get("fecha")); m.put("origen", v.get("origen"));
                            m.put("observaciones", v.get("observaciones"));
                            lista.add(m);
                        }
                        d.put("versiones", lista);
                    }
                } catch (RuntimeException ignorada) { /* id de ejemplo que no existe en MongoDB */ }
            }
            if (vistaCliente) d.remove("archivo_mongo_id");
        }
        r.put("documentos", docs);

        // ---- Línea de tiempo: todo lo que pasó en el caso, del más reciente al más antiguo
        String tl = "SELECT * FROM ("
                + " SELECT ce.fecha_inicio AS f, 'ETAPA' AS tipo, N'Inicia la etapa: ' + ep.nombre AS titulo, CAST(NULL AS NVARCHAR(300)) AS detalle "
                + "   FROM dbo.caso_etapa ce JOIN dbo.etapa_procesal ep ON ep.id_etapa = ce.id_etapa WHERE ce.id_caso = ?"
                + " UNION ALL SELECT CAST(p.fecha_hora AS DATE), 'PRESENTACION', N'Se presentó: ' + d.titulo, en.nombre + N' · ' + p.modalidad + COALESCE(N' · cargo ' + p.nro_cargo, N'') "
                + "   FROM dbo.presentacion p JOIN dbo.documento_legal d ON d.id_documento = p.id_documento JOIN dbo.entidad en ON en.id_entidad = p.id_entidad WHERE d.id_caso = ?"
                + " UNION ALL SELECT r.fecha_notificacion, 'RESOLUCION', CASE WHEN r.nro_resolucion LIKE N'Res%' THEN r.nro_resolucion ELSE N'Resolución ' + COALESCE(r.nro_resolucion, N'') END + N' (' + LOWER(r.tipo_resolucion) + N')', "
                + "   en.nombre + COALESCE(N' · ' + r.sumilla, N'') FROM dbo.resolucion r JOIN dbo.entidad en ON en.id_entidad = r.id_entidad WHERE r.id_caso = ?"
                + " UNION ALL SELECT CAST(a.fecha_hora AS DATE), 'AUDIENCIA', N'Audiencia ' + LOWER(a.tipo_audiencia) + N' (' + LOWER(a.estado) + N')', "
                + "   FORMAT(a.fecha_hora, 'HH:mm') + N' · ' + LOWER(a.modalidad) FROM dbo.audiencia a JOIN dbo.resolucion r ON r.id_resolucion = a.id_resolucion WHERE r.id_caso = ?"
                + (vistaCliente ? "" :
                  " UNION ALL SELECT CAST(d.fecha_creacion AS DATE), 'ESCRITO', N'Escrito redactado: ' + d.titulo, d.tipo_documento + N' · ' + d.estado "
                + "   FROM dbo.documento_legal d WHERE d.id_caso = ?"
                + " UNION ALL SELECT v.fecha_cumplimiento, 'PLAZO', N'Plazo cumplido: ' + v.descripcion, NULL FROM dbo.vw_plazo_estado v WHERE v.id_caso = ? AND v.fecha_cumplimiento IS NOT NULL")
                + ") t WHERE f <= CAST(GETDATE() AS DATE) ORDER BY f DESC";
        List<Map<String, Object>> eventos = vistaCliente ? q(tl, idCaso, idCaso, idCaso, idCaso) : q(tl, idCaso, idCaso, idCaso, idCaso, idCaso, idCaso);
        for (Map<String, Object> e : eventos) { Object f = e.remove("f"); e.put("fecha", f == null ? null : f.toString()); }
        r.put("linea", eventos);

        // ---- Cuotas del contrato del caso
        r.put("cuotas", q("SELECT v.nro_cuota, v.concepto, v.monto, FORMAT(v.fecha_vencimiento, 'dd/MM/yyyy') AS vence, v.estado "
                + "FROM dbo.vw_cuota_estado v JOIN dbo.caso c ON c.id_contrato = v.id_contrato WHERE c.id_caso = ? ORDER BY v.nro_cuota", idCaso));

        // ---- Bitácora interna (MongoDB «expedientes»): solo para el panel
        if (!vistaCliente && hayMongo) {
            try {
                Document exp = mongo.buscarPor("expedientes", "id_caso", idCaso);
                if (exp != null && exp.get("bitacora") instanceof List<?> b) {
                    List<Map<String, Object>> bit = new ArrayList<>();
                    for (Object o : b) if (o instanceof Document d) {
                        Map<String, Object> m = new LinkedHashMap<>();
                        m.put("fecha", d.get("fecha"));                       // java.util.Date → milisegundos en el JSON
                        m.put("evento", String.valueOf(d.get("evento")));
                        m.put("usuario", d.get("usuario") == null ? "" : String.valueOf(d.get("usuario")));
                        bit.add(m);
                    }
                    java.util.Collections.reverse(bit);
                    r.put("bitacora", bit.size() > 15 ? bit.subList(0, 15) : bit);
                    r.put("etiquetas", exp.get("etiquetas"));
                    r.put("resumen_hechos", exp.get("resumen_hechos"));
                }
            } catch (RuntimeException ignorada) { /* sin expediente digital */ }
        }
        r.put("mongo", hayMongo);
        return r;
    }

    private List<Map<String, Object>> q(String sql, Object... p) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            return Datos.filas(ps);
        }
    }
}
