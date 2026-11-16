package pe.edu.utp.magallanes.web;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Landing Page (W01) + Panel del estudio: Login (W02), Bandeja de consultas (W04) y Agendar cita (W06).
 * Abra http://localhost:8080 después de ejecutar: mvn spring-boot:run
 */
@SpringBootApplication
public class MagallanesWebApplication {
    public static void main(String[] args) {
        SpringApplication.run(MagallanesWebApplication.class, args);
    }
}
