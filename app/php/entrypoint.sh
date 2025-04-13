#!/usr/bin/env bash

# Define o valor padrão de IS_PRE_SYNC como 'false' caso a variável não tenha sido passada
: "${IS_PRE_SYNC:=false}"

# Verifica a variável de ambiente para saber qual script executar
if [ "$IS_PRE_SYNC" = "true" ]; then
  echo "Executando o entrypoint do PreSync..."
  /entrypoint-pre-sync.sh "$@"
else
  echo "Executando o entrypoint principal..."
  /entrypoint-main.sh "$@"
fi
