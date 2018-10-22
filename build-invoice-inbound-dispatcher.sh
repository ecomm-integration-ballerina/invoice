ballerina build invoice-inbound-dispatcher
docker build -t rajkumar/invoice-inbound-dispatcher:0.1.0 -f invoice-inbound-dispatcher/docker/Dockerfile .
docker push rajkumar/invoice-inbound-dispatcher:0.1.0
kubectl delete -f invoice-inbound-dispatcher/kubernetes/invoice_inbound_dispatcher_deployment.yaml
kubectl create -f invoice-inbound-dispatcher/kubernetes/invoice_inbound_dispatcher_deployment.yaml