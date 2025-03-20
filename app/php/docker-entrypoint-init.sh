#!/usr/bin/env bash

set -e

if [[ -d "vendor" && ${CACHE_CLEAR:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan cache:clear\033[0m\n\n"

    php artisan cache:clear 2>/dev/null || true
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
