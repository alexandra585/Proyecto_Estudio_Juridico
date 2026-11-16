package pe.edu.utp.magallanes.web.dto;

/** Datos del formulario «Agendar cita» (W06). fecha = aaaa-mm-dd, hora = HH:mm. */
public record SolicitudCita(Integer idConsulta, Integer idAbogado, String fecha, String hora, String modalidad) { }
