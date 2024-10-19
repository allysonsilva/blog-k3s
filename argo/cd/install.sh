#!/usr/bin/env bash

# Install in root:
# ./argo/cd/install.sh

# This will cause the script to exit on the first error
set -e

ARGO_CHART_VERSION="7.5.2"
ARGO_APP_NAME="argocd-helm"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

[[ ! -x "$(command -v kubectl)" ]] && echo "kubectl not found, you need to install kubectl" && exit 1
[[ ! -x "$(command -v helm)" ]] && echo "helm not found, you need to install helm" && exit 1
[[ ! -x "$(command -v argocd)" ]] && echo "argocd not found, you need to install argocd-cli" && exit 1

message ">>> deploying ArgoCD"

echo
kubectl apply -f argo/cd/namespace.yaml
echo

# Install chart
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
# helm uninstall $ARGO_APP_NAME
# kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
helm upgrade --install $ARGO_APP_NAME argo/argo-cd --create-namespace --namespace=argocd --version $ARGO_CHART_VERSION \
--set fullnameOverride=argocd \
--set applicationSet.enabled=false \
--set notifications.enabled=false \
--set dex.enabled=false \
--set configs.params."server.insecure"=true \
--set configs.cm."kustomize\.buildOptions"="--load-restrictor LoadRestrictionsNone"

echo
kubectl -n argocd rollout status deployment/argocd-server
echo

echo
./scripts/env-to-file.sh --file="argo/cd/application-helm.yaml" | kubectl apply -f -
echo

message ">>> Awaiting ArgoCD to sync..."

export ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
until argocd login --core --username admin --password $ARGOCD_PWD --insecure; do :; done

kubectl config set-context --current --namespace=argocd
until argocd app sync $ARGO_APP_NAME; do echo "awaiting argocd to be sync..." && sleep 10; done

echo
kubectl -n argocd rollout status deployment/argocd-repo-server
echo

echo
./scripts/env-to-file.sh --file="argo/cd/ingress.yaml" | kubectl apply -f -
echo

message ">>> username: 'admin', password: '$ARGOCD_PWD'"
