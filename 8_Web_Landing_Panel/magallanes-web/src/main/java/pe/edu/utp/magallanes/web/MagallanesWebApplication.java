package pe.edu.utp.magallanes.web;

import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Landing Page (W01) + Panel del estudio (W02–W22) + Dashboard (W03).
 * Abra http://localhost:8080 después de ejecutar: mvn spring-boot:run (o el botón Run de VS Code).
 */
@SpringBootApplication
public class MagallanesWebApplication {
    public static void main(String[] args) {
        cargarEnv();
        SpringApplication.run(MagallanesWebApplication.class, args);
    }

    /**
     * Lee .env.example y luego .env (el .env gana) de la carpeta magallanes-web, sin importar desde qué carpeta
     * se ejecute (VS Code, mvn, otra copia del proyecto). Cada CLAVE=valor queda disponible para
     * application.properties como ${CLAVE}. Una variable de entorno de Windows con el mismo nombre tiene prioridad.
     */
    static void cargarEnv() {
        Path home = carpetaDelProyecto();
        for (String nombre : new String[] { ".env.example", ".env" }) {
            Path f = home.resolve(nombre);
            if (!Files.isRegularFile(f)) continue;
            Properties p = new Properties();
            try (Reader r = Files.newBufferedReader(f, StandardCharsets.UTF_8)) {
                p.load(r);
            } catch (Exception e) {
                System.err.println("No se pudo leer " + f + ": " + e.getMessage());
                continue;
            }
            p.forEach((k, v) -> {
                String clave = k.toString().trim(), valor = v.toString().trim();
                if (System.getenv(clave) == null) System.setProperty(clave, valor);
            });
            System.out.println("Configuración leída de " + f);
        }
    }

    /** Carpeta magallanes-web: se sube desde target/classes hasta encontrar pom.xml (o .env.example). */
    static Path carpetaDelProyecto() {
        try {
            Path p = Paths.get(MagallanesWebApplication.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            for (int i = 0; i < 5 && p != null; i++, p = p.getParent()) {
                if (Files.exists(p.resolve("pom.xml")) || Files.exists(p.resolve(".env.example"))) return p;
            }
        } catch (Exception ignorada) { /* se usa la carpeta actual */ }
        return Paths.get(".").toAbsolutePath();
    }
}
