void DownloadFiles()
{
	PrecacheEffect("ParticleEffect");
	
	char Configfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/kento_sandbox/downloads.cfg");
	
	if (!FileExists(Configfile))
	{
		LogError("Unable to open download file \"%s\"!", Configfile);
		return;
	}
	
	char line[PLATFORM_MAX_PATH];
	Handle fileHandle = OpenFile(Configfile,"r");

	while(!IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, line, sizeof(line)))
	{
		// Remove whitespaces and empty lines
		TrimString(line);
		ReplaceString(line, sizeof(line), " ", "", false);
	
		// Skip comments
		if (line[0] != '/' && FileExists(line, true))
		{
			AddFileToDownloadsTable(line);
		}
	}
	CloseHandle(fileHandle);
}