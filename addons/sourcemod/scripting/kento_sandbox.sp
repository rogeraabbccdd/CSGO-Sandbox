#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <kento_csgocolors>
#include <clientprefs>
#include <cstrike>
#include <smlib>
#include <emitsoundany>

#pragma newdecls required

// Cvar
ConVar Cvar_Save;
float fSave;
Handle hSave = INVALID_HANDLE;
ConVar Cvar_Limit;
int iLimit;

// Menu
// Code taken from https://forums.alliedmods.net/showpost.php?p=2155885&postcount=32
#define MAX_LANGUAGES 27
Menu ModelMenu[MAX_LANGUAGES];
char MenuLanguage[MAX_LANGUAGES][4];

// Model
int iModelCount;

public Plugin myinfo =
{
	name = "[CS:GO] Sandbox",
	author = "Kento",
	version = "1.0",
	description = "Build your own world!",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart() 
{
	RegConsoleCmd("sm_model", CMD_Model, "Models menu");
	RegConsoleCmd("sm_dmodel", CMD_DeleteBlock, "Delete model");
	
	Cvar_Save = CreateConVar("sm_auto_save", "60.0", "Auto save in x seconds?\n0.0 = disabled, FLOAT VALUE ONLY", _, true, 0.0);
	Cvar_Save.AddChangeHook(OnConVarChanged);
	
	Cvar_Limit = CreateConVar("sm_model_limit", "300", "Max models", _, true, 0.0);
	Cvar_Limit.AddChangeHook(OnConVarChanged);
	
	AutoExecConfig(true, "kento_sandbox");
}

public void OnConfigsExecuted()
{
	fSave = Cvar_Save.FloatValue;
	if(fSave > 0.0)	hSave = CreateTimer(fSave, SaveDataTimer, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	iLimit = Cvar_Limit.IntValue;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == Cvar_Save)	iLimit = Cvar_Save.IntValue;
	else if(convar == Cvar_Limit)
	{
		fSave = Cvar_Save.FloatValue;
		
		if(hSave != INVALID_HANDLE)
		{
			KillTimer(hSave);
		}
		hSave = INVALID_HANDLE;
		
		hSave = CreateTimer(fSave, SaveDataTimer, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnMapStart() 
{
	LoadModels();
	DownloadFiles();
	LoadData();
}

public Action SaveDataTimer(Handle timer)
{
	SaveData();
}

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
	
	char name[30], lang[4], path[1024], title[64], finalOutput[100];
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
				
				if(langID == -1 && ModelMenu[nextLangID] == INVALID_HANDLE)
				{
					// new language, create the menu
					ModelMenu[nextLangID] = CreateMenu(ModelMenu_Handler);
					//Format(title, sizeof(title), "%T:", "Title Select Model", LANG_SERVER);
					
					//ModelMenu[nextLangID].SetTitle(title);
					ModelMenu[nextLangID].SetTitle("title");
					ModelMenu[nextLangID].ExitButton = true;
				}
				
				// add it to the menu
				if(langID == -1)
					ModelMenu[nextLangID].AddItem(finalOutput, name);
				else
					ModelMenu[langID].AddItem(finalOutput, name);
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

public int ModelMenu_Handler(Menu menu, MenuAction action, int client, int param)
{
	// make sure again, the player is a Terrorist
	if(IsValidClient(client))
	{
		if (action == MenuAction_Select)
		{
			char sModelPath[100];
			
			GetMenuItem(menu, param, sModelPath, sizeof(sModelPath));
				
			SpawnModel(client, sModelPath);
			
			ModelMenu[GetClientLanguageID(client)].DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		} 
	}
}

void SpawnModel(int client, char [] path)
{
	if(iLimit - iModelCount > 0)
	{
		int model = CreateEntityByName("prop_dynamic_override");
		iModelCount++;
		
		char cName[64];
		Format(cName, sizeof(cName), "xXx_model1337_xXx_%d", iModelCount);
		SetEntPropString(model, Prop_Data, "m_iName", cName);
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
	//else CPrintToChat(client, "%T", "Model Limit", client);
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

void LoadData()
{

}

void SaveData()
{

}

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

public Action CMD_Model(int client, int args)
{
	if(IsValidClient(client))	ModelMenu[GetClientLanguageID(client)].Display(client, MENU_TIME_FOREVER);
}

// https://forums.alliedmods.net/showpost.php?p=2471747&postcount=4
stock void PrecacheEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("EffectDispatch");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}

stock void PrecacheParticleEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("ParticleEffectNames");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}


/******************************************************************************************************************************/
// Code taken from boomix's base builder
bool 	g_OnceStopped						[MAXPLAYERS + 1];
float 	g_fPlayerSelectedBlockDistance		[MAXPLAYERS + 1];
int 	g_iPlayerSelectedBlock				[MAXPLAYERS + 1];
int 	g_iPlayerPrevButtons				[MAXPLAYERS + 1];
int 	g_iPlayerNewEntity					[MAXPLAYERS + 1];
bool 	bTakenWithNoOwner					[MAXPLAYERS + 1];
int 	clientlocks			[MAXPLAYERS + 1];
int g_iMaxLocks;

int colorr[52] =  	{ 
						0,	243, 232, 155, 102, 62, 32, 2, 0, 0, 75, 138, 204, 254, 254, 254, 254, 120, 
							243, 232, 155, 102, 62, 32, 2, 0, 0, 75, 138, 204, 254, 254, 254, 254, 120,
							243, 232, 155, 102, 62, 32, 2, 0, 0, 75, 138, 204, 254, 254, 254, 254, 120
					};
						
int colorg[52] =  	{
						0, 	66, 29, 38, 57, 80, 149, 168, 187, 149, 174, 194, 219, 234, 192, 151, 86, 84,
							66, 29, 38, 57, 80, 149, 168, 187, 149, 174, 194, 219, 234, 192, 151, 86, 84,
							66, 29, 38, 57, 80, 149, 168, 187, 149, 174, 194, 219, 234, 192, 151, 86, 84
				
					};

int colorb[52] =  	{ 
						0, 	53, 98, 175, 182, 180, 242, 243, 211, 135, 79, 73, 56, 58, 6, 0, 33, 71,
							53, 98, 175, 182, 180, 242, 243, 211, 135, 79, 73, 56, 58, 6, 0, 33, 71,
							53, 98, 175, 182, 180, 242, 243, 211, 135, 79, 73, 56, 58, 6, 0, 33, 71
					};

public void Blockmoving_OnClientPutInServer(int client)
{
	g_iPlayerNewEntity[client] = -1;
	g_iPlayerSelectedBlock[client] = -1;
	bTakenWithNoOwner[client] = false;
}

public void BlockMoving_PlayerSpawn(int client)
{
	g_iPlayerNewEntity[client] = -1;
	g_iPlayerSelectedBlock[client] = -1;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon) 
{
	if(IsValidClient(client) && GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		// ** 	FIRST CLICK (RUNS ONCE) 	**//
		if(!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE)
		{
			FirstTimePress(client);
		}
			
		//** 	SECOND CLICK (RUNS ALL TIME) 	**//
		else if (iButtons & IN_USE)
		{
			StillPressingButton(client, iButtons);
		}
			
		//** 	LAST CLICK (RUNS ONCE) 	**//
		else if(g_OnceStopped[client])
		{
			StoppedMovingBlock(client);
		}
			
		//** 	BLOCK ROTATE 	**//	
		if(iButtons & IN_RELOAD && !(g_iPlayerPrevButtons[client] & IN_RELOAD))
		{
			if(g_OnceStopped[client])	RotateBlock(g_iPlayerNewEntity[client]);
		}
		
		g_iPlayerPrevButtons[client] = iButtons;
	}
	
}


public void FirstTimePress(int client)
{
	g_iPlayerSelectedBlock[client] = GetTargetBlock(client);
	
	PrintToChat(client, "%d", g_iPlayerSelectedBlock[client]);
	
	if(IsValidEntity(g_iPlayerSelectedBlock[client]) && g_iPlayerSelectedBlock[client] != -1) {
		
		char classname[150];
		GetEntityClassname(g_iPlayerSelectedBlock[client], classname, sizeof(classname));
		
		if(!StrEqual(classname, "weaponworldmodel"))
		{
			if(GetBlockOwner(g_iPlayerSelectedBlock[client]) == 0 || GetBlockOwner(g_iPlayerSelectedBlock[client]) == client) {
				
				if(GetBlockOwner(g_iPlayerSelectedBlock[client]) == 0)
					bTakenWithNoOwner[client] = true;
				else
					bTakenWithNoOwner[client] = false;
				
				g_OnceStopped[client] = true;
				
				if(!IsValidEntity(g_iPlayerNewEntity[client]) || g_iPlayerNewEntity[client] <= 0)
					g_iPlayerNewEntity[client] = CreateEntityByName("prop_physics_override");
				
				float TeleportNewEntityOrg[3];
				GetAimOrigin(client, TeleportNewEntityOrg);
				TeleportEntity(g_iPlayerNewEntity[client], TeleportNewEntityOrg, NULL_VECTOR, NULL_VECTOR);
				
				//SetEntityModel(g_iPlayerNewEntity[client], "models/player/kuristaja/zombies/classic/classic.mdl");
				
				SetVariantString("!activator");
				AcceptEntityInput(g_iPlayerSelectedBlock[client], "SetParent", g_iPlayerNewEntity[client], g_iPlayerSelectedBlock[client], 0);
				
				//SetVariantString("!activator");
				//AcceptEntityInput(g_iPlayerNewEntity[client], "SetParent", g_iPlayerNewEntity[client], g_iPlayerNewEntity[client], 0);
			
				//Get distance between player and block
				float posent[3];
				float playerpos[3];
				GetClientEyePosition(client, playerpos);
				GetEntPropVector(g_iPlayerNewEntity[client], Prop_Send, "m_vecOrigin", posent);
				g_fPlayerSelectedBlockDistance[client] =  GetVectorDistance(playerpos, posent);
				
							
				//Get the prop closer if it's to far away
				if (g_fPlayerSelectedBlockDistance[client] > 250.0)
					g_fPlayerSelectedBlockDistance[client] = 250.0;
				
				ColorBlock(client, false);
				Sounds_TookBlock(client);
				
				//LockBlock(client);
				SetBlockOwner(g_iPlayerSelectedBlock[client], client);
				SetLastMover(g_iPlayerSelectedBlock[client], client);
			}
		}
	}
	
}

void StillPressingButton(int client, int &iButtons)
{
	if (iButtons & IN_ATTACK)
		g_fPlayerSelectedBlockDistance[client] += 1.0;
					
	else if (iButtons & IN_ATTACK2)
		g_fPlayerSelectedBlockDistance[client] -= 1.0;
		
	MoveBlock(client);
}

void MoveBlock(int client)
{
	if (IsValidEntity(g_iPlayerSelectedBlock[client]) && IsValidEntity(g_iPlayerNewEntity[client])) {
		
		float posent[3];
		GetEntPropVector(g_iPlayerNewEntity[client], Prop_Send, "m_vecOrigin", posent);
		
		float playerpos[3];
		GetClientEyePosition(client, playerpos);

		float playerangle[3];
		GetClientEyeAngles(client, playerangle);
		
		float final[3];
		AddInFrontOf(playerpos, playerangle, g_fPlayerSelectedBlockDistance[client], final);
		
		TeleportEntity(g_iPlayerNewEntity[client], final, NULL_VECTOR, NULL_VECTOR);
	
	}
}

public void StoppedMovingBlock(int client)
{
	
	if(IsValidEntity(g_iPlayerSelectedBlock[client])) {
		if(bTakenWithNoOwner[client])
			ColorBlock(client, true);
		else
			ColorBlock(client, false);
			
		Sounds_DropBlock(client);
		
		SetVariantString("!activator");
		AcceptEntityInput(g_iPlayerSelectedBlock[client], "SetParent", g_iPlayerSelectedBlock[client], g_iPlayerSelectedBlock[client], 0);
	}
	
	g_OnceStopped[client] = false;
	if(bTakenWithNoOwner[client]) {
		SetBlockOwner(g_iPlayerSelectedBlock[client], 0);
		LockBlock(client, g_iPlayerSelectedBlock[client]);
	}

}

public void BlockMoving_OnPrepTimeStart()
{
	for (int i = 1; i <= MAXPLAYERS ; i++)
	{
		if(IsValidEntity(g_iPlayerSelectedBlock[i])) {
			SetVariantString("!activator");
			AcceptEntityInput(g_iPlayerSelectedBlock[i], "SetParent", g_iPlayerSelectedBlock[i], g_iPlayerSelectedBlock[i], 0);
		}
		
		if(IsValidEntity(g_iPlayerNewEntity[i])) {
			SetVariantString("!activator");
			AcceptEntityInput(g_iPlayerNewEntity[i], "SetParent", g_iPlayerNewEntity[i], g_iPlayerNewEntity[i], 0);
		}
		
		if(g_OnceStopped[i])	ColorBlock(i, true);	
	}
}


//**	FUNCTIONS	**//

int GetTargetBlock(int client)
{
	int entity = GetClientAimTarget(client, false);
	if (IsValidEntity(entity))
	{
		char classname[32];
		GetEdictClassname(entity, classname, 32);
		
		if(StrContains(classname, "prop_dynamic") != -1)
			return entity;
	}
	return -1;
}

stock void AddInFrontOf(float vecOrigin[3], float vecAngle[3], float units, float output[3])
{
	float vecAngVectors[3];
	vecAngVectors = vecAngle; //Don't change input
	GetAngleVectors(vecAngVectors, vecAngVectors, NULL_VECTOR, NULL_VECTOR);
	for (int i; i < 3; i++)
	output[i] = vecOrigin[i] + (vecAngVectors[i] * units);
}

stock int GetAimOrigin(int client, float hOrigin[3]) 
{
    float vAngles[3];
    float fOrigin[3];
    GetClientEyePosition(client,fOrigin);
    GetClientEyeAngles(client, vAngles);

    Handle trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

    if(TR_DidHit(trace)) 
    {
        TR_GetEndPosition(hOrigin, trace);
        CloseHandle(trace);
        return 1;
    }

    CloseHandle(trace);
    return 0;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) 
{
    return entity > GetMaxClients();
}

void ColorBlock(int client, bool reset)
{	
	int entity = g_iPlayerSelectedBlock[client];
	
	if(IsValidEntity(entity) && client != -1) 
	{
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		
		if (reset)	Entity_SetRenderColor(entity, 255, 255, 255, 255);
		else Entity_SetRenderColor(entity, colorr[client], colorg[client], colorb[client], 255);
	}
}

void RotateEntity(int client)
{
	int blocktorotate = GetTargetBlock(client);
	
	if(IsValidEntity(blocktorotate) && blocktorotate != -1) {
		
		if(GetBlockOwner(blocktorotate) == 0) {
	
			float angles[3];
			GetEntPropVector(blocktorotate, Prop_Send, "m_angRotation", angles);
			angles[0] += 0.0;
			angles[1] += 45.0;
			angles[2] += 0.0;
			TeleportEntity(blocktorotate, NULL_VECTOR, angles, NULL_VECTOR);
		
		}	
	}
}

void RotateBlock(int entity)
{
	if (IsValidEntity(entity))
	{
		float angles[3];
		GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
		angles[0] += 0.0;
		angles[1] += 45.0;
		angles[2] += 0.0;
		TeleportEntity(entity, NULL_VECTOR, angles, NULL_VECTOR);
	}
}

public Action CMD_DeleteBlock(int client, int args)
{
	int entity = GetTargetBlock(client);
	
	if (entity != -1)
		if(IsValidEntity(entity))
			AcceptEntityInput(entity, "kill");
				
	return Plugin_Handled;
}

int GetBlockOwner(int entity)
{
	char entname[MAX_NAME_LENGTH];
	Entity_GetName(entity, entname, sizeof(entname));
	
	int entval = StringToInt(entname);
	
	return entval;
}

void SetBlockOwner(int entity, int owner)
{
	if(IsValidEntity(entity))
		Entity_SetName(entity, "%i", owner); 
}

void SetLastMover(int entity, int owner)
{
	Entity_SetGlobalName(entity, "%i", owner);
}

int GetLastMover(int entity)
{
	char entityname[10];
	Entity_GetGlobalName(entity, entityname, sizeof(entityname));
	int LastMover = StringToInt(entityname);
	return LastMover;
}

public void Sounds_TookBlock(int client)
{
	EmitSoundToClientAny(client, "sourcemod/basebuilder/block_grab.mp3");
}

public void Sounds_DropBlock(int client)
{
	EmitSoundToClientAny(client, "sourcemod/basebuilder/block_drop.mp3");
}

void LockBlock(int client, int entitys = 0, bool lockedWithG = false)
{
	if(IsValidClient(client) && GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		int entity = (entitys == 0) ? GetTargetBlock(client) : entitys;
			
		if (entity != -1)
		{
			int owner = GetBlockOwner(entity);
			
			// block has no owner yet: Lock it!
			if (owner <= 0)
			{
				if (clientlocks[client] < g_iMaxLocks)
				{
					ColorBlockByEntity(client, entity, false);
					SetBlockOwner(entity, client);
					if(lockedWithG)
						//PrintHintText(client, "%T", "Locked", client);
					clientlocks[client]++;
				} 
				//else  PrintHintText(client, "%T", "Max locked", client, g_iMaxLocks);
			}
			// Block has already a owner
			else
			{
				// Another player owns this block
				if (client != owner && !IsAdmin(client)) 
				{
					char username[MAX_NAME_LENGTH];
					GetClientName(owner, username, sizeof(username));
					//PrintHintText(client, "%T", "Already locked", client, username);
				}
				
				//Unlock block this player owns	it	
				else if(!g_OnceStopped[client])
				{
					ColorBlockByEntity(client, entity, true);
					SetBlockOwner(entity, 0);
					//PrintHintText(client, "%T", "Unlocked", client);
					clientlocks[client]--;
				}
			}
		}
	}

}

void ColorBlockByEntity(int client, int entity, bool reset)
{
	if(IsValidEntity(entity) && client != -1) 
	{
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		
		if (reset)
			Entity_SetRenderColor(entity, 255, 255, 255, 255);
		else Entity_SetRenderColor(entity, colorr[client], colorg[client], colorb[client], 255);
	}
	
}

public bool IsAdmin(int client)
{
	if(Client_HasAdminFlags(client, ADMFLAG_GENERIC) || Client_HasAdminFlags(client, ADMFLAG_ROOT) || Client_HasAdminFlags(client, ADMFLAG_BAN))
		return true;
	else return false;
}