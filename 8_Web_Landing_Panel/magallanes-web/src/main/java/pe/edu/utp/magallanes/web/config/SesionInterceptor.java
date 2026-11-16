package pe.edu.utp.magallanes.web.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.servlet.HandlerInterceptor;

/** Protege /api/panel/**: solo entra quien inició sesión en W02 (tabla USUARIO). */
public class SesionInterceptor implements HandlerInterceptor {
    public static final String USUARIO = "usuario";

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) throws Exception {
        HttpSession s = req.getSession(false);
        if (s != null && s.getAttribute(USUARIO) != null) return true;
        res.setStatus(401);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"error\":\"Inicie sesión para usar el panel.\"}");
        return false;
    }
}
