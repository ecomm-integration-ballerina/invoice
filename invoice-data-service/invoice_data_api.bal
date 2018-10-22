import ballerina/http;
import ballerina/log;
import raj/invoice.model as model;

endpoint http:Listener invoiceListener {
    host: "localhost",
    port: 8280
};

@http:ServiceConfig {
    basePath: "/data/invoice"
}
service<http:Service> invoiceAPI bind invoiceListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        body: "invoice"
    }
    addInvoice (endpoint outboundEp, http:Request req, model:Invoice invoice) {
        http:Response res = addInvoice(req, untaint invoice);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["POST"],
        path: "/batch/",
        body: "invoices"
    }
    addInvoices (endpoint outboundEp, http:Request req, model:Invoices invoices) {
        http:Response res = addInvoices(req, untaint invoices);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/"
    }
    getInvoices (endpoint outboundEp, http:Request req) {
        http:Response res = getInvoices(untaint req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/",
        body: "invoice"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, model:Invoice invoice) {
        http:Response res = updateProcessFlag(req, untaint invoice);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/batch/",
        body: "invoices"
    }
    batchUpdateProcessFlag (endpoint outboundEp, http:Request req, model:Invoices invoices) {
        http:Response res = batchUpdateProcessFlag(req, invoices);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }    
}
