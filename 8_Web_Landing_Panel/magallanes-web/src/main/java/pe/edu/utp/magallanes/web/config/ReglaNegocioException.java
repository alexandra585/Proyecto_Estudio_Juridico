package pe.edu.utp.magallanes.web.config;

/** Error de validación que se muestra tal cual al usuario (HTTP 400). */
public class ReglaNegocioException extends RuntimeException {
    public ReglaNegocioException(String mensaje) { super(mensaje); }
}
