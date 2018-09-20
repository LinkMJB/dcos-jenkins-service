FROM jenkins/jenkins:2.138.1
WORKDIR /tmp

# Environment variables used throughout this Dockerfile
#
# $JENKINS_HOME     will be the final destination that Jenkins will use as its
#                   data directory. This cannot be populated before Marathon
#                   has a chance to create the host-container volume mapping.
#
ENV JENKINS_FOLDER /usr/share/jenkins

# Build Args
ARG LIBMESOS_DOWNLOAD_URL=https://downloads.mesosphere.io/libmesos-bundle/libmesos-bundle-1.11.0.tar.gz
ARG LIBMESOS_DOWNLOAD_SHA256=bd4a785393f0477da7f012bf9624aa7dd65aa243c94d38ffe94adaa10de30274
ARG BLUEOCEAN_VERSION=1.6.2
ARG JENKINS_STAGING=/usr/share/jenkins/ref/
ARG JENKINS_DCOS_HOME=/var/jenkinsdcos_home
ARG user=nobody
ARG uid=99
ARG gid=99

ENV JENKINS_HOME $JENKINS_DCOS_HOME
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log
# Default policy according to https://wiki.jenkins.io/display/JENKINS/Configuring+Content+Security+Policy
ENV JENKINS_CSP_OPTS="sandbox; default-src 'none'; img-src 'self'; style-src 'self';"

USER root

# install dependencies
RUN apt-get update && apt-get install -y nginx python zip jq
# libmesos bundle
RUN curl -fsSL "$LIBMESOS_DOWNLOAD_URL" -o libmesos-bundle.tar.gz  \
  && echo "$LIBMESOS_DOWNLOAD_SHA256 libmesos-bundle.tar.gz" | sha256sum -c - \
  && tar -C / -xzf libmesos-bundle.tar.gz  \
  && rm libmesos-bundle.tar.gz
# update to newer git version
RUN echo "deb http://ftp.debian.org/debian testing main" >> /etc/apt/sources.list \
  && apt-get update && apt-get -t testing install -y git

RUN mkdir -p "${JENKINS_HOME}" "${JENKINS_FOLDER}/war"

# Override the default property for DNS lookup caching
RUN echo 'networkaddress.cache.ttl=60' >> ${JAVA_HOME}/jre/lib/security/java.security

# bootstrap scripts and needed dir setup
COPY scripts/bootstrap.py /usr/local/jenkins/bin/bootstrap.py
COPY scripts/export-libssl.sh /usr/local/jenkins/bin/export-libssl.sh
COPY scripts/dcos-account.sh /usr/local/jenkins/bin/dcos-account.sh
COPY scripts/run.sh /usr/local/jenkins/bin/run.sh

# nginx setup
RUN mkdir -p /var/log/nginx/jenkins /var/nginx/
COPY conf/nginx/nginx.conf /var/nginx/nginx.conf

# jenkins setup
COPY conf/jenkins/config.xml "${JENKINS_STAGING}/config.xml"
COPY conf/jenkins/jenkins.model.JenkinsLocationConfiguration.xml "${JENKINS_STAGING}/jenkins.model.JenkinsLocationConfiguration.xml"
COPY conf/jenkins/nodeMonitors.xml "${JENKINS_STAGING}/nodeMonitors.xml"
COPY scripts/init.groovy.d/mesos-auth.groovy "${JENKINS_STAGING}/init.groovy.d/mesos-auth.groovy"

