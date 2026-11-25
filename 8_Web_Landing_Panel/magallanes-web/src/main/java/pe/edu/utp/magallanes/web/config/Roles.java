package pe.edu.utp.magallanes.web.config;

import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * ROLES DEL PANEL. El rol sale de empleado.cargo (no hay tabla de roles: sería un dato repetido, 3FN).
 *   ADMINISTRADOR → Gerencia: ve todo.
 *   ABOGADO       → dashboard, consultas, propuestas (W07), expediente nuevo (W09), escritos y resoluciones (W11–W13).
 *   SECRETARIA    → consultas y citas (W04/W06), contratos y cuotas (W08), cobranza y cierre (W18–W22).
 *   PRACTICANTE   → consultas y escritos y resoluciones (W11–W13).
 * Cada regla: expresión sobre la ruta /api/panel/... → cargos que pueden usarla. Gana la PRIMERA que coincide.
 * El menú (js/menu.js) usa las mismas pantallas, pero quien protege de verdad es el servidor (403).
 */
public final class Roles {
    private Roles() { }

    static final String ADM = "ADMINISTRADOR", ABO = "ABOGADO", SEC = "SECRETARIA", PRA = "PRACTICANTE";

    record Regla(Pattern ruta, Set<String> cargos, String pantalla) { }

    private static Regla r(String regex, String pantalla, String... cargos) {
        return new Regla(Pattern.compile("^/api/panel/" + regex), Set.of(cargos), pantalla);
    }

    static final List<Regla> REGLAS = List.of(
        r("(mongo/|inicio)", "Inicio", ADM, ABO, SEC, PRA),
        r("dashboard", "W03 · Dashboard", ADM, ABO),
        r("t2/(propuestas$|consultas-para-propuesta)", "W07 · Propuestas", ADM, ABO),
        r("t2/(propuestas-por-responder|propuestas/\\d+/aceptar|propuestas-aceptadas|clientes|siguiente-nro-contrato|contratos$|contratos/\\d+/(cuotas|firma-presencial))",
                "W08 · Contratos y cuotas", ADM, SEC),
        r("t2/casos/\\d+/expediente-mongo", "Expediente digital", ADM, ABO, SEC, PRA),
        r("t2/", "W09 · Expediente nuevo", ADM, ABO),
        r("t3/(casos/\\d+/plazos-pendientes|plazos/\\d+/cumplir)", "Plazos del caso", ADM, ABO, SEC, PRA),
        r("t3/", "W11–W13 · Escritos y resoluciones", ADM, ABO, PRA),
        r("t4/", "W18–W22 · Cobranza y cierre", ADM, SEC),
        r("(citas|disponibilidad)", "W06 · Agendar cita", ADM, SEC, ABO),
        r("", "Panel", ADM, ABO, SEC, PRA));

    /** Devuelve la regla que aplica a la ruta. */
    static Regla regla(String ruta) {
        for (Regla x : REGLAS) if (x.ruta().matcher(ruta).find()) return x;
        return REGLAS.get(REGLAS.size() - 1);
    }

    public static boolean puede(String cargo, String ruta) { return regla(ruta).cargos().contains(cargo); }
}
