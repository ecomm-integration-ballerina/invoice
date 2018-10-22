kubectl delete -f invoice-data-service/kubernetes/invoice_data_service_deployment.yaml
kubectl delete -f invoice-inbound-dispatcher/kubernetes/invoice_inbound_dispatcher_deployment.yaml
kubectl delete -f invoice-inbound-processor/kubernetes/invoice_inbound_processor_deployment.yaml
kubectl delete -f invoice-outbound/kubernetes/invoice_outbound_deployment.yaml