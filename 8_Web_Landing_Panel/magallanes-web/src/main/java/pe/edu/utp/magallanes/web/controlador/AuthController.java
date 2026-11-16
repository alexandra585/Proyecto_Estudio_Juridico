package pe.edu.utp.magallanes.web.controlador;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import java.sql.SQLException;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.config.SesionInterceptor;
import pe.edu.utp.magallanes.web.dto.Login;
import pe.edu.utp.magallanes.web.dto.SesionUsuario;
import pe.edu.utp.magallanes.web.repositorio.UsuarioRepositorio;

/** W02 · Inicio de sesión del panel contra la tabla USUARIO (contraseña con hash BCrypt). */
@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final UsuarioRepositorio usuarios;
    private final BCryptPasswordEncoder bcrypt;

    public AuthController(UsuarioRepositorio usuarios, BCryptPasswordEncoder bcrypt) {
        this.usuarios = usuarios;
        this.bcrypt = bcrypt;
    }

    @PostMapping("/login")
    public SesionUsuario login(@RequestBody Login l, HttpServletRequest req) throws SQLException {
        if (l.email() == null || l.contrasena() == null) throw new ReglaNegocioException("Ingrese su correo y contraseña.");
        var cuenta = usuarios.buscarCuentaDelPanel(l.email().trim().toLowerCase())
                .filter(c -> bcrypt.matches(l.contrasena(), c.hash()))
                .orElseThrow(() -> new ReglaNegocioException("Correo o contraseña incorrectos."));
        if (!cuenta.activo()) throw new ReglaNegocioException("Su cuenta está bloqueada (usuario.activo = 0).");
        usuarios.registrarAcceso(cuenta.idUsuario());
        SesionUsuario s = new SesionUsuario(cuenta.idUsuario(), cuenta.idEmpleado(), cuenta.nombre(), cuenta.cargo(), cuenta.email());
        HttpSession anterior = req.getSession(false);
        if (anterior != null) anterior.invalidate();
        req.getSession(true).setAttribute(SesionInterceptor.USUARIO, s);
        return s;
    }

    @GetMapping("/yo")
    public ResponseEntity<?> yo(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        Object u = s == null ? null : s.getAttribute(SesionInterceptor.USUARIO);
        return u == null ? ResponseEntity.status(401).body(Map.of("error", "Sin sesión")) : ResponseEntity.ok(u);
    }

    @PostMapping("/salir")
    public Map<String, String> salir(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        if (s != null) s.invalidate();
        return Map.of("ok", "Sesión cerrada");
    }
}
