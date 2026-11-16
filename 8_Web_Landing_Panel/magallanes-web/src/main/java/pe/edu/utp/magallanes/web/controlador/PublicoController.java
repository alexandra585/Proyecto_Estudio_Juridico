package pe.edu.utp.magallanes.web.controlador;

import java.sql.SQLException;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.dto.Calificacion;
import pe.edu.utp.magallanes.web.dto.Materia;
import pe.edu.utp.magallanes.web.dto.RespuestaConsulta;
import pe.edu.utp.magallanes.web.dto.Socio;
import pe.edu.utp.magallanes.web.dto.SolicitudConsulta;
import pe.edu.utp.magallanes.web.repositorio.ConsultaRepositorio;
import pe.edu.utp.magallanes.web.repositorio.PublicoRepositorio;

/** Servicios de la Landing Page (sin inicio de sesión). */
@RestController
@RequestMapping("/api/publico")
public class PublicoController {
    private final PublicoRepositorio publico;
    private final ConsultaRepositorio consultas;

    public PublicoController(PublicoRepositorio publico, ConsultaRepositorio consultas) {
        this.publico = publico;
        this.consultas = consultas;
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
        validar(s);
        return consultas.registrarDesdeLanding(s);
    }

    /** Mismas reglas que exigen los CHECK de SQL Server, para dar un mensaje claro antes de grabar. */
    private static void validar(SolicitudConsulta s) {
        if (vacio(s.nombres()) || vacio(s.apellidos())) throw new ReglaNegocioException("Ingrese sus nombres y apellidos.");
        if (vacio(s.tipoDocumento()) || !List.of("DNI", "CE", "PASAPORTE").contains(s.tipoDocumento()))
            throw new ReglaNegocioException("Seleccione el tipo de documento.");
        String nro = s.nroDocumento() == null ? "" : s.nroDocumento().trim();
        if ("DNI".equals(s.tipoDocumento()) && !nro.matches("\\d{8}")) throw new ReglaNegocioException("El DNI debe tener 8 dígitos.");
        if (!nro.matches("[A-Za-z0-9]{6,15}")) throw new ReglaNegocioException("Número de documento no válido.");
        if (vacio(s.telefono()) && vacio(s.email())) throw new ReglaNegocioException("Ingrese su celular o su correo para responderle.");
        if (!vacio(s.telefono()) && !s.telefono().replace(" ", "").matches("\\+?\\d{7,15}")) throw new ReglaNegocioException("Celular no válido.");
        if (!vacio(s.email()) && !s.email().trim().matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")) throw new ReglaNegocioException("Correo no válido.");
        if (s.idMateria() == null) throw new ReglaNegocioException("Seleccione la materia de su caso.");
        if (vacio(s.resumen()) || s.resumen().trim().length() < 15) throw new ReglaNegocioException("Cuéntenos un poco más de su caso (mínimo 15 caracteres).");
        if (s.resumen().length() > 500) throw new ReglaNegocioException("El relato no puede pasar de 500 caracteres.");
        if (!s.aceptaDatos()) throw new ReglaNegocioException("Debe aceptar el tratamiento de sus datos personales (Ley 29733).");
        if ("NATURAL".equals(s.contraparteTipo()) && (vacio(s.contraparteNombres()) || vacio(s.contraparteApellidos())))
            throw new ReglaNegocioException("Ingrese nombres y apellidos de la contraparte, o deje la contraparte en blanco.");
        if ("JURIDICA".equals(s.contraparteTipo()) && vacio(s.contraparteRazonSocial()))
            throw new ReglaNegocioException("Ingrese la razón social de la contraparte, o deje la contraparte en blanco.");
    }

    private static boolean vacio(String x) { return x == null || x.isBlank(); }
}
