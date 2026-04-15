FROM jenkins/jenkins:lts

ENV JAVA_OPTS=-Djenkins.install.runSetupWizard=false

COPY --chown=jenkins:jenkins plugins.txt /var/jenkins_home/

RUN jenkins-plugin-cli -f /var/jenkins_home/plugins.txt

USER root

RUN apt-get update && apt-get install make build-essential -y

USER jenkins
