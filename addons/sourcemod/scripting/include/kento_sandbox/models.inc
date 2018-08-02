// Code edit from
// https://forums.alliedmods.net/showpost.php?p=2155885&postcount=32
void LoadModels()
{
	char Configfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/kento_sandbox/models.cfg");
	
	if (!FileExists(Configfile))
	{
		SetFailState("Fatal error: Unable to open configuration file \"%s\"!", Configfile);
	}
	
	KeyValues kv = CreateKeyValues("Models");
	kv.ImportFromFile(Configfile);
	
	if(!kv.GotoFirstSubKey())
	{
		SetFailState("Fatal error: Unable to read configuration file \"%s\"!", Configfile);
	}
	
	char name[30], lang[4], title[100], path[1024], finalOutput[100];
	int langID, nextLangID = -1;
	int g_iTotalModelsAvailable = 0;
	do
	{
		// get the model path and precache it
		kv.GetSectionName(path, sizeof(path));
		FormatEx(finalOutput, sizeof(finalOutput), "models/%s.mdl", path);
		PrecacheModel(finalOutput, true);
		
		// roll through all available languages
		for(int i=0;i<GetLanguageCount();i++)
		{
			GetLanguageInfo(i, lang, sizeof(lang));
			// search for the translation
			kv.GetString(lang, name, sizeof(name));
			if(strlen(name) > 0)
			{
				
				// language already in array, only in the wrong order in the file?
				langID = GetLanguageID(lang);
				
				// language new?
				if(langID == -1)
				{
					nextLangID = GetNextLangID();
					MenuLanguage[nextLangID] = lang;
				}
				
				if(langID == -1)
				{
					if(Menu_DynamicModel[nextLangID] == INVALID_HANDLE)
					{
						// new language, create the menu
						Menu_DynamicModel[nextLangID] = CreateMenu(MenuHandler_DynamicModel);
						Format(title, sizeof(title), "%T", "Dynamic Model Title", LANG_SERVER);
						Menu_DynamicModel[nextLangID].SetTitle(title);
						Menu_DynamicModel[nextLangID].ExitButton = true;
					}
					
					if(Menu_PhysicsModel[nextLangID] == INVALID_HANDLE)
					{
						// new language, create the menu
						Menu_PhysicsModel[nextLangID] = CreateMenu(MenuHandler_PhysicsModel);
						Format(title, sizeof(title), "%T", "Physics Model Title", LANG_SERVER);
						Menu_PhysicsModel[nextLangID].SetTitle(title);
						Menu_PhysicsModel[nextLangID].ExitButton = true;
					}
					
					if(Menu_StaticModel[nextLangID] == INVALID_HANDLE)
					{
						// new language, create the menu
						Menu_StaticModel[nextLangID] = CreateMenu(MenuHandler_StaticModel);
						Format(title, sizeof(title), "%T", "Static Model Title", LANG_SERVER);
						Menu_StaticModel[nextLangID].SetTitle(title);
						Menu_StaticModel[nextLangID].ExitButton = true;
					}
				}
				
				// add it to the menu
				if(langID == -1)
				{
					Menu_DynamicModel[nextLangID].AddItem(finalOutput, name);
					Menu_PhysicsModel[nextLangID].AddItem(finalOutput, name);
					Menu_StaticModel[nextLangID].AddItem(finalOutput, name);
				}
				else
				{
					Menu_DynamicModel[langID].AddItem(finalOutput, name);
					Menu_PhysicsModel[langID].AddItem(finalOutput, name);
					Menu_StaticModel[langID].AddItem(finalOutput, name);
				}
			}
			
		}
		
		g_iTotalModelsAvailable++;
	} while (kv.GotoNextKey());
	
	kv.Rewind();
	delete kv;
	
	if (g_iTotalModelsAvailable == 0)
	{
		SetFailState("No models parsed in configuration file \"%s\"!", Configfile);
		return;
	}
}

public int MenuHandler_DynamicModel(Menu menu, MenuAction action, int client, int param)
{
	// make sure again, the player is a Terrorist
	if(IsValidClient(client))
	{
		if (action == MenuAction_Select)
		{
			char sModelPath[100];
			
			GetMenuItem(menu, param, sModelPath, sizeof(sModelPath));
				
			SpawnModel(client, sModelPath, 1);
			
			Menu_DynamicModel[GetClientLanguageID(client)].DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		} 
		else if(action == MenuAction_Cancel)
		{
			ShowMenu(client, "model");
		}
	}
}

