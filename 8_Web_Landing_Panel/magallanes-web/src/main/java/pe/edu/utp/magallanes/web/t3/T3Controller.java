package pe.edu.utp.magallanes.web.t3;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** MÓDULO T3 · Gestión del expediente (COMPAÑERO 2) — W11, W12 y W13. Ver docs/GUIA_COMPANERO_2_T3.md. */
@RestController
@RequestMapping("/api/panel/t3")
public class T3Controller {
    private final T3Repositorio repo;

    public T3Controller(T3Repositorio repo) { this.repo = repo; }

    /** Ejemplo ya funcionando: casos activos (combo de W11). */
    @GetMapping("/casos-activos")
    public List<Map<String, Object>> casosActivos() throws SQLException { return repo.casosActivos(); }

    /** W11 · TODO: escrito + jurisprudencia citada + archivo en MongoDB. */
    @PostMapping("/escritos")
    public Map<String, Object> registrarEscrito(@RequestBody Map<String, Object> d) throws SQLException { return repo.registrarEscrito(d); }

    /** W12 · TODO: presentación (cargo de mesa de partes). */
    @PostMapping("/presentaciones")
    public Map<String, Object> registrarPresentacion(@RequestBody Map<String, Object> d) throws SQLException { return repo.registrarPresentacion(d); }

    /** W13 · TODO: resolución + plazo (+ PDF en MongoDB). */
    @PostMapping("/resoluciones")
    public Map<String, Object> registrarResolucion(@RequestBody Map<String, Object> d) throws SQLException { return repo.registrarResolucion(d); }
}
