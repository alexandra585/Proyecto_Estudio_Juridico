package pe.edu.utp.magallanes.web.dto;

/** Fila de la bandeja de consultas (W04). */
public record FilaBandeja(int idConsulta, String fechaRecepcion, String cliente, String documento, String telefono,
                          int idMateria, String materia, String canal, String estado, boolean esUrgente,
                          int contrapartes, String proximaCita) { }