public int MenuHandler_PhysicsModel(Menu menu, MenuAction action, int client, int param)
{
	// make sure again, the player is a Terrorist
	if(IsValidClient(client))
	{
		if (action == MenuAction_Select)
		{
			char sModelPath[100];
			
			GetMenuItem(menu, param, sModelPath, sizeof(sModelPath));
				
			SpawnModel(client, sModelPath, 2);
			
			Menu_PhysicsModel[GetClientLanguageID(client)].DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		} 
		else if(action == MenuAction_Cancel)
		{
			ShowMenu(client, "model");
		}
	}
}

public int MenuHandler_StaticModel(Menu menu, MenuAction action, int client, int param)
{
	// make sure again, the player is a Terrorist
	if(IsValidClient(client))
	{
		if (action == MenuAction_Select)
		{
			char sModelPath[100];
			
			GetMenuItem(menu, param, sModelPath, sizeof(sModelPath));
				
			SpawnModel(client, sModelPath, 3);
			
			Menu_StaticModel[GetClientLanguageID(client)].DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		} 
		else if(action == MenuAction_Cancel)
		{
			ShowMenu(client, "model");
		}
	}
}

void SpawnModel(int client, char [] path, int type)
{
	if(EdictCount() <= iLimit)
	{
		int model;
		if(type == 1)	model = CreateEntityByName("prop_dynamic_override");
		else if(type == 2)	model = CreateEntityByName("prop_physics_override");
		else if(type == 3)	model = CreateEntityByName("prop_static_override");
		
		DispatchKeyValue(model, "model", path);
		SetEntPropFloat(model, Prop_Send, "m_flModelScale", 1.0);
		
		//SetEntProp(model, Prop_Data, "m_CollisionGroup", 8);
		//SetEntProp(model, Prop_Data, "m_usSolidFlags", 152);
		SetEntProp(model, Prop_Data, "m_nSolidType", 6);
		
		SetEntProp(model, Prop_Data, "m_takedamage", 0);
	
		DispatchSpawn(model);	
		AcceptEntityInput(model, "TurnOn", model, model, 0);
		
		float pos[3];
		float clientEye[3], clientAngle[3];
		GetClientEyePosition(client, clientEye);
		GetClientEyeAngles(client, clientAngle);
			
		TR_TraceRayFilter(clientEye, clientAngle, MASK_SOLID, RayType_Infinite, HitSelf, client);
		
		if (TR_DidHit(INVALID_HANDLE))	TR_GetEndPosition(pos);
		
		TeleportEntity(model, pos, NULL_VECTOR, NULL_VECTOR); 
	
		SetVariantString("!activator");
	}
	else CPrintToChat(client, "%T", "Entity Limit", client);
}

public bool HitSelf(int entity, int contentsMask, any data)
{
	if (entity == data)	return false;
	return true;
}

int GetLanguageID(const char [] langCode)
{
	for(int i=0;i<MAX_LANGUAGES;i++)
	{
		if(StrEqual(MenuLanguage[i], langCode))
			return i;
	}
	return -1;
}

int GetClientLanguageID(int client, char languageCode[]="", int maxlen=0)
{
	char langCode[4];
	GetLanguageInfo(GetClientLanguage(client), langCode, sizeof(langCode));
	// is client's prefered language available?
	int langID = GetLanguageID(langCode);
	if(langID != -1)
	{
		strcopy(languageCode, maxlen, langCode);
		return langID; // yes.
	}
	else
	{
		GetLanguageInfo(GetServerLanguage(), langCode, sizeof(langCode));
		// is default server language available?
		langID = GetLanguageID(langCode);
		if(langID != -1)
		{
			strcopy(languageCode, maxlen, langCode);
			return langID; // yes.
		}
		else
		{
			// default to english
			for(int i=0;i<MAX_LANGUAGES;i++)
			{
				if(StrEqual(MenuLanguage[i], "en"))
				{
					strcopy(languageCode, maxlen, "en");
					return i;
				}
			}
			
			// english not found? happens on custom map configs e.g.
			// use the first language available
			// this should always work, since we would have SetFailState() on parse
			if(strlen(MenuLanguage[0]) > 0)
			{
				strcopy(languageCode, maxlen, MenuLanguage[0]);
				return 0;
			}
		}
	}
	// this should never happen
	return -1;
}

int GetNextLangID()
{
	for(int i=0;i<MAX_LANGUAGES;i++)
	{
		if(strlen(MenuLanguage[i]) == 0)	return i;
	}
	SetFailState("Can't handle more than %d languages. Increase MAX_LANGUAGES and recompile.", MAX_LANGUAGES);
	return -1;
}