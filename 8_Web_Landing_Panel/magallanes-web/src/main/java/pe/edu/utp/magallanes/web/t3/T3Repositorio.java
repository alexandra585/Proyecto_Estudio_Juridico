package pe.edu.utp.magallanes.web.t3;

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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.sql.DataSource;
import org.bson.Document;
import org.springframework.stereotype.Repository;
import pe.edu.utp.magallanes.web.config.Datos;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;

/**
 * MÓDULO T3 · Gestión del expediente (proceso P2).
 *   W11 Nuevo escrito ........ DOCUMENTO_LEGAL + DOCUMENTO_JURISPRUDENCIA (n) + MongoDB «archivos» (texto del escrito)
 *   W12 Presentación ......... PRESENTACION + UPDATE DOCUMENTO_LEGAL (estado PRESENTADO)
 *   W13 Resolución y plazo ... RESOLUCION + PLAZO (vencimiento en días hábiles con FERIADO) + MongoDB «archivos»
 * Cada operación: una transacción en SQL Server; el _id de MongoDB se guarda en la columna CHAR(24) y,
 * si SQL Server hace ROLLBACK, el documento de MongoDB se borra (compensación).
 */
@Repository
public class T3Repositorio {
    private static final Set<String> TIPOS_DOC = Set.of("DEMANDA", "CONTESTACION", "DENUNCIA", "DESCARGO", "RECURSO", "SUBSANACION", "ABSOLUCION", "SOLICITUD", "ESCRITO_SIMPLE");
    private static final Set<String> TIPOS_RES = Set.of("ADMISORIO", "INADMISIBLE", "IMPROCEDENTE", "TRASLADO", "REQUERIMIENTO", "CITACION", "DECRETO", "ACTA_CONCILIACION", "SENTENCIA", "LAUDO", "AUTO_FINAL");
    private static final Set<String> MEDIOS = Set.of("SINOE", "CEDULA", "CASILLA_ADMINISTRATIVA", "CORREO", "CEJ");

    private final DataSource ds;
    private final MongoDocumentos mongo;

    public T3Repositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    // ------------------------------------------------------------------ lecturas
    public List<Map<String, Object>> casosActivos() throws SQLException {
        return q("SELECT c.id_caso, c.codigo_interno, c.id_materia, m.nombre AS materia, e.nombres + ' ' + e.apellidos AS abogado, "
                + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, c.expediente_mongo_id "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona pe ON pe.id_persona = k.id_cliente "
                + "WHERE c.estado = 'ACTIVO' ORDER BY c.id_caso DESC");
    }

    public List<Map<String, Object>> casosTodos() throws SQLException {
        return q("SELECT c.id_caso, c.codigo_interno, c.estado, m.nombre AS materia, "
                + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona pe ON pe.id_persona = k.id_cliente "
                + "ORDER BY CASE c.estado WHEN 'ACTIVO' THEN 0 ELSE 1 END, c.id_caso DESC");
    }

    public List<Map<String, Object>> jurisprudenciaDelCaso(int idCaso) throws SQLException {
        return q("SELECT j.id_jurisprudencia, j.tipo, j.referencia, j.titulo FROM dbo.jurisprudencia j "
                + "JOIN dbo.caso c ON c.id_materia = j.id_materia WHERE c.id_caso = ? ORDER BY j.tipo, j.referencia", idCaso);
    }

    public List<Map<String, Object>> entidades() throws SQLException {
        return q("SELECT id_entidad, nombre, tipo_entidad FROM dbo.entidad ORDER BY tipo_entidad, nombre");
    }

    public List<Map<String, Object>> empleados() throws SQLException {
        return q("SELECT id_empleado, nombres + ' ' + apellidos AS nombre, cargo FROM dbo.empleado WHERE activo = 1 ORDER BY cargo, nombres");
    }

