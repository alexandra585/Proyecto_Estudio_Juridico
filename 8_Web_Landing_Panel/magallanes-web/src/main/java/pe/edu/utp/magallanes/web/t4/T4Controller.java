package pe.edu.utp.magallanes.web.t4;

import jakarta.servlet.http.HttpSession;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.Sesion;

/** MÓDULO T4 · Cobranza y cierre — pantallas W18, W19, W21 y W22 (rutas /api/panel/t4/**, requieren sesión). */
@RestController
@RequestMapping("/api/panel/t4")
public class T4Controller {
    private final T4Repositorio repo;

    public T4Controller(T4Repositorio repo) { this.repo = repo; }

    @GetMapping("/comprobantes")
    public List<Map<String, Object>> comprobantes() throws SQLException { return repo.comprobantes(); }

    @GetMapping("/clientes-con-cuotas")
    public List<Map<String, Object>> clientesConCuotas() throws SQLException { return repo.clientesConCuotas(); }

    @GetMapping("/clientes/{id}/cuotas")
    public List<Map<String, Object>> cuotas(@PathVariable int id) throws SQLException { return repo.cuotasPorFacturar(id); }

    @GetMapping("/series")
    public List<Map<String, Object>> series() throws SQLException { return repo.series(); }

    @GetMapping("/comprobantes-con-saldo")
    public List<Map<String, Object>> conSaldo() throws SQLException { return repo.comprobantesConSaldo(); }

    @GetMapping("/comprobantes/{id}/pagos")
    public List<Map<String, Object>> pagos(@PathVariable int id) throws SQLException { return repo.pagosDe(id); }

    @GetMapping("/casos-para-cerrar")
    public List<Map<String, Object>> casosParaCerrar() throws SQLException { return repo.casosParaCerrar(); }

    @GetMapping("/encuestas-pendientes")
    public List<Map<String, Object>> encuestasPendientes() throws SQLException { return repo.encuestasPendientes(); }

    @GetMapping("/encuestas-resumen")
    public Map<String, Object> encuestasResumen() throws SQLException { return repo.resumenEncuestas(); }

    @GetMapping("/encuestas-respondidas")
    public List<Map<String, Object>> encuestasRespondidas() throws SQLException { return repo.encuestasRespondidas(); }

    @GetMapping("/formulario-encuesta")
    public Map<String, Object> formulario() { return repo.formularioEncuesta(); }

    @GetMapping("/encuestas/{id}/mongo")
    public Map<String, Object> encuestaMongo(@PathVariable int id) { return repo.encuestaMongo(id); }

    /** W18 · COMPROBANTE + DETALLE_COMPROBANTE. */
    @PostMapping("/comprobantes")
    public Map<String, Object> emitir(@RequestBody Map<String, Object> d, HttpSession s) throws SQLException {
        return repo.emitirComprobante(d, Sesion.usuario(s).idEmpleado());
    }

    /** W19 · PAGO + CUOTA + NOTIFICACION. */
    @PostMapping("/pagos")
    public Map<String, Object> pagar(@RequestBody Map<String, Object> d, HttpSession s) throws SQLException {
        return repo.registrarPago(d, Sesion.usuario(s).idEmpleado());
    }

    /** W21 · cierre del caso + ENCUESTA + NOTIFICACION + MongoDB «encuestas». */
    @PostMapping("/casos/{id}/cerrar")
    public Map<String, Object> cerrar(@PathVariable int id, HttpSession s) throws SQLException {
        return repo.cerrarCaso(id, Sesion.usuario(s).nombre());
    }

    /** W22 · respuesta de la encuesta: SQL Server (calificación, NPS) + MongoDB (respuestas completas). */
    @PostMapping("/encuestas/{id}/responder")
    public Map<String, Object> responder(@PathVariable int id, @RequestBody Map<String, Object> d) throws SQLException {
        return repo.responderEncuesta(id, d);
    }
}
