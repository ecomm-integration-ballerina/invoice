import wso2/ftp;
import ballerina/io;
import ballerina/config;
import ballerina/mb;
import ballerina/log;

endpoint ftp:Listener invoiceSFTPListener {
    protocol: ftp:SFTP,
    host: config:getAsString("ecomm_backend.invoice.sftp.host"),
    port: config:getAsInt("ecomm_backend.invoice.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("ecomm_backend.invoice.sftp.username"),
            password: config:getAsString("ecomm_backend.invoice.sftp.password")
        }
    },
    path:config:getAsString("ecomm_backend.invoice.sftp.path") + "/original"
};

endpoint mb:SimpleQueueSender invoiceInboundQueue {
    host: config:getAsString("invoice.mb.host"),
    port: config:getAsInt("invoice.mb.port"),
    queueName: config:getAsString("invoice.mb.queueName")
};

service invoiceMonitor bind invoiceSFTPListener {

    fileResource (ftp:WatchEvent m) {

        foreach v in m.addedFiles {
            log:printInfo("New invoice received, inserting into invoiceInboundQueue : " + v.path);
            handleInvoice(v.path);
        }

        foreach v in m.deletedFiles {
            // ignore
        }
    }
}

function handleInvoice(string path) {
    match (invoiceInboundQueue.createTextMessage(path)) {
        error e => {
            log:printError("Error occurred while creating message", err = e);
        }
        mb:Message msg => {
            invoiceInboundQueue->send(msg) but {
                error e => log:printError("Error occurred while sending message to invoiceInboundQueue", err = e)
            };
        }
    }
}