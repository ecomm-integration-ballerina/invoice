public type Invoice record {
    int transactionId;
    string orderNo;
    string invoiceId;
    string settlementId;
    string trackingNumber;
    string itemIds;
    string countryCode;
    string request;
    string processFlag;
    int retryCount;
    string errorMessage;
    string createdTime;
    string lastUpdatedTime;
};

public type Invoices record {
    Invoice[] invoices;
};