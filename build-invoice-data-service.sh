ballerina build invoice-data-service
docker build -t rajkumar/invoice-data-service:0.1.0 -f invoice-data-service/docker/Dockerfile .
docker push rajkumar/invoice-data-service:0.1.0
kubectl delete -f invoice-data-service/kubernetes/invoice_data_service_deployment.yaml
kubectl create -f invoice-data-service/kubernetes/invoice_data_service_deployment.yaml