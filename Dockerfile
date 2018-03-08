FROM tomcat:8-jre8
ADD evaluation/build/libs/evaluation-0.0.1-SNAPSHOT.war  /usr/local/tomcat/webapps/
