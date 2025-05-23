#!/usr/bin/env bash

set -e

printf "\n\033[34m--- [$CONTAINER_ROLE] ENTRYPOINT APP --- \033[0m\n"

# Convert to UPPERCASE
CONTAINER_ROLE=${CONTAINER_ROLE^^}

if [ -z "$APP_ENV" ]; then
    printf "\n\033[31m[$CONTAINER_ROLE] A \$APP_ENV environment is required to run this container!\033[0m\n"
    exit 1
fi

configure_php_ini() {
    sed -i \
        -e "s/memory_limit.*$/memory_limit = ${PHP_MEMORY_LIMIT:-128M}/g" \
        -e "s/max_execution_time.*$/max_execution_time = ${PHP_MAX_EXECUTION_TIME:-30}/g" \
        -e "s/max_input_time.*$/max_input_time = ${PHP_MAX_INPUT_TIME:-30}/g" \
        -e "s/post_max_size.*$/post_max_size = ${PHP_POST_MAX_SIZE:-8M}/g" \
        -e "s/upload_max_filesize.*$/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE:-2M}/g" \
    \
    $PHP_INI_DIR/php.ini

    # sed -i \
    #     -e '/opcache.jit_buffer_size/s/^; //g' \
    #     -e '/opcache.jit/s/^; //g' \
    # \
    # $PHP_INI_SCAN_DIR/99-opcache.ini

    # { \
    #     echo 'session.use_strict_mode = 1'; \
    # } > $PHP_INI_SCAN_DIR/zz-session-strict.ini
}

if [[ ${OPCACHE_ENABLED:-true} == false ]]; then
    rm -f ${PHP_INI_SCAN_DIR}/opcache.ini >/dev/null 2>&1 || true
    rm -f ${PHP_INI_SCAN_DIR}/docker-php-ext-opcache.ini >/dev/null 2>&1 || true
fi

if [ "$APP_ENV" = "production" ]; then
    configure_php_ini
fi

echo
php -v
echo
php --ini

if [ "$CONTAINER_ROLE" = "APP" ]; then
    printf "\033[34m[$CONTAINER_ROLE] Running with Laravel Octane ...\033[0m\n"

    sudo mv /etc/supervisor/conf.d/laravel-octane.conf.tpl /etc/supervisor/conf.d/laravel-octane.conf

    exec /usr/bin/supervisord --nodaemon --configuration /etc/supervisor/supervisord.conf

elif [ "$CONTAINER_ROLE" = "QUEUE" ]; then

    printf "\n\033[34m[$CONTAINER_ROLE] Running the [QUEUE-WORKER] Service ...\033[0m\n"

    fileWorkerTpl=/etc/supervisor/conf.d/laravel-worker.conf.tpl

    sudo sed -i \
            -e "s|{{USER_NAME}}|$USER_NAME|g" \
            -e "s|{{REMOTE_SRC}}|${REMOTE_SRC}|g" \
            -e "s|{{REDIS_QUEUE}}|${REDIS_QUEUE:-default}|g" \
            -e "s|{{QUEUE_CONNECTION}}|${QUEUE_CONNECTION:-redis}|g" \
            -e "s|{{QUEUE_TIMEOUT}}|${QUEUE_TIMEOUT:-60}|g" \
            -e "s|{{QUEUE_MEMORY}}|${QUEUE_MEMORY:-64}|g" \
            -e "s|{{QUEUE_TRIES}}|${QUEUE_TRIES:-3}|g" \
            -e "s|{{QUEUE_BACKOFF}}|${QUEUE_BACKOFF:-3}|g" \
            -e "s|{{QUEUE_SLEEP}}|${QUEUE_SLEEP:-10}|g" ${fileWorkerTpl} \
    \
    && sudo mv $fileWorkerTpl /etc/supervisor/conf.d/laravel-worker.conf

    printf "\n\033[34m[$CONTAINER_ROLE] Starting [SUPERVISOR] ... \033[0m\n\n"

    exec /usr/bin/supervisord --nodaemon --configuration /etc/supervisor/supervisord.conf

    # # Reload the daemon's configuration files
    # supervisorctl -c /etc/supervisor/supervisord.conf reread
    # # Reload config and add/remove as necessary
    # supervisorctl -c /etc/supervisor/supervisord.conf update
    # # Start all processes of the group "laravel-worker"
    # supervisorctl -c /etc/supervisor/supervisord.conf start laravel-worker:*

    # # Since queue workers are long-lived processes, they will not notice changes to your code without being restarted.
    # # So, the simplest way to deploy an application using queue workers is to restart the workers during your deployment process.
    # # You may gracefully restart all of the workers by issuing the queue:restart command:
    #
    # # This command will instruct all queue workers to gracefully exit after they finish processing their current job so that no existing jobs are lost.
    # php artisan queue:restart

elif [ "$CONTAINER_ROLE" = "SCHEDULER" ]; then
    printf "\n\033[34m[$CONTAINER_ROLE] Starting [CRON] Service ...\033[0m\n\n"

    exec php artisan schedule:work
fi

# Se argumentos forem passados, executa eles diretamente
# echo "🧪 Executando comando customizado: $@"
exec "$@"
