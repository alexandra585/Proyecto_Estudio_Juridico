package pe.edu.utp.magallanes.web.t4;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Types;
import java.time.LocalDate;
import java.util.ArrayList;
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
 * MÓDULO T4 · Cobranza y cierre (proceso P3).
 *   W18 Emitir comprobante .. COMPROBANTE + DETALLE_COMPROBANTE (n cuotas); el trigger trg_comprobante_correlativo
 *                             valida el número y avanza SERIE_COMPROBANTE. El total y el IGV NO se guardan (vistas).
 *   W19 Registrar pago ...... PAGO + UPDATE CUOTA (PAGADA / PAGADA_PARCIAL) + NOTIFICACION (CONSTANCIA_PAGO)
 *   W21 Cierre del caso ..... UPDATE CASO_ETAPA + INSERT CASO_ETAPA (Cerrado) + UPDATE CASO (CERRADO) + ENCUESTA
 *                             + NOTIFICACION (ENVIO_ENCUESTA) + MongoDB «encuestas» (ENVIADA)
 *   W22 Responder encuesta .. UPDATE ENCUESTA (calificación y NPS) + MongoDB «encuestas» (respuestas completas)
 */
@Repository
public class T4Repositorio {
    private static final Set<String> MEDIOS = Set.of("EFECTIVO", "YAPE", "PLIN", "TRANSFERENCIA", "DEPOSITO", "TARJETA");

    private final DataSource ds;
    private final MongoDocumentos mongo;

    public T4Repositorio(DataSource ds, MongoDocumentos mongo) { this.ds = ds; this.mongo = mongo; }

    // ------------------------------------------------------------------ lecturas
    public List<Map<String, Object>> comprobantes() throws SQLException {
        return q("SELECT TOP 15 s.id_comprobante, s.serie, s.numero, FORMAT(c.fecha_emision, 'dd/MM/yyyy') AS emision, "
                + "COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, s.total, s.pagado, s.saldo, s.estado_pago "
                + "FROM dbo.vw_comprobante_saldo s JOIN dbo.comprobante c ON c.id_comprobante = s.id_comprobante "
                + "JOIN dbo.persona p ON p.id_persona = c.id_persona ORDER BY s.id_comprobante DESC");
    }

    /** Clientes con cuotas que todavía no se han facturado (no están en un comprobante vigente). */
    public List<Map<String, Object>> clientesConCuotas() throws SQLException {
        return q("SELECT k.id_cliente, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                + "COALESCE(p.tipo_documento + ' ' + p.nro_documento, 'SIN DOCUMENTO') AS documento, p.tipo_persona, COUNT(*) AS cuotas "
                + "FROM dbo.cuota q JOIN dbo.contrato k ON k.id_contrato = q.id_contrato JOIN dbo.persona p ON p.id_persona = k.id_cliente "
                + "WHERE q.estado = 'PENDIENTE' AND k.fecha_firma IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.detalle_comprobante dc "
                + "  JOIN dbo.comprobante c ON c.id_comprobante = dc.id_comprobante WHERE dc.id_cuota = q.id_cuota AND c.estado <> 'ANULADO') "
                + "GROUP BY k.id_cliente, p.razon_social, p.nombres, p.apellidos, p.tipo_documento, p.nro_documento, p.tipo_persona ORDER BY cliente");
    }

    public List<Map<String, Object>> cuotasPorFacturar(int idCliente) throws SQLException {
        return q("SELECT q.id_cuota, k.nro_contrato, q.nro_cuota, q.concepto, q.monto, FORMAT(q.fecha_vencimiento, 'dd/MM/yyyy') AS vence, v.estado "
                + "FROM dbo.cuota q JOIN dbo.contrato k ON k.id_contrato = q.id_contrato JOIN dbo.vw_cuota_estado v ON v.id_cuota = q.id_cuota "
                + "WHERE k.id_cliente = ? AND q.estado = 'PENDIENTE' AND k.fecha_firma IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.detalle_comprobante dc "
                + "  JOIN dbo.comprobante c ON c.id_comprobante = dc.id_comprobante WHERE dc.id_cuota = q.id_cuota AND c.estado <> 'ANULADO') "
                + "ORDER BY q.fecha_vencimiento", idCliente);
    }

