package pe.edu.utp.magallanes.web.dto;

/** Fila de NOTIFICACION (avisos generados por las transacciones). */
public record FilaNotificacion(int idNotificacion, String destinatario, String tipoEvento, String canal, String estado,
                               String fechaProgramada, String mensaje) { }
