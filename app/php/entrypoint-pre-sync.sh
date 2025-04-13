#!/usr/bin/env bash

set -e

if [ -z "$APP_ENV" ]; then
    printf "\n\033[31m[$CONTAINER_ROLE] A \$APP_ENV environment is required to run this container!\033[0m\n"
    exit 1
fi

if [ -z "$APP_KEY" ]; then
    printf "\n\033[31m[$CONTAINER_ROLE] A \$APP_KEY environment is required to run this container!\033[0m\n"
    exit 1
fi

shopt -s dotglob
sudo chown -R ${USER_NAME}:${USER_NAME} \
        /home/${USER_NAME} \
        /usr/local/var/run \
        /var/run \
        /var/log \
        /tmp/php \
        $LOG_PATH
shopt -u dotglob

sudo find /usr/local/etc ! -name "php.ini" | xargs -I {} chown ${USER_NAME}:${USER_NAME} {}

if [ ! -d "vendor" ] && [ -f "composer.json" ]; then
    printf "\n\033[33mComposer vendor folder was not installed. Running >_ composer install --prefer-dist --no-interaction --optimize-autoloader --ansi\033[0m\n\n"

    composer install --prefer-dist --no-interaction --optimize-autoloader --ignore-platform-reqs --ansi

    printf "\n\033[33mcomposer run-script post-root-package-install\033[0m\n\n"

    composer run-script post-root-package-install

    printf "\n\033[33mcomposer run-script post-autoload-dump\033[0m\n\n"

    composer run-script post-autoload-dump
fi

if [[ -d "vendor" && ${CACHE_CLEAR:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan cache:clear\033[0m\n\n"

    php artisan cache:clear 2>/dev/null || true
fi

# $> {view:clear} && {cache:clear} && {route:clear} && {config:clear} && {clear-compiled}
# @see https://github.com/laravel/framework/blob/9.x/src/Illuminate/Foundation/Console/OptimizeClearCommand.php
if [[ -d "vendor" && ${FORCE_CLEAR:-true} == true ]]; then
    printf "\n\033[33mLaravel - artisan view:clear + route:clear + config:clear + clear-compiled\033[0m\n\n"

    php artisan event:clear || true
    php artisan view:clear
    php artisan route:clear
    php artisan config:clear
    php artisan clear-compiled
fi

if [[ -d "vendor" && ${FORCE_OPTIMIZE:-true} == true ]]; then
    printf "\n\033[33mLaravel Cache Optimization - artisan config:cache + route:cache + view:cache\033[0m\n\n"

    # $> {config:cache} && {route:cache}
    # @see https://github.com/laravel/framework/blob/9.x/src/Illuminate/Foundation/Console/OptimizeCommand.php
    php artisan optimize || true
    php artisan view:cache || true
    php artisan event:cache || true
fi

if [[ -d "vendor" && ${FORCE_MIGRATE:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan migrate --force\033[0m\n\n"

    php artisan migrate --force || true
fi

if [[ ${FORCE_STORAGE_LINK:-true} == true ]]; then
    printf "\n\033[33mLaravel - artisan storage:link\033[0m\n\n"

    rm -rf ${REMOTE_SRC}/public/storage || true
    php artisan storage:link || true
fi

echo
php -v
echo

php artisan app:generate-feed || true
php artisan app:generate-sitemap || true

npm --section=site run mix-production || true

php artisan app:generate-partials-shell --no-interaction || true

npm run workbox-precache || true

npm --section=combine run mix-production || true

exec "$@"
