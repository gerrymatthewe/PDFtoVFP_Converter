This stand alone Salesforce application takes any size PDF file and with the click of a button turns it into a Visualforce page within seconds..

The pdf to vfp converter allows you to take any PDF (each PDF page can only be 2GB maximum in size, the PDF itself can be as large as your org has space technically) and convert it into a visual force page instantly via an extremely easy to use UI. It can be configured to be run by any user as a loop hole has been implemented to bypass the limitations of the Tooling API.
Production Package URL: https://login.salesforce.com/packaging/installPackage.apexp?p0=04t1H000000KOwf

Sandbox Package URL: https://test.salesforce.com/packaging/installPackage.apexp?p0=04t1H000000KOwf

Video Demo of the PDF to VFP converter: https://www.youtube.com/watch?v=oHg2KfSI9ws

To setup the PDF to VFP converter correctly follow the instruction below after installing the package:

Enable content in your org
Create a library and name it whatever you want
Make sure the users you would like to utilize the converter have the "Salesforce CRM Content User" checkbox checked on their user.
Add the users you want to generate pdfs to the content library you created in step 2 as Library Administrators
Create a permission set that gives the users you would like to utilize the converter modify all and create access to the PDF and PDFPage objects and create and read access to the PDFtoVFP error log objet. Also ensure that the users have full permissions on the document object and access to the files tab. You will also want to grant them all permissions in the App Permissions section for Content.
Go to Setup -> Custom Settings -> PDF to VFP Settings -> Manage
Create new at the custom setting Hierarchy level
For apex page version put whatever version of Salesforce you are currently on (currently 46.0) or any previous version.
For System Admin Profile Name put the name of your System Administrator profile
For PDF Master CSS File put: gAuto__PDFtoVFP_Default_Generated_PDF_Page_CSS (you can change this css file at any point to change the look and feel of your generated pdfs)
For Content Library Name put the name of the content library you created in step 2
For the Visualforce Page Base URL, place the URL for your site that acts as the base URL prior to the /apex/[Visualforce Page Name]. Typically that looks something like this: "https://[domain or server number]--[namespace or the letter c if you have no namespace].visual.force.com
Save the custom setting
Go to Setup -> Custom Setting -> PDF to VFP Profiles for PDF Converter -> Manage
Create a new record for every profile you would like to potentially grant access to the visual force pages you are creating. In the name field place the exact name of the profile.
Go to Setup -> Remote Site Settings and edit the PDFtoVFP_Metadata_API
Change the url to your orgs url minus your namespace (if you have a namespace, most orgs probably do not have a namespace)
Go to Setup -> Remote Site Settings and edit the PDFtoVFP_ToolingAPI
Change the url to your orgs url for visual for pages. This is typically formatted the following way https://[namespace]—-gauto.[server or domain].visual.force.com
These steps are only necessary if non-admins are going to be utilizing the converter app so that they can "fake" access to the Tooling API:

Create a connected app (Setup -> Create -> Apps -> New Connected App)
Name the connected app whatever you'd like, use whatever contact email you'd like.
Check the "Enable OAuth Settings" button when setting up the app. Make the callback url whatever you'd like (ex: https://www.google.com). In "Selected OAuth Scopes" select whatever you want.
Create the app
Copy the Consumer Key and secret for your app
Create an API user for the pdf to vfp converter that is a System Administrator (or use an existing Administrators credentials). Write down the username, password and security token for that user.
Go to Setup -> Custom Setting -> PDF to VFP Admin Credentials -> Manage
In client secret, put the client secret that was generated when you created the connected app
In the Client Id, put the client id that was generated when you created the connected app
In the Password field put the password for you admin user you created in step 19
In the Username field put the username for the admin user you created in step 19
In the Security Token field put the security token for the admin user you created in step 19
In the Grant Type field put the value "password" without quotes
In the App Authentication Base URL field put the value "https://login.salesforce.com/services/oauth2/token" without quotes
Save the custom setting
Go to Settings -> Remote Site Settings and edit the PDFtoVFP_OAuth_Login
If you are in a sandbox make the url "https://test.salesforce.com" if you are in a production environment make the url "https://login.salesforce.com"
