ARG APP_FOLDER=.
ARG COMPOSER_VERSION=2.7
ARG K3S_FOLDER=./k3s
ARG PHP_BASE_IMAGE_VERSION=8.4-zts-alpine

#####
## COMPOSER
#####

FROM composer:${COMPOSER_VERSION} as vendor

WORKDIR /app

ENV COMPOSER_HOME /composer

ARG APP_FOLDER

COPY $APP_FOLDER/composer.json .
COPY $APP_FOLDER/composer.lock .

RUN set -xe \
    &&  composer install \
        --optimize-autoloader \
        --ignore-platform-reqs \
        --prefer-dist \
        --no-progress \
        --no-dev \
        --no-cache \
        --no-scripts \
        --no-interaction \
        --ansi

#####
## FRONTEND
#####

FROM node:21-alpine as frontend

ARG APP_FOLDER

ENV ROOT=/app

WORKDIR ${ROOT}

RUN npm config set update-notifier false && npm set progress=false

COPY $APP_FOLDER/package*.json ./

RUN set -xe \
    && npm install

#####
## PHP
#####

FROM php:$PHP_BASE_IMAGE_VERSION as dependencies

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN set -xe; \
    \
    echo "---> Installing PHP Extensions"; \
    \
    apk update; \
    \
    apk add --no-cache --virtual .phpize-deps \
        $PHPIZE_DEPS \
        curl-dev \
        linux-headers \
        brotli-dev \
        openssl-dev \
        pcre-dev \
        sqlite-dev \
        icu-dev \
        pcre2-dev \
        zlib-dev \
        rabbitmq-c-dev \
    ; \
    apk add --no-cache libstdc++ \
    ; \
    pecl channel-update pecl.php.net && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
    install-php-extensions \
        gd \
        zip \
        gmp \
        intl \
        soap \
        exif \
        pcntl \
        bcmath \
        mysqli \
        sockets \
        opcache \
        pdo_mysql \
        ds-^1 \
        amqp-^2.1@stable \
        mongodb-^1.20@stable \
        igbinary-^3.2@stable \
        msgpack-^3.0@stable \
        redis-^6@stable \
        ; \
    # SWOOLE
    mkdir -p /usr/src/php/ext/swoole && \
    curl -sfL https://github.com/swoole/swoole-src/archive/v6.0.1.tar.gz -o swoole.tar.gz && \
    tar xfz swoole.tar.gz --strip-components=1 -C /usr/src/php/ext/swoole && \
    docker-php-ext-configure swoole \
        --enable-swoole-curl   \
        --enable-swoole-thread \
        --enable-mysqlnd       \
        --enable-swoole-sqlite \
        --enable-brotli        \
        --enable-openssl       \
        --enable-sockets    && \
    docker-php-ext-install -j$(nproc) swoole && \
    rm -f swoole.tar.gz \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache $runDeps; \
    apk del --no-network .phpize-deps; \
    docker-php-source delete; \
    rm -rf /tmp/* /var/cache/apk/*

RUN set -xe; \
    \
    echo "---> Installing Packages Dependencies"; \
    \
    apk update; \
    \
    apk add --update --no-cache \
        fd \
        exa \
        git \
        vim \
        npm \
        sudo \
        curl \
        wget \
        make \
        bash \
        tini \
        nodejs \
        tzdata \
        libcap \
        bind-tools \
        supervisor \
        mysql-client \
        busybox-suid \
        openssh-client \
        bash-completion; \
    \
    rm -rf /tmp/* /var/cache/apk/*

#####
## APP CONTAINER
#####

FROM dependencies as main

LABEL maintainer="Alyson Silva <hello@alysonsilva.dev>"
LABEL org.opencontainers.image.title="alysonsilva.dev Laravel Octane Dockerfile"
LABEL org.opencontainers.image.description="Docker my personal blog using octane Laravel Octane"
LABEL org.opencontainers.image.source=https://github.com/allysonsilva/blog-k3s
LABEL org.opencontainers.image.licenses=MIT

ARG APP_FOLDER
ENV APP_FOLDER $APP_FOLDER

ARG K3S_FOLDER
ENV K3S_FOLDER $K3S_FOLDER

# = /usr/local/etc/php
ENV PHP_INI_DIR ${PHP_INI_DIR:-/usr/local/etc/php}
# = /usr/local/etc/php/conf.d
ENV PHP_INI_SCAN_DIR ${PHP_INI_DIR}/conf.d
# Default PATH LOG
ENV LOG_PATH=/usr/local/var/log
# Path logs PHP
ENV PHP_LOG_PATH=$LOG_PATH/php

# Default directory for application deployment
# Location of the folder in the container, path of the folder inside the container
ARG REMOTE_SRC=/var/www/app
ENV REMOTE_SRC $REMOTE_SRC

# Image user
ARG USER_NAME=app
ENV USER_NAME $USER_NAME

ARG USER_UID=1000
ARG USER_GID=1000

# Path docker PHP/APP folder
# Path Config/Dockerfile PHP/APP
ARG APP_BUILD_CONTAINER_PATH=${K3S_FOLDER}/app/php
ENV APP_BUILD_CONTAINER_PATH $APP_BUILD_CONTAINER_PATH

ARG APP_FOLDER
ENV APP_FOLDER $APP_FOLDER

# app || queue || scheduler
ARG CONTAINER_ROLE=app
ENV CONTAINER_ROLE $CONTAINER_ROLE

ARG APP_ENV=production
ENV APP_ENV ${APP_ENV:-production}

#####
## CONFIGURATIONS
#####

COPY $APP_BUILD_CONTAINER_PATH/configs/conf.d/* $PHP_INI_SCAN_DIR/

# /usr/local/etc/php/php.ini
COPY $APP_BUILD_CONTAINER_PATH/configs/php-$APP_ENV.ini $PHP_INI_DIR/php.ini

# SUPERVISOR CONF's
COPY $APP_BUILD_CONTAINER_PATH/configs/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY $APP_BUILD_CONTAINER_PATH/configs/supervisor/templates/* /etc/supervisor/conf.d/

RUN set -xe \
    && mkdir -p $PHP_LOG_PATH $LOG_PATH/supervisor && touch $PHP_LOG_PATH/php.errors.log

RUN if [ "$USER_UID" != 1000 ]; then \
        set -xe \
        && echo "---> Adding the www-data(1000) user" \
        && deluser --remove-home www-data \
        && delgroup www-data || true \
        && addgroup --gid 1000 www-data \
        && adduser --gecos "" --disabled-password --uid 1000 --ingroup www-data --shell /bin/bash www-data \
        && echo "www-data ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers \
        && chown -R www-data:www-data /home/www-data \
    ;fi

RUN set -xe \
    && echo "---> Adding USER to IMAGE" \
    && addgroup --gid ${USER_GID:-1000} $USER_NAME \
    && adduser --gecos "" --disabled-password --uid ${USER_UID:-1000} --ingroup $USER_NAME --shell /bin/bash $USER_NAME \
    && echo "$USER_NAME ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers \
    # Replace it with /bin/bash:
    && sed -i "/root/s/bin\/ash/bin\/bash/g" /etc/passwd

RUN if [ ! -d "$REMOTE_SRC" ]; then \
        mkdir -p /tmp/php /tmp/php/sessions /tmp/php/uploads $REMOTE_SRC $REMOTE_SRC/database/certs/mysql \
    ;fi

RUN set -xe \
    && rm -rf /tmp/pear ~/.pearrc \
    && rm -rf /var/www/html

RUN set -xe; \
    \
    # ps -ef | grep cron | grep -v grep
    echo "---> Create Cron Files"; \
    \
    touch /var/log/cron.log; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    \
    touch /var/spool/cron/crontabs/$USER_NAME

# ENTRYPOINT
COPY $APP_BUILD_CONTAINER_PATH/docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

#####
## APPLICATION
#####

# Application directory
WORKDIR $REMOTE_SRC

# Define the running USER
USER $USER_NAME

# Remove folder docker
RUN     if [ -d ${K3S_FOLDER} ]; then \
            sudo rm -rf ${K3S_FOLDER} \
        ;fi

COPY --chown=${USER_NAME}:${USER_NAME} --from=vendor /usr/bin/composer /usr/local/bin/composer

RUN set -xe \
    && echo "---> Installing Composer" \
    && COMPOSER_HOME="/home/${USER_NAME}/.composer/" \
    # && curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer --version=2.7.0 \
    && sudo chown ${USER_NAME}:${USER_NAME} /usr/local/bin/composer

# Environment variables
# Default: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PATH="$PATH:/home/${USER_NAME}/.composer/vendor/bin"

# Files APP
# Copy our application
COPY $APP_FOLDER $REMOTE_SRC

## Copy the downloaded dependencies from the {vendor} stage
COPY --chown=${USER_NAME}:${USER_NAME} --from=vendor /app/vendor $REMOTE_SRC/vendor
COPY --chown=${USER_NAME}:${USER_NAME} --from=frontend /app/node_modules $REMOTE_SRC/node_modules

RUN sudo mkdir -p   storage/logs \
                    storage/app/public \
                    storage/framework/{sessions,views,cache} \
                    ; \
                    sudo touch storage/logs/laravel.log

RUN set -xe \
    && echo "---> Changing Permissions" \
    && sudo chown -R $USER_NAME:$USER_NAME \
        /usr/local/etc \
        /var/run \
        /var/log \
        /usr/local/var/run \
        /home/${USER_NAME} \
        $LOG_PATH \
        /tmp/php

RUN set -xe \
    && sudo composer run-script post-root-package-install || true \
    && sudo composer run-script post-create-project-cmd || true \
    # && composer dump-autoload --optimize --classmap-authoritative --no-dev --ansi || true \
    && sudo composer run-script post-autoload-dump || true

RUN set -xe \
    && DEFAULT_PARAMETERS_FD="--threads $(nproc) --hidden --no-ignore --ignore-case --show-errors" \
    && DEFAULT_EXCLUDE_FD='--exclude public -E .git -E vendor -E node_modules' \
    # -E, --exclude <pattern>... Exclude files/directories that match the given glob pattern
    # -E "{**/fileX,**/fileY}"
    # -E "{folderX,folderY}"
    && sudo fd $DEFAULT_EXCLUDE_FD $DEFAULT_PARAMETERS_FD --type directory --exec chmod 755 {} \; . $REMOTE_SRC \
    && sudo fd $DEFAULT_EXCLUDE_FD $DEFAULT_PARAMETERS_FD --type file --exec chmod 644 {} \; . $REMOTE_SRC \
    && sudo fd -E .git -E vendor -E node_modules $DEFAULT_PARAMETERS_FD --exec chown $USER_NAME:$USER_NAME . $REMOTE_SRC \
    && sudo chgrp -R $USER_NAME storage bootstrap/cache \
    && sudo chmod -R ug+rwx storage bootstrap/cache

RUN set -xe \
    && php artisan view:clear \
    && php artisan route:clear \
    && php artisan config:clear \
    && php artisan storage:link \
    && exa --all --group --header --links --long --accessed --modified --git --icons --color=always

RUN set -xe \
    && PHP_ERROR="$( php -v 2>&1 1>/dev/null )" \
    && if [ -n "$PHP_ERROR" ]; then echo "$PHP_ERROR"; false; fi \
    && php -m; php -v; php --ini \
    && php -i | grep -E '^opcache\.(enable_cli|jit|jit_buffer_size) ' \
    && composer --version

VOLUME ${LOG_PATH}

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

EXPOSE 80 443 443/udp 9111 8000

# vim:set ft=dockerfile:
