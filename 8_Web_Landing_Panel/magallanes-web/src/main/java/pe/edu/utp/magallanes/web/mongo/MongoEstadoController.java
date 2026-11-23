package pe.edu.utp.magallanes.web.mongo;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Indicador para las pantallas: ¿está encendido MongoDB? (GET /api/panel/mongo/estado). */
@RestController
public class MongoEstadoController {
    private final MongoDocumentos mongo;

    public MongoEstadoController(MongoDocumentos mongo) { this.mongo = mongo; }

    @GetMapping("/api/panel/mongo/estado")
    public Map<String, Object> estado() {
        return Map.of("disponible", mongo.disponible(), "base", "magallanes_montero");
    }
}
