package pe.edu.utp.magallanes.web.dto;

/** Ids que generó la transacción de agendamiento. */
public record RespuestaCita(int idCita, String fechaHora, int idNotificacionCliente, int idNotificacionAbogado, String mensaje) { }
