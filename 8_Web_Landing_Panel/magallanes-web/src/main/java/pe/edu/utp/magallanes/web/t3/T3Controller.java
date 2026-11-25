package pe.edu.utp.magallanes.web.t3;

import jakarta.servlet.http.HttpSession;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.Sesion;
import pe.edu.utp.magallanes.web.dto.SesionUsuario;

/** MÓDULO T3 · Gestión del expediente — pantallas W11, W12 y W13 (rutas /api/panel/t3/**, requieren sesión). */
@RestController
@RequestMapping("/api/panel/t3")
public class T3Controller {
    private final T3Repositorio repo;
    private final pe.edu.utp.magallanes.web.expediente.ExpedienteRepositorio expedientes;

    public T3Controller(T3Repositorio repo, pe.edu.utp.magallanes.web.expediente.ExpedienteRepositorio expedientes) {
        this.repo = repo; this.expedientes = expedientes;
    }

    /** Ficha completa del expediente (etapas, semáforo de plazos, línea de tiempo, documentos y versiones, bitácora). */
    @GetMapping("/casos/{id}/ficha")
    public Map<String, Object> ficha(@PathVariable int id) throws SQLException { return expedientes.ficha(id, false); }

    /** Todos los casos (activos y cerrados) para consultar su expediente. */
    @GetMapping("/casos-todos")
    public List<Map<String, Object>> casosTodos() throws SQLException { return repo.casosTodos(); }

    @GetMapping("/casos-activos")
    public List<Map<String, Object>> casosActivos() throws SQLException { return repo.casosActivos(); }

    @GetMapping("/casos/{id}/jurisprudencia")
    public List<Map<String, Object>> jurisprudencia(@PathVariable int id) throws SQLException { return repo.jurisprudenciaDelCaso(id); }

    @GetMapping("/casos/{id}/documentos")
    public List<Map<String, Object>> documentos(@PathVariable int id) throws SQLException { return repo.documentosDelCaso(id); }

    @GetMapping("/casos/{id}/presentaciones")
    public List<Map<String, Object>> presentaciones(@PathVariable int id) throws SQLException { return repo.presentacionesDelCaso(id); }

    @GetMapping("/casos/{id}/plazos-pendientes")
    public List<Map<String, Object>> plazosPendientes(@PathVariable int id) throws SQLException { return repo.plazosPendientes(id); }

    /** Marca el plazo como cumplido (opcional: idPresentacion con la que se cumplió). */
    @PostMapping("/plazos/{id}/cumplir")
    public Map<String, Object> cumplirPlazo(@PathVariable int id, @RequestBody(required = false) Map<String, Object> d, HttpSession s) throws SQLException {
        return repo.cumplirPlazo(id, d == null ? null : pe.edu.utp.magallanes.web.config.Datos.enteroOpcional(d, "idPresentacion"), Sesion.usuario(s).nombre());
    }

    @GetMapping("/casos/{id}/resoluciones")
    public List<Map<String, Object>> resoluciones(@PathVariable int id) throws SQLException { return repo.resolucionesDelCaso(id); }

    @GetMapping("/entidades")
    public List<Map<String, Object>> entidades() throws SQLException { return repo.entidades(); }

    @GetMapping("/empleados")
    public List<Map<String, Object>> empleados() throws SQLException { return repo.empleados(); }

    @GetMapping("/vencimiento")
    public Map<String, String> vencimiento(@RequestParam String inicio, @RequestParam int dias, @RequestParam String tipo) throws SQLException {
        return Map.of("vence", repo.calcularVencimiento(LocalDate.parse(inicio), dias, tipo).toString());
    }

    @GetMapping("/archivos/{id}")
    public Map<String, Object> archivo(@PathVariable String id) { return repo.archivoMongo(id); }

    /** W11 · DOCUMENTO_LEGAL + DOCUMENTO_JURISPRUDENCIA + MongoDB «archivos». */
    @PostMapping("/escritos")
    public Map<String, Object> escrito(@RequestBody Map<String, Object> d, HttpSession s) throws SQLException {
        SesionUsuario u = Sesion.usuario(s);
        return repo.registrarEscrito(d, u.idEmpleado(), u.nombre());
    }

    /** W12 · PRESENTACION + UPDATE DOCUMENTO_LEGAL. */
    @PostMapping("/presentaciones")
    public Map<String, Object> presentacion(@RequestBody Map<String, Object> d, HttpSession s) throws SQLException {
        SesionUsuario u = Sesion.usuario(s);
        return repo.registrarPresentacion(d, u.idEmpleado(), u.nombre());
    }

    /** W13 · RESOLUCION + PLAZO + MongoDB «archivos». */
    @PostMapping("/resoluciones")
    public Map<String, Object> resolucion(@RequestBody Map<String, Object> d, HttpSession s) throws SQLException {
        return repo.registrarResolucion(d, Sesion.usuario(s).nombre());
    }
}
