import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/mysql;
import ballerina/sql;
import raj/invoice.model as model;

type invoiceBatchType string|int|float;

endpoint mysql:Client invoiceDB {
    host: config:getAsString("invoice.db.host"),
    port: config:getAsInt("invoice.db.port"),
    name: config:getAsString("invoice.db.name"),
    username: config:getAsString("invoice.db.username"),
    password: config:getAsString("invoice.db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false, serverTimezone:"UTC" }
};

public function addInvoice (http:Request req, model:Invoice invoice)
                    returns http:Response {

    string sqlString = "INSERT INTO invoice(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
        PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

    log:printInfo("Calling invoiceDB->insert for order : " + invoice.orderNo);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = invoiceDB->update(sqlString, invoice.orderNo, invoice.invoiceId, invoice.settlementId, 
            invoice.countryCode, invoice.processFlag, invoice.errorMessage, invoice.retryCount, invoice.itemIds, 
            invoice.trackingNumber, invoice.request);

        match ret {
            int insertedRows => {
                if (insertedRows < 1) {
                    log:printError("Calling invoiceDB->insert for order : " + invoice.orderNo 
                        + " failed", err = ());
                    isSuccessful = false;
                    abort;
                } else {
                    log:printInfo("Calling invoiceDB->insert order : " + invoice.orderNo + " succeeded");
                    isSuccessful = true;
                }
            }
            error err => {
                log:printError("Calling invoiceDB->insert for order : " + invoice.orderNo 
                    + " failed", err = err);
                isSuccessful = false;
                retry;
            }
        }        
    }  

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = http:OK_200;
        resJson = { "Status": "Invoice is inserted to the staging database for order : " 
                    + invoice.orderNo };
    } else {
        statusCode = http:INTERNAL_SERVER_ERROR_500;
        resJson = { "Status": "Failed to insert invoice to the staging database for order : " 
                    + invoice.orderNo };
    }
    
    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;   
}

public function addInvoices (http:Request req, model:Invoices invoices)
                    returns http:Response {

    string uniqueString;
    invoiceBatchType[][] invoiceBatches;
    foreach i, invoice in invoices.invoices {
        invoiceBatchType[] ref = [invoice.orderNo, invoice.invoiceId, invoice.settlementId, 
            invoice.countryCode, invoice.processFlag, invoice.errorMessage, invoice.retryCount, invoice.itemIds, 
            invoice.trackingNumber, invoice.request];
        invoiceBatches[i] = ref;
        uniqueString = uniqueString + "," + invoice.orderNo;        
    }
    
    string sqlString = "INSERT INTO invoice(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
        PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

    log:printInfo("Calling invoiceDB->batchUpdate for order : " + uniqueString);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {  
        var retBatch = invoiceDB->batchUpdate(sqlString, ...invoiceBatches); 
        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling invoiceDB->batchUpdate for order : =" + uniqueString 
                            + " failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling invoiceDB->batchUpdate order : " + uniqueString + " succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling invoiceDB->batchUpdate for order : " + uniqueString 
                    + " failed", err = err);
                retry;
            }
        }
    }        

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = http:OK_200;
        resJson = { "Status": "Invoices are inserted to the staging database for order : " 
            + uniqueString};
    } else {
        statusCode = http:INTERNAL_SERVER_ERROR_500;
        resJson = { "Status": "Failed to insert invoices to the staging database for order : " 
            + uniqueString };
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function updateProcessFlag (http:Request req, model:Invoice invoice)
                    returns http:Response {

    log:printInfo("Calling invoiceDB->updateProcessFlag for tid : " + invoice.transactionId + 
                    ", order : " + invoice.orderNo);
    string sqlString = "UPDATE invoice SET PROCESS_FLAG = ?, RETRY_COUNT = ?, ERROR_MESSAGE = ? 
                            where TRANSACTION_ID = ?";

    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = invoiceDB->update(sqlString, invoice.processFlag, invoice.retryCount, 
                                    invoice.errorMessage, invoice.transactionId);

        match ret {
            int insertedRows => {
                log:printInfo("Calling invoiceDB->updateProcessFlag for tid : " + invoice.transactionId + 
                                ", order : " + invoice.orderNo + " succeeded");
                isSuccessful = true;
            }
            error err => {
                log:printError("Calling invoiceDB->updateProcessFlag for tid : " + invoice.transactionId + 
                                ", order : " + invoice.orderNo + " failed", err = err);
                retry;
            }
        }        
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlag is updated for order : " + invoice.transactionId };
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "Failed to update ProcessFlag for order : " + invoice.transactionId };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function batchUpdateProcessFlag (http:Request req, model:Invoices invoices)
                    returns http:Response {

    invoiceBatchType[][] invoiceBatches;
    foreach i, invoice in invoices.invoices {
        invoiceBatchType[] ref = [invoice.processFlag, invoice.retryCount, 
                                    invoice.errorMessage, invoice.transactionId];
        invoiceBatches[i] = ref;
    }

    string sqlString = "UPDATE invoice SET PROCESS_FLAG = ?, RETRY_COUNT = ?, ERROR_MESSAGE = ? 
                            where TRANSACTION_ID = ?";

    log:printInfo("Calling invoiceDB->batchUpdateProcessFlag");
    
    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var retBatch = invoiceDB->batchUpdate(sqlString, ... invoiceBatches);

        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling invoiceDB->batchUpdateProcessFlag failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling invoiceDB->batchUpdateProcessFlag succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling invoiceDB->batchUpdateProcessFlag failed", err = err);
                retry;
            }
        }      
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlags updated"};
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "ProcessFlags not updated" };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function getInvoices (http:Request req)
                    returns http:Response {

    int retryCount = config:getAsInt("invoice.data.service.default.retryCount");
    int resultsLimit = config:getAsInt("invoice.data.service.default.resultsLimit");
    string processFlag = config:getAsString("invoice.data.service.default.processFlag");

    map<string> params = req.getQueryParams();

    if (params.hasKey("processFlag")) {
        processFlag = params.processFlag;
    }

    if (params.hasKey("maxRetryCount")) {
        match <int> params.maxRetryCount {
            int n => {
                retryCount = n;
            }
            error err => {
                throw err;
            }
        }
    }

    if (params.hasKey("maxRecords")) {
        match <int> params.maxRecords {
            int n => {
                resultsLimit = n;
            }
            error err => {
                throw err;
            }
        }
    }

    string sqlString = "select * from invoice where PROCESS_FLAG in ( ? ) 
        and RETRY_COUNT <= ? order by TRANSACTION_ID asc limit ?";

    string[] processFlagArray = processFlag.split(",");
    sql:Parameter processFlagPara = { sqlType: sql:TYPE_VARCHAR, value: processFlagArray };

    var ret = invoiceDB->select(sqlString, model:Invoice, processFlagPara, retryCount, resultsLimit);

    http:Response resp = new;
    json jsonReturnValue;
    match ret {
        table tableReturned => {
            jsonReturnValue = check <json> tableReturned;
            resp.statusCode = http:OK_200;
        }
        error err => {
            jsonReturnValue = { "Status": "Internal Server Error", "Error": err.message };
            resp.statusCode = http:INTERNAL_SERVER_ERROR_500;
        }
    }

    resp.setJsonPayload(untaint jsonReturnValue);
    return resp;
}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}