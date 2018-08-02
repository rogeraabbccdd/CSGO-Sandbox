#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <kento_csgocolors>
#include <clientprefs>
#include <cstrike>
#include <smlib>

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
Menu Menu_DynamicModel[MAX_LANGUAGES];
Menu Menu_PhysicsModel[MAX_LANGUAGES];
Menu Menu_StaticModel[MAX_LANGUAGES];
char MenuLanguage[MAX_LANGUAGES][4];

#include <kento_sandbox/models>
#include <kento_sandbox/move>
#include <kento_sandbox/download>

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
	RegConsoleCmd("sm_lm", 	CMD_LastMover, "Last mover");
	
	Cvar_Save = CreateConVar("sm_auto_save", "60.0", "Auto save in x seconds?\n0.0 = disabled, FLOAT VALUE ONLY", _, true, 0.0);
	Cvar_Save.AddChangeHook(OnConVarChanged);
	
	Cvar_Limit = CreateConVar("sm_model_limit", "1700", "Max edicts limit when spawning model.", _, true, 0.0);
	Cvar_Limit.AddChangeHook(OnConVarChanged);
	
	AutoExecConfig(true, "kento_sandbox");
	
	LoadTranslations("core.phrases");
	LoadTranslations("kento.sandbox.phrases");
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



void LoadData()
{

}

void SaveData()
{

}



public Action CMD_Model(int client, int args)
{
	if(IsValidClient(client))	ShowMenu(client, "model");
}

void ShowMenu(int client, char [] menu)
{
	char tmp[1024];
	
	if(StrEqual(menu, "model"))
	{
		Menu Menu_Model = new Menu(MenuHandler_Model);
		
		Format(tmp, sizeof(tmp), "%T", "Model Menu Title", client);
		Menu_Model.SetTitle(tmp);
		
		Format(tmp, sizeof(tmp), "%T", "Dynamic Model", client);
		Menu_Model.AddItem("d", tmp);
		
		Format(tmp, sizeof(tmp), "%T", "Physics Model", client);
		Menu_Model.AddItem("p", tmp);
		
		/*
		Format(tmp, sizeof(tmp), "%T", "Static Model", client);
		Menu_Model.AddItem("s", tmp);
		*/
		
		Menu_Model.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_Model(Menu menu, MenuAction action, int client, int param)
{
	if(action == MenuAction_Select)
	{
		char name[1024];
		GetMenuItem(menu, param, name, sizeof(name));
		
		if(StrEqual(name, "d"))
		{
			Menu_DynamicModel[GetClientLanguageID(client)].Display(client, MENU_TIME_FOREVER);
		}
		else if(StrEqual(name, "p"))
		{
			Menu_PhysicsModel[GetClientLanguageID(client)].Display(client, MENU_TIME_FOREVER);
		}
		else if(StrEqual(name, "s"))
		{
			Menu_StaticModel[GetClientLanguageID(client)].Display(client, MENU_TIME_FOREVER);
		}
	}
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

int EdictCount()
{
	int count;
	for (int iEntity = 0; iEntity <= 2048; iEntity++) 
	{
		if (!IsValidEntity(iEntity) || !IsValidEdict(iEntity)) continue;
		++count;
    }
	return count;
}

public bool IsAdmin(int client)
{
	if(Client_HasAdminFlags(client, ADMFLAG_GENERIC) || Client_HasAdminFlags(client, ADMFLAG_ROOT) || Client_HasAdminFlags(client, ADMFLAG_BAN))
		return true;
	else return false;
}