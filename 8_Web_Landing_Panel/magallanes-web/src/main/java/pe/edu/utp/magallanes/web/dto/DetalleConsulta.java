package pe.edu.utp.magallanes.web.dto;

import java.util.List;

/** Todo lo que el panel muestra de una consulta antes de agendar la cita. */
public record DetalleConsulta(FilaBandeja consulta, String resumen, String email, Boolean existeConflicto,
                              List<String> contrapartes, List<String> posiblesConflictos,
                              List<FilaCita> citas, List<FilaNotificacion> notificaciones) { }
