/**
 * This wrapper class takes JSON data representing a ContentDocument/PDFPage and parses it into an object we can use
 * in our apex controller
 * Created by Matt Gerry ::: gAuto ::: 8/23/2019.
 */

public with sharing class PDF_Page_Wrapper
{
	//Attributes of the JSON object
	public class ContentDocuments
	{
		public List<Documents> documentsList;
	}

	public ContentDocuments ContentDocuments;

	public class Documents
	{
		public String Title;
		public String VersionData;
		public String PathOnClient;
	}
	//End attributes of the JSON object

	//This method takes a JSON string, parses it out and turns it into a PDF_Page_Wrapper object
	public static PDF_Page_Wrapper parse(String json)
	{
		return (PDF_Page_Wrapper) System.JSON.deserialize(json, PDF_Page_Wrapper.class);
	}
}