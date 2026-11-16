package pe.edu.utp.magallanes.web.dto;

/** Fila de CITA con datos del cliente y del abogado. */
public record FilaCita(int idCita, int idConsulta, String fechaHora, String cliente, String abogado, String modalidad, String estado) { }
