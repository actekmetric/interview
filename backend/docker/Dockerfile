# Runtime stage - Eclipse Temurin (recommended OpenJDK distribution)
# Using specific Java version to ensure consistent, reproducible builds
# Update this tag periodically to get latest security patches
# Last updated: 2025-12-13
# Note: Upgrading libpng until base image is updated with Alpine 3.23+
FROM eclipse-temurin:25-jre-alpine

# Upgrade libpng to fix CVE-2025-64720, CVE-2025-65018, CVE-2025-66293
# Remove this once base image includes Alpine 3.23+ with libpng 1.6.53+
RUN apk upgrade --no-cache libpng

# Create tomcat user and group with specific UID/GID for consistency
RUN addgroup -g 1000 tomcat && \
    adduser -D -u 1000 -G tomcat -h /opt/tomcat -s /sbin/nologin tomcat

# Set working directory
WORKDIR /opt/tomcat

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Download OpenTelemetry Java agent (curl is removed after download)
ARG OTEL_AGENT_VERSION=1.32.0
RUN apk add --no-cache curl && \
    mkdir -p /opt/opentelemetry && \
    curl -L -o /opt/opentelemetry/javaagent.jar \
    "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar" && \
    apk del curl

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
