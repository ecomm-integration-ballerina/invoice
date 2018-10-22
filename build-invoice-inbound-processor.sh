ballerina build invoice-inbound-processor
docker build -t rajkumar/invoice-inbound-processor:0.1.0 -f invoice-inbound-processor/docker/Dockerfile .
docker push rajkumar/invoice-inbound-processor:0.1.0
kubectl delete -f invoice-inbound-processor/kubernetes/invoice_inbound_processor_deployment.yaml
kubectl create -f invoice-inbound-processor/kubernetes/invoice_inbound_processor_deployment.yaml