    public List<Map<String, Object>> series() throws SQLException {
        return q("SELECT serie, tipo_comprobante, ultimo_numero + 1 AS siguiente FROM dbo.serie_comprobante ORDER BY serie");
    }

    public List<Map<String, Object>> comprobantesConSaldo() throws SQLException {
        return q("SELECT s.id_comprobante, s.serie, s.numero, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                + "s.total, s.pagado, s.saldo, s.estado_pago FROM dbo.vw_comprobante_saldo s JOIN dbo.comprobante c ON c.id_comprobante = s.id_comprobante "
                + "JOIN dbo.persona p ON p.id_persona = c.id_persona WHERE s.estado_pago IN ('PENDIENTE', 'PAGADO_PARCIAL') ORDER BY s.id_comprobante DESC");
    }

    public List<Map<String, Object>> pagosDe(int idComprobante) throws SQLException {
        return q("SELECT id_pago, FORMAT(fecha_pago, 'dd/MM/yyyy HH:mm') AS fecha, monto, medio_pago, nro_operacion FROM dbo.pago WHERE id_comprobante = ? ORDER BY id_pago", idComprobante);
    }

    public List<Map<String, Object>> casosParaCerrar() throws SQLException {
        return q("SELECT c.id_caso, c.codigo_interno, m.nombre AS materia, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                + "(SELECT COUNT(*) FROM dbo.vw_plazo_estado x WHERE x.id_caso = c.id_caso AND x.estado <> 'CUMPLIDO') AS plazos_pendientes, "
                + "(SELECT COALESCE(SUM(s.saldo), 0) FROM dbo.vw_comprobante_saldo s JOIN dbo.comprobante cp ON cp.id_comprobante = s.id_comprobante "
                + "   WHERE cp.id_persona = k.id_cliente AND s.estado_pago IN ('PENDIENTE','PAGADO_PARCIAL')) AS saldo_cliente "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia JOIN dbo.contrato k ON k.id_contrato = c.id_contrato "
                + "JOIN dbo.persona p ON p.id_persona = k.id_cliente WHERE c.estado = 'ACTIVO' ORDER BY c.id_caso DESC");
    }

    public List<Map<String, Object>> encuestasPendientes() throws SQLException {
        return q("SELECT e.id_encuesta, c.id_caso, c.codigo_interno, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                + "FORMAT(e.fecha_envio, 'dd/MM/yyyy HH:mm') AS enviada FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona p ON p.id_persona = k.id_cliente "
                + "WHERE e.fecha_respuesta IS NULL ORDER BY e.id_encuesta DESC");
    }

    public List<Map<String, Object>> encuestasRespondidas() throws SQLException {
        return q("SELECT TOP 10 e.id_encuesta, c.codigo_interno, e.calificacion, e.nps, CAST(e.comentario AS NVARCHAR(200)) AS comentario, "
                + "FORMAT(e.fecha_respuesta, 'dd/MM/yyyy HH:mm') AS respondida FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso "
                + "WHERE e.fecha_respuesta IS NOT NULL ORDER BY e.fecha_respuesta DESC");
    }

    /** Formulario vigente de la encuesta: se lee de MongoDB «formularios_encuesta» (las preguntas cambian sin tocar tablas). */
    public Map<String, Object> formularioEncuesta() {
        Document f = null;
        if (mongo.disponible()) f = mongo.buscarPor("formularios_encuesta", "activo", true);
        if (f != null) return Map.of("origen", "MongoDB · formularios_encuesta", "version", f.get("version"), "preguntas", f.get("preguntas"));
        return Map.of("origen", "formulario por defecto (MongoDB sin formulario activo)", "version", 1, "preguntas", List.of(
                Map.of("clave", "calificacion", "texto", "Califique la atención recibida", "tipo", "ESTRELLAS_1_5"),
                Map.of("clave", "nps", "texto", "¿Qué tan probable es que nos recomiende?", "tipo", "NPS_0_10"),
                Map.of("clave", "explico_etapas", "texto", "¿El abogado le explicó cada etapa?", "tipo", "SI_NO")));
    }

