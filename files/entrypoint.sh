#!/usr/bin/env bash

if [ ! -d $MYSQL_DATA_DIR/mysql ]; then rm -rf $MYSQL_DATA_DIR/* \
    && mkdir -p $MYSQL_PID_DIR \
    && chmod 777 $MYSQL_PID_DIR \
    && usermod -d $MYSQL_DATA_DIR mysql \
    && chown -R mysql:mysql $MYSQL_DATA_DIR $MYSQL_PID_DIR \
    && mysqld --user=mysql --initialize-insecure \
    && service mysql start \
    && mysql -v -e "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"
fi;

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
