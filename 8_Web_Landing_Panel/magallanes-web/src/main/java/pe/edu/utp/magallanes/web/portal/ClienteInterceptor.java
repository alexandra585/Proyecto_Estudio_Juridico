package pe.edu.utp.magallanes.web.portal;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.servlet.HandlerInterceptor;

/** Protege /api/portal/**: solo entra un cliente que inició sesión en el portal (401 si no). */
public class ClienteInterceptor implements HandlerInterceptor {
    public static final String CLIENTE = "cliente";

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) throws Exception {
        HttpSession s = req.getSession(false);
        if (s != null && s.getAttribute(CLIENTE) instanceof SesionCliente) return true;
        res.setStatus(401);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"error\":\"Inicie sesión en el portal del cliente.\"}");
        return false;
    }

    static SesionCliente cliente(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        Object c = s == null ? null : s.getAttribute(CLIENTE);
        if (!(c instanceof SesionCliente sc)) throw new pe.edu.utp.magallanes.web.config.ReglaNegocioException("La sesión venció: vuelva a ingresar.");
        return sc;
    }
}