    public Map<String, Object> encuestaMongo(int idEncuesta) {
        if (!mongo.disponible()) throw new ReglaNegocioException("MongoDB no está encendido en esta computadora.");
        Document doc = mongo.buscarPor("encuestas", "id_encuesta", idEncuesta);
        if (doc == null) throw new ReglaNegocioException("La encuesta " + idEncuesta + " no está en MongoDB.");
        return Map.of("coleccion", "encuestas", "json", doc.toJson());
    }

    // ------------------------------------------------------------------ W18 · EMITIR COMPROBANTE
    public Map<String, Object> emitirComprobante(Map<String, Object> d, int idEmisor) throws SQLException {
        int idCliente = Datos.entero(d, "idPersona");
        String serie = Datos.texto(d, "serie");
        LocalDate vence = Datos.fecha(d, "fechaVencimiento");
        List<Object> cuotas = Datos.valores(d, "cuotas");
        if (cuotas.isEmpty()) throw new ReglaNegocioException("Elija al menos una cuota para facturar.");
        if (vence.isBefore(LocalDate.now())) throw new ReglaNegocioException("El comprobante no puede vencer antes de emitirse.");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // 0) Siguiente número de la serie (UPDLOCK: dos cajeros no toman el mismo número)
                String tipo;
                int numero;
                try (PreparedStatement ps = cn.prepareStatement("SELECT tipo_comprobante, ultimo_numero + 1 FROM dbo.serie_comprobante WITH (UPDLOCK) WHERE serie = ?")) {
                    ps.setString(1, serie);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("La serie no existe.");
                        tipo = rs.getString(1); numero = rs.getInt(2);
                    }
                }
                BigDecimal igv = "RECIBO_HONORARIOS".equals(tipo) ? BigDecimal.ZERO : new BigDecimal("0.18");

