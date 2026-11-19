package pe.edu.utp.magallanes.web.t2;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * MÓDULO T2 · Contratación — pantallas W07, W08 y W09 del Figma. Rutas bajo /api/panel/** (requieren sesión).
 * W07 (propuesta) y W08 (contrato + cuotas) ya funcionan; W09 lo completa el Compañero 1 (docs/GUIA_COMPANERO_1_T2.md).
 */
@RestController
@RequestMapping("/api/panel/t2")
public class T2Controller {
    private final T2Repositorio repo;

    public T2Controller(T2Repositorio repo) { this.repo = repo; }

    @GetMapping("/propuestas")
    public List<Map<String, Object>> propuestasRecientes() throws SQLException { return repo.propuestasRecientes(); }

    @GetMapping("/consultas-para-propuesta")
    public List<Map<String, Object>> consultasParaPropuesta() throws SQLException { return repo.consultasParaPropuesta(); }

    // ---------------- Paso previo: el cliente acepta la propuesta
    @GetMapping("/propuestas-por-responder")
    public List<Map<String, Object>> propuestasPorResponder() throws SQLException { return repo.propuestasPorResponder(); }

    @PostMapping("/propuestas/{id}/aceptar")
    public Map<String, Object> aceptar(@PathVariable int id) throws SQLException { return repo.aceptarPropuesta(id); }

    // ---------------- W08 · Contrato y cronograma de cuotas
    @GetMapping("/propuestas-aceptadas")
    public List<Map<String, Object>> propuestasAceptadas() throws SQLException { return repo.propuestasAceptadasSinContrato(); }

    @GetMapping("/clientes")
    public List<Map<String, Object>> clientes() throws SQLException { return repo.clientes(); }

    @GetMapping("/siguiente-nro-contrato")
    public Map<String, String> siguienteNro() throws SQLException { return Map.of("nroContrato", repo.siguienteNroContrato()); }

    @GetMapping("/contratos")
    public List<Map<String, Object>> contratos() throws SQLException { return repo.contratosRecientes(); }

    @GetMapping("/contratos/{id}/cuotas")
    public List<Map<String, Object>> cuotas(@PathVariable int id) throws SQLException { return repo.cuotasDelContrato(id); }

    /** TRANSACCIÓN W08: CONTRATO + CUOTA (n) + UPDATE CONSULTA. */
    @PostMapping("/contratos")
    public Map<String, Object> registrarContrato(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.registrarContrato(datos);
    }

    // ---------------- Pendientes (Compañero 1)
    /** W07 · TRANSACCIÓN: UPDATE PROPUESTA anterior + INSERT PROPUESTA + UPDATE CONSULTA (estado = PROPUESTA). */
    @PostMapping("/propuestas")
    public Map<String, Object> registrarPropuesta(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.registrarPropuesta(datos);
    }

    /** W09 · TODO: abrir el caso (CASO + CASO_PARTE + CASO_ETAPA) y crear el expediente en MongoDB. */
    @PostMapping("/casos")
    public Map<String, Object> abrirCaso(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.abrirCaso(datos);
    }
}
