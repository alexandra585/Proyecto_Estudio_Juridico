package pe.edu.utp.magallanes.web.dto;

/** Datos que envía el formulario «Cuéntenos su caso» de la Landing (W01). */
public record SolicitudConsulta(String nombres, String apellidos, String tipoDocumento, String nroDocumento,
                                String telefono, String email, Integer idMateria, String resumen,
                                boolean esUrgente, boolean aceptaDatos,
                                String contraparteTipo, String contraparteNombres, String contraparteApellidos,
                                String contraparteRazonSocial) { }
