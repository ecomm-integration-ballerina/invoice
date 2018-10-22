import wso2/ftp;
import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerina/mb;
import ballerina/http;

endpoint ftp:Client invoiceSFTPClient {
    protocol: ftp:SFTP,
    host: config:getAsString("ecomm_backend.invoice.sftp.host"),
    port: config:getAsInt("ecomm_backend.invoice.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("ecomm_backend.invoice.sftp.username"),
            password: config:getAsString("ecomm_backend.invoice.sftp.password")
        }
    }
};

endpoint http:Client invoiceDataEndpoint {
    url: config:getAsString("invoice.data.service.url")
};

endpoint mb:SimpleQueueReceiver invoiceInboundQueue {
    host: config:getAsString("invoice.mb.host"),
    port: config:getAsInt("invoice.mb.port"),
    queueName: config:getAsString("invoice.mb.queueName")
};

service<mb:Consumer> invoiceInboundQueueReceiver bind invoiceInboundQueue {
    onMessage(endpoint consumer, mb:Message message) {
        match (message.getTextMessageContent()) {
            string path => {
                log:printInfo("New invoice received from invoiceInboundQueue : " + path);
                boolean success = handleInvoice(path);

                if (success) {
                    archiveCompletedInvoice(path);
                } else {
                    archiveErroredInvoice(path);
                }
            }
            error e => {
                log:printError("Error occurred while reading message from invoiceInboundQueue", err = e);
            }
        }
    }
}

function handleInvoice(string path) returns boolean {

    boolean success = false;
    var invoiceOrError = invoiceSFTPClient -> get(path);

    match invoiceOrError {

        io:ByteChannel byteChannel => {
            io:CharacterChannel characters = new(byteChannel, "utf-8");
            xml invoice = check characters.readXml();
            _ = byteChannel.close();

            json invoices = generateInvoicesJson(invoice);

            http:Request req = new;
            req.setJsonPayload(untaint invoices);
            var response = invoiceDataEndpoint->post("/batch/", req);

            match response {
                http:Response resp => {
                    match resp.getJsonPayload() {
                        json j => {
                            log:printInfo("Response from invoiceDataEndpoint : " + j.toString());
                            success = true;
                        }
                        error err => {
                            log:printError("Response from invoiceDataEndpoint is not a json : " + err.message, err = err);
                        }
                    }
                }
                error err => {
                    log:printError("Error while calling invoiceDataEndpoint : " + err.message, err = err);
                }
            }
        }

        error err => {
            log:printError("Error while reading files from invoiceSFTPClient : " + err.message, err = err);
        }
    }

    return success;
}

function generateInvoicesJson(xml invoiceXml) returns json {

    json invoices;
    foreach i, x in invoiceXml.selectDescendants("ZECOMMINVOICE") {
        json invoiceJson = {
            "orderNo" : x.selectDescendants("ZBLCORD").getTextValue(),
            "invoiceId" : x.selectDescendants("VBELN").getTextValue(),
            "settlementId" : x.selectDescendants("ZSETTID").getTextValue(),
            "trackingNumber" : x.selectDescendants("TRACK_NUMBER").getTextValue(),
            "itemIds" : x.selectDescendants("ZBLCITEM").getTextValue(),
            "countryCode" : x.selectDescendants("LAND1").getTextValue(),
            "request" : <string> x,
            "processFlag" : "N",
            "retryCount" : 0,
            "errorMessage":"None"
        };
        invoices.invoices[i] = invoiceJson;
    }

    return invoices;
}

function archiveCompletedInvoice(string  path) {
    string archivePath = config:getAsString("ecomm_backend.invoice.sftp.path") + "/archive/" + getFileName(path);
    _ = invoiceSFTPClient -> rename(path, archivePath);
    io:println("Archived invoice path : ", archivePath);
}

function archiveErroredInvoice(string path) {
    string erroredPath = config:getAsString("ecomm_backend.invoice.sftp.path") + "/error/" + getFileName(path);
    _ = invoiceSFTPClient -> rename(path, erroredPath);
    io:println("Errored invoice path : ", erroredPath);
}

function getFileName(string path) returns string {
    string[] tmp = path.split("/");
    int size = lengthof tmp;
    return tmp[size-1];
}