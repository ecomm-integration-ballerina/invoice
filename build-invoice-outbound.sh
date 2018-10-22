ballerina build invoice-outbound
docker build -t rajkumar/invoice-outbound:0.1.0 -f invoice-outbound/docker/Dockerfile .
docker push rajkumar/invoice-outbound:0.1.0
kubectl delete -f invoice-outbound/kubernetes/invoice_outbound_deployment.yaml
kubectl create -f invoice-outbound/kubernetes/invoice_outbound_deployment.yaml