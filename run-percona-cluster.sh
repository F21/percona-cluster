#!/usr/bin/env bash

CONFIG_FILE=/etc/mysql/my.cnf

: ${CLUSTER_NAME:?"CLUSTER_NAME is required."}
: ${DATADIR:="/var/lib/mysql"}

# Update my.cnf
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/bind-address 0.0.0.0"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/datadir ${DATADIR}"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/binlog_format ROW"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/default_storage_engine InnoDB"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/innodb_autoinc_lock_mode 2"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/character-set-server utf8mb4"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/collation-server utf8mb4_unicode_ci"

mkdir -p $DATADIR
chown -R mysql:mysql "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then

    : ${ROOT_PASSWORD:?"ROOT_PASSWORD is required."}
    : ${WSREP_SST_AUTH_USER:?"WSREP_SST_AUTH_USER is required."}
    : ${WSREP_SST_AUTH_PASS:?"WSREP_SST_AUTH_PASS is required."}

    echo "Initializing database directory..."
    mysql_install_db --user=mysql --datadir="$DATADIR"

    echo "Starting mysql for configuration..."
    mysqld_safe --skip-syslog --skip-networking > /dev/null &

    while [[ ! -e /var/run/mysqld/mysqld.sock ]] ; do sleep 1; done
    while ! mysql -e 'select now()'; do sleep 1; done

    echo "Initializing timezone info..."
    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql

    echo "Removing anonymous user..."
    mysql -e "DELETE FROM mysql.db WHERE Db LIKE 'test%'; \
              DELETE FROM mysql.user WHERE user = ''; \
              FLUSH PRIVILEGES;"

    echo "Droping test database..."
    mysql -e "DROP DATABASE IF EXISTS test;"

    echo "Creating replication user..."
    mysql -e "CREATE USER '${WSREP_SST_AUTH_USER}'@'localhost' IDENTIFIED BY '${WSREP_SST_AUTH_PASS}'; \
              GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${WSREP_SST_AUTH_USER}'@'localhost'; \
              FLUSH PRIVILEGES;"

    echo "Make root accessible from all hosts..."
    mysql -e "RENAME USER 'root'@'localhost' TO 'root'@'%'; \
              DELETE FROM mysql.user WHERE user = 'root' AND host != '%'; \
              FLUSH PRIVILEGES;"

    echo "Setting root password..."
    mysqladmin -u root password ${ROOT_PASSWORD}

    echo "Stopping mysql..."
    mysqladmin -u root -p${ROOT_PASSWORD} shutdown
fi

augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_provider /usr/lib/libgalera_smm.so"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_node_address $(awk 'NR==1 {print $1}' /etc/hosts)"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_sst_method xtrabackup-v2"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_cluster_name ${CLUSTER_NAME}"
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_sst_auth \"${WSREP_SST_AUTH_USER}:${WSREP_SST_AUTH_PASS}\""
augtool -s set "/files${CONFIG_FILE}/target[ . = \"mysqld\"]/wsrep_cluster_address gcomm://${WSREP_CLUSTER_ADDRESS}"

if [ -n "$BOOTSTRAP" ]; then
    echo "Starting mysql in bootstrap mode..."
    mysqld_safe --wsrep-new-cluster
else
    echo "Starting mysql..."
    mysqld_safe
fi