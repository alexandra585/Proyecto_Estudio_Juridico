package pe.edu.utp.magallanes.web.t2;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * MÓDULO T2 · Contratación y apertura (COMPAÑERO 1) — pantallas W07, W08 y W09 del Figma.
 * Ver docs/GUIA_COMPANERO_1_T2.md. Las rutas quedan bajo /api/panel/** (requieren sesión).
 */
@RestController
@RequestMapping("/api/panel/t2")
public class T2Controller {
    private final T2Repositorio repo;

    public T2Controller(T2Repositorio repo) { this.repo = repo; }

    /** Ejemplo ya funcionando: consultas AGENDADAS/ATENDIDAS listas para propuesta (para el combo de W07). */
    @GetMapping("/consultas-para-propuesta")
    public List<Map<String, Object>> consultasParaPropuesta() throws SQLException {
        return repo.consultasParaPropuesta();
    }

    /** W07 · TODO: registrar la propuesta (INSERT PROPUESTA + UPDATE CONSULTA estado = PROPUESTA). */
    @PostMapping("/propuestas")
    public Map<String, Object> registrarPropuesta(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.registrarPropuesta(datos);
    }

    /** W08 · TODO: contrato + cuotas (maestro-detalle). */
    @PostMapping("/contratos")
    public Map<String, Object> registrarContrato(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.registrarContrato(datos);
    }

    /** W09 · TODO: abrir el caso (CASO + CASO_PARTE + CASO_ETAPA) y crear el expediente en MongoDB. */
    @PostMapping("/casos")
    public Map<String, Object> abrirCaso(@RequestBody Map<String, Object> datos) throws SQLException {
        return repo.abrirCaso(datos);
    }
}
