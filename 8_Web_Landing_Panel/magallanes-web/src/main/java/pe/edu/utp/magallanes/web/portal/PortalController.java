package pe.edu.utp.magallanes.web.portal;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.Datos;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.expediente.ExpedienteRepositorio;
import pe.edu.utp.magallanes.web.expediente.NotificacionRepositorio;
import pe.edu.utp.magallanes.web.t4.T4Repositorio;

/** API del PORTAL DEL CLIENTE. Todo lo que no sea /login exige sesión de cliente (ClienteInterceptor). */
@RestController
@RequestMapping("/api/portal")
public class PortalController {
    private final PortalRepositorio repo;
    private final ExpedienteRepositorio expedientes;
    private final NotificacionRepositorio avisos;
    private final T4Repositorio t4;
    private final BCryptPasswordEncoder bcrypt;

    public PortalController(PortalRepositorio repo, ExpedienteRepositorio expedientes, NotificacionRepositorio avisos, T4Repositorio t4, BCryptPasswordEncoder bcrypt) {
        this.repo = repo; this.expedientes = expedientes; this.avisos = avisos; this.t4 = t4; this.bcrypt = bcrypt;
    }

    /** Ingreso con DNI/RUC (o correo) + contraseña. */
    @PostMapping("/login")
    public SesionCliente login(@RequestBody Map<String, Object> d, HttpServletRequest req) throws SQLException {
        String usuario = Datos.textoOpcional(d, "usuario"), clave = Datos.textoOpcional(d, "contrasena");
        if (usuario == null || clave == null) throw new ReglaNegocioException("Ingrese su DNI/RUC (o correo) y su contraseña.");
        var c = repo.buscarCuenta(usuario.trim())
                .filter(x -> bcrypt.matches(clave, x.hash()))
                .orElseThrow(() -> new ReglaNegocioException("Documento o contraseña incorrectos."));
        if (!c.activo()) throw new ReglaNegocioException("Su cuenta del portal está desactivada. Comuníquese con el estudio.");
        repo.registrarAcceso(c.idUsuario());
        SesionCliente s = new SesionCliente(c.idUsuario(), c.idPersona(), c.nombre(), c.documento(), c.email());
        // Nuevo id de sesión (evita fijación de sesión) sin cerrar la otra cuenta: panel y portal pueden convivir en el mismo navegador
        if (req.getSession(false) != null) req.changeSessionId();
        req.getSession(true).setAttribute(ClienteInterceptor.CLIENTE, s);
        return s;
    }

    @GetMapping("/yo")
    public SesionCliente yo(HttpServletRequest req) { return ClienteInterceptor.cliente(req); }

    @PostMapping("/salir")
    public Map<String, String> salir(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        if (s != null) s.removeAttribute(ClienteInterceptor.CLIENTE);
        return Map.of("ok", "Sesión cerrada");
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumen(HttpServletRequest req) throws SQLException {
        SesionCliente c = ClienteInterceptor.cliente(req);
        Map<String, Object> r = new LinkedHashMap<>(repo.resumen(c.idPersona()));
        r.put("avisos", avisos.delCliente(c.idPersona()));
        return r;
    }

    @GetMapping("/casos/{id}")
    public Map<String, Object> caso(@PathVariable int id, HttpServletRequest req) throws SQLException {
        repo.verificarCaso(id, ClienteInterceptor.cliente(req).idPersona());
        return expedientes.ficha(id, true);
    }

    @GetMapping("/contratos/{id}")
    public Map<String, Object> contrato(@PathVariable int id, HttpServletRequest req) throws SQLException {
        return repo.contrato(id, ClienteInterceptor.cliente(req).idPersona());
    }

    @PostMapping("/contratos/{id}/firmar")
    public Map<String, Object> firmar(@PathVariable int id, @RequestBody Map<String, Object> d, HttpServletRequest req) throws SQLException {
        if (!Datos.booleano(d, "acepta")) throw new ReglaNegocioException("Marque que leyó y acepta el contrato.");
        String ip = req.getHeader("X-Forwarded-For");
        return repo.firmar(id, ClienteInterceptor.cliente(req), Datos.textoOpcional(d, "firma"), ip != null ? ip.split(",")[0].trim() : req.getRemoteAddr());
    }

    @GetMapping("/formulario-encuesta")
    public Map<String, Object> formulario() { return t4.formularioEncuesta(); }

    @PostMapping("/encuestas/{id}/responder")
    public Map<String, Object> responder(@PathVariable int id, @RequestBody Map<String, Object> d, HttpServletRequest req) throws SQLException {
        SesionCliente c = ClienteInterceptor.cliente(req);
        repo.verificarEncuesta(id, c.idPersona());
        Map<String, Object> r = t4.responderEncuesta(id, d);
        try { repo.avisarEncuestaRespondida(id, c.nombre(), Datos.entero(d, "calificacion")); }
        catch (SQLException ignorada) { /* el aviso es complementario */ }
        return r;
    }

    @GetMapping("/avisos")
    public List<Map<String, Object>> misAvisos(HttpServletRequest req) throws SQLException {
        return avisos.delCliente(ClienteInterceptor.cliente(req).idPersona());
    }
}
