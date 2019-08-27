/**
 * Created by Matt Gerry ::: 8/23/2019.
 */

public with sharing class PDF_Page_Wrapper
{
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


	public static PDF_Page_Wrapper parse(String json)
	{
		return (PDF_Page_Wrapper) System.JSON.deserialize(json, PDF_Page_Wrapper.class);
	}
}