#!/usr/bin/env bash

# This will cause the script to exit on the first error
set -e

set -o allexport
[[ -f deploy.env ]] && source deploy.env
[[ -f .env ]] && source .env
set +o allexport

# ./scripts/env-to-file.sh --env=app/.env --file=app/app-config.yml

options=$(getopt --longoptions "env:,file:" --options "" --alternative -- "$@")

if [ $? != 0 ] ; then echo -e "\n Terminating..." >&2 ; exit 1 ; fi

# Check for piped input
# Checking if stdin is not open on the terminal (because it is piped to a file) is done with test ! -t 0 (check if the file descriptor zero (aka stdin) is not open).
if test ! -t 0; then
    echo "$(cat)" | envsubst

    exit 0
fi

eval set -- "$options"

if [[ -z "$1" || "$1" == "--" ]] ; then
    printf "\033[31m[ ERROR: ] No arguments supplied!\033[0m\n" >&2
    printf "\033[31m[ ERROR: ] Please call '$0 <argument>' to run this command!\033[0m\n" >&2

    exit 1
fi

ENV=${ENV:-}
FILE=${FILE:-}
OTHER_ARGUMENTS=()

while true ; do
    case $1 in
        --env) shift; ENV="$1" ;;
        --file) shift; FILE="$1" ;;
        --) shift ; break ;;
        *) shift;  OTHER_ARGUMENTS+=("$1") ;;
    esac
    shift
done

set -o allexport
[[ -f $ENV ]] && source $ENV
set +o allexport

envsubst < $FILE

exit 0
