#pragma semicolon 1

#include <colors>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>

#pragma newdecls required

#define PANIC_SOUND "panic/panic.mp3" // path to sound file without 'sound/'

public Plugin myinfo = 
{
	name = "Panic",
	author = "Pr[E]fix (https://vk.com/cyxaruk1337)",
	description = "Panic",
	version = "2.0",
	url = ""
};

ConVar g_Cvar_PanicTime = null;
ConVar g_Cvar_PanicSpeed = null;

Handle g_hPanicTimers[MAXPLAYERS + 1] =  { null, ... };
bool g_bUsedPanic[MAXPLAYERS + 1] =  { false, ... };

public void OnPluginStart()
{
	g_Cvar_PanicTime = CreateConVar("sm_panic_time", "5.0", "Время паника (сек.)", 0, true, 1.0);
	g_Cvar_PanicSpeed = CreateConVar("sm_panic_speed", "1.3", "1.0 = нормальная скорость", 0, true, 0.1);
	AutoExecConfig(true, "panic");
	
	RegConsoleCmd("sm_panic", Cmd_Panic);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;
		
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	}
}

public void OnMapStart()
{
	char[] szBuffer = new char[PLATFORM_MAX_PATH];
	Format(szBuffer, PLATFORM_MAX_PATH, "sound/%s", PANIC_SOUND);
	if(FileExists(szBuffer))
		AddFileToDownloadsTable(szBuffer);
	
	PrecacheSound(PANIC_SOUND);
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public Action Hook_WeaponCanUse(int client, int weapon)
{
	return Plugin_Continue;
}

public Action Cmd_Panic(int client, int args)
{
	if(!client)
	{
		CPrintToChat(client, "{lightgreen}[SM] {green}Только в игре");
		return Plugin_Handled;
	}
	
	if(g_hPanicTimers[client] != null)
	{
		CPrintToChat(client, "{lightgreen}[SM] {green}Ты уже в панике");
		return Plugin_Handled;
	}
	
	if(g_bUsedPanic[client])
	{
		CPrintToChat(client, "{lightgreen}[SM] {green}Вы уже использовали способность паники в этом раунде");
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{lightgreen}[SM] {green}Должно быть жив");
		return Plugin_Handled;
	}
	
	if(!ZR_IsClientHuman(client))
	{
		CPrintToChat(client, "{lightgreen}[SM] {green}Должно быть человеком");
		return Plugin_Handled;
	}
	
	g_bUsedPanic[client] = true;
	g_hPanicTimers[client] = CreateTimer(g_Cvar_PanicTime.FloatValue, Timer_ResetPanic, client);
	
	int index;  
	for (int slot = 0; slot < 5; slot++)  
	{  
		if (slot != 3 && (index = GetPlayerWeaponSlot(client, slot)) > 0)  
		{  
			RemovePlayerItem(client, index); 
		}  
	}
	
	GivePlayerItem(client, "weapon_knife");
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Cvar_PanicSpeed.FloatValue);
	
	if(IsSoundPrecached(PANIC_SOUND))
		EmitSoundToAll(PANIC_SOUND, client, 8, _, _, 1.3);
	
	CPrintToChatAll("{lightgreen}Игрок %N {green}убегает в панике", client);
	
	return Plugin_Handled;
}

public Action Timer_ResetPanic(Handle timer, any client)
{
	g_hPanicTimers[client] = null;
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !ZR_IsClientHuman(client))
		return Plugin_Stop;
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	
	return Plugin_Stop;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
		g_bUsedPanic[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client)
		return;
	
	if(g_hPanicTimers[client] != null)
	{
		KillTimer(g_hPanicTimers[client]);
		g_hPanicTimers[client] = null;
	}
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if(g_hPanicTimers[client] != null)
	{
		KillTimer(g_hPanicTimers[client]);
		g_hPanicTimers[client] = null;
	}
	
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if(g_hPanicTimers[client] != null)
	{
		KillTimer(g_hPanicTimers[client]);
		g_hPanicTimers[client] = null;
	}
}