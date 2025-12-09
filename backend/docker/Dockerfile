# Runtime stage - Alpine for security
FROM openjdk:8u212-jre-alpine

# Create tomcat user and group with specific UID/GID for consistency
RUN addgroup -g 1000 tomcat && \
    adduser -D -u 1000 -G tomcat -h /opt/tomcat -s /sbin/nologin tomcat

# Set working directory
WORKDIR /opt/tomcat

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

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
