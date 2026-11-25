package pe.edu.utp.magallanes.web.portal;

/** Cliente del PORTAL guardado en la sesión HTTP (cuenta USUARIO con id_persona, no con id_empleado). */
public record SesionCliente(int idUsuario, int idPersona, String nombre, String documento, String email) implements java.io.Serializable { }
