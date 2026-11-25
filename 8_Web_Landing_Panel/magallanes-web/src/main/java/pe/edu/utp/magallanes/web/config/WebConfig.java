package pe.edu.utp.magallanes.web.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new SesionInterceptor()).addPathPatterns("/api/panel/**");
        // Portal del cliente: todo menos el ingreso exige sesión de cliente
        registry.addInterceptor(new pe.edu.utp.magallanes.web.portal.ClienteInterceptor())
                .addPathPatterns("/api/portal/**").excludePathPatterns("/api/portal/login");
    }

    /** Direcciones cortas: /portal y /panel abren su página de inicio. */
    @Override
    public void addViewControllers(org.springframework.web.servlet.config.annotation.ViewControllerRegistry registry) {
        registry.addRedirectViewController("/portal", "/portal/index.html");
        registry.addRedirectViewController("/portal/", "/portal/index.html");
        registry.addRedirectViewController("/panel", "/panel/login.html");
        registry.addRedirectViewController("/panel/", "/panel/login.html");
    }

    /** BCrypt: compara la contraseña escrita con usuario.contrasena_hash (nunca se guarda la contraseña). */
    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
