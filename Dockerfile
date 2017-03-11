FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
ENV APACHE_ENVVARS=/etc/apache2/envvars
ENV TZ=Asia/Seoul
ENV WWW_ROOT_DIR=/var/www/html
ENV XHGUI_DIR=/var/www/xhgui
ENV XHGUI_PORT=9002

RUN echo "export TERM=xterm-256color" >> /root/.bashrc

#-------------------------------------------------------------------------------
# System Timezone Setting
#-------------------------------------------------------------------------------

RUN echo $TZ | tee /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata

#-------------------------------------------------------------------------------
# Install Packages
#-------------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        curl \
        apache2 \
        ca-certificates \
        supervisor \
        cron \
        beanstalkd \
        git \
        mongodb \
        php \
        php-cli \
        php7.0-dev \
        php-pear \
        php-intl \
        php-zip \
        php-curl \
        php-gd \
        php-mbstring \
        php-mysql \
        php-sqlite3 \
        php-xml \
        php-opcache \
        libapache2-mod-php

#-------------------------------------------------------------------------------
# Copy Settings
#-------------------------------------------------------------------------------

COPY files /

#-------------------------------------------------------------------------------
# Install Tideways-Fork of XHProf
# @note xhprof doesnot support PHP 7
#-------------------------------------------------------------------------------

RUN git clone https://github.com/tideways/php-profiler-extension.git \
    && cd php-profiler-extension \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && curl -O https://github.com/tideways/profiler/releases/download/v2.0.14/Tideways.php \
    && cp Tideways.php $(php -r 'echo ini_get("extension_dir")."\n";') \
    && echo "extension=tideways.so" > /etc/php/7.0/mods-available/tideways.ini \
    && echo "tideways.auto_prepend_library=0" >> /etc/php/7.0/mods-available/tideways.ini \
    && phpenmod tideways

WORKDIR $WWW_ROOT_DIR

#-------------------------------------------------------------------------------
# Install Mongo DB (xhgui uses mongoDB)
#-------------------------------------------------------------------------------

RUN pecl install mongodb \
    && echo "extension=mongodb.so" > /etc/php/7.0/mods-available/mongodb.ini \
    && phpenmod mongodb

# Index is recommended for better performance of XHGui
#    && /usr/bin/mongod --config /etc/mongodb.conf --dbpath /var/lib/mongodb/ --rest \
#    && mongo --eval 'use xhprof;' \
#    && mongo --eval 'db.results.ensureIndex( { "meta.SERVER.REQUEST_TIME" : -1 } );' \
#    && mongo --eval 'db.results.ensureIndex( { "profile.main().wt" : -1 } );' \
#    && mongo --eval 'db.results.ensureIndex( { "profile.main().mu" : -1 } );' \
#    && mongo --eval 'db.results.ensureIndex( { "profile.main().cpu" : -1 } );' \
#    && mongo --eval 'db.results.ensureIndex( { "meta.url" : 1 } );'

#-------------------------------------------------------------------------------
# Install XHGui
#-------------------------------------------------------------------------------

RUN git clone https://github.com/perftools/xhgui.git /var/www/xhgui \
    && cd $XHGUI_DIR \
    && curl -sS https://getcomposer.org/installer | php \
    && /usr/bin/php $XHGUI_DIR/install.php \
    # Slim has some bugs when extending base View class in Twig class
    && curl https://gist.githubusercontent.com/appkr/a1373932ded11b274af3b74055f5c0a1/raw/c393a9ebf2fa09710b0253778a8bb3f5ea9d418a/Twig.php > vendor/slim/views/Slim/Views/Twig.php \
    && curl https://gist.githubusercontent.com/appkr/cce0f4dbc4902022b3c6ac26ea49388c/raw/5feb2d0c187a2933c8f2fb0f0fec7f1e6984ce1b/View.php > vendor/slim/slim/Slim/View.php \
    && curl https://gist.githubusercontent.com/appkr/13648361c92aa06d3d73536dca06e065/raw/a323ba8d18fec147c991d180a6fd8d94084817fd/config.default.php > /var/www/xhgui/config/config.default.php \
    && a2ensite xhgui \
    && echo "Listen ${XHGUI_PORT}" >> /etc/apache2/ports.conf

#-------------------------------------------------------------------------------
# Configure Apache
#-------------------------------------------------------------------------------

RUN usermod -u 1000 www-data \
    && groupmod -g 1000 www-data

# Recreate Apache directories and set correct permissions
# @see https://github.com/docker-library/php/blob/e573f8f7fda5d7378bae9c6a936a298b850c4076/7.0/apache/Dockerfile#L38
RUN sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS" \
    && . "$APACHE_ENVVARS" \
    && for dir in \
        "$APACHE_LOCK_DIR" \
        "$APACHE_RUN_DIR" \
        "$APACHE_LOG_DIR" \
        /var/www/html \
    ; do \
        rm -rvf "$dir" \
            && mkdir -p "$dir" \
            && chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
    done

#-------------------------------------------------------------------------------
# Publish Applications
#-------------------------------------------------------------------------------

ADD . $WWW_ROOT_DIR

RUN a2dissite 000-default \
    && rm /etc/apache2/sites-available/000-default.conf \
    && a2ensite app \
    && a2enmod rewrite deflate headers \
    && chmod -R 775 $WWW_ROOT_DIR/storage $WWW_ROOT_DIR/bootstrap/cache \
    && chown -R www-data:www-data $WWW_ROOT_DIR/storage $WWW_ROOT_DIR/bootstrap/cache

#-------------------------------------------------------------------------------
# Install Cron Job
#-------------------------------------------------------------------------------

RUN crontab /etc/cron.d/cronjob \
    && touch /var/log/cron.log

#-------------------------------------------------------------------------------
# Clean Up
#-------------------------------------------------------------------------------

RUN apt-get remove -y \
        build-essential \
        git \
        php7.0-dev \
        php-pear \
        pkg-config \
        libssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && rm -rf $WWW_ROOT_DIR/php-profiler-extension

#-------------------------------------------------------------------------------
# Run Environment
#-------------------------------------------------------------------------------

WORKDIR $WWW_ROOT_DIR

VOLUME ["/var/lib/mongodb/"]

# 80    app
# 9001  supervisord web interface
# 9002  xhgui web interface
# 28017 mongodb web interface
EXPOSE 80 9001 9002 28017

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