                // 1) Líneas: las cuotas elegidas (deben ser del cliente y no estar facturadas)
                List<Object[]> lineas = new ArrayList<>();
                BigDecimal subtotal = BigDecimal.ZERO;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT q.id_cuota, q.monto, q.concepto + ' ' + CAST(q.nro_cuota AS VARCHAR(3)) + ' · contrato ' + k.nro_contrato, k.id_cliente, "
                      + "(SELECT COUNT(*) FROM dbo.detalle_comprobante dc JOIN dbo.comprobante c ON c.id_comprobante = dc.id_comprobante "
                      + " WHERE dc.id_cuota = q.id_cuota AND c.estado <> 'ANULADO') "
                      + "FROM dbo.cuota q WITH (UPDLOCK) JOIN dbo.contrato k ON k.id_contrato = q.id_contrato WHERE q.id_cuota = ?")) {
                    for (Object o : cuotas) {
                        ps.setInt(1, Integer.parseInt(o.toString()));
                        try (ResultSet rs = ps.executeQuery()) {
                            if (!rs.next()) throw new ReglaNegocioException("La cuota " + o + " no existe.");
                            if (rs.getInt(5) > 0) throw new ReglaNegocioException("La cuota " + o + " ya está facturada.");
                            if (rs.getInt(4) != idCliente) throw new ReglaNegocioException("La cuota " + o + " es de otro cliente.");
                            lineas.add(new Object[] { rs.getInt(1), rs.getBigDecimal(2), rs.getString(3) });
                            subtotal = subtotal.add(rs.getBigDecimal(2));
                        }
                    }
                }
                // Detracción 12 % en facturas de servicios mayores a S/ 700 (con IGV)
                BigDecimal total = subtotal.multiply(BigDecimal.ONE.add(igv));
                BigDecimal detraccion = "FACTURA".equals(tipo) && total.compareTo(new BigDecimal("700")) > 0 ? new BigDecimal("0.12") : BigDecimal.ZERO;

                // 2) COMPROBANTE (estado EMITIDO por DEFAULT). Triggers: correlativo (50008) y receptor con documento (50012)
                int idComp;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.comprobante (id_persona, id_emisor, serie, numero, fecha_emision, fecha_vencimiento, tasa_igv, porcentaje_detraccion) "
                      + "VALUES (?, ?, ?, ?, CAST(GETDATE() AS DATE), ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idCliente); ps.setInt(2, idEmisor); ps.setString(3, serie); ps.setInt(4, numero);
                    ps.setDate(5, Date.valueOf(vence)); ps.setBigDecimal(6, igv); ps.setBigDecimal(7, detraccion);
                    ps.executeUpdate();
                    idComp = Datos.idGenerado(ps);
                }
                // 3) DETALLE_COMPROBANTE (una línea por cuota; trigger trg_detalle_comprobante_coherencia)
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.detalle_comprobante (id_comprobante, nro_linea, id_cuota, id_gasto, descripcion, cantidad, valor_unitario) "
                      + "VALUES (?, ?, ?, NULL, ?, 1, ?)")) {
                    int n = 1;
                    for (Object[] l : lineas) {
                        ps.setInt(1, idComp); ps.setInt(2, n++); ps.setInt(3, (Integer) l[0]); ps.setString(4, (String) l[2]); ps.setBigDecimal(5, (BigDecimal) l[1]);
                        ps.addBatch();
                    }
                    ps.executeBatch();
                }
                cn.commit();                                           // COMMIT

                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idComprobante", idComp);
                r.put("comprobante", serie + "-" + String.format("%06d", numero));
                r.put("lineas", lineas.size());
                r.put("totales", q("SELECT subtotal, igv, total, detraccion FROM dbo.vw_comprobante_total WHERE id_comprobante = ?", idComp));
                r.put("mensaje", tipo + " " + serie + "-" + String.format("%06d", numero) + " emitida con " + lineas.size() + " línea(s).");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* el trigger ya pudo hacer ROLLBACK */ }
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W19 · REGISTRAR PAGO
    public Map<String, Object> registrarPago(Map<String, Object> d, int idEmpleado) throws SQLException {
        int idComp = Datos.entero(d, "idComprobante");
        BigDecimal monto = Datos.decimal(d, "monto");
        String medio = Datos.texto(d, "medioPago");
        String operacion = Datos.textoOpcional(d, "nroOperacion");
        if (!MEDIOS.contains(medio)) throw new ReglaNegocioException("Medio de pago no válido.");
        if (monto.signum() <= 0) throw new ReglaNegocioException("El pago debe ser mayor a cero.");
        if (!"EFECTIVO".equals(medio) && operacion == null) throw new ReglaNegocioException("Escriba el N.° de operación (no es efectivo).");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                // 0) Bloquear el comprobante y leer su saldo (vista calculada: no se guarda)
                int idPersona;
                try (PreparedStatement ps = cn.prepareStatement("SELECT id_persona, estado FROM dbo.comprobante WITH (UPDLOCK) WHERE id_comprobante = ?")) {
                    ps.setInt(1, idComp);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El comprobante no existe.");
                        if ("ANULADO".equals(rs.getString(2))) throw new ReglaNegocioException("El comprobante está ANULADO.");
                        idPersona = rs.getInt(1);
                    }
                }
                BigDecimal saldo = saldo(cn, idComp);
                if (monto.compareTo(saldo) > 0) throw new ReglaNegocioException("El pago (S/ " + monto + ") supera el saldo pendiente (S/ " + saldo + ").");

                // 1) PAGO (fecha_pago por DEFAULT = ahora)
                int idPago;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.pago (id_comprobante, id_empleado, monto, medio_pago, nro_operacion) VALUES (?, ?, ?, ?, ?)", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idComp); ps.setInt(2, idEmpleado); ps.setBigDecimal(3, monto); ps.setString(4, medio); Datos.setTextoONull(ps, 5, operacion);
                    ps.executeUpdate();
                    idPago = Datos.idGenerado(ps);
                }
                // 2) CUOTA: las cuotas del comprobante pasan a PAGADA o PAGADA_PARCIAL
                BigDecimal nuevoSaldo = saldo.subtract(monto);
                String estadoCuota = nuevoSaldo.signum() == 0 ? "PAGADA" : "PAGADA_PARCIAL";
                int cuotas;
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.cuota SET estado = ? WHERE id_cuota IN (SELECT id_cuota FROM dbo.detalle_comprobante WHERE id_comprobante = ? AND id_cuota IS NOT NULL)")) {
                    ps.setString(1, estadoCuota); ps.setInt(2, idComp);
                    cuotas = ps.executeUpdate();
                }
                // 3) NOTIFICACION: constancia de pago al cliente (debe nacer de un caso o de una consulta)
                Integer idCaso = null, idConsulta = null;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT TOP 1 ca.id_caso, pr.id_consulta FROM dbo.detalle_comprobante dc JOIN dbo.cuota q ON q.id_cuota = dc.id_cuota "
                      + "JOIN dbo.contrato k ON k.id_contrato = q.id_contrato JOIN dbo.propuesta pr ON pr.id_propuesta = k.id_propuesta "
                      + "LEFT JOIN dbo.caso ca ON ca.id_contrato = k.id_contrato WHERE dc.id_comprobante = ?")) {
                    ps.setInt(1, idComp);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) { idCaso = (Integer) rs.getObject(1); idConsulta = (Integer) rs.getObject(2); }
                    }
                }
                if (idConsulta == null) {
                    try (PreparedStatement ps = cn.prepareStatement("SELECT id_consulta FROM dbo.comprobante WHERE id_comprobante = ?")) {
                        ps.setInt(1, idComp);
                        try (ResultSet rs = ps.executeQuery()) { if (rs.next()) idConsulta = (Integer) rs.getObject(1); }
                    }
                }
                Integer idNotif = null;
                if (idCaso != null || idConsulta != null) {
                    try (PreparedStatement ps = cn.prepareStatement(
                            "INSERT INTO dbo.notificacion (id_persona, id_empleado, id_consulta, id_caso, tipo_evento, canal, mensaje, fecha_programada) "
                          + "VALUES (?, NULL, ?, ?, 'CONSTANCIA_PAGO', 'WHATSAPP', ?, SYSDATETIME())", Statement.RETURN_GENERATED_KEYS)) {
                        ps.setInt(1, idPersona);
                        if (idCaso != null) { ps.setNull(2, Types.INTEGER); ps.setInt(3, idCaso); } else { ps.setInt(2, idConsulta); ps.setNull(3, Types.INTEGER); }
                        ps.setString(4, "Magallanes-Montero: recibimos su pago de S/ " + monto + " (" + medio + "). Saldo pendiente: S/ " + nuevoSaldo + ".");
                        ps.executeUpdate();
                        idNotif = Datos.idGenerado(ps);
                    }
                }
                cn.commit();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idPago", idPago); r.put("saldoAnterior", saldo); r.put("saldo", nuevoSaldo); r.put("cuotasActualizadas", cuotas);
                r.put("estadoCuotas", estadoCuota); r.put("idNotificacion", idNotif);
                r.put("mensaje", "Pago N.° " + idPago + " registrado. Saldo pendiente: S/ " + nuevoSaldo + ".");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W21 · CIERRE DEL CASO Y ENVÍO DE ENCUESTA
    public Map<String, Object> cerrarCaso(int idCaso, String usuario) throws SQLException {
        String idMongo = null;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                String codigo;
                int idCliente;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT c.estado, c.codigo_interno, k.id_cliente, (SELECT COUNT(*) FROM dbo.vw_plazo_estado x WHERE x.id_caso = c.id_caso AND x.estado <> 'CUMPLIDO') "
                      + "FROM dbo.caso c WITH (UPDLOCK) JOIN dbo.contrato k ON k.id_contrato = c.id_contrato WHERE c.id_caso = ?")) {
                    ps.setInt(1, idCaso);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El caso no existe.");
                        if (!"ACTIVO".equals(rs.getString(1))) throw new ReglaNegocioException("El caso no está ACTIVO.");
                        if (rs.getInt(4) > 0) throw new ReglaNegocioException("No se puede cerrar: el caso tiene " + rs.getInt(4) + " plazo(s) sin cumplir.");
                        codigo = rs.getString(2); idCliente = rs.getInt(3);
                    }
                }
                // 1) CASO_ETAPA: termina la etapa actual y se abre la etapa «Cerrado»
                try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.caso_etapa SET fecha_fin = CAST(GETDATE() AS DATE) WHERE id_caso = ? AND fecha_fin IS NULL")) {
                    ps.setInt(1, idCaso); ps.executeUpdate();
                }
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.caso_etapa (id_caso, id_etapa, fecha_inicio, fecha_fin) "
                      + "SELECT ?, id_etapa, CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE) FROM dbo.etapa_procesal WHERE nombre = N'Cerrado' "
                      + "AND NOT EXISTS (SELECT 1 FROM dbo.caso_etapa x JOIN dbo.etapa_procesal e ON e.id_etapa = x.id_etapa "
                      + "  WHERE x.id_caso = ? AND e.nombre = N'Cerrado' AND x.fecha_inicio = CAST(GETDATE() AS DATE))")) {
                    ps.setInt(1, idCaso); ps.setInt(2, idCaso); ps.executeUpdate();
                }
                // 2) CASO → CERRADO
                try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.caso SET estado = 'CERRADO', fecha_cierre = CAST(GETDATE() AS DATE) WHERE id_caso = ?")) {
                    ps.setInt(1, idCaso); ps.executeUpdate();
                }
                // 3) ENCUESTA (1:1 con el caso: UNIQUE id_caso)
                int idEnc;
                try (PreparedStatement ps = cn.prepareStatement("INSERT INTO dbo.encuesta (id_caso, fecha_envio) VALUES (?, SYSDATETIME())", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idCaso); ps.executeUpdate();
                    idEnc = Datos.idGenerado(ps);
                }
                // 4) NOTIFICACION al cliente con el enlace de la encuesta
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.notificacion (id_persona, id_caso, tipo_evento, canal, mensaje, fecha_programada) "
                      + "VALUES (?, ?, 'ENVIO_ENCUESTA', 'WHATSAPP', ?, SYSDATETIME())")) {
                    ps.setInt(1, idCliente); ps.setInt(2, idCaso);
                    ps.setString(3, "Su caso " + codigo + " ha concluido. ¿Nos ayuda con una encuesta de 1 minuto? Respóndala en su portal del cliente (encuesta N.° " + idEnc + ").");
                    ps.executeUpdate();
                }
                // 5) MongoDB «encuestas»: documento ENVIADA (las respuestas llegan en W22)
                String aviso = null;
                if (mongo.disponible()) {
                    Object version = 1;
                    Document f = mongo.buscarPor("formularios_encuesta", "activo", true);
                    if (f != null && f.get("version") != null) version = f.get("version");
                    idMongo = mongo.guardar("encuestas", new Document("id_encuesta", idEnc).append("id_caso", idCaso).append("codigo_caso", codigo)
                            .append("version_formulario", version).append("canal", "WHATSAPP").append("enviada", new java.util.Date()).append("estado", "ENVIADA"));
                } else aviso = "MongoDB no está encendido: la encuesta se registró solo en SQL Server.";
                cn.commit();
                try { if (mongo.disponible()) mongo.anotarEnExpediente(idCaso, "Caso cerrado y encuesta enviada", usuario, new Document("id_encuesta", idEnc)); }
                catch (RuntimeException ignorada) { /* complementario */ }
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idCaso", idCaso); r.put("idEncuesta", idEnc); r.put("encuestaMongoId", idMongo); r.put("aviso", aviso);
                r.put("mensaje", "Caso " + codigo + " CERRADO. Encuesta N.° " + idEnc + " enviada al cliente.");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                mongo.borrar("encuestas", idMongo);
                throw e;
            }
        }
    }

    // ------------------------------------------------------------------ W22 · RESPONDER ENCUESTA
    public Map<String, Object> responderEncuesta(int idEncuesta, Map<String, Object> d) throws SQLException {
        int calificacion = Datos.entero(d, "calificacion");
        int nps = Datos.entero(d, "nps");
        String comentario = Datos.textoOpcional(d, "comentario");
        Object extra = d.get("respuestas");
        boolean autoriza = Datos.tiene(d, "autorizaPublicar") && Datos.booleano(d, "autorizaPublicar");
        String firma = Datos.tiene(d, "firma") ? Datos.texto(d, "firma") : "INICIALES";
        if (!java.util.Set.of("NOMBRE", "INICIALES", "ANONIMO").contains(firma)) throw new ReglaNegocioException("Firma no válida.");
        if (calificacion < 1 || calificacion > 5) throw new ReglaNegocioException("La calificación va de 1 a 5 estrellas.");
        if (nps < 0 || nps > 10) throw new ReglaNegocioException("El NPS va de 0 a 10.");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                int idCaso;
                String codigo;
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.encuesta SET fecha_respuesta = SYSDATETIME(), calificacion = ?, nps = ?, comentario = ? "
                      + "OUTPUT inserted.id_caso WHERE id_encuesta = ? AND fecha_respuesta IS NULL")) {
                    ps.setInt(1, calificacion); ps.setInt(2, nps); Datos.setTextoONull(ps, 3, comentario); ps.setInt(4, idEncuesta);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("La encuesta no existe o ya fue respondida.");
                        idCaso = rs.getInt(1);
                    }
                }
                String nombres, apellidos, razon, materia;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT c.codigo_interno, p.nombres, p.apellidos, p.razon_social, m.nombre FROM dbo.caso c "
                      + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona p ON p.id_persona = k.id_cliente "
                      + "JOIN dbo.materia m ON m.id_materia = c.id_materia WHERE c.id_caso = ?")) {
                    ps.setInt(1, idCaso);
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next(); codigo = rs.getString(1); nombres = rs.getString(2); apellidos = rs.getString(3); razon = rs.getString(4); materia = rs.getString(5);
                    }
                }
                // Permiso para publicar el comentario en la página web: se guarda SOLO en MongoDB (campo nuevo, sin ALTER TABLE)
                Document publicacion = new Document("autoriza", autoriza && comentario != null).append("firma", firma)
                        .append("nombre_publico", nombrePublico(firma, nombres, apellidos, razon)).append("materia", materia);
                // MongoDB «encuestas»: TODAS las respuestas (en SQL solo quedan calificación y NPS para el dashboard)
                String aviso = null;
                if (mongo.disponible()) {
                    Document resp = new Document("calificacion", calificacion).append("nps", nps);
                    if (extra instanceof Map<?, ?> m) m.forEach((k, v) -> resp.append(String.valueOf(k), v));
                    Document actual = mongo.buscarPor("encuestas", "id_encuesta", idEncuesta);
                    Map<String, Object> campos = new LinkedHashMap<>();
                    campos.put("respuestas", resp); campos.put("respondida", new java.util.Date()); campos.put("estado", "RESPONDIDA");
                    if (comentario != null) campos.put("comentario", comentario);
                    campos.put("publicacion", publicacion);
                    if (actual != null) mongo.actualizar("encuestas", actual.getObjectId("_id").toHexString(), campos);
                    else {
                        Document nuevo = new Document("id_encuesta", idEncuesta).append("id_caso", idCaso).append("codigo_caso", codigo)
                                .append("version_formulario", 1).append("canal", "PORTAL");
                        campos.forEach(nuevo::append);
                        mongo.guardar("encuestas", nuevo);
                    }
                } else aviso = "MongoDB no está encendido: solo se guardaron la calificación y el NPS en SQL Server.";
                cn.commit();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idEncuesta", idEncuesta); r.put("aviso", aviso); r.put("publicable", autoriza && comentario != null && aviso == null);
                r.put("nombrePublico", publicacion.getString("nombre_publico"));
                r.put("mensaje", "Encuesta N.° " + idEncuesta + " respondida: " + calificacion + " estrella(s), NPS " + nps + ".");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;
            }
        }
    }

    /** Cómo firma el cliente su comentario en la web: «Carmen V.» · «C. V.» · «Cliente». */
    static String nombrePublico(String firma, String nombres, String apellidos, String razon) {
        if ("ANONIMO".equals(firma)) return "Cliente del estudio";
        if (razon != null && !razon.isBlank()) return "NOMBRE".equals(firma) ? razon : inicial(razon) + ".";
        String n = nombres == null ? "" : nombres.trim().split("\\s+")[0];
        String a = apellidos == null || apellidos.isBlank() ? "" : inicial(apellidos) + ".";
        return "NOMBRE".equals(firma) ? (n + " " + a).trim() : (inicial(n) + ". " + a).trim();
    }

    private static String inicial(String t) { return t == null || t.isBlank() ? "" : t.trim().substring(0, 1).toUpperCase(); }

    // ------------------------------------------------------------------ W22 · RESULTADOS DE LAS ENCUESTAS
    /** Promedio de estrellas, NPS (promotores − detractores) y últimas respuestas con el nombre del cliente (uso interno). */
    public Map<String, Object> resumenEncuestas() throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        List<Map<String, Object>> t = q("SELECT COUNT(*) AS respondidas, CAST(AVG(CAST(calificacion AS DECIMAL(4,2))) AS DECIMAL(3,1)) AS promedio, "
                + "SUM(CASE WHEN nps >= 9 THEN 1 ELSE 0 END) AS promotores, SUM(CASE WHEN nps BETWEEN 7 AND 8 THEN 1 ELSE 0 END) AS pasivos, "
                + "SUM(CASE WHEN nps <= 6 THEN 1 ELSE 0 END) AS detractores, "
                + "(SELECT COUNT(*) FROM dbo.encuesta WHERE fecha_respuesta IS NULL) AS pendientes "
                + "FROM dbo.encuesta WHERE fecha_respuesta IS NOT NULL");
        r.put("totales", t.isEmpty() ? Map.of() : t.get(0));
        r.put("estrellas", q("SELECT calificacion AS estrellas, COUNT(*) AS cantidad FROM dbo.encuesta WHERE fecha_respuesta IS NOT NULL GROUP BY calificacion ORDER BY calificacion DESC"));
        List<Map<String, Object>> filas = q("SELECT TOP 12 e.id_encuesta, c.codigo_interno, m.nombre AS materia, "
                + "COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, e.calificacion, e.nps, e.comentario, "
                + "FORMAT(e.fecha_respuesta, 'dd/MM/yyyy') AS fecha FROM dbo.encuesta e JOIN dbo.caso c ON c.id_caso = e.id_caso "
                + "JOIN dbo.contrato k ON k.id_contrato = c.id_contrato JOIN dbo.persona p ON p.id_persona = k.id_cliente "
                + "JOIN dbo.materia m ON m.id_materia = c.id_materia WHERE e.fecha_respuesta IS NOT NULL ORDER BY e.fecha_respuesta DESC");
        // Permiso de publicación (solo existe en MongoDB)
        boolean hayMongo = mongo.disponible();
        for (Map<String, Object> f : filas) {
            Object pub = null;
            if (hayMongo) {
                Document doc = mongo.buscarPor("encuestas", "id_encuesta", f.get("id_encuesta"));
                if (doc != null && doc.get("publicacion") instanceof Document pd) pub = pd.get("autoriza");
            }
            f.put("publicable", Boolean.TRUE.equals(pub));
        }
        r.put("respuestas", filas);
        r.put("mongo", hayMongo);
        return r;
    }

    // ------------------------------------------------------------------ utilidades
    private static BigDecimal saldo(Connection cn, int idComp) throws SQLException {
        try (PreparedStatement ps = cn.prepareStatement("SELECT saldo FROM dbo.vw_comprobante_saldo WHERE id_comprobante = ?")) {
            ps.setInt(1, idComp);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) throw new ReglaNegocioException("El comprobante no tiene líneas.");
                return rs.getBigDecimal(1).setScale(2, RoundingMode.HALF_UP);
            }
        }
    }

    private List<Map<String, Object>> q(String sql, Object... p) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
            return Datos.filas(ps);
        }
    }
}
