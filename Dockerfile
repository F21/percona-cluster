# Percona XtraDB Cluster 5.6

FROM ubuntu:14.04.3
MAINTAINER Francis Chuang <francis.chuang@boostport.com>

ENV PERCONA_VER=56
ENV DEBIAN_FRONTEND noninteractive

ADD 00percona.pref /etc/apt/preferences.d/00percona.pref

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A \
    && echo "deb http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list \
    && echo "deb-src http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y augeas-tools percona-xtradb-cluster-$PERCONA_VER \
    && rm -rf /var/lib/mysql

ADD run-percona-cluster.sh /run-percona-cluster.sh

VOLUME ["/var/lib/mysql"]

EXPOSE 3306 4444 4567 4568

CMD ["/run-percona-cluster.sh"]