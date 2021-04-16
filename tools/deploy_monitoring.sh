#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Specific to Prow instance
CLUSTER="falco-prow"
ZONE="eu-west-1"

function main() {
  echo "Getting Kubeconfig for cluster access" 
  updateKubeConfig
  echo "Launching Prow Monitoring stack" 
  launchMonitoring
  echo "All done!"
}

function updateKubeConfig() {
  aws eks --region ${ZONE} update-kubeconfig --name ${CLUSTER}-test-infra
}

function launchMonitoring(){
  # Requires EBS CSI driver installed, and prow installation to create the storage-class

  # Create monitoring namespace
  kubectl apply -f config/clusters/monitoring/prow_monitoring_namespace.yaml

  # Create Secrets from 1password
  export SLACK_API_URL=$(./tools/1password.sh -d slack-api-url)
  envsubst < config/clusters/monitoring/alertmanager/alertmanager-prow_secret.yaml | kubectl apply -f -

  kubectl create secret generic grafana-password --from-literal=grafana-password="$(./tools/1password.sh -d grafana-password)" --namespace=prow-monitoring  || true

  # # Launch Prometheus CRD's
  # kubectl apply -f config/clusters/monitoring/crd/

  # # Launch Prometheus
  # kubectl apply -f config/clusters/monitoring/prometheus/

  # # Launch Prometheus Alertmanager
  # kubectl apply -f config/clusters/monitoring/alertmanager/

  # # Launch Grafana
  # kubectl apply -f config/clusters/monitoring/grafana/
}

function cleanup() {
  returnCode="$?"
  exit "${returnCode}"
}

trap cleanup EXIT
main "$@"
cleanup