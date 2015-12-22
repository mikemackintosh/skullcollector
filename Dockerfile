FROM     ubuntu:latest

# ---------------- #
#   Installation   #
# ---------------- #

# Install all prerequisites
RUN     apt-get -y install software-properties-common
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get -y update
RUN     apt-get -y install python-django-tagging python-simplejson python-memcache python-ldap python-cairo python-pysqlite2 python-support \
                           python-pip gunicorn supervisor nginx-light nodejs git wget curl openjdk-7-jre build-essential python-dev


RUN     pip install Twisted==11.1.0
RUN     pip install Django==1.5
RUN     pip install pytz

# Install JVM
#RUN     cd ~ && add-apt-repository -y ppa:webupd8team/java
#RUN     cd ~ && apt-get update && apt-get -y --force-yes install oracle-java8-installer
RUN setcap 'cap_net_bind_service=+ep' \
    /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java

# Install Elasticsearch
RUN     cd ~ && wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.4.4.deb
RUN     cd ~ && dpkg -i elasticsearch-1.4.4.deb && rm elasticsearch-1.4.4.deb


# Checkout the stable branches of Graphite, Carbon and Whisper and install from there
RUN     mkdir /src
RUN     git clone https://github.com/graphite-project/whisper.git /src/whisper            &&\
        cd /src/whisper                                                                   &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install


RUN     git clone https://github.com/graphite-project/carbon.git /src/carbon              &&\
        cd /src/carbon                                                                    &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install


RUN     git clone https://github.com/graphite-project/graphite-web.git /src/graphite-web  &&\
        cd /src/graphite-web                                                              &&\
        git checkout 0.9.x                                                                &&\
        python setup.py install


# Install StatsD
RUN     git clone https://github.com/etsy/statsd.git /src/statsd                                    &&\
        cd /src/statsd                                                                              &&\
        git checkout v0.7.2


# Install Grafana
RUN     mkdir /src/grafana                                                                                    &&\
        mkdir /opt/grafana                                                                                    &&\
        wget https://grafanarel.s3.amazonaws.com/builds/grafana-2.1.3.linux-x64.tar.gz -O /src/grafana.tar.gz &&\
        tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1                                     &&\
        rm /src/grafana.tar.gz &&\
        cd /opt/grafana && npm install ini


# Install Logstash
RUN     cd ~ && echo 'deb http://packages.elasticsearch.org/logstash/1.5/debian stable main'        |\
        tee /etc/apt/sources.list.d/logstash.list                                                   &&\
        apt-get update                                                                              &&\
        apt-get -y --force-yes install logstash


# Install Kibana
RUN     mkdir -p /opt/kibana                                                                          &&\
        cd ~ && wget https://download.elasticsearch.org/kibana/kibana/kibana-4.0.1-linux-x64.tar.gz   &&\
        tar xvf kibana-*.tar.gz -C /opt/kibana --strip-components=1


# ----------------- #
#   Configuration   #
# ----------------- #

# Configure Elasticsearch
ADD     ./elasticsearch/run /usr/local/bin/run_elasticsearch
RUN     chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
RUN     mkdir -p /tmp/elasticsearch && chown elasticsearch:elasticsearch /tmp/elasticsearch

# Confiure StatsD
ADD     ./statsd/config.js /src/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/initial_data.json /opt/graphite/webapp/graphite/initial_data.json
ADD     ./graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf

# Configure Logstash
ADD     ./logstash/* /etc/logstash/conf.d/
RUN     mkdir -p /var/log/logstash
RUN     mkdir -p /var/lib/logstash
RUN     chown -R logstash /var/lib/logstash

# Configure Kibana
ADD     ./kibana/kibana.yml /opt/kibana/config/kibana.yml
RUN     chown -R www-data /opt/kibana

# Configure Grafana
ADD     ./grafana/custom.ini /opt/grafana/conf/custom.ini

# Add the default dashboards
RUN     mkdir /src/dashboards
ADD     ./grafana/dashboards/* /src/dashboards/
RUN     mkdir /src/dashboard-loader
ADD     ./grafana/dashboard-loader/dashboard-loader.js /src/dashboard-loader/

# Configure nginx and supervisord
ADD     ./nginx/nginx.conf /etc/nginx/nginx.conf
ADD     ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ---------------- #
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80
EXPOSE  81
EXPOSE  443

# StatsD UDP port
EXPOSE  8125/udp
EXPOSE  8125/tcp

# StatsD Management port
EXPOSE  8126
EXPOSE  8080
EXPOSE  8000

EXPOSE  3000
EXPOSE  3001

# Logstash/Elasticsearch
# BAD IDEA TO EXPOSE
# EXPOSE  9200

# Syslog
EXPOSE  514
EXPOSE  514/udp

# -------- #
#   Run!   #
# -------- #
ADD ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD     ["/entrypoint.sh"]
