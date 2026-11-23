package pe.edu.utp.magallanes.web.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Protege /api/panel/**: 1) solo entra quien inició sesión en W02 (tabla USUARIO) → si no, 401;
 * 2) el cargo del empleado (rol) debe tener permiso para esa pantalla (ver Roles) → si no, 403.
 */
public class SesionInterceptor implements HandlerInterceptor {
    public static final String USUARIO = "usuario";

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) throws Exception {
        HttpSession s = req.getSession(false);
        Object u = s == null ? null : s.getAttribute(USUARIO);
        if (!(u instanceof pe.edu.utp.magallanes.web.dto.SesionUsuario su)) {
            res.setStatus(401);
            res.setContentType("application/json;charset=UTF-8");
            res.getWriter().write("{\"error\":\"Inicie sesión para usar el panel.\"}");
            return false;
        }
        String ruta = req.getRequestURI().substring(req.getContextPath().length());
        if (Roles.puede(su.cargo(), ruta)) return true;
        res.setStatus(403);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"error\":\"Su rol (" + su.cargo() + ") no tiene acceso a " + Roles.regla(ruta).pantalla() + ".\"}");
        return false;
    }
}
