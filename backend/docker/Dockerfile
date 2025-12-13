# Runtime stage - Eclipse Temurin (recommended OpenJDK distribution)
FROM eclipse-temurin:17-jre-alpine

# Update Alpine packages to get latest security patches (including libpng fix)
RUN apk upgrade --no-cache

# Create tomcat user and group with specific UID/GID for consistency
RUN addgroup -g 1000 tomcat && \
    adduser -D -u 1000 -G tomcat -h /opt/tomcat -s /sbin/nologin tomcat

# Set working directory
WORKDIR /opt/tomcat

# Install dumb-init and curl for proper signal handling and downloading agent
RUN apk add --no-cache dumb-init curl

# Download OpenTelemetry Java agent
ARG OTEL_AGENT_VERSION=1.32.0
RUN mkdir -p /opt/opentelemetry && \
    curl -L -o /opt/opentelemetry/javaagent.jar \
    "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar"

# Copy entrypoint script
COPY docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Copy JAR file (will be built by CI)
COPY target/*.jar /opt/tomcat/backend.jar

# Change ownership to tomcat user
RUN chown -R tomcat:tomcat /opt/tomcat

# Switch to non-root user
USER tomcat

# Expose default Spring Boot port
EXPOSE 8080

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Run the entrypoint script
CMD ["/usr/local/bin/docker-entrypoint.sh"]
