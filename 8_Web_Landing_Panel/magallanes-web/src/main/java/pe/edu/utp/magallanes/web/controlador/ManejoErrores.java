package pe.edu.utp.magallanes.web.controlador;

import java.sql.SQLException;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import pe.edu.utp.magallanes.web.config.ReglaNegocioException;

/** Convierte los errores en JSON {"error": "..."} para que la página los muestre. */
@RestControllerAdvice
public class ManejoErrores {

    @ExceptionHandler(ReglaNegocioException.class)
    public ResponseEntity<Map<String, String>> regla(ReglaNegocioException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }

    /** Errores de SQL Server: CHECK, FK, UNIQUE o THROW de un trigger. La transacción ya se deshizo (ROLLBACK). */
    @ExceptionHandler(SQLException.class)
    public ResponseEntity<Map<String, String>> sql(SQLException e) {
        return ResponseEntity.badRequest().body(Map.of("error",
                "SQL Server rechazó la operación y se hizo ROLLBACK: " + e.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> otro(Exception e) {
        return ResponseEntity.internalServerError().body(Map.of("error", "Error inesperado: " + e.getMessage()));
    }
}
