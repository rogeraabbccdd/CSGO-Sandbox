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
			RotateEntity(client);
		}
		
		g_iPlayerPrevButtons[client] = iButtons;
	}
	
}


public void FirstTimePress(int client)
{
	g_iPlayerSelectedBlock[client] = GetTargetEntity(client);
	
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

int GetTargetEntity(int client)
{
	int entity = GetClientAimTarget(client, false);
	if (IsValidEntity(entity))
	{
		char classname[32];
		GetEdictClassname(entity, classname, 32);
		
		if (StrContains(classname, "prop_") != -1)	return entity;
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
	int blocktorotate = GetTargetEntity(client);
	
	if(IsValidEntity(blocktorotate) && blocktorotate != -1) {
		
		if(GetBlockOwner(blocktorotate) == 0) {
	
			float angles[3];
			GetEntPropVector(blocktorotate, Prop_Send, "m_angRotation", angles);
			angles[0] += 0.0;
			angles[1] += 10.0;
			angles[2] += 0.0;
			TeleportEntity(blocktorotate, NULL_VECTOR, angles, NULL_VECTOR);
		
		}	
	}
}

public Action CMD_DeleteBlock(int client, int args)
{
	int entity = GetTargetEntity(client);
	
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

void LockBlock(int client, int entitys = 0, bool lockedWithG = false)
{
	if(IsValidClient(client) && GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		int entity = (entitys == 0) ? GetTargetEntity(client) : entitys;
			
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

public Action CMD_LastMover(int client, int args)
{
	int entity = GetTargetEntity(client);
	
	if(IsValidEntity(entity)) {
		int lastmover = GetLastMover(entity);
		if(lastmover > 0) {
			char username[MAX_NAME_LENGTH];
			GetClientName(lastmover, username, sizeof(username));
			CPrintToChat(client, "%T", "Last Mover", client, username);
		} else {
			CPrintToChat(client, "%T", "Not Moved", client);
		}
	}

}