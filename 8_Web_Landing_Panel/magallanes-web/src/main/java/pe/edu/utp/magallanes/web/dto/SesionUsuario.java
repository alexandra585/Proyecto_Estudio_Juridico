package pe.edu.utp.magallanes.web.dto;

/** Usuario del panel guardado en la sesión HTTP después del login. */
public record SesionUsuario(int idUsuario, int idEmpleado, String nombre, String cargo, String email) implements java.io.Serializable { }
