package pe.edu.utp.magallanes.web.dto;

/** Ids que generó la transacción T1 (se muestran al cliente y en la demostración). */
public record RespuestaConsulta(int idConsulta, int idPersona, boolean personaNueva, Integer idContraparte,
                                int idNotificacion, String mensaje) { }
