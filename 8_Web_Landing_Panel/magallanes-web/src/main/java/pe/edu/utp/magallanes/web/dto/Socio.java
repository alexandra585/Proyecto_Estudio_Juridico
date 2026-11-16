package pe.edu.utp.magallanes.web.dto;

/** Abogado socio: EMPLEADO + ABOGADO + materias de ABOGADO_MATERIA. */
public record Socio(int idEmpleado, String nombre, String iniciales, String colegiatura, String materias) { }
