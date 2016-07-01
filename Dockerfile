FROM phusion/baseimage:0.9.18
MAINTAINER Damien Garros <dgarros@gmail.com>

RUN     apt-get -y update && \
        apt-get -y upgrade && \
        apt-get clean   &&\
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# dependencies
RUN     apt-get -y update && \
        apt-get -y install \
        git adduser libfontconfig wget make curl && \
        apt-get clean   &&\
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN     rm -f /etc/service/sshd/down
RUN     /usr/sbin/enable_insecure_key

# Latest version
ENV GRAFANA_VERSION 3.0.4-1464167696
ENV INFLUXDB_VERSION 1.0.0-beta1
ENV TELEGRAF_VERSION 0.13.1
# ENV FLUENTD_VERSION 0.12.20
# ENV FLUENTD_JUNIPER_VERSION 0.2.11

RUN     apt-get -y update && \
        apt-get -y install \
            build-essential \
            python-simplejson \
            python-support \
            python-dev \
            python-yaml \
            python-pip \
            python-dev \
            libxml2-dev \
            libxslt-dev \
            tcpdump \
            tree \
            nginx-light \
            snmp \
            zlib1g-dev \
            libffi-dev \
            libssl-dev && \
        apt-get clean   &&\
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

        # ruby \
        # ruby-dev \

# # Install some python modules
RUN     pip install influxdb && \
        pip install xmltodict && \
        pip install pexpect && \
        easy_install pysnmp && \
        pip install lxml && \
        pip install python-crontab && \
        pip install junos-eznc && \
        pip install pytest && \
        pip install mock &&\
        pip install cryptography==1.2.1

RUN     mkdir /src

########################
### Install Grafana
########################
RUN     mkdir /src/grafana                                                                                    &&\
        mkdir /opt/grafana                                                                                    &&\
        wget https://grafanarel.s3.amazonaws.com/builds/grafana-${GRAFANA_VERSION}.linux-x64.tar.gz -O /src/grafana.tar.gz &&\
        tar -xzf /src/grafana.tar.gz -C /opt/grafana --strip-components=1                                     &&\
        rm /src/grafana.tar.gz

RUN     /opt/grafana/bin/grafana-cli plugins install grafana-piechart-panel

########################
### Install Fluentd  ###
########################

# # install RVM, Ruby, and Bundler
# RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import
# RUN \curl -L https://get.rvm.io | bash -s stable
# RUN /bin/bash -l -c "rvm requirements"
# RUN /bin/bash -l -c "rvm install 1.9.3"
#
# # RUN     gem install fluentd fluent-plugin-influxdb --no-ri --no-rdoc
# RUN     /bin/bash -l -c "gem install --no-ri --no-rdoc \
#             fluentd -v ${FLUENTD_VERSION}" && \
#         /bin/bash -l -c "gem install --no-ri --no-rdoc \
#             cause \
#             influxdb \
#             rake \
#             bundler \
#             protobuf \
#             statsd-ruby \
#             dogstatsd-ruby \
#             fluent-plugin-newsyslog \
#             fluent-plugin-rewrite-tag-filter"
#
# RUN     /bin/bash -l -c "gem install --no-ri --no-rdoc \
#             fluent-plugin-juniper-telemetry -v ${FLUENTD_JUNIPER_VERSION}"
#
# ADD     docker/fluentd/fluentd.launcher.sh /etc/service/fluentd/run

########################
### Install InfluxDB ###
########################

RUN     curl -s -o /tmp/influxdb_latest_amd64.deb https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_amd64.deb && \
        dpkg -i /tmp/influxdb_latest_amd64.deb && \
        rm /tmp/influxdb_latest_amd64.deb

ADD     docker/influxdb/types.db /usr/share/collectd/types.db
ADD     docker/influxdb/influxdb-config.toml /config/config.toml
ADD     docker/influxdb/influxdbrun.sh /influxdbrun.sh

RUN     mkdir /etc/service/influxdb
ADD     docker/influxdb/influxdb.launcher.sh /etc/service/influxdb/run

########################
### Install telegraf ###
########################

RUN     curl -s -o /tmp/telegraf_latest_amd64.deb https://dl.influxdata.com/telegraf/releases/telegraf_${TELEGRAF_VERSION}_amd64.deb && \
        dpkg -i /tmp/telegraf_latest_amd64.deb && \
        rm /tmp/telegraf_latest_amd64.deb

ADD     docker/telegraf/telegraf.conf /etc/telegraf/telegraf.conf

RUN     mkdir /etc/service/telegraf
ADD     docker/telegraf/telegraf.launcher.sh /etc/service/telegraf/run

########################
### Configuration    ###
########################

### Configure Grafana ###
ADD     docker/grafana/custom.ini /opt/grafana/conf/custom.ini
ADD     docker/grafana/run.sh /etc/service/grafana/run
ADD     docker/grafana/grafana.init.sh /etc/my_init.d/grafana.init.sh

# Add the default dashboards
RUN     mkdir /src/dashboards && \
        mkdir /opt/grafana/data && \
        chown -R www-data /opt/grafana/data

### Configure nginx ###
ADD     docker/nginx/nginx.conf /etc/nginx/nginx.conf
ADD     docker/nginx/run.sh /etc/service/nginx/run

### open-nti python scripts (for gathering informatino from server to router)  ###
ADD     open-nti/open-nti.py /opt/open-nti/open-nti.py
ADD     open-nti/startcron.py /opt/open-nti/startcron.py
ADD     tests/pyez_mock.py /opt/open-nti/pyez_mock.py

### Add test files
RUN     mkdir /opt/open-nti/tests

# ################

# RUN     chmod +x /etc/service/fluentd/run       &&\
RUN     chmod +x /etc/service/nginx/run         &&\
        chmod +x /etc/service/grafana/run       &&\
        chmod +x /etc/my_init.d/grafana.init.sh &&\
        chmod +x /etc/service/influxdb/run      &&\
        chmod +x /etc/service/telegraf/run      &&\
        chmod +x /influxdbrun.sh

#######
### Copy files that change often
######

# RUN     mkdir /etc/fluent && \
#         mkdir /etc/fluent/plugin

# ADD     docker/fluentd/fluent.conf /etc/fluent/fluent.conf
# ADD     docker/fluentd/fluent.conf /fluent/fluent.conf
# RUN     /bin/bash -l -c "fluentd --setup"

# ADD     docker/fluentd/plugin/out_influxdb.rb       /etc/fluent/plugin/out_influxdb.rb
# ADD     docker/fluentd/plugin/out_statsd.rb         /etc/fluent/plugin/out_statsd.rb

# # WORKDIR /tmp
# # RUN     wget -O /tmp/fluent-plugin-juniper-telemetry.tar.gz https://github.com/JNPRAutomate/fluent-plugin-juniper-telemetry/archive/v${FLUENTD_JUNIPER_VERSION}.tar.gz &&\
# #        tar -xzf /tmp/fluent-plugin-juniper-telemetry.tar.gz                &&\
# #        cd /tmp/fluent-plugin-juniper-telemetry-${FLUENTD_JUNIPER_VERSION}  &&\
# #        rake install

WORKDIR /
ENV HOME /root
ENV SSL_SUPPORT **False**
ENV SSL_CERT **None**
RUN chmod -R 777 /var/log/

# ## Graphana
EXPOSE 80
EXPOSE 3000

# # Influxdb Admin server WebUI
EXPOSE 8083
EXPOSE 8086

CMD ["/sbin/my_init"]
