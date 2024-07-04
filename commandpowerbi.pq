//
// Implementation notes:
//
//  Claims Authentication:
//  * A claims token must be pre-generated from another method prior to using Power BI
//      NOTE: A long-lived token may be required when returning large data sets
//  * Select 'Anonymous' in the Power BI authentication screen
//  * Enter the token in the 'Claim Token' field on the query
//
//  Extra Certificate Row:
//  * The total number of records is returned in the header by Keyfactor Command API calls
//    however, Power BI custom connectors can only read the content-type header.  So in order
//    to implement paging, pages of returned data are read until an empty page is returned.
//    This results in an additional 'null' record which can easily be filtered out after import.
//

[Version = "1.0.0"]
section commandpowerbi;

[DataSource.Kind="commandpowerbi", Publish="commandpowerbi.Publish"]
shared commandpowerbi.Contents = Value.ReplaceType(commandpowerbiImpl, commandpowerbiType);

commandpowerbiType = type function () as table meta [
        Documentation.Name = "Keyfactor Command Power BI Connector",
        Documentation.LongDescription = "A set of functions to call Keyfactor Command API endpoints to return data for analysis."
    ];

// Creates a Power BI navigation table with the desired Keyfactor Command API endpoint calling functions
commandpowerbiImpl = () =>
    let
        source = #table (
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"GetCertificates", "GetCertificates", commandpowerbi.GetCertificates, "Function", "GetCertificates", true},
                {"GetSSLNetworks", "GetSSLNetworks", commandpowerbi.GetSSLNetworks, "Function", "GetSSLNetworks", true}
            }
        ),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

//
// Certificates
// 
[Datasource.Kind = "commandpowerbi"]
shared commandpowerbi.GetCertificates = Value.ReplaceType(GetCertificates, GetCertificatesType);

GetCertificatesType = 
    type function (    
    ApiUrl as (
        type text meta [
            Documentation.FieldCaption = "Keyfactor API URI",
            Documentation.FieldDescription = "URI pointing to the Keyfactor Command API",
            Documentation.SampleValues = {"https://keyfactor.company.com/KeyfactorAPI/"}
        ]
    ),
    optional ClaimToken as (
        type text meta [
            Documentation.FieldCaption = "Claim Token (OAuth only)",
            Documentation.FieldDescription = "Currently valid claim token - only required for Anonymous->Claims Authentication",
            Documentation.SampleValues = {"abcdefg12345678"}
        ]
    ),
    optional IncludeRevoked as (
        type text meta [
            Documentation.FieldCaption = "Include Revoked",
            Documentation.FieldDescription = "Include revoked certificates in the results",
            Documentation.AllowedValues = {"true", "false"}
        ]
    ),
    optional IncludeExpired as (
        type text meta [
            Documentation.FieldCaption = "Include Expired",
            Documentation.FieldDescription = "Include expired certificates in the results",
            Documentation.AllowedValues = {"true", "false"}
        ]
    ),
    optional IncludeMetadata as (
        type text meta [
            Documentation.FieldCaption = "Include Metadata",
            Documentation.FieldDescription = "Include metadata in the certificate results",
            Documentation.AllowedValues = {"true", "false"}
        ]
    ),
    optional IncludeLocations as (
        type text meta [
            Documentation.FieldCaption = "Include Locations",
            Documentation.FieldDescription = "Include certificate locations in the results",
            Documentation.AllowedValues = {"true", "false"}
        ]
    ),
    optional IncludeHasPrivateKey as (
        type text meta [
            Documentation.FieldCaption = "Include Private Key Flag",
            Documentation.FieldDescription = "Include the flag indicating if a certificate has a private key in the results",
            Documentation.AllowedValues = {"true", "false"}
        ]
    ),
    optional PageSize as (
        type number meta [
            Documentation.FieldCaption = "Page Size",
            Documentation.FieldDescription = "Maximum number of records to be returned from a single request",
            Documentation.SampleValues = {"1000"}
        ]
    ),
    optional CertificateQuery as (
        type text meta [
            Documentation.FieldCaption = "Certificate Query",
            Documentation.FieldDescription = "Optional query to filter certificates",
            Documentation.SampleValues = {"field1 -eq value1 AND field2 -gt value2"}
        ]
    ),
    optional CollectionId as (
        type number meta [
            Documentation.FieldCaption = "Collection Id",
            Documentation.FieldDescription = "Optional certificate collection identifier used to ensure user access to the certificate",
            Documentation.SampleValues = {"1000"}
        ]
    )) as table
    meta
    [
        Documentation.Name = "KeyfactorCommand.GetCertificates",
        Documentation.LongDescription = "Return certificates matching the provided criteria"
    ];

