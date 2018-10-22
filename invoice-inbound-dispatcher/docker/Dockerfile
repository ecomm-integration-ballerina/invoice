FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/invoice-inbound-dispatcher.balx /home/ballerina
COPY invoice-inbound-dispatcher/conf/ballerina.conf /home/ballerina

COPY invoice-inbound-dispatcher/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/
COPY invoice-inbound-dispatcher/dependencies/packages/balo/* /ballerina/runtime/lib/repo/

CMD ballerina run invoice-inbound-dispatcher.balx
