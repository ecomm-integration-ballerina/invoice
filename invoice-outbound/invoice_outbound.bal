import ballerina/log;
import ballerina/http;
import ballerina/config;
import ballerina/task;
import ballerina/runtime;
import ballerina/io;
import raj/invoice.model as model;

endpoint http:Client invoiceDataServiceEndpoint {
    url: config:getAsString("invoice.data.service.url")
};

endpoint http:Client ecommFrontendInvoiceAPIEndpoint {
    url: config:getAsString("ecomm_frontend.invoice.api.url")
};

int count;
task:Timer? timer;
int interval = config:getAsInt("invoice.outbound.task.interval");
int delay = config:getAsInt("invoice.outbound.task.delay");
int maxRetryCount = config:getAsInt("invoice.outbound.task.maxRetryCount");
int maxRecords = config:getAsInt("invoice.outbound.task.maxRecords");
string apiKey = config:getAsString("ecomm_frontend.invoice.api.key");


function main(string... args) {

    (function() returns error?) onTriggerFunction = doInvoiceETL;

    function(error) onErrorFunction = handleError;

    log:printInfo("Starting invoices ETL");

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(20000000);
}

function doInvoiceETL() returns  error? {

    log:printInfo("Starting invoices ETL");
    log:printInfo("Calling invoiceDataServiceEndpoint to fetch invoices");

    http:Request req = new;

    var response = invoiceDataServiceEndpoint->get("?maxRecords=" + maxRecords
            + "&maxRetryCount=" + maxRetryCount + "&processFlag=N,E");

    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json jsonInvoiceArray => {

                    model:Invoice[] invoices = check <model:Invoice[]> jsonInvoiceArray;
                    // terminate the flow if no invoices found
                    if (lengthof invoices == 0) {
                        return;
                    }
                    // update process flag to P in DB so that next ETL won't fetch these again
                    boolean success = batchUpdateProcessFlagsToP(invoices);
                    // send invoices to Ecomm Frontend
                    if (success) {
                        processInvoicesToEcommFrontend(invoices);
                    }
                }
                error err => {
                    log:printError("Response from invoiceDataServiceEndpoint is not a json : " + err.message, err = err);
                    throw err;
                }
            }
        }
        error err => {
            log:printError("Error while calling invoiceDataServiceEndpoint : " + err.message, err = err);
            throw err;
        }
    }

    return ();
}

function processInvoicesToEcommFrontend (model:Invoice[] invoices) {
    
    http:Request req = new;
    foreach invoice in invoices {

        int tid = invoice.transactionId;
        string invoiceId = invoice.invoiceId;
        string orderNo = invoice.orderNo;
        int retryCount = invoice.retryCount;

        json jsonPayload = untaint getInvoicePayload(invoice);
        req.setJsonPayload(jsonPayload);
        req.setHeader("Api-Key", apiKey);
        string contextId = "ECOMM_" + invoice.countryCode;
        req.setHeader("Context-Id", contextId);

        log:printInfo("Calling ecomm-frontend to process invoice for : " + invoiceId + ". Payload : " + jsonPayload.toString());

        var response = ecommFrontendInvoiceAPIEndpoint->post("/" + untaint orderNo + "/capture/async", req);

        match response {
            http:Response resp => {

                int httpCode = resp.statusCode;
                if (httpCode == 201) {
                    log:printInfo("Successfully processed invoice : " + invoiceId + " to ecomm-frontend");
                    updateProcessFlag(tid, retryCount, "C", "sent to ecomm-frontend");
                } else {
                    match resp.getTextPayload() {
                        string payload => {
                            log:printInfo("Failed to process invoice : " + invoiceId +
                                    " to ecomm-frontend. Error code : " + httpCode + ". Error message : " + payload);
                            updateProcessFlag(tid, retryCount + 1, "E", payload);
                        }
                        error err => {
                            log:printInfo("Failed to process invoice : " + invoiceId +
                                    " to ecomm-frontend. Error code : " + httpCode);
                            updateProcessFlag(tid, retryCount + 1, "E", err.message);
                        }
                    }
                }
            }
            error err => {
                log:printError("Error while calling ecomm-frontend for invoice : " + invoiceId, err = err);
                updateProcessFlag(tid, retryCount + 1, "E", err.message);
            }
        }
    }
}

function getInvoicePayload(model:Invoice invoice) returns (json) {

    // convert string 7,8,9 to json ["7","8","9"]
    string itemIds = invoice.itemIds;
    string[] itemIdsArray = itemIds.split(",");
    json itemIdsJsonArray = check <json> itemIdsArray;

    string request = invoice.request;
    io:StringReader sr = new(request);
    xml? requestXml = check sr.readXml();

    json invoicePayload = {
        "amount": requestXml.DMBTR.getTextValue(),
        "totalAmount": requestXml.ZDMBTR.getTextValue(),
        "currency": requestXml.WAERK.getTextValue(),
        "countryCode": invoice.countryCode,
        "invoiceId": invoice.invoiceId,
        "itemIds": itemIdsJsonArray,
        "additionalProperties":{
            "trackingNumber": invoice.trackingNumber
        }
    };

    if (<string>invoice["SETTLEMENT_ID"] != "") {
        invoicePayload["settlementId"] = invoice.settlementId;
    }

    return invoicePayload;
}

function batchUpdateProcessFlagsToP (model:Invoice[] invoices) returns boolean {

    json batchUpdateProcessFlagsPayload;
    foreach i, invoice in invoices {
        json updateProcessFlagPayload = {
            "transactionId": invoice.transactionId,
            "retryCount": invoice.retryCount,
            "processFlag": "P"           
        };
        batchUpdateProcessFlagsPayload.invoices[i] = updateProcessFlagPayload;
    }

    http:Request req = new;
    req.setJsonPayload(untaint batchUpdateProcessFlagsPayload);

    var response = invoiceDataServiceEndpoint->put("/process-flag/batch/", req);

    boolean success;
    match response {
        http:Response resp => {
            if (resp.statusCode == 202) {
                success = true;
            }
        }
        error err => {
            log:printError("Error while calling invoiceDataServiceEndpoint.batchUpdateProcessFlags", err = err);
        }
    }

    return success;
}

function updateProcessFlag(int tid, int retryCount, string processFlag, string errorMessage) {

    json updateInvoice = {
        "transactionId": tid,
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updateInvoice);

    var response = invoiceDataServiceEndpoint->put("/process-flag/", req);

    match response {
        http:Response resp => {
            int httpCode = resp.statusCode;
            if (httpCode == 202) {
                if (processFlag == "E" && retryCount > maxRetryCount) {
                    notifyOperation();
                }
            }
        }
        error err => {
            log:printError("Error while calling invoiceDataServiceEndpoint", err = err);
        }
    }
}

function notifyOperation()  {
    log:printInfo("Notifying operations");
}

function handleError(error e) {
    log:printError("Error in processing invoices to ecomm-frontend", err = e);
    // I don't want to stop the ETL if backend is down
    // timer.stop();
}