    /** Escritos del caso (para W12) y presentaciones del caso (para W13). */
    public List<Map<String, Object>> documentosDelCaso(int idCaso) throws SQLException {
        return q("SELECT d.id_documento, d.tipo_documento, d.titulo, d.version, d.estado, FORMAT(d.fecha_creacion, 'dd/MM/yyyy HH:mm') AS creado, "
                + "e.nombres + ' ' + e.apellidos AS redactor, d.archivo_mongo_id, "
                + "(SELECT COUNT(*) FROM dbo.documento_jurisprudencia x WHERE x.id_documento = d.id_documento) AS citas "
                + "FROM dbo.documento_legal d JOIN dbo.empleado e ON e.id_empleado = d.id_redactor WHERE d.id_caso = ? ORDER BY d.id_documento DESC", idCaso);
    }

    public List<Map<String, Object>> presentacionesDelCaso(int idCaso) throws SQLException {
        return q("SELECT p.id_presentacion, d.titulo, en.nombre AS entidad, FORMAT(p.fecha_hora, 'dd/MM/yyyy HH:mm') AS fecha, p.modalidad, p.nro_cargo "
                + "FROM dbo.presentacion p JOIN dbo.documento_legal d ON d.id_documento = p.id_documento "
                + "JOIN dbo.entidad en ON en.id_entidad = p.id_entidad WHERE d.id_caso = ? ORDER BY p.id_presentacion DESC", idCaso);
    }

    /** Plazos del caso que aún no se cumplen (PENDIENTE o VENCIDO). Mientras existan, el caso no se puede cerrar. */
    public List<Map<String, Object>> plazosPendientes(int idCaso) throws SQLException {
        return q("SELECT id_plazo, descripcion, FORMAT(fecha_vencimiento, 'dd/MM/yyyy') AS vence, estado "
                + "FROM dbo.vw_plazo_estado WHERE id_caso = ? AND estado <> 'CUMPLIDO' ORDER BY fecha_vencimiento", idCaso);
    }

