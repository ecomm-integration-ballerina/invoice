FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/invoice-outbound.balx /home/ballerina
COPY invoice-outbound/conf/ballerina.conf /home/ballerina

CMD ballerina run invoice-outbound.balx
