# Keyfactor Command Power BI Connector
## Summary
A common use case is to export certificate data from Command and import into Power BI or Excel for customized reporting and analysis.  A Power BI Custom Connector has been created to facilitate this use case.  The code is hosted and can be freely modified as desired to enhance functionality.

> The connector obtains data via the Keyfactor Command API. Retrieving large amounts of data could impact performance of the Command system.  Care should be taken during development and usage to ensure optimal system performance. 

## Preparing for Usage
A few steps will need to be completed prior to using the connector:
1. Install the Power BI Desktop: Power BI Desktop
2. Follow the steps in the following article to ensure the directory and Power BI settings are in place: [Power BI Connector Extensibility]([https://www.microsoft.com/en-us/power-platform/products/power-bi/desktop](https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-connector-extensibility))
3. Install Visual Studio Code: [Visual Studio Code](https://code.visualstudio.com/)
4. Install the Power Query SDK: [Power Query SDK on Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=PowerQuery.vscode-powerquery-sdk)
5. Clone the repository onto the local computer
6. Compile the connector into a commandpowerbi.mez file
7. Copy the commandpowerbi.mez into the directory outlined in step #2

## Using the Connector
> Some steps below relating to specific navigator functions assume the default connector is being used.

1. Open Power BI
2. Open the data connector dialog using either selecting ‘Get data from other sources’ from the home screen or ‘Get data’ and ‘More…’ from the workspace
3. Search for ‘Keyfactor’ or click on ‘Other’ and locate the connector and click on ‘Connector’
4. If this is the first use the authentication dialog will be displayed

> Use Anonymous for Claims authentication and the token can be provided in the navigator function.

> Previous authentication credentials can be cleared by selecting ‘Data source settings’ from the ‘Transform data’ method and click on ‘Clear Permissions’.

6. The ‘Navigator’ dialog will then be displayed showing the available functions, which by default are:
  - Get Certificates - Calls the Keyfactor Command API ‘Certificates' endpoint
  - Get SSL Networks - Calls the Keyfactor Command API ‘SSL/Networks’ endpoint
  - Get SSL Endpoints - Calls the Keyfactor Command API ‘SSL/Endpoints’ endpoint
7. The Keyfactor API URI should be entered as: <keyfactor command host>/<api endpoint>
8. The ‘Claim Token’ is only needed when ‘Anonymous’ is selected for authentication to utilize OAuth
9. Enter the desired parameters, using the associated API endpoint documentation as a guide and click on the ‘Apply’ button

> In most cases ‘Transform Data’ should be selected as the data will contain sub-tables and sub-records that will need to be manipulated into the desired data format.

## References
- [Power BI Custom Connector Tutorial](https://learn.microsoft.com/en-us/power-query/samples/trippin/readme)

## Support
command-powerbi is open source and supported on best effort level for this tool/library/client.  This means customers can report Bugs, Feature Requests, Documentation amendment or questions as well as requests for customer information required for setup that needs Keyfactor access to obtain. Such requests do not follow normal SLA commitments for response or resolution. If you have a support issue, please open a support ticket via the Keyfactor Support Portal at [https://support.keyfactor.com/](https://support.keyfactor.com/).