    /**
     * Marca un plazo como CUMPLIDO: UPDATE plazo SET fecha_cumplimiento (y, si se indica, la presentación con la que se cumplió;
     * el trigger trg_plazo_mismo_caso exige que sea del mismo caso).
     */
    public Map<String, Object> cumplirPlazo(int idPlazo, Integer idPresentacion, String usuario) throws SQLException {
        int idCaso;
        String descripcion;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                try (PreparedStatement ps = cn.prepareStatement("SELECT id_caso, descripcion, fecha_cumplimiento FROM dbo.plazo WITH (UPDLOCK) WHERE id_plazo = ?")) {
                    ps.setInt(1, idPlazo);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El plazo no existe.");
                        if (rs.getDate(3) != null) throw new ReglaNegocioException("Ese plazo ya está cumplido.");
                        idCaso = rs.getInt(1); descripcion = rs.getString(2);
                    }
                }
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.plazo SET fecha_cumplimiento = CAST(GETDATE() AS DATE), id_presentacion_cumplimiento = ? WHERE id_plazo = ?")) {
                    Datos.setEnteroONull(ps, 1, idPresentacion); ps.setInt(2, idPlazo); ps.executeUpdate();
                }
                cn.commit();
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;
            }
        }
        anotar(idCaso, "Plazo cumplido: " + descripcion, usuario, new Document("id_plazo", idPlazo), null, null, null);
        return Map.of("idPlazo", idPlazo, "idCaso", idCaso, "mensaje", "Plazo «" + descripcion + "» marcado como CUMPLIDO.");
    }

    public List<Map<String, Object>> resolucionesDelCaso(int idCaso) throws SQLException {
        return q("SELECT r.id_resolucion, r.nro_resolucion, r.tipo_resolucion, FORMAT(r.fecha_notificacion, 'dd/MM/yyyy') AS notificada, "
                + "r.medio_notificacion, en.nombre AS entidad, r.archivo_mongo_id, "
                + "(SELECT TOP 1 p.descripcion + ' · vence ' + FORMAT(p.fecha_vencimiento, 'dd/MM/yyyy') + ' · ' + p.estado "
                + "   FROM dbo.vw_plazo_estado p WHERE p.id_resolucion = r.id_resolucion) AS plazo "
                + "FROM dbo.resolucion r JOIN dbo.entidad en ON en.id_entidad = r.id_entidad WHERE r.id_caso = ? ORDER BY r.id_resolucion DESC", idCaso);
    }

    /** Documento de MongoDB «archivos» (texto del escrito o de la resolución). */
    public Map<String, Object> archivoMongo(String id) {
        if (!mongo.disponible()) throw new ReglaNegocioException("MongoDB no está encendido en esta computadora.");
        Document doc = mongo.buscar("archivos", id);
        if (doc == null) throw new ReglaNegocioException("No existe el documento " + id + " en MongoDB.");
        return Map.of("coleccion", "archivos", "json", doc.toJson());
    }

    /** Fecha de vencimiento: CALENDARIO = inicio + días; HABIL = días sin sábados, domingos ni FERIADO. */
    public LocalDate calcularVencimiento(LocalDate inicio, int dias, String tipo) throws SQLException {
        if (dias <= 0) throw new ReglaNegocioException("El plazo debe ser de al menos un día.");
        if ("CALENDARIO".equals(tipo)) return inicio.plusDays(dias);
        Set<LocalDate> feriados = new HashSet<>();
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement("SELECT fecha FROM dbo.feriado WHERE fecha > ?")) {
            ps.setDate(1, Date.valueOf(inicio));
            try (ResultSet rs = ps.executeQuery()) { while (rs.next()) feriados.add(rs.getDate(1).toLocalDate()); }
        }
        LocalDate f = inicio;
        int contados = 0;
        while (contados < dias) {
            f = f.plusDays(1);
            if (f.getDayOfWeek() != DayOfWeek.SATURDAY && f.getDayOfWeek() != DayOfWeek.SUNDAY && !feriados.contains(f)) contados++;
        }
        return f;
    }

    // ------------------------------------------------------------------ W11 · NUEVO ESCRITO
    public Map<String, Object> registrarEscrito(Map<String, Object> d, int idEmpleado, String usuario) throws SQLException {
        int idCaso = Datos.entero(d, "idCaso");
        String tipo = Datos.texto(d, "tipoDocumento");
        String titulo = Datos.texto(d, "titulo");
        String contenido = Datos.texto(d, "contenido");
        boolean ia = Datos.booleano(d, "elaboradoConIa");
        boolean firma = Datos.booleano(d, "requiereFirmaCliente");
        List<Map<String, Object>> citas = Datos.lista(d, "jurisprudencia");
        if (!TIPOS_DOC.contains(tipo)) throw new ReglaNegocioException("Tipo de escrito no válido.");

        String idMongo = null;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                casoActivo(cn, idCaso);
                // 1) DOCUMENTO_LEGAL (estado BORRADOR y versión 1 por DEFAULT)
                int idDoc;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.documento_legal (id_caso, id_redactor, tipo_documento, titulo, elaborado_con_ia, requiere_firma_cliente) "
                      + "VALUES (?, ?, ?, ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idCaso); ps.setInt(2, idEmpleado); ps.setString(3, tipo); ps.setString(4, titulo);
                    ps.setBoolean(5, ia); ps.setBoolean(6, firma);
                    ps.executeUpdate();
                    idDoc = Datos.idGenerado(ps);
                }
                // 2) DOCUMENTO_JURISPRUDENCIA (relación N:M escrito – jurisprudencia citada)
                List<String> referencias = new ArrayList<>();
                if (!citas.isEmpty()) {
                    try (PreparedStatement ps = cn.prepareStatement(
                            "INSERT INTO dbo.documento_jurisprudencia (id_documento, id_jurisprudencia, nota) VALUES (?, ?, ?)")) {
                        for (Map<String, Object> c : citas) {
                            ps.setInt(1, idDoc); ps.setInt(2, Datos.entero(c, "idJurisprudencia"));
                            Datos.setTextoONull(ps, 3, Datos.textoOpcional(c, "nota"));
                            ps.addBatch();
                            if (Datos.tiene(c, "referencia")) referencias.add(Datos.texto(c, "referencia"));
                        }
                        ps.executeBatch();
                    }
                }
                // 3) MongoDB «archivos»: el texto completo del escrito con su historial de versiones
                String aviso = null;
                if (mongo.disponible()) {
                    idMongo = mongo.guardar("archivos", new Document("tipo", "ESCRITO").append("id_caso", idCaso).append("id_sql", idDoc)
                            .append("titulo", titulo).append("version_actual", 1)
                            .append("versiones", List.of(new Document("v", 1).append("autor", usuario).append("fecha", new java.util.Date())
                                    .append("origen", ia ? "PLANTILLA_IA" : "MANUAL").append("contenido_texto", contenido)))
                            .append("jurisprudencia_citada", referencias)
                            .append("metadatos", new Document("tipo_documento", tipo).append("requiere_firma_cliente", firma)));
                    try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.documento_legal SET archivo_mongo_id = ? WHERE id_documento = ?")) {
                        ps.setString(1, idMongo); ps.setInt(2, idDoc); ps.executeUpdate();
                    }
                } else aviso = "MongoDB no está encendido: el escrito se grabó en SQL Server sin su texto (archivo_mongo_id = NULL).";

                cn.commit();                                           // COMMIT
                if (idMongo != null) anotar(idCaso, "Escrito registrado: " + titulo, usuario, new Document("id_documento", idDoc), idMongo, "ESCRITO", titulo);
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idDocumento", idDoc); r.put("citas", citas.size()); r.put("archivoMongoId", idMongo); r.put("aviso", aviso);
                r.put("mensaje", "Escrito N.° " + idDoc + " registrado como BORRADOR.");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                mongo.borrar("archivos", idMongo);                     // compensación
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W12 · PRESENTACIÓN
    public Map<String, Object> registrarPresentacion(Map<String, Object> d, int idEmpleado, String usuario) throws SQLException {
        int idDoc = Datos.entero(d, "idDocumento");
        int idEntidad = Datos.entero(d, "idEntidad");
        String modalidad = Datos.texto(d, "modalidad");
        String cargo = Datos.textoOpcional(d, "nroCargo");
        Integer idPlazo = Datos.enteroOpcional(d, "idPlazo");
        LocalDateTime cuando = Datos.tiene(d, "fechaHora") ? LocalDateTime.parse(Datos.texto(d, "fechaHora")) : LocalDateTime.now();
        if (!Set.of("FISICA", "ELECTRONICA").contains(modalidad)) throw new ReglaNegocioException("Modalidad no válida.");
        if (cuando.isAfter(LocalDateTime.now().plusMinutes(5))) throw new ReglaNegocioException("La presentación no puede ser futura.");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                int idCaso;
                String titulo;
                try (PreparedStatement ps = cn.prepareStatement("SELECT id_caso, estado, titulo FROM dbo.documento_legal WITH (UPDLOCK) WHERE id_documento = ?")) {
                    ps.setInt(1, idDoc);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El escrito no existe.");
                        if ("PRESENTADO".equals(rs.getString(2))) throw new ReglaNegocioException("Ese escrito ya fue presentado.");
                        idCaso = rs.getInt(1); titulo = rs.getString(3);
                    }
                }
                int idPres;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.presentacion (id_documento, id_entidad, id_empleado, fecha_hora, modalidad, nro_cargo) VALUES (?, ?, ?, ?, ?, ?)",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idDoc); ps.setInt(2, idEntidad); ps.setInt(3, idEmpleado); ps.setTimestamp(4, Timestamp.valueOf(cuando));
                    ps.setString(5, modalidad); Datos.setTextoONull(ps, 6, cargo);
                    ps.executeUpdate();
                    idPres = Datos.idGenerado(ps);
                }
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.documento_legal SET estado = 'PRESENTADO', fecha_aprobacion = COALESCE(fecha_aprobacion, SYSDATETIME()) WHERE id_documento = ?")) {
                    ps.setInt(1, idDoc); ps.executeUpdate();
                }
                // Si el escrito responde a un plazo, el plazo queda CUMPLIDO con esta presentación
                if (idPlazo != null) {
                    try (PreparedStatement ps = cn.prepareStatement(
                            "UPDATE dbo.plazo SET fecha_cumplimiento = ?, id_presentacion_cumplimiento = ? "
                          + "WHERE id_plazo = ? AND id_caso = ? AND fecha_cumplimiento IS NULL")) {
                        ps.setDate(1, java.sql.Date.valueOf(cuando.toLocalDate())); ps.setInt(2, idPres); ps.setInt(3, idPlazo); ps.setInt(4, idCaso);
                        if (ps.executeUpdate() == 0) throw new ReglaNegocioException("El plazo elegido no es de este caso o ya estaba cumplido.");
                    }
                }
                cn.commit();
                anotar(idCaso, "Escrito presentado: " + titulo, usuario, new Document("id_presentacion", idPres).append("nro_cargo", cargo), null, null, null);
                Map<String, Object> r = new java.util.LinkedHashMap<>();
                r.put("idPresentacion", idPres); r.put("idDocumento", idDoc); r.put("idPlazo", idPlazo);
                r.put("mensaje", "Presentación N.° " + idPres + " registrada; el escrito quedó PRESENTADO" + (idPlazo != null ? " y el plazo quedó CUMPLIDO." : "."));
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W13 · RESOLUCIÓN + PLAZO
    public Map<String, Object> registrarResolucion(Map<String, Object> d, String usuario) throws SQLException {
        int idCaso = Datos.entero(d, "idCaso");
        int idEntidad = Datos.entero(d, "idEntidad");
        Integer idPres = Datos.enteroOpcional(d, "idPresentacion");
        String nro = Datos.textoOpcional(d, "nroResolucion");
        String tipo = Datos.texto(d, "tipoResolucion");
        LocalDate notif = Datos.fecha(d, "fechaNotificacion");
        String medio = Datos.texto(d, "medioNotificacion");
        String sumilla = Datos.textoOpcional(d, "sumilla");
        String texto = Datos.textoOpcional(d, "texto");
        boolean conPlazo = Datos.tiene(d, "plazoDescripcion");
        if (!TIPOS_RES.contains(tipo)) throw new ReglaNegocioException("Tipo de resolución no válido.");
        if (!MEDIOS.contains(medio)) throw new ReglaNegocioException("Medio de notificación no válido.");
        if (notif.isAfter(LocalDate.now())) throw new ReglaNegocioException("La fecha de notificación no puede ser futura.");

        String idMongo = null;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                casoActivo(cn, idCaso);
                // 1) RESOLUCION (el trigger trg_resolucion_mismo_caso exige que la presentación sea del mismo caso)
                int idRes;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.resolucion (id_caso, id_entidad, id_presentacion, nro_resolucion, tipo_resolucion, fecha_notificacion, "
                      + "medio_notificacion, sumilla) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idCaso); ps.setInt(2, idEntidad); Datos.setEnteroONull(ps, 3, idPres); Datos.setTextoONull(ps, 4, nro);
                    ps.setString(5, tipo); ps.setDate(6, Date.valueOf(notif)); ps.setString(7, medio); Datos.setTextoONull(ps, 8, sumilla);
                    ps.executeUpdate();
                    idRes = Datos.idGenerado(ps);
                }
                // 2) PLAZO (opcional): vencimiento calculado en días hábiles o calendario
                Integer idPlazo = null;
                LocalDate vence = null;
                if (conPlazo) {
                    int dias = Datos.entero(d, "plazoDias");
                    String computo = Datos.texto(d, "plazoTipoComputo");
                    if (!Set.of("HABIL", "CALENDARIO").contains(computo)) throw new ReglaNegocioException("Tipo de cómputo no válido.");
                    vence = calcularVencimiento(notif, dias, computo);
                    try (PreparedStatement ps = cn.prepareStatement(
                            "INSERT INTO dbo.plazo (id_caso, id_resolucion, id_empleado_responsable, descripcion, fecha_inicio, dias_plazo, tipo_computo, fecha_vencimiento) "
                          + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                        ps.setInt(1, idCaso); ps.setInt(2, idRes); ps.setInt(3, Datos.entero(d, "plazoResponsable"));
                        ps.setString(4, Datos.texto(d, "plazoDescripcion")); ps.setDate(5, Date.valueOf(notif)); ps.setInt(6, dias);
                        ps.setString(7, computo); ps.setDate(8, Date.valueOf(vence));
                        ps.executeUpdate();
                        idPlazo = Datos.idGenerado(ps);
                    }
                }
                // 3) MongoDB «archivos»: texto/PDF de la resolución
                String aviso = null;
                if (texto != null) {
                    if (mongo.disponible()) {
                        idMongo = mongo.guardar("archivos", new Document("tipo", "RESOLUCION").append("id_caso", idCaso).append("id_sql", idRes)
                                .append("titulo", "Resolución " + (nro == null ? "s/n" : nro) + " · " + tipo).append("version_actual", 1)
                                .append("versiones", List.of(new Document("v", 1).append("autor", usuario).append("fecha", new java.util.Date())
                                        .append("origen", "SINOE".equals(medio) ? "SINOE" : "ESCANEO").append("contenido_texto", texto)))
                                .append("metadatos", new Document("medio", medio).append("sumilla", sumilla)));
                        try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.resolucion SET archivo_mongo_id = ? WHERE id_resolucion = ?")) {
                            ps.setString(1, idMongo); ps.setInt(2, idRes); ps.executeUpdate();
                        }
                    } else aviso = "MongoDB no está encendido: la resolución se grabó sin su texto (archivo_mongo_id = NULL).";
                }
                cn.commit();
                anotar(idCaso, "Resolución notificada: " + tipo + (vence != null ? " · plazo vence " + vence : ""), usuario,
                        new Document("id_resolucion", idRes), idMongo, "RESOLUCION", "Resolución " + (nro == null ? "s/n" : nro));
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idResolucion", idRes); r.put("idPlazo", idPlazo); r.put("vence", vence == null ? null : vence.toString());
                r.put("archivoMongoId", idMongo); r.put("aviso", aviso);
                r.put("mensaje", "Resolución N.° " + idRes + " registrada" + (vence != null ? "; el plazo vence el " + vence : "") + ".");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                mongo.borrar("archivos", idMongo);
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ utilidades
    private static void casoActivo(Connection cn, int idCaso) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement("SELECT estado FROM dbo.caso WITH (UPDLOCK) WHERE id_caso = ?")) {
            ps.setInt(1, idCaso);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new ReglaNegocioException("El caso no existe.");
                if (!"ACTIVO".equals(rs.getString(1))) throw new ReglaNegocioException("El caso no está ACTIVO.");
            }
        }
    }

    /** Bitácora e índice del expediente digital (después del COMMIT; si MongoDB falla no se deshace lo de SQL). */
    private void anotar(int idCaso, String evento, String usuario, Document detalle, String archivoId, String tipo, String titulo) {
        try {
            if (!mongo.disponible()) return;
            mongo.anotarEnExpediente(idCaso, evento, usuario, detalle);
            if (archivoId != null) mongo.indexarArchivo(idCaso, archivoId, tipo, titulo);
        } catch (RuntimeException ignorada) { /* la bitácora es complementaria */ }
    }

    private List<Map<String, Object>> q(String sql, Object... p) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            return Datos.filas(ps);
        }
    }
}
