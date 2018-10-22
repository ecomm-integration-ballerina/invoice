FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/invoice-inbound-processor.balx /home/ballerina
COPY invoice-inbound-processor/conf/ballerina.conf /home/ballerina

COPY invoice-inbound-processor/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/
COPY invoice-inbound-processor/dependencies/packages/balo/* /ballerina/runtime/lib/repo/

CMD ballerina run invoice-inbound-processor.balx
