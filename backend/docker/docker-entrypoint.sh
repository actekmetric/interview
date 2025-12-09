#!/bin/sh
set -e

# Default JVM options if not provided
DEFAULT_JVM_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Use provided JVM_OPTS or fall back to defaults
JVM_OPTS="${JVM_OPTS:-$DEFAULT_JVM_OPTS}"

echo "Starting application with JVM options: $JVM_OPTS"

# Execute the JAR file with JVM options
exec java $JVM_OPTS -jar /opt/tomcat/backend.jar "$@"
