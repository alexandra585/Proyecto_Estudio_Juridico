package pe.edu.utp.magallanes.web.t2;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.time.Year;
import java.time.format.DateTimeParseException;
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
 * MÓDULO T2 · Contratación.
 *
 * YA PROGRAMADO:
 *   · Aceptar propuesta ............ UPDATE PROPUESTA (estado = ACEPTADA, fecha_respuesta)
 *   · W08 Contrato y cuotas ........ TRANSACCIÓN: INSERT CONTRATO → INSERT CUOTA (n) → UPDATE CONSULTA (CONTRATADA)
 *
 *   · W07 Propuesta ................ TRANSACCIÓN: UPDATE PROPUESTA anterior → INSERT PROPUESTA → UPDATE CONSULTA (PROPUESTA)
 *
 *   · W09 Apertura del expediente .. TRANSACCIÓN: INSERT CASO → INSERT CASO_PARTE (n) → INSERT CASO_ETAPA → MongoDB «expedientes»
 * Patrón: cn.setAutoCommit(false) → INSERTs/UPDATEs → cn.commit();  si algo falla → cn.rollback().
 */
@Repository
public class T2Repositorio {
    private static final Set<String> TIPOS_ENCARGO = Set.of("PATROCINIO", "REPRESENTACION", "TRAMITE", "PRO_BONO");
    private static final Set<String> MODALIDADES = Set.of("UNICO", "CUOTAS", "IGUALA_MENSUAL");
    private static final Set<String> CONCEPTOS = Set.of("ADELANTO", "CUOTA", "IGUALA", "SALDO");

    private final DataSource ds;
    private final MongoDocumentos mongo;
    private final org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder bcrypt;

    public T2Repositorio(DataSource ds, MongoDocumentos mongo, org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder bcrypt) {
        this.ds = ds; this.mongo = mongo; this.bcrypt = bcrypt;
    }

    // =====================================================================================
    // Lecturas
    // =====================================================================================

    /** W07 · consultas que ya tuvieron cita (o que negocian otra versión de la propuesta). */
    public List<Map<String, Object>> consultasParaPropuesta() throws SQLException {
        return consulta("SELECT c.id_consulta, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS cliente, "
                + "COALESCE(p.tipo_documento + ' ' + p.nro_documento, 'SIN DOCUMENTO') AS documento, "
                + "c.id_materia, m.nombre AS materia, c.canal, c.estado, CAST(c.resumen AS NVARCHAR(300)) AS resumen, "
                + "(SELECT MAX(pr.version) FROM dbo.propuesta pr WHERE pr.id_consulta = c.id_consulta) AS ultima_version, "
                + "(SELECT TOP 1 FORMAT(ci.fecha_hora, 'dd/MM/yyyy HH:mm') FROM dbo.cita ci WHERE ci.id_consulta = c.id_consulta ORDER BY ci.fecha_hora DESC) AS cita, "
                + "(SELECT TOP 1 ci.id_abogado FROM dbo.cita ci WHERE ci.id_consulta = c.id_consulta ORDER BY ci.fecha_hora DESC) AS id_abogado_cita "
                + "FROM dbo.consulta c JOIN dbo.persona p ON p.id_persona = c.id_persona JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "WHERE c.estado IN ('AGENDADA', 'ATENDIDA', 'PROPUESTA') "
                + "AND NOT EXISTS (SELECT 1 FROM dbo.propuesta x WHERE x.id_consulta = c.id_consulta AND x.estado = 'ACEPTADA') "
                + "ORDER BY c.id_consulta DESC");
    }

    /** Últimas propuestas registradas (para ver lo grabado en W07). */
    public List<Map<String, Object>> propuestasRecientes() throws SQLException {
        return consulta("SELECT TOP 10 p.id_propuesta, p.id_consulta, p.version, COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, "
                + "e.nombres + ' ' + e.apellidos AS abogado, p.monto_honorarios, p.porcentaje_cuota_litis, p.nro_cuotas, "
                + "FORMAT(p.fecha_envio, 'dd/MM/yyyy') AS fecha_envio, p.estado, c.estado AS estado_consulta "
                + "FROM dbo.propuesta p JOIN dbo.consulta c ON c.id_consulta = p.id_consulta "
                + "JOIN dbo.persona pe ON pe.id_persona = c.id_persona JOIN dbo.empleado e ON e.id_empleado = p.id_abogado "
                + "ORDER BY p.id_propuesta DESC");
    }

    private static final String SELECT_PROPUESTA =
            "SELECT p.id_propuesta, p.version, p.id_consulta, c.id_persona AS id_cliente, "
          + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, "
          + "COALESCE(pe.tipo_documento + ' ' + pe.nro_documento, 'SIN DOCUMENTO') AS documento, m.nombre AS materia, "
          + "e.nombres + ' ' + e.apellidos AS abogado, p.monto_honorarios, p.porcentaje_cuota_litis, p.nro_cuotas, "
          + "FORMAT(p.fecha_envio, 'dd/MM/yyyy') AS fecha_envio, FORMAT(p.fecha_respuesta, 'dd/MM/yyyy') AS fecha_respuesta, "
          + "p.estado, c.estado AS estado_consulta "
          + "FROM dbo.propuesta p "
          + "JOIN dbo.consulta c ON c.id_consulta = p.id_consulta "
          + "JOIN dbo.persona pe ON pe.id_persona = c.id_persona "
          + "JOIN dbo.materia m ON m.id_materia = c.id_materia "
          + "JOIN dbo.empleado e ON e.id_empleado = p.id_abogado ";

