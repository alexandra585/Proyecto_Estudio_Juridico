package pe.edu.utp.magallanes.web.dto;

import java.util.List;

/** Horario del abogado en una fecha: horas posibles, horas ocupadas por otras citas y si es feriado. */
public record Disponibilidad(String fecha, String feriado, boolean domingo, List<String> horas, List<String> ocupadas) { }
