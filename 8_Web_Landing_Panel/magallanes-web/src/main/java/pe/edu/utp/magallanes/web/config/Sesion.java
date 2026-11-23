package pe.edu.utp.magallanes.web.config;

import jakarta.servlet.http.HttpSession;
import pe.edu.utp.magallanes.web.dto.SesionUsuario;

/** Lee el usuario que inició sesión (lo guarda AuthController en la sesión HTTP). */
public final class Sesion {
    private Sesion() { }

    public static SesionUsuario usuario(HttpSession s) {
        Object u = s == null ? null : s.getAttribute(SesionInterceptor.USUARIO);
        if (!(u instanceof SesionUsuario su)) throw new ReglaNegocioException("La sesión venció: vuelva a iniciar sesión.");
        return su;
    }
}
