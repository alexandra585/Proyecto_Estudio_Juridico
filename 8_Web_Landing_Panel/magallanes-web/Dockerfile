# Imagen de la aplicación web Magallanes-Montero (Spring Boot, Java 17)
# Etapa 1: compila el .jar con Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

# Etapa 2: solo el runtime de Java + el .jar
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
# La configuración (DB_HOST, DB_PASSWORD, MONGO_URI...) llega por variables de entorno de Azure
ENV APP_PORT=8080
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
