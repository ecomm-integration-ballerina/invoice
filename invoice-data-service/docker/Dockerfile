FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/invoice-data-service.balx /home/ballerina
COPY invoice-data-service/conf/ballerina.conf /home/ballerina

COPY invoice-data-service/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/

EXPOSE  8280

CMD ballerina run invoice-data-service.balx