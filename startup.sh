export my_region=us-central1
export my_cluster=autopilot-cluster-1

gcloud container clusters create-auto $my_cluster --region $my_region

#NAME: autopilot-cluster-1
#LOCATION: us-central1
#MASTER_VERSION: 1.29.7-gke.1104000
#MASTER_IP: 35.238.225.139
#MACHINE_TYPE: e2-small
#NODE_VERSION: 1.29.7-gke.1104000
#NUM_NODES: 3
#STATUS: RUNNING

kubectl create -f deployments/auth.yaml
kubectl create -f services/auth.yaml

kubectl create -f deployments/hello.yaml
kubectl create -f services/hello.yaml

kubectl create secret generic tls-certs --from-file tls/
kubectl create configmap nginx-proxy-conf --from-file=nginx/default.conf
kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml

kubectl get deployments
kubectl get replicasets
kubectl get pods
kubectl get services frontend

curl -k http://35.184.142.26