    /** Última versión de cada propuesta ENVIADA o EN_NEGOCIACION: el cliente aún no respondió. */
    public List<Map<String, Object>> propuestasPorResponder() throws SQLException {
        return consulta(SELECT_PROPUESTA + "WHERE p.estado IN ('ENVIADA', 'EN_NEGOCIACION') "
                + "AND NOT EXISTS (SELECT 1 FROM dbo.propuesta p2 WHERE p2.id_consulta = p.id_consulta AND p2.version > p.version) "
                + "ORDER BY p.id_propuesta DESC");
    }

    /** Combo de W08: propuestas ACEPTADAS sin contrato (contrato.id_propuesta es UNIQUE → relación 1:1). */
    public List<Map<String, Object>> propuestasAceptadasSinContrato() throws SQLException {
        return consulta(SELECT_PROPUESTA + "WHERE p.estado = 'ACEPTADA' "
                + "AND NOT EXISTS (SELECT 1 FROM dbo.contrato k WHERE k.id_propuesta = p.id_propuesta) ORDER BY p.id_propuesta DESC");
    }

    /** Quién firma el contrato (contrato.id_cliente). Se marcan las personas sin documento: el trigger no las acepta. */
    public List<Map<String, Object>> clientes() throws SQLException {
        return consulta("SELECT id_persona, COALESCE(razon_social, nombres + ' ' + apellidos) AS nombre, "
                + "COALESCE(tipo_documento + ' ' + nro_documento, 'SIN DOCUMENTO') AS documento, "
                + "CAST(CASE WHEN nro_documento IS NULL THEN 1 ELSE 0 END AS BIT) AS sin_documento "
                + "FROM dbo.persona ORDER BY nombre");
    }

    /** Sugerencia del siguiente número: CT-AAAA-0001, CT-AAAA-0002… (nro_contrato es UNIQUE). */
    public String siguienteNroContrato() throws SQLException {
        String prefijo = "CT-" + Year.now().getValue() + "-";
        try (Connection cn = ds.getConnection();
             PreparedStatement ps = cn.prepareStatement("SELECT MAX(nro_contrato) FROM dbo.contrato WHERE nro_contrato LIKE ?")) {
            ps.setString(1, prefijo + "%");
            try (ResultSet rs = ps.executeQuery()) {
                int n = 0;
                if (rs.next() && rs.getString(1) != null) {
                    try { n = Integer.parseInt(rs.getString(1).substring(prefijo.length())); } catch (NumberFormatException ignored) { }
                }
                return prefijo + String.format("%04d", n + 1);
            }
        }
    }

    /** Últimos contratos con su total de cuotas (para ver lo grabado). */
    public List<Map<String, Object>> contratosRecientes() throws SQLException {
        return consulta("SELECT TOP 10 k.id_contrato, k.nro_contrato, FORMAT(k.fecha_firma, 'dd/MM/yyyy') AS fecha_firma, k.modalidad_firma, "
                + "CASE WHEN k.fecha_firma IS NULL THEN 'PENDIENTE_FIRMA' ELSE 'FIRMADO' END AS estado_firma, "
                + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, k.tipo_encargo, k.modalidad_pago, "
                + "k.id_propuesta, p.id_consulta, c.estado AS estado_consulta, "
                + "(SELECT COUNT(*) FROM dbo.cuota q WHERE q.id_contrato = k.id_contrato) AS nro_cuotas, "
                + "(SELECT COALESCE(SUM(q.monto), 0) FROM dbo.cuota q WHERE q.id_contrato = k.id_contrato) AS total_cuotas "
                + "FROM dbo.contrato k JOIN dbo.persona pe ON pe.id_persona = k.id_cliente "
                + "JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta JOIN dbo.consulta c ON c.id_consulta = p.id_consulta "
                + "ORDER BY k.id_contrato DESC");
    }

    /** Cuotas del contrato desde la vista vw_cuota_estado («VENCIDA» se calcula, no se guarda). */
    public List<Map<String, Object>> cuotasDelContrato(int idContrato) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(
                "SELECT id_cuota, nro_cuota, concepto, monto, FORMAT(fecha_vencimiento, 'dd/MM/yyyy') AS fecha_vencimiento, estado "
              + "FROM dbo.vw_cuota_estado WHERE id_contrato = ? ORDER BY nro_cuota")) {
            ps.setInt(1, idContrato);
            try (ResultSet rs = ps.executeQuery()) { return filas(rs); }
        }
    }

    // =====================================================================================
    // Paso previo a W08 · el cliente acepta la propuesta: UPDATE PROPUESTA
    // =====================================================================================
    public Map<String, Object> aceptarPropuesta(int idPropuesta) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(
                "UPDATE dbo.propuesta SET estado = 'ACEPTADA', fecha_respuesta = CAST(GETDATE() AS DATE) "
              + "WHERE id_propuesta = ? AND estado IN ('ENVIADA', 'EN_NEGOCIACION')")) {
            ps.setInt(1, idPropuesta);
            if (ps.executeUpdate() == 0) throw new ReglaNegocioException("La propuesta " + idPropuesta + " ya no está pendiente de respuesta.");
        }
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("idPropuesta", idPropuesta);
        r.put("mensaje", "Propuesta " + idPropuesta + " marcada como ACEPTADA.");
        return r;
    }

    // =====================================================================================
    // W08 · CONTRATO + CUOTAS + CONSULTA  (una sola transacción, maestro-detalle)
    // =====================================================================================
    private static final String INSERT_CONTRATO =
            "INSERT INTO dbo.contrato (id_propuesta, id_cliente, nro_contrato, fecha_firma, modalidad_firma, tipo_encargo, modalidad_pago, con_carta_poder) "
          + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";                    // firma DIGITAL: fecha y modalidad quedan NULL hasta que el cliente firme en el portal
    private static final String INSERT_CUOTA =
            "INSERT INTO dbo.cuota (id_contrato, nro_cuota, concepto, monto, fecha_vencimiento) VALUES (?, ?, ?, ?, ?)";
                                                                   // estado = 'PENDIENTE' por DEFAULT; id_liquidacion NULL
    private static final String UPDATE_CONSULTA =
            "UPDATE dbo.consulta SET estado = 'CONTRATADA' WHERE id_consulta = ?";

    @SuppressWarnings("unchecked")
    public Map<String, Object> registrarContrato(Map<String, Object> d) throws SQLException {
        // ---------- 0) Datos que llegan de la pantalla W08
        int idPropuesta = entero(d, "idPropuesta");
        int idCliente = entero(d, "idCliente");
        String nro = texto(d, "nroContrato");
        // Firma: DIGITAL = el cliente firma después en su portal (queda PENDIENTE); PRESENCIAL = ya firmó en el estudio
        String firma = Datos.tiene(d, "modalidadFirma") ? texto(d, "modalidadFirma") : "PRESENCIAL";
        if (!Set.of("DIGITAL", "PRESENCIAL").contains(firma)) throw new ReglaNegocioException("Modalidad de firma no válida.");
        boolean pendiente = "DIGITAL".equals(firma);
        LocalDate fechaFirma = pendiente ? null : fecha(d, "fechaFirma");
        String tipo = texto(d, "tipoEncargo");
        String modalidad = texto(d, "modalidadPago");
        boolean cartaPoder = Boolean.TRUE.equals(d.get("conCartaPoder"));
        Object listaCuotas = d.get("cuotas");
        List<Map<String, Object>> cuotas = listaCuotas instanceof List<?> l ? (List<Map<String, Object>>) l : List.of();

        if (!TIPOS_ENCARGO.contains(tipo)) throw new ReglaNegocioException("Tipo de encargo no válido.");
        if (!MODALIDADES.contains(modalidad)) throw new ReglaNegocioException("Modalidad de pago no válida.");
        if (fechaFirma != null && fechaFirma.isAfter(LocalDate.now())) throw new ReglaNegocioException("La fecha de firma no puede ser futura.");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // ---------- 1) Releer la propuesta dentro de la transacción (UPDLOCK: nadie más la contrata a la vez)
                int idConsulta;
                BigDecimal honorarios;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT p.id_consulta, p.monto_honorarios, p.estado, "
                      + "(SELECT COUNT(*) FROM dbo.contrato k WHERE k.id_propuesta = p.id_propuesta) "
                      + "FROM dbo.propuesta p WITH (UPDLOCK) WHERE p.id_propuesta = ?")) {
                    ps.setInt(1, idPropuesta);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("La propuesta no existe.");
                        if (!"ACEPTADA".equals(rs.getString(3))) throw new ReglaNegocioException("Solo se contrata una propuesta ACEPTADA.");
                        if (rs.getInt(4) > 0) throw new ReglaNegocioException("Esa propuesta ya tiene contrato (relación 1:1).");
                        idConsulta = rs.getInt(1);
                        honorarios = rs.getBigDecimal(2);
                    }
                }
                validarCronograma(cuotas, honorarios, tipo, fechaFirma != null ? fechaFirma : LocalDate.now());

                // ---------- 2) CONTRATO (cabecera). El trigger trg_contrato_cliente_documento exige DNI o RUC del cliente.
                int idContrato;
                try (PreparedStatement ps = cn.prepareStatement(INSERT_CONTRATO, Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idPropuesta);
                    ps.setInt(2, idCliente);
                    ps.setString(3, nro);
                    if (pendiente) { ps.setNull(4, java.sql.Types.DATE); ps.setNull(5, java.sql.Types.VARCHAR); }
                    else { ps.setDate(4, Date.valueOf(fechaFirma)); ps.setString(5, "PRESENCIAL"); }
                    ps.setString(6, tipo);
                    ps.setString(7, modalidad);
                    ps.setBoolean(8, cartaPoder);
                    ps.executeUpdate();
                    idContrato = idGenerado(ps);
                }

                // ---------- 3) CUOTA (detalle): una fila por cada cuota del cronograma (FK id_contrato)
                List<Integer> idsCuota = new ArrayList<>();
                try (PreparedStatement ps = cn.prepareStatement(INSERT_CUOTA, Statement.RETURN_GENERATED_KEYS)) {
                    for (Map<String, Object> q : cuotas) {
                        ps.setInt(1, idContrato);
                        ps.setInt(2, entero(q, "nroCuota"));
                        ps.setString(3, texto(q, "concepto"));
                        ps.setBigDecimal(4, decimal(q, "monto"));
                        ps.setDate(5, Date.valueOf(fecha(q, "fechaVencimiento")));
                        ps.executeUpdate();
                        idsCuota.add(idGenerado(ps));
                    }
                }

                // ---------- 4) CONSULTA de origen → CONTRATADA
                try (PreparedStatement ps = cn.prepareStatement(UPDATE_CONSULTA)) {
                    ps.setInt(1, idConsulta);
                    ps.executeUpdate();
                }

                // ---------- 5) PORTAL DEL CLIENTE: cuenta en USUARIO (id_persona) si aún no tiene + aviso para firmar
                Map<String, Object> portal = asegurarCuentaPortal(cn, idCliente);
                pe.edu.utp.magallanes.web.expediente.NotificacionRepositorio.avisarCliente(cn, idCliente, idConsulta, null, "FIRMA_DOCUMENTO",
                        pendiente ? "Su contrato " + nro + " está listo. Revíselo y fírmelo en su portal del cliente."
                                  : "Registramos su contrato " + nro + " firmado en el estudio. Puede ver sus cuotas en su portal del cliente.");

                cn.commit();                                           // COMMIT
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idContrato", idContrato);
                r.put("nroContrato", nro);
                r.put("idConsulta", idConsulta);
                r.put("idsCuota", idsCuota);
                r.put("cuotas", cuotasDelContrato(idContrato));
                r.put("pendienteFirma", pendiente);
                r.put("portal", portal);
                r.put("mensaje", "Contrato " + nro + " registrado con " + idsCuota.size() + " cuota(s)"
                        + (pendiente ? ": queda PENDIENTE DE FIRMA del cliente en su portal." : " y firmado en el estudio (PRESENCIAL)."));
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* el trigger ya pudo haber hecho ROLLBACK */ }
                throw e;                                               // ROLLBACK: ni contrato, ni cuotas, ni cambio de estado
            }
        }
    }

    /**
     * Cuenta del portal del cliente (USUARIO con id_persona). Si no existe se crea: entra con su N.° de documento
     * y la contraseña inicial es ese mismo número (solo se guarda el hash BCrypt).
     */
    private Map<String, Object> asegurarCuentaPortal(Connection cn, int idPersona) throws SQLException {
        Map<String, Object> r = new LinkedHashMap<>();
        String doc, email;
        try (PreparedStatement ps = cn.prepareStatement("SELECT p.tipo_documento, p.nro_documento, p.email, "
                + "(SELECT COUNT(*) FROM dbo.usuario u WHERE u.id_persona = p.id_persona) FROM dbo.persona p WHERE p.id_persona = ?")) {
            ps.setInt(1, idPersona);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next() || rs.getString(2) == null) { r.put("creada", false); return r; }
                doc = rs.getString(2);
                r.put("usuario", rs.getString(1) + " " + doc);
                if (rs.getInt(4) > 0) { r.put("creada", false); return r; }
                email = rs.getString(3) != null ? rs.getString(3).toLowerCase() : null;
                if (email == null) email = rs.getString(1).toLowerCase() + doc + "@portal.mmabogados.pe";
            }
        }
        try (PreparedStatement ps = cn.prepareStatement("SELECT COUNT(*) FROM dbo.usuario WHERE email = ?")) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) { rs.next(); if (rs.getInt(1) > 0) email = "cliente" + idPersona + "@portal.mmabogados.pe"; }
        }
        try (PreparedStatement ps = cn.prepareStatement("INSERT INTO dbo.usuario (id_persona, email, contrasena_hash, activo) VALUES (?, ?, ?, 1)")) {
            ps.setInt(1, idPersona); ps.setString(2, email); ps.setString(3, bcrypt.encode(doc));
            ps.executeUpdate();
        }
        r.put("creada", true);
        r.put("contrasenaInicial", "su N.° de documento");
        return r;
    }

    /** W08 · El cliente firmó en el estudio un contrato que estaba pendiente: UPDATE CONTRATO (fecha + PRESENCIAL) + avisos. */
    public Map<String, Object> firmaPresencial(int idContrato, Map<String, Object> d) throws SQLException {
        LocalDate f = Datos.tiene(d, "fechaFirma") ? fecha(d, "fechaFirma") : LocalDate.now();
        if (f.isAfter(LocalDate.now())) throw new ReglaNegocioException("La fecha de firma no puede ser futura.");
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);
            try {
                int idCliente, idConsulta, idAbogado; String nro;
                try (PreparedStatement ps = cn.prepareStatement("SELECT k.fecha_firma, k.nro_contrato, k.id_cliente, p.id_consulta, p.id_abogado "
                        + "FROM dbo.contrato k WITH (UPDLOCK) JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta WHERE k.id_contrato = ?")) {
                    ps.setInt(1, idContrato);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El contrato no existe.");
                        if (rs.getDate(1) != null) throw new ReglaNegocioException("El contrato ya está firmado.");
                        nro = rs.getString(2); idCliente = rs.getInt(3); idConsulta = rs.getInt(4); idAbogado = rs.getInt(5);
                    }
                }
                try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.contrato SET fecha_firma = ?, modalidad_firma = 'PRESENCIAL' WHERE id_contrato = ?")) {
                    ps.setDate(1, Date.valueOf(f)); ps.setInt(2, idContrato); ps.executeUpdate();
                }
                pe.edu.utp.magallanes.web.expediente.NotificacionRepositorio.avisarEquipo(cn, List.of(), idAbogado, idConsulta, null, "FIRMA_DOCUMENTO",
                        "El contrato " + nro + " se firmó en el estudio (presencial). Ya se puede abrir el expediente.");
                pe.edu.utp.magallanes.web.expediente.NotificacionRepositorio.avisarCliente(cn, idCliente, idConsulta, null, "FIRMA_DOCUMENTO",
                        "Registramos la firma presencial de su contrato " + nro + ".");
                cn.commit();
                return Map.of("idContrato", idContrato, "mensaje", "Contrato " + nro + " firmado en el estudio el " + f + " (PRESENCIAL).");
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;
            }
        }
    }

    /** Reglas del cronograma que no puede validar un CHECK de una sola fila. */
    private static void validarCronograma(List<Map<String, Object>> cuotas, BigDecimal honorarios, String tipo, LocalDate firma) {
        if (honorarios.signum() == 0) {
            if (!"PRO_BONO".equals(tipo)) throw new ReglaNegocioException("La propuesta es de S/ 0: el tipo de encargo debe ser PRO_BONO.");
            if (!cuotas.isEmpty()) throw new ReglaNegocioException("Un contrato PRO_BONO no lleva cuotas.");
            return;
        }
        if (cuotas.isEmpty()) throw new ReglaNegocioException("Agregue al menos una cuota al cronograma.");
        BigDecimal suma = BigDecimal.ZERO;
        int esperado = 1;
        for (Map<String, Object> q : cuotas) {
            if (entero(q, "nroCuota") != esperado++) throw new ReglaNegocioException("Las cuotas deben numerarse 1, 2, 3… sin saltos.");
            if (!CONCEPTOS.contains(texto(q, "concepto"))) throw new ReglaNegocioException("Concepto de cuota no válido.");
            BigDecimal m = decimal(q, "monto");
            if (m.signum() <= 0) throw new ReglaNegocioException("Cada cuota debe ser mayor a cero.");
            if (fecha(q, "fechaVencimiento").isBefore(firma)) throw new ReglaNegocioException("Ninguna cuota puede vencer antes de la firma.");
            suma = suma.add(m);
        }
        if (suma.compareTo(honorarios) != 0)
            throw new ReglaNegocioException("La suma de las cuotas (S/ " + suma + ") debe ser igual a los honorarios aceptados (S/ " + honorarios + ").");
    }

    // =====================================================================================
    // W07 · PROPUESTA
    // =====================================================================================
    // =====================================================================================
    // W07 · PROPUESTA DE HONORARIOS  (una sola transacción)
    //   1) UPDATE propuesta  : la versión anterior ENVIADA pasa a EN_NEGOCIACION (si existe)
    //   2) INSERT propuesta  : nueva versión = MAX(version) + 1  (UNIQUE id_consulta + version)
    //   3) UPDATE consulta   : estado = 'PROPUESTA'
    // =====================================================================================
    public Map<String, Object> registrarPropuesta(Map<String, Object> d) throws SQLException {
        int idConsulta = entero(d, "idConsulta");
        int idAbogado = entero(d, "idAbogado");
        BigDecimal honorarios = decimal(d, "montoHonorarios");
        BigDecimal litis = decimal(d, "porcentajeCuotaLitis");
        int nroCuotas = entero(d, "nroCuotas");
        if (honorarios.signum() < 0) throw new ReglaNegocioException("Los honorarios no pueden ser negativos (0 = pro bono).");
        if (litis.signum() < 0 || litis.compareTo(BigDecimal.valueOf(100)) > 0) throw new ReglaNegocioException("La cuota litis va de 0 % a 100 %.");
        if (nroCuotas < 1 || nroCuotas > 24) throw new ReglaNegocioException("El número de cuotas va de 1 a 24.");
        if (honorarios.signum() == 0 && nroCuotas != 1) throw new ReglaNegocioException("Una propuesta pro bono (S/ 0) lleva 1 sola cuota.");

        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // 0) Releer la consulta con bloqueo y validar estado y abogado de la materia
                int idMateria;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT estado, id_materia FROM dbo.consulta WITH (UPDLOCK) WHERE id_consulta = ?")) {
                    ps.setInt(1, idConsulta);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("La consulta no existe.");
                        String est = rs.getString(1);
                        if (!Set.of("AGENDADA", "ATENDIDA", "PROPUESTA").contains(est))
                            throw new ReglaNegocioException("Solo se envía propuesta a una consulta que ya tuvo cita (estado actual: " + est + ").");
                        idMateria = rs.getInt(2);
                    }
                }
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT 1 FROM dbo.abogado_materia WHERE id_abogado = ? AND id_materia = ?")) {
                    ps.setInt(1, idAbogado);
                    ps.setInt(2, idMateria);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("Ese abogado no atiende la materia de la consulta.");
                    }
                }
                int version;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT COALESCE(MAX(version), 0) + 1 FROM dbo.propuesta WITH (UPDLOCK) WHERE id_consulta = ?")) {
                    ps.setInt(1, idConsulta);
                    try (ResultSet rs = ps.executeQuery()) { rs.next(); version = rs.getInt(1); }
                }

                // 1) La versión anterior que seguía ENVIADA pasa a EN_NEGOCIACION
                int anteriores;
                try (PreparedStatement ps = cn.prepareStatement(
                        "UPDATE dbo.propuesta SET estado = 'EN_NEGOCIACION', fecha_respuesta = CAST(GETDATE() AS DATE) "
                      + "WHERE id_consulta = ? AND estado = 'ENVIADA'")) {
                    ps.setInt(1, idConsulta);
                    anteriores = ps.executeUpdate();
                }

                // 2) INSERT PROPUESTA (estado = 'ENVIADA' por DEFAULT)
                int idPropuesta;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.propuesta (id_consulta, id_abogado, version, monto_honorarios, porcentaje_cuota_litis, nro_cuotas, fecha_envio) "
                      + "VALUES (?, ?, ?, ?, ?, ?, CAST(GETDATE() AS DATE))", Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idConsulta);
                    ps.setInt(2, idAbogado);
                    ps.setInt(3, version);
                    ps.setBigDecimal(4, honorarios);
                    ps.setBigDecimal(5, litis);
                    ps.setInt(6, nroCuotas);
                    ps.executeUpdate();
                    idPropuesta = idGenerado(ps);
                }

                // 3) CONSULTA → PROPUESTA
                try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.consulta SET estado = 'PROPUESTA' WHERE id_consulta = ?")) {
                    ps.setInt(1, idConsulta);
                    ps.executeUpdate();
                }

                cn.commit();                                           // COMMIT
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idPropuesta", idPropuesta);
                r.put("version", version);
                r.put("idConsulta", idConsulta);
                r.put("anterioresEnNegociacion", anteriores);
                r.put("mensaje", "Propuesta N.° " + idPropuesta + " (versión " + version + ") enviada al cliente.");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                throw e;                                               // ROLLBACK
            }
        }
    }

    // =====================================================================================
    // W09 · APERTURA DEL EXPEDIENTE: CASO + CASO_PARTE (n) + CASO_ETAPA + MongoDB «expedientes»
    // =====================================================================================

    /** Contratos firmados que todavía no tienen caso (caso.id_contrato es UNIQUE → 1:1). */
    public List<Map<String, Object>> contratosSinCaso() throws SQLException {
        return consulta("SELECT k.id_contrato, k.nro_contrato, FORMAT(k.fecha_firma, 'dd/MM/yyyy') AS fecha_firma, k.tipo_encargo, "
                + "k.id_cliente, COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, "
                + "c.id_consulta, c.id_materia, m.nombre AS materia, CAST(c.resumen AS NVARCHAR(500)) AS resumen, "
                + "p.id_abogado, e.nombres + ' ' + e.apellidos AS abogado "
                + "FROM dbo.contrato k JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta "
                + "JOIN dbo.consulta c ON c.id_consulta = p.id_consulta JOIN dbo.materia m ON m.id_materia = c.id_materia "
                + "JOIN dbo.persona pe ON pe.id_persona = k.id_cliente JOIN dbo.empleado e ON e.id_empleado = p.id_abogado "
                + "WHERE k.fecha_firma IS NOT NULL "                                // TO-BE: solo se abre el expediente de un contrato FIRMADO
                + "AND NOT EXISTS (SELECT 1 FROM dbo.caso x WHERE x.id_contrato = k.id_contrato) ORDER BY k.id_contrato DESC");
    }

    /** Contratos que todavía esperan la firma del cliente (no pueden abrir expediente). */
    public List<Map<String, Object>> contratosPorFirmar() throws SQLException {
        return consulta("SELECT k.id_contrato, k.nro_contrato, COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente "
                + "FROM dbo.contrato k JOIN dbo.persona pe ON pe.id_persona = k.id_cliente WHERE k.fecha_firma IS NULL ORDER BY k.id_contrato DESC");
    }

    /** Contrapartes que el cliente mencionó en su consulta (pasan al caso como CONTRAPARTE). */
    public List<Map<String, Object>> contrapartesDeConsulta(int idConsulta) throws SQLException {
        return consultaP("SELECT p.id_persona, COALESCE(p.razon_social, p.nombres + ' ' + p.apellidos) AS nombre, "
                + "COALESCE(p.tipo_documento + ' ' + p.nro_documento, 'SIN DOCUMENTO') AS documento "
                + "FROM dbo.consulta_contraparte cc JOIN dbo.persona p ON p.id_persona = cc.id_persona WHERE cc.id_consulta = ?", idConsulta);
    }

    public List<Map<String, Object>> rolesProcesales() throws SQLException {
        return consulta("SELECT id_rol, nombre, familia FROM dbo.rol_procesal ORDER BY familia, id_rol");
    }

    public List<Map<String, Object>> etapasProcesales() throws SQLException {
        return consulta("SELECT id_etapa, nombre, orden FROM dbo.etapa_procesal ORDER BY orden");
    }

    /** EXP-AAAA-0001, EXP-AAAA-0002… (caso.codigo_interno es UNIQUE). */
    public String siguienteCodigoCaso() throws SQLException {
        String prefijo = "EXP-" + Year.now().getValue() + "-";
        try (Connection cn = ds.getConnection();
             PreparedStatement ps = cn.prepareStatement("SELECT MAX(codigo_interno) FROM dbo.caso WHERE codigo_interno LIKE ?")) {
            ps.setString(1, prefijo + "%");
            try (ResultSet rs = ps.executeQuery()) {
                int n = 0;
                if (rs.next() && rs.getString(1) != null) {
                    try { n = Integer.parseInt(rs.getString(1).substring(prefijo.length())); } catch (NumberFormatException ignored) { }
                }
                return prefijo + String.format("%04d", n + 1);
            }
        }
    }

    /** Últimos casos abiertos, con el _id de su expediente digital en MongoDB. */
    public List<Map<String, Object>> casosRecientes() throws SQLException {
        return consulta("SELECT TOP 10 c.id_caso, c.codigo_interno, FORMAT(c.fecha_apertura, 'dd/MM/yyyy') AS apertura, m.nombre AS materia, "
                + "COALESCE(pe.razon_social, pe.nombres + ' ' + pe.apellidos) AS cliente, e.nombres + ' ' + e.apellidos AS abogado, c.estado, "
                + "(SELECT COUNT(*) FROM dbo.caso_parte x WHERE x.id_caso = c.id_caso) AS partes, "
                + "(SELECT TOP 1 ep.nombre FROM dbo.caso_etapa ce JOIN dbo.etapa_procesal ep ON ep.id_etapa = ce.id_etapa "
                + "  WHERE ce.id_caso = c.id_caso AND ce.fecha_fin IS NULL) AS etapa_actual, c.expediente_mongo_id "
                + "FROM dbo.caso c JOIN dbo.materia m ON m.id_materia = c.id_materia JOIN dbo.contrato k ON k.id_contrato = c.id_contrato "
                + "JOIN dbo.persona pe ON pe.id_persona = k.id_cliente JOIN dbo.empleado e ON e.id_empleado = c.id_abogado_responsable "
                + "ORDER BY c.id_caso DESC");
    }

    /** Documento del expediente digital tal como está guardado en MongoDB (para mostrarlo en pantalla). */
    public Map<String, Object> expedienteMongo(int idCaso) {
        if (!mongo.disponible()) throw new ReglaNegocioException("MongoDB no está encendido en esta computadora.");
        Document doc = mongo.buscarPor("expedientes", "id_caso", idCaso);
        if (doc == null) throw new ReglaNegocioException("El caso " + idCaso + " no tiene expediente digital en MongoDB.");
        return Map.of("coleccion", "expedientes", "json", doc.toJson());
    }

    public Map<String, Object> abrirCaso(Map<String, Object> d, String usuario) throws SQLException {
        int idContrato = Datos.entero(d, "idContrato");
        int idAbogado = Datos.entero(d, "idAbogado");
        String codigo = Datos.texto(d, "codigoInterno");
        String nroJudicial = Datos.textoOpcional(d, "nroExpedienteJudicial");
        String descripcion = Datos.texto(d, "descripcion");
        boolean alta = Datos.booleano(d, "esAltaComplejidad");
        int idRolCliente = Datos.entero(d, "idRolCliente");
        int idEtapa = Datos.entero(d, "idEtapa");
        List<Map<String, Object>> contrapartes = Datos.lista(d, "contrapartes");
        String resumen = Datos.textoOpcional(d, "resumenHechos");
        List<String> etiquetas = new ArrayList<>();
        for (Object o : Datos.valores(d, "etiquetas")) if (o != null && !o.toString().isBlank()) etiquetas.add(o.toString().trim().toLowerCase());
        if (!codigo.matches("EXP-\\d{4}-\\d{4}")) throw new ReglaNegocioException("El código interno debe tener el formato EXP-AAAA-0000.");

        String idMongo = null;
        try (Connection cn = ds.getConnection()) {
            cn.setAutoCommit(false);                                   // BEGIN TRANSACTION
            try {
                // 0) Contrato sin caso (UPDLOCK) y materia de la consulta de origen
                int idCliente, idMateria;
                String materia;
                try (PreparedStatement ps = cn.prepareStatement(
                        "SELECT k.id_cliente, c.id_materia, m.nombre, (SELECT COUNT(*) FROM dbo.caso x WHERE x.id_contrato = k.id_contrato) "
                      + "FROM dbo.contrato k WITH (UPDLOCK) JOIN dbo.propuesta p ON p.id_propuesta = k.id_propuesta "
                      + "JOIN dbo.consulta c ON c.id_consulta = p.id_consulta JOIN dbo.materia m ON m.id_materia = c.id_materia "
                      + "WHERE k.id_contrato = ?")) {
                    ps.setInt(1, idContrato);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) throw new ReglaNegocioException("El contrato no existe.");
                        if (rs.getInt(4) > 0) throw new ReglaNegocioException("Ese contrato ya tiene expediente (relación 1:1).");
                        idCliente = rs.getInt(1); idMateria = rs.getInt(2); materia = rs.getString(3);
                    }
                }

                // 1) CASO (estado ACTIVO por DEFAULT)
                int idCaso;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.caso (id_contrato, id_materia, id_abogado_responsable, codigo_interno, nro_expediente_judicial, "
                      + "descripcion, es_alta_complejidad, fecha_apertura) VALUES (?, ?, ?, ?, ?, ?, ?, CAST(GETDATE() AS DATE))",
                        Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, idContrato); ps.setInt(2, idMateria); ps.setInt(3, idAbogado); ps.setString(4, codigo);
                    Datos.setTextoONull(ps, 5, nroJudicial); ps.setString(6, descripcion); ps.setBoolean(7, alta);
                    ps.executeUpdate();
                    idCaso = Datos.idGenerado(ps);
                }

                // 2) CASO_PARTE: el cliente y cada contraparte (PK compuesta id_caso + id_persona + id_rol)
                int partes = 0;
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.caso_parte (id_caso, id_persona, id_rol, tipo_parte, abogado_externo) VALUES (?, ?, ?, ?, ?)")) {
                    ps.setInt(1, idCaso); ps.setInt(2, idCliente); ps.setInt(3, idRolCliente); ps.setString(4, "CLIENTE"); ps.setNull(5, java.sql.Types.NVARCHAR);
                    ps.addBatch(); partes++;
                    for (Map<String, Object> cp : contrapartes) {
                        ps.setInt(1, idCaso); ps.setInt(2, Datos.entero(cp, "idPersona")); ps.setInt(3, Datos.entero(cp, "idRol"));
                        ps.setString(4, "CONTRAPARTE"); Datos.setTextoONull(ps, 5, Datos.textoOpcional(cp, "abogadoExterno"));
                        ps.addBatch(); partes++;
                    }
                    ps.executeBatch();
                }

                // 3) CASO_ETAPA: primera etapa abierta (fecha_fin NULL; índice único filtrado uq_caso_etapa_abierta)
                try (PreparedStatement ps = cn.prepareStatement(
                        "INSERT INTO dbo.caso_etapa (id_caso, id_etapa, fecha_inicio) VALUES (?, ?, CAST(GETDATE() AS DATE))")) {
                    ps.setInt(1, idCaso); ps.setInt(2, idEtapa); ps.executeUpdate();
                }

                // 4) MongoDB «expedientes»: el expediente digital (texto libre, etiquetas, bitácora) → su _id va a SQL
                String aviso = null;
                if (mongo.disponible()) {
                    idMongo = mongo.guardar("expedientes", new Document("id_caso", idCaso)
                            .append("codigo_interno", codigo).append("materia", materia)
                            .append("resumen_hechos", resumen == null ? descripcion : resumen)
                            .append("etiquetas", etiquetas).append("archivos", new ArrayList<>())
                            .append("bitacora", List.of(new Document("fecha", new java.util.Date()).append("evento", "Apertura del expediente")
                                    .append("usuario", usuario).append("detalle", new Document("id_contrato", idContrato)))));
                    try (PreparedStatement ps = cn.prepareStatement("UPDATE dbo.caso SET expediente_mongo_id = ? WHERE id_caso = ?")) {
                        ps.setString(1, idMongo); ps.setInt(2, idCaso); ps.executeUpdate();
                    }
                } else {
                    aviso = "MongoDB no está encendido: el caso se grabó en SQL Server y el expediente digital queda pendiente (expediente_mongo_id = NULL).";
                }

                cn.commit();                                           // COMMIT
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idCaso", idCaso);
                r.put("codigoInterno", codigo);
                r.put("partes", partes);
                r.put("expedienteMongoId", idMongo);
                r.put("aviso", aviso);
                r.put("mensaje", "Expediente " + codigo + " abierto con " + partes + " parte(s).");
                return r;
            } catch (SQLException | RuntimeException e) {
                try { cn.rollback(); } catch (SQLException ignorada) { /* ya revertida */ }
                mongo.borrar("expedientes", idMongo);                  // compensación en MongoDB
                throw e;
            }
        }
    }

    // =====================================================================================
    // Utilidades
    // =====================================================================================
    private List<Map<String, Object>> consultaP(String sql, Object... params) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) ps.setObject(i + 1, params[i]);
            return Datos.filas(ps);
        }
    }

    private List<Map<String, Object>> consulta(String sql) throws SQLException {
        try (Connection cn = ds.getConnection(); PreparedStatement ps = cn.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            return filas(rs);
        }
    }

    private static int idGenerado(PreparedStatement ps) throws SQLException {
        try (ResultSet k = ps.getGeneratedKeys()) {
            if (!k.next()) throw new SQLException("SQL Server no devolvió el id generado (IDENTITY).");
            return k.getInt(1);
        }
    }

    private static Object requerido(Map<String, Object> d, String k) {
        Object v = d.get(k);
        if (v == null || v.toString().isBlank()) throw new ReglaNegocioException("Falta el dato: " + k);
        return v;
    }
    private static int entero(Map<String, Object> d, String k) {
        try { return new BigDecimal(requerido(d, k).toString()).intValueExact(); }
        catch (ArithmeticException | NumberFormatException e) { throw new ReglaNegocioException("Número no válido en " + k); }
    }
    private static BigDecimal decimal(Map<String, Object> d, String k) {
        try { return new BigDecimal(requerido(d, k).toString()).setScale(2, RoundingMode.HALF_UP); }
        catch (NumberFormatException e) { throw new ReglaNegocioException("Monto no válido en " + k); }
    }
    private static String texto(Map<String, Object> d, String k) { return requerido(d, k).toString().trim(); }
    private static LocalDate fecha(Map<String, Object> d, String k) {
        try { return LocalDate.parse(texto(d, k)); }
        catch (DateTimeParseException e) { throw new ReglaNegocioException("Fecha no válida en " + k); }
    }

    public static List<Map<String, Object>> filasPublic(ResultSet rs) throws SQLException { return filas(rs); }

    static List<Map<String, Object>> filas(ResultSet rs) throws SQLException {
        List<Map<String, Object>> r = new ArrayList<>();
        ResultSetMetaData md = rs.getMetaData();
        while (rs.next()) {
            Map<String, Object> f = new LinkedHashMap<>();
            for (int i = 1; i <= md.getColumnCount(); i++) f.put(md.getColumnLabel(i), rs.getObject(i));
            r.add(f);
        }
        return r;
    }
}