# add plugins
RUN /usr/local/bin/install-plugins.sh       \
  blueocean-bitbucket-pipeline:${BLUEOCEAN_VERSION}    \
  blueocean-commons:${BLUEOCEAN_VERSION}    \
  blueocean-config:${BLUEOCEAN_VERSION}     \
  blueocean-dashboard:${BLUEOCEAN_VERSION}  \
  blueocean-events:${BLUEOCEAN_VERSION}     \
  blueocean-git-pipeline:${BLUEOCEAN_VERSION}          \
  blueocean-github-pipeline:${BLUEOCEAN_VERSION}       \
  blueocean-i18n:${BLUEOCEAN_VERSION}       \
  blueocean-jwt:${BLUEOCEAN_VERSION}        \
  blueocean-jira:${BLUEOCEAN_VERSION}       \
  blueocean-personalization:${BLUEOCEAN_VERSION}        \
  blueocean-pipeline-api-impl:${BLUEOCEAN_VERSION}      \
  blueocean-pipeline-editor:${BLUEOCEAN_VERSION}        \
  blueocean-pipeline-scm-api:${BLUEOCEAN_VERSION}       \
  blueocean-rest-impl:${BLUEOCEAN_VERSION}  \
  blueocean-rest:${BLUEOCEAN_VERSION}       \
  blueocean-web:${BLUEOCEAN_VERSION}        \
  blueocean:${BLUEOCEAN_VERSION}            \
  ant:1.8                        \
  ansicolor:0.5.2                \
  antisamy-markup-formatter:1.5  \
  artifactory:2.16.2             \
  authentication-tokens:1.3      \
  azure-credentials:1.6.0        \
  azure-vm-agents:0.7.3          \
  branch-api:2.0.20              \
  build-name-setter:1.6.9        \
  build-timeout:1.19             \
  cloudbees-folder:6.5.1         \
  conditional-buildstep:1.3.6    \
  config-file-provider:2.18      \
  copyartifact:1.39.1            \
  cvs:2.14                       \
  docker-build-publish:1.3.2     \
  docker-workflow:1.17           \
  durable-task:1.25              \
  ec2:1.39                       \
  embeddable-build-status:1.9    \
  external-monitor-job:1.7       \
  ghprb:1.42.0                   \
  git:3.9.1                      \
  git-client:2.7.3               \
  git-server:1.7                 \
  github:1.29.2                  \
  github-api:1.92                \
  github-branch-source:2.3.6     \
  github-organization-folder:1.6 \
  gitlab-plugin:1.5.9            \
  gradle:1.29                    \
  greenballs:1.15                \
  handlebars:1.1.1               \
  ivy:1.28                       \
  jackson2-api:2.8.11.3          \
  job-dsl:1.70                   \
  jobConfigHistory:2.18          \
  jquery:1.12.4-0                \
  ldap:1.20                      \
  mapdb-api:1.0.9.0              \
  marathon:1.6.0                 \
  matrix-auth:2.3                \
  matrix-project:1.13            \
  maven-plugin:3.1.2             \
  mesos:0.17.1                   \
  metrics:4.0.2.2                \
  metrics-graphite:3.0           \
  monitoring:1.73.1              \
  nant:1.4.3                     \
  node-iterator-api:1.5.0        \
  pam-auth:1.4                   \
  parameterized-trigger:2.35.2   \
  pipeline-build-step:2.7        \
  pipeline-github-lib:1.0        \
  pipeline-input-step:2.8        \
  pipeline-milestone-step:1.3.1  \
  pipeline-model-api:1.3.2       \
  pipeline-model-definition:1.3.2 \
  pipeline-model-extensions:1.3.2 \
  pipeline-rest-api:2.10         \
  pipeline-stage-step:2.3        \
  pipeline-stage-view:2.10       \
  plain-credentials:1.4          \
  prometheus:2.0.0               \
  rebuild:1.28                   \
  role-strategy:2.9.0            \
  run-condition:1.2              \
  s3:0.11.2                      \
  saferestart:0.3                \
  saml:1.0.7                     \
  scm-api:2.2.7                  \
  ssh-agent:1.16                 \
  ssh-slaves:1.28                \
  subversion:2.11.1              \
  timestamper:1.8.10             \
  translation:1.16               \
  variant:1.1                    \
  windows-slaves:1.3.1           \
  workflow-aggregator:2.5        \
  workflow-api:2.27              \
  workflow-basic-steps:2.8.2     \
  workflow-cps:2.55              \
  workflow-cps-global-lib:2.11   \
  workflow-durable-task-step:2.21 \
  workflow-job:2.25              \
  workflow-multibranch:2.20      \
  workflow-scm-step:2.6          \
  workflow-step-api:2.16         \
  workflow-support:2.20

# change the config for $user
# alias uid to $uid - should match nobody for host
# set home directory to JENKINS_HOME
# change gid to $gid
RUN groupadd -g ${gid} nobody \
    && usermod -u ${uid} -g ${gid} ${user} \
    && usermod -a -G users nobody \
    && echo "nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin" >> /etc/passwd

RUN chmod -R ugo+rw "$JENKINS_HOME" "${JENKINS_FOLDER}" \
    && chmod -R ugo+r "${JENKINS_STAGING}" \
    && chmod -R ugo+rx /usr/local/jenkins/bin/ \
    && chmod -R ugo+rw /var/jenkins_home/ \
    && chmod -R ugo+rw /var/lib/nginx/ /var/nginx/ /var/log/nginx \
    && chmod ugo+rx /usr/local/jenkins/bin/*

USER ${user}

# disable first-run wizard
RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

CMD /usr/local/jenkins/bin/run.sh