// Gets all certificates according to the provided parameters
GetCertificates = 
    (ApiUrl as text, optional ClaimsToken as text, optional IncludeRevoked as text, optional IncludeExpired as text, optional IncludeMetadata as text,
        optional IncludeLocations as text, optional IncludeHasPrivateKey as text, optional PageSize as number, optional CertificateQuery as text, 
        optional CollectionId as number) as table =>
    Table.GenerateByPage(
        (previous) =>
            let
                // Process optional variables and provide default values if null
                apiBase = if Text.EndsWith(ApiUrl, "/") then ApiUrl else ApiUrl & "/",
                returnLimit = if PageSize <> null then PageSize else 1000,
                queryString = if CertificateQuery <> null then "&QueryString=" & Uri.EscapeDataString(CertificateQuery) else "",
                collId = if CollectionId <> null then CollectionId else 0,
                claim = if ClaimsToken <> null then ClaimsToken else "",
                incRevoked = if IncludeRevoked <> null then IncludeRevoked else "false",
                incExpired = if IncludeExpired <> null then IncludeExpired else "false",
                incMetadata = if IncludeMetadata <> null then IncludeMetadata else "false",
                incLocations = if IncludeLocations <> null then IncludeLocations else "false",
                incHasPrivateKey = if IncludeHasPrivateKey <> null then IncludeHasPrivateKey else "false",

                // This is the first page of data if 'previous' is null
                nextPage = if (previous = null) then 1 else Value.Metadata(previous)[NextPage]?,

                // All records have been processed if 'nextPage' was set to null by the previous call
                page = if (nextPage <> null) then 
                        // Retrieve the next page of data
                        GetCertsPage(apiBase, claim, returnLimit, incRevoked, incExpired, incMetadata, 
                        incLocations, incHasPrivateKey, queryString, collId, nextPage) 
                       else null
            in
                page
    );

