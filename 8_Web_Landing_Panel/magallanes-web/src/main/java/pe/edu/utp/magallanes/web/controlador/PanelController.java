package pe.edu.utp.magallanes.web.controlador;

import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;
import pe.edu.utp.magallanes.web.dto.Abogado;
import pe.edu.utp.magallanes.web.dto.DetalleConsulta;
import pe.edu.utp.magallanes.web.dto.Disponibilidad;
import pe.edu.utp.magallanes.web.dto.FilaBandeja;
import pe.edu.utp.magallanes.web.dto.FilaCita;
import pe.edu.utp.magallanes.web.dto.RespuestaCita;
import pe.edu.utp.magallanes.web.dto.SolicitudCita;
import pe.edu.utp.magallanes.web.repositorio.CitaRepositorio;
import pe.edu.utp.magallanes.web.repositorio.ConsultaRepositorio;
import pe.edu.utp.magallanes.web.repositorio.DashboardRepositorio;
import pe.edu.utp.magallanes.web.repositorio.InicioRepositorio;
import pe.edu.utp.magallanes.web.config.Sesion;
import jakarta.servlet.http.HttpSession;

/** Servicios del panel (protegidos por SesionInterceptor): bandeja W04 y agendar cita W06. */
@RestController
@RequestMapping("/api/panel")
public class PanelController {
    private final ConsultaRepositorio consultas;
    private final CitaRepositorio citas;
    private final DashboardRepositorio dashboard;
    private final InicioRepositorio inicio;

    public PanelController(ConsultaRepositorio consultas, CitaRepositorio citas, DashboardRepositorio dashboard, InicioRepositorio inicio) {
        this.consultas = consultas;
        this.citas = citas;
        this.dashboard = dashboard;
        this.inicio = inicio;
    }

    /** Inicio del panel: pendientes del día según el rol (empleado.cargo) del usuario que inició sesión. */
    @GetMapping("/inicio")
    public java.util.Map<String, Object> inicio(HttpSession s) throws SQLException {
        return inicio.inicio(Sesion.usuario(s));
    }

    /** W03 · Dashboard gerencial: indicadores calculados por las vistas vw_dash_* de SQL Server. */
    @GetMapping("/dashboard")
    public java.util.Map<String, Object> dashboard(@RequestParam(required = false) String desde,
                                                   @RequestParam(required = false) String hasta) throws SQLException {
        LocalDate h = (hasta == null || hasta.isBlank()) ? LocalDate.now() : LocalDate.parse(hasta);
        LocalDate d = (desde == null || desde.isBlank()) ? h.withDayOfYear(1) : LocalDate.parse(desde);   // por defecto: este año
        if (d.isAfter(h)) throw new ReglaNegocioException("La fecha «desde» no puede ser posterior a «hasta».");
        return dashboard.todo(d, h);
    }

    @GetMapping("/consultas")
    public List<FilaBandeja> bandeja(@RequestParam(required = false) String estado,
                                     @RequestParam(required = false) String canal) throws SQLException {
        return consultas.bandeja(estado, canal);
    }

    @GetMapping("/consultas/{id}")
    public DetalleConsulta detalle(@PathVariable int id) throws SQLException {
        return consultas.detalle(id);
    }

    @GetMapping("/abogados")
    public List<Abogado> abogados(@RequestParam int materia) throws SQLException {
        return citas.abogadosPorMateria(materia);
    }

    @GetMapping("/disponibilidad")
    public Disponibilidad disponibilidad(@RequestParam int abogado, @RequestParam String fecha) throws SQLException {
        try {
            return citas.disponibilidad(abogado, LocalDate.parse(fecha));
        } catch (java.time.format.DateTimeParseException e) {
            throw new ReglaNegocioException("Fecha no válida.");
        }
    }

    @PostMapping("/citas")
    public RespuestaCita agendar(@RequestBody SolicitudCita s) throws SQLException {
        if (s.idConsulta() == null || s.idAbogado() == null || s.fecha() == null || s.hora() == null)
            throw new ReglaNegocioException("Complete abogado, fecha y hora.");
        return citas.agendar(s);
    }

    @GetMapping("/citas")
    public List<FilaCita> proximas() throws SQLException {
        return citas.proximas();
    }
}
