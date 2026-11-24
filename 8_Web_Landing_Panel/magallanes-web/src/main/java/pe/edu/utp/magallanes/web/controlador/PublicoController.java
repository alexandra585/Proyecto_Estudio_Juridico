package pe.edu.utp.magallanes.web.controlador;

import java.sql.SQLException;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.config.Validar;
import pe.edu.utp.magallanes.web.dto.Calificacion;
import pe.edu.utp.magallanes.web.dto.Materia;
import pe.edu.utp.magallanes.web.dto.RespuestaConsulta;
import pe.edu.utp.magallanes.web.dto.Socio;
import pe.edu.utp.magallanes.web.dto.SolicitudConsulta;
import pe.edu.utp.magallanes.web.repositorio.ConsultaRepositorio;
import pe.edu.utp.magallanes.web.repositorio.PublicoRepositorio;
import pe.edu.utp.magallanes.web.mongo.MongoDocumentos;
import org.bson.Document;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;

/** Servicios de la Landing Page (sin inicio de sesión). */
@RestController
@RequestMapping("/api/publico")
public class PublicoController {
    private final PublicoRepositorio publico;
    private final ConsultaRepositorio consultas;
    private final MongoDocumentos mongo;

    public PublicoController(PublicoRepositorio publico, ConsultaRepositorio consultas, MongoDocumentos mongo) {
        this.publico = publico;
        this.consultas = consultas;
        this.mongo = mongo;
    }

    /** Cifras reales de la landing (SQL Server): casos, clientes, abogados y satisfacción. */
    @GetMapping("/cifras")
    public Map<String, Object> cifras() throws SQLException { return publico.cifras(); }

    /**
     * Testimonios de la landing: SOLO comentarios que el cliente autorizó publicar en la encuesta (W22).
     * El permiso y el nombre con el que firma están en MongoDB «encuestas.publicacion». Nunca se muestra el nombre completo
     * si el cliente eligió iniciales o anónimo.
     */
    @GetMapping("/testimonios")
    public List<Map<String, Object>> testimonios() {
        List<Map<String, Object>> r = new ArrayList<>();
        if (!mongo.disponible()) return r;
        for (Document d : mongo.testimonios(6)) {
            Document pub = d.get("publicacion", Document.class);
            Document resp = d.get("respuestas", Document.class);
            Map<String, Object> t = new LinkedHashMap<>();
            t.put("nombre", pub == null ? "Cliente del estudio" : pub.getString("nombre_publico"));
            t.put("materia", pub == null ? null : pub.getString("materia"));
            t.put("estrellas", resp == null ? null : resp.get("calificacion"));
            t.put("comentario", d.getString("comentario"));
            Object f = d.get("respondida");
            t.put("fecha", f instanceof java.util.Date fd ? new java.text.SimpleDateFormat("MMMM yyyy", java.util.Locale.forLanguageTag("es-PE")).format(fd) : null);
            r.add(t);
        }
        return r;
    }

    @GetMapping("/materias")
    public List<Materia> materias() throws SQLException { return publico.materias(); }

    @GetMapping("/socios")
    public List<Socio> socios() throws SQLException { return publico.socios(); }

    @GetMapping("/calificacion")
    public Calificacion calificacion() throws SQLException { return publico.calificacion(); }

    /** Formulario «Cuéntenos su caso» → transacción T1. */
    @PostMapping("/consultas")
    public RespuestaConsulta registrar(@RequestBody SolicitudConsulta s) throws SQLException {
        return consultas.registrarDesdeLanding(validar(s));
    }

    /**
     * Mismas reglas que los CHECK de SQL Server (magallanes_montero_validaciones.sql), para dar un mensaje claro antes de grabar.
     * Devuelve los datos ya LIMPIOS (sin espacios de más, celular sin espacios, correo en minúsculas).
     */
    private static SolicitudConsulta validar(SolicitudConsulta s) {
        String nombres = Validar.nombre(s.nombres(), "sus nombres");
        String apellidos = Validar.nombre(s.apellidos(), "sus apellidos");
        if (vacio(s.tipoDocumento()) || !List.of("DNI", "CE", "PASAPORTE").contains(s.tipoDocumento()))
            throw new ReglaNegocioException("Seleccione el tipo de documento.");
        String nro = Validar.documento(s.tipoDocumento(), s.nroDocumento());
        if (vacio(s.telefono()) && vacio(s.email())) throw new ReglaNegocioException("Ingrese su celular o su correo para responderle.");
        String tel = Validar.telefono(s.telefono());
        String email = Validar.email(s.email());
        if (s.idMateria() == null) throw new ReglaNegocioException("Seleccione la materia de su caso.");
        String resumen = Validar.limpiar(s.resumen());
        if (resumen == null || resumen.length() < 15) throw new ReglaNegocioException("Cuéntenos un poco más de su caso (mínimo 15 caracteres).");
        if (resumen.length() > 500) throw new ReglaNegocioException("El relato no puede pasar de 500 caracteres.");
        if (!s.aceptaDatos()) throw new ReglaNegocioException("Debe aceptar el tratamiento de sus datos personales (Ley 29733).");
        String cpN = null, cpA = null, cpR = null;
        if ("NATURAL".equals(s.contraparteTipo())) {
            cpN = Validar.nombre(s.contraparteNombres(), "los nombres de la contraparte");
            cpA = Validar.nombre(s.contraparteApellidos(), "los apellidos de la contraparte");
        } else if ("JURIDICA".equals(s.contraparteTipo())) {
            cpR = Validar.razonSocial(s.contraparteRazonSocial());
        }
        return new SolicitudConsulta(nombres, apellidos, s.tipoDocumento(), nro, tel, email, s.idMateria(), resumen,
                s.esUrgente(), s.aceptaDatos(), vacio(s.contraparteTipo()) ? null : s.contraparteTipo(), cpN, cpA, cpR);
    }

    private static boolean vacio(String x) { return x == null || x.isBlank(); }
}