// Gets an individual page of certificate records according to the page size
GetCertsPage = (url as text, claimsToken as text, pageSize as number, includeRevoked as text, includeExpired as text, includeMetadata as text, 
    includeLocations as text, includeHasPrivateKey as text, certificateQuery as text, collectionId as number, page as number) as table =>
    let
        // Only attempt to add an authorization header if a claim token was provided
        RequestHeaders = if claimsToken <> "" then [#"Authorization"="Bearer " & claimsToken] else [],

        // Construct the query & querystring and call the certificates endpoint
        source = Web.Contents(url & "Certificates?PageReturned=" 
            & Number.ToText(page) 
            & "&ReturnLimit=" 
            & Number.ToText(pageSize) 
            & "&QueryString="
            & certificateQuery 
            & "&collectionId="
            & Number.ToText(collectionId)
            & "&includeRevoked="
            & includeRevoked
            & "&includeExpired="
            & includeExpired
            & "&includeMetadata="
            & includeMetadata
            & "&includeLocations="
            & includeLocations
            & "&includeHasPrivateKey="
            & includeHasPrivateKey 
            & "&verbose=0", 
            [Headers=RequestHeaders]), 
        
        // Process the results into a json object
        json = Json.Document(source),
        asTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        // Determine if the end of the results has been reached if no records are returned
        nextPage = if Table.IsEmpty(asTable) then null else page + 1,

        expandAll = if Table.IsEmpty(asTable) then 
                        // Create an empty table, which creates a null row
                        // While this is not desireable it is required since the total number of records is unknown
                        #table({"Id", "Thumbprint", "SerialNumber", "IssuedDN", "IssuedCN", "ImportDate", "NotBefore", "NotAfter", "IssuerDN", "PrincipalId", "TemplateId", "CertState", "KeySizeInBits", 
                        "KeyType", "RequesterId", "IssuedOU", "IssuedEmail", "KeyUsage", "SigningAlgorithm", "CertStateString", "KeyTypeString", "RevocationEffDate", "RevocationReason", "RevocationComment", 
                        "CertificateAuthorityId", "CertificateAuthorityName", "TemplateName", "ArchivedKey", "HasPrivateKey", "PrincipalName", "CertRequestId", "RequesterName", "ContentBytes", 
                        "ExtendedKeyUsages", "SubjectAltNameElements", "CRLDistributionPoints", "LocationsCount", "SSLLocations", "Locations", "Metadata", "CertificateKeyId", "CARowIndex", "CARecordId", 
                        "DetailedKeyUsage", "KeyRecoverable", "Curve"}, {})
                    else 
                        Table.ExpandRecordColumn(asTable, "Column1", {"Id", "Thumbprint", "SerialNumber", "IssuedDN", "IssuedCN", "ImportDate", "NotBefore", "NotAfter", "IssuerDN", "PrincipalId", 
                        "TemplateId", "CertState", "KeySizeInBits", "KeyType", "RequesterId", "IssuedOU", "IssuedEmail", "KeyUsage", "SigningAlgorithm", "CertStateString", "KeyTypeString", "RevocationEffDate", 
                        "RevocationReason", "RevocationComment", "CertificateAuthorityId", "CertificateAuthorityName", "TemplateName", "ArchivedKey", "HasPrivateKey", "PrincipalName", "CertRequestId", 
                        "RequesterName", "ContentBytes", "ExtendedKeyUsages", "SubjectAltNameElements", "CRLDistributionPoints", "LocationsCount", "SSLLocations", "Locations", "Metadata", "CertificateKeyId", 
                        "CARowIndex", "CARecordId", "DetailedKeyUsage", "KeyRecoverable", "Curve"}, 
                        {"Id", "Thumbprint", "SerialNumber", "IssuedDN", "IssuedCN", "ImportDate", "NotBefore", "NotAfter", "IssuerDN", "PrincipalId", "TemplateId", "CertState", "KeySizeInBits", 
                        "KeyType", "RequesterId", "IssuedOU", "IssuedEmail", "KeyUsage", "SigningAlgorithm", "CertStateString", "KeyTypeString", "RevocationEffDate", "RevocationReason", "RevocationComment", 
                        "CertificateAuthorityId", "CertificateAuthorityName", "TemplateName", "ArchivedKey", "HasPrivateKey", "PrincipalName", "CertRequestId", "RequesterName", "ContentBytes", 
                        "ExtendedKeyUsages", "SubjectAltNameElements", "CRLDistributionPoints", "LocationsCount", "SSLLocations", "Locations", "Metadata", "CertificateKeyId", "CARowIndex", "CARecordId", 
                        "DetailedKeyUsage", "KeyRecoverable", "Curve"})
    in
        expandAll meta [NextPage = nextPage];

//
// SSL
// 
[Datasource.Kind = "commandpowerbi"]
shared commandpowerbi.GetSSLNetworks = Value.ReplaceType(GetSSLNetworks, GetSSLNetworksType);

GetSSLNetworksType = 
    type function (    
    ApiUrl as (
        type text meta [
            Documentation.FieldCaption = "Keyfactor API URI",
            Documentation.FieldDescription = "URI pointing to the Keyfactor Command API",
            Documentation.SampleValues = {"https://keyfactor.company.com/KeyfactorAPI/"}
        ]
    ),
    optional ClaimToken as (
        type text meta [
            Documentation.FieldCaption = "Claim Token (OAuth only)",
            Documentation.FieldDescription = "Currently valid claim token - only required for Anonymous->Claims Authentication",
            Documentation.SampleValues = {"abcdefg12345678"}
        ]
    ),
    optional PageSize as (
        type number meta [
            Documentation.FieldCaption = "Page Size",
            Documentation.FieldDescription = "Maximum number of records to be returned from a single request",
            Documentation.SampleValues = {"1000"}
        ]
    ),
    optional Query as (
        type text meta [
            Documentation.FieldCaption = "Query",
            Documentation.FieldDescription = "Optional query to filter SSL Networks",
            Documentation.SampleValues = {"field1 -eq value1 AND field2 -gt value2"}
        ]
    )) as table
    meta
    [
        Documentation.Name = "KeyfactorCommand.GetSSLNetworks",
        Documentation.LongDescription = "Return SSL networks matching the provided criteria"
    ];

