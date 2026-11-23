package pe.edu.utp.magallanes.web.t2;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.Sesion;

/**
 * MÓDULO T2 · Contratación — pantallas W07, W08 y W09 del Figma. Rutas bajo /api/panel/** (requieren sesión).
 * W07 propuesta, W08 contrato + cuotas y W09 apertura del expediente (con MongoDB).
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

    // ---------------- W07 · Propuesta
    /** W07 · TRANSACCIÓN: UPDATE PROPUESTA anterior + INSERT PROPUESTA + UPDATE CONSULTA (estado = PROPUESTA). */
    @PostMapping("/propuestas")
    public Map<String, Object> registrarPropuesta(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.registrarPropuesta(datos);
    }

    // ---------------- W09 · Apertura del expediente (SQL Server + MongoDB «expedientes»)
    @GetMapping("/contratos-sin-caso")
    public List<Map<String, Object>> contratosSinCaso() throws SQLException { return repo.contratosSinCaso(); }

    @GetMapping("/consultas/{id}/contrapartes")
    public List<Map<String, Object>> contrapartes(@PathVariable int id) throws SQLException { return repo.contrapartesDeConsulta(id); }

    @GetMapping("/roles")
    public List<Map<String, Object>> roles() throws SQLException { return repo.rolesProcesales(); }

    @GetMapping("/etapas")
    public List<Map<String, Object>> etapas() throws SQLException { return repo.etapasProcesales(); }

    @GetMapping("/siguiente-codigo-caso")
    public Map<String, String> siguienteCodigo() throws SQLException { return Map.of("codigoInterno", repo.siguienteCodigoCaso()); }

    @GetMapping("/casos")
    public List<Map<String, Object>> casos() throws SQLException { return repo.casosRecientes(); }

    @GetMapping("/casos/{id}/expediente-mongo")
    public Map<String, Object> expedienteMongo(@PathVariable int id) { return repo.expedienteMongo(id); }

    /** TRANSACCIÓN W09: CASO + CASO_PARTE (n) + CASO_ETAPA + documento en MongoDB. */
    @PostMapping("/casos")
    public Map<String, Object> abrirCaso(@RequestBody Map<String, Object> datos, HttpSession sesion) throws SQLException {
        return repo.abrirCaso(datos, Sesion.usuario(sesion).nombre());
    }
}
