package pe.edu.utp.magallanes.web.t4;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** MÓDULO T4 · Cobranza y cierre (COMPAÑERO 3) — W18, W19, W21 y W22. Ver docs/GUIA_COMPANERO_3_T4.md. */
@RestController
@RequestMapping("/api/panel/t4")
public class T4Controller {
    private final T4Repositorio repo;

    public T4Controller(T4Repositorio repo) { this.repo = repo; }

    /** Ejemplo ya funcionando: saldo de cada comprobante (vista vw_comprobante_saldo). */
    @GetMapping("/comprobantes")
    public List<Map<String, Object>> comprobantes() throws SQLException { return repo.comprobantes(); }

    /** W18 · TODO: comprobante + detalle (maestro-detalle; el trigger asigna el correlativo de la serie). */
    @PostMapping("/comprobantes")
    public Map<String, Object> emitirComprobante(@RequestBody Map<String, Object> d) throws SQLException { return repo.emitirComprobante(d); }

    /** W19 · TODO: pago + notificación de constancia. */
    @PostMapping("/pagos")
    public Map<String, Object> registrarPago(@RequestBody Map<String, Object> d) throws SQLException { return repo.registrarPago(d); }

    /** W21/W22 · TODO: cierre del caso + encuesta (resumen en SQL, respuesta completa en MongoDB). */
    @PostMapping("/encuestas")
    public Map<String, Object> responderEncuesta(@RequestBody Map<String, Object> d) throws SQLException { return repo.responderEncuesta(d); }
}