// Gets all SSL networks according to the provided parameters
GetSSLNetworks = 
    (ApiUrl as text, optional ClaimsToken as text, optional PageSize as number, optional Query as text) as table =>
    Table.GenerateByPage(
        (previous) =>
            let
                // Process optional variables and provide default values if null
                apiBase = if Text.EndsWith(ApiUrl, "/") then ApiUrl else ApiUrl & "/",
                returnLimit = if PageSize <> null then PageSize else 1000,
                queryString = if Query <> null then "&QueryString=" & Uri.EscapeDataString(Query) else "",
                claim = if ClaimsToken <> null then ClaimsToken else "",

                // This is the first page of data if 'previous' is null
                nextPage = if (previous = null) then 1 else Value.Metadata(previous)[NextPage]?,

                // All records have been processed if 'nextPage' was set to null by the previous call
                page = if (nextPage <> null) then 
                        // Retrieve the next page of data
                        GetSSLNetworksPage(apiBase, claim, returnLimit, queryString, nextPage) 
                       else null
            in
                page
    );

// Gets an individual page of SSL network records according to the page size
GetSSLNetworksPage = (url as text, claimsToken as text, pageSize as number, Query as text, page as number) as table =>
    let
        // Only attempt to add an authorization header if a claim token was provided
        RequestHeaders = if claimsToken <> "" then [#"Authorization"="Bearer " & claimsToken] else [],

        // Construct the query & querystring and call the certificates endpoint
        source = Web.Contents(url & "SSL/Networks?PageReturned=" 
            & Number.ToText(page) 
            & "&ReturnLimit=" 
            & Number.ToText(pageSize) 
            & "&QueryString="
            & Query 
            & "&verbose=0", 
            [Headers=RequestHeaders]), 
        
        // Process the results into a json object
        json = Json.Document(source),
        asTable = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

        // Determine if the end of the results has been reached if no records are returned
        nextPage = if Table.IsEmpty(asTable) then null else page + 1,

        expandAll = if Table.IsEmpty(asTable) then 
                        // Create an empty table, which creates a null row
                        // While this is not desireable it is required since the total number of records is unknown
                        #table({"NetworkId", "Name", "AgentPoolName", "AgentPoolId", "Description", "Enabled", "DiscoverSchedule"}, {})
                    else 
                        Table.ExpandRecordColumn(asTable, "Column1", {"NetworkId", "Name", "AgentPoolName", "AgentPoolId", "Description", "Enabled", "DiscoverSchedule"}, 
                            {"NetworkId", "Name", "AgentPoolName", "AgentPoolId", "Description", "Enabled", "DiscoverSchedule"})
    in
        expandAll meta [NextPage = nextPage];

// Data Source Kind description
commandpowerbi = [
    Authentication = [
        Anonymous = [],                                     // Anonymous is used for OAuth implementation
        UsernamePassword = [],                              // UsernamePassword is used for Basic auth implementation
        Windows = [ SupportsAlternateCredentials = true ]   // Windows is used for AD auth implementation
    ]
];

// Data Source UI publishing description
commandpowerbi.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = commandpowerbi.Icons,
    SourceTypeImage = commandpowerbi.Icons
];

commandpowerbi.Icons = [
    Icon16 = { Extension.Contents("keyfactor-command-icon-16.png"), Extension.Contents("keyfactor-command-icon-20.png"), Extension.Contents("keyfactor-command-icon-24.png"), Extension.Contents("keyfactor-command-icon-32.png") },
    Icon32 = { Extension.Contents("keyfactor-command-icon-32.png"), Extension.Contents("keyfactor-command-icon-40.png"), Extension.Contents("keyfactor-command-icon-48.png"), Extension.Contents("keyfactor-command-icon-64.png") }
];

//
// Common functions
//
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// The getNextPage function takes a single argument and is expected to return a nullable table
Table.GenerateByPage = (getNextPage as function) as table =>
    let
        listOfPages = List.Generate(
            // get the first page of data
            () => getNextPage(null),
            // stop when the function returns null
            (lastPage) => lastPage <> null,
            // pass the previous page to the next function call
            (lastPage) => getNextPage(lastPage)
        ),
        // concatenate the pages together
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0} ?
    in
        // if we didn't get back any pages of data, return an empty table
        // otherwise set the table type based on the columns of the first page
        if (firstRow = null) then
            Table.FromRows({})
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );