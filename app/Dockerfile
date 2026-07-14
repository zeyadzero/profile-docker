# =============================================================================
# Stage 1 - build the WAR (this stage is discarded from the final image;
# Maven, the JDK, and the full source tree never ship to production)
# =============================================================================
FROM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /build

# Clone the app source. Pin a commit/tag in real usage instead of a branch
# name, so builds are reproducible.
RUN git clone -b main https://github.com/zeyadzero/vprofile.git .

# Placeholders (not real values) get baked into the WAR at this stage -
# they are replaced with real values at container *startup*, never at
# build time, so no credential ever lands in an image layer.
RUN sed -i \
      -e "s#jdbc:mysql://db01:#jdbc:mysql://__DB_HOST__:__DB_PORT__/__DB_NAME__?#" \
      -e "/jdbc.username=/c jdbc.username=__DB_USER__" \
      -e "/jdbc.password=/c jdbc.password=__DB_PASS__" \
      -e "s#memcached.active.host=mc01#memcached.active.host=__MC_HOST__#" \
      -e "s#memcached.standBy.host=mc01#memcached.standBy.host=__MC_HOST__#" \
      -e "s#rabbitmq.address=rmq01#rabbitmq.address=__MQ_HOST__#" \
      src/main/resources/application.properties

RUN mvn -B clean package -DskipTests

# =============================================================================
# Stage 2 - runtime image. Minimal Tomcat, no build tools, no source tree.
# =============================================================================
FROM tomcat:9.0-jre11-temurin-jammy

# Remove Tomcat's default webapps - manager/host-manager/examples/docs are
# a well-known attack surface and have no place in a production image.
RUN rm -rf /usr/local/tomcat/webapps/* \
    && mkdir -p /usr/local/tomcat/webapps/ROOT

# Extract the WAR at build time (not deploy it as a .war) so the entrypoint
# can rewrite the properties file in place at every container start.
COPY --from=build /build/target/*.war /tmp/app.war
RUN cd /usr/local/tomcat/webapps/ROOT \
    && jar -xf /tmp/app.war \
    && rm /tmp/app.war \
    && cp WEB-INF/classes/application.properties /usr/local/tomcat/application.properties.template \
    && rm WEB-INF/classes/application.properties \
    && ln -s /tmp/application.properties WEB-INF/classes/application.properties

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Non-root user. The official Tomcat image runs as root by default -
# we override that.
RUN groupadd --system tomcat \
    && useradd --system --gid tomcat --home-dir /usr/local/tomcat --shell /usr/sbin/nologin tomcat \
    && chown -R tomcat:tomcat /usr/local/tomcat

USER tomcat

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8080/login || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["catalina.sh", "run"]
