package pe.edu.utp.magallanes.web.config;

import java.util.regex.Pattern;

/**
 * Reglas de formato de datos personales (las mismas que los CHECK de
 * 1_SQL_Server/magallanes_montero_validaciones.sql y que la validación de la pantalla):
 * se revisan en Java para dar un mensaje claro ANTES de llegar a SQL Server.
 */
public final class Validar {
    private Validar() { }

    private static final Pattern SOLO_LETRAS = Pattern.compile("[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' -]{2,80}");
    private static final Pattern CELULAR = Pattern.compile("(\\+51)?9\\d{8}");
    private static final Pattern EMAIL = Pattern.compile("[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}");

    /** Quita espacios de más: "  maría   josé " → "maría josé". */
    public static String limpiar(String t) { return t == null ? null : t.trim().replaceAll("\\s+", " "); }

    /** Celular sin espacios ni guiones: "987 654-321" → "987654321". */
    public static String telefono(String t) {
        if (t == null || t.isBlank()) return null;
        String x = t.replaceAll("[\\s-]", "");
        if (!CELULAR.matcher(x).matches()) throw new ReglaNegocioException("El celular debe tener 9 dígitos y empezar con 9 (ej.: 987654321).");
        return x;
    }

    public static String nombre(String t, String campo) {
        String x = limpiar(t);
        if (x == null || x.isEmpty()) throw new ReglaNegocioException("Ingrese " + campo + ".");
        if (!SOLO_LETRAS.matcher(x).matches()) throw new ReglaNegocioException(Character.toUpperCase(campo.charAt(0)) + campo.substring(1)
                + ": solo letras (con tildes y ñ), espacios, apóstrofo o guion; entre 2 y 80 caracteres.");
        return x;
    }

    public static String documento(String tipo, String nro) {
        String x = nro == null ? "" : nro.trim().toUpperCase();
        boolean ok = switch (tipo == null ? "" : tipo) {
            case "DNI" -> x.matches("\\d{8}");
            case "RUC" -> x.matches("(10|20)\\d{9}");
            case "CE" -> x.matches("\\d{9,12}");
            case "PASAPORTE" -> x.matches("[A-Z0-9]{6,12}");
            default -> throw new ReglaNegocioException("Seleccione el tipo de documento.");
        };
        if (!ok) throw new ReglaNegocioException(switch (tipo) {
            case "DNI" -> "El DNI debe tener exactamente 8 dígitos (solo números).";
            case "RUC" -> "El RUC debe tener 11 dígitos y empezar con 10 o 20.";
            case "CE" -> "El carné de extranjería debe tener de 9 a 12 dígitos.";
            default -> "El pasaporte debe tener de 6 a 12 letras o números.";
        });
        return x;
    }

    public static String email(String t) {
        if (t == null || t.isBlank()) return null;
        String x = t.trim().toLowerCase();
        if (x.length() > 120 || !EMAIL.matcher(x).matches()) throw new ReglaNegocioException("Correo no válido (ej.: nombre@gmail.com).");
        return x;
    }

    public static String razonSocial(String t) {
        String x = limpiar(t);
        if (x == null || x.length() < 3 || x.length() > 150) throw new ReglaNegocioException("La razón social debe tener entre 3 y 150 caracteres.");
        return x;
    }
}
