#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tengu_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "recorder",
	author      = "Tengu",
	description = "<insert_description_here>",
	version     = "0.1",
	url         = "http://steamcommunity.com/id/tengulawl/"
};

enum {
	CP1_ORIGIN_X,
	CP1_ORIGIN_Y,
	CP1_ORIGIN_Z,
	CP1_ANGLES_X,
	CP1_ANGLES_Y,
	CP1_ANGLES_Z,
	CP1_VELOCITY_X,
	CP1_VELOCITY_Y,
	CP1_VELOCITY_Z,
	CP2_ORIGIN_X,
	CP2_ORIGIN_Y,
	CP2_ORIGIN_Z,
	CP2_ANGLES_X,
	CP2_ANGLES_Y,
	CP2_ANGLES_Z,
	CP2_VELOCITY_X,
	CP2_VELOCITY_Y,
	CP2_VELOCITY_Z,
	CHECKPOINT_SIZE
};

ArrayList g_checkpoints;
char g_recName[32];
char g_recFileName[48];
float g_recResumeTime;
bool g_recWaiting;
int g_recorder;
int g_partner;
float g_displayTime[MAX_PLAYERS];

public void OnPluginStart() {
	g_checkpoints = new ArrayList(CHECKPOINT_SIZE);
	HookEvent("player_team", Event_StopRecording);
	HookEvent("player_death", Event_StopRecording);
	RegAdminCmd("sm_rec", Command_StartRec, ADMFLAG_CUSTOM2);
	RegAdminCmd("sm_stoprec", Command_StopRec, ADMFLAG_CUSTOM2);
	RegAdminCmd("sm_recmenu", Command_RecMenu, ADMFLAG_CUSTOM2);
}

public void OnClientDisconnect(int client) {
	g_displayTime[client] = 0.0;

	if (client && (client == g_recorder || client == g_partner)) {
		ServerCommand("tv_stoprecord");
		g_recorder = 0;
		g_partner = 0;
		g_checkpoints.Clear();
	}
}

public void Event_StopRecording(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && (client == g_recorder || client == g_partner)) {
		ServerCommand("tv_stoprecord");
		g_recorder = 0;
		g_partner = 0;
		g_checkpoints.Clear();
	}
}

public Action Command_StopRec(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (!g_recorder || !g_partner) {
		PrintToConsole(client, "[SM] There is no active recording.");
		PrintToChat(client, "[SM] There is no active recording.");
		return Plugin_Handled;
	}

	if (client != g_recorder) {
		PrintToConsole(client, "[SM] You are not allowed to use this command.");
		PrintToChat(client, "[SM] You are not allowed to use this command.");
		return Plugin_Handled;
	}

	ServerCommand("tv_stoprecord");
	g_recorder = 0;
	g_partner = 0;
	g_checkpoints.Clear();

	PrintToConsole(client, "[SM] Recording finished.");
	PrintToChat(client, "[SM] Recording finished.");
	return Plugin_Handled;
}

public Action Command_StartRec(int client, int args) {
	if (args < 1) {
		PrintToConsole(client, "[SM] Usage: sm_rec <name>");
		PrintToChat(client, "[SM] Usage: !rec <name>");
		return Plugin_Handled;
	}

	if (g_recorder || g_partner) {
		PrintToConsole(client, "[SM] You must stop the active recording before starting another.");
		PrintToChat(client, "[SM] You must stop the active recording before starting another.");
		return Plugin_Handled;
	}

	GetCmdArg(1, g_recName, sizeof(g_recName));

	int i;
	char c;

	while (g_recName[i] != '\0') {
		c = g_recName[i];

		if (c < '0' || (c > '9' && c < 'A') || (c > 'Z' && c < 'a') || c > 'z') {
			g_recName[i] = '_';
		}

		i++;
	}

	FormatEx(g_recFileName, sizeof(g_recFileName), "%s001.dem", g_recName);

	if (FileExists(g_recFileName)) {
		PrintToConsole(client, "[SM] A recording with this name does already exist.");
		PrintToChat(client, "[SM] A recording with this name does already exist.");
		return Plugin_Handled;
	}

	Menu menu = new Menu(Handler_StartRec);
	menu.SetTitle("Select your partner:");

	char info[16], display[32];
	int numPlayers;

	for (i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i)) {
			IntToString(GetClientUserId(i), info, sizeof(info));
			GetClientName(i, display, sizeof(display));
			menu.AddItem(info, display);
			numPlayers++;
		}
	}

	if (!numPlayers) {
		delete menu;
		PrintToConsole(client, "[SM] There are no players you could select as your partner.");
		PrintToChat(client, "[SM] There are no players you could select as your partner.");
		return Plugin_Handled;
	}

	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Handler_StartRec(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char info[16];
		menu.GetItem(param2, info, sizeof(info));

		int userid = StringToInt(info);

		if (!userid) {
			PrintToChat(param1, "[SM] The player you selected is no longer connected.");
			return 0;
		}

		g_recorder = param1;
		g_partner = GetClientOfUserId(userid);

		PrintToChat(g_partner, "[SM] %N has selected you as recording partner.", g_recorder);

		SaveCheckpoint();
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

public Action Command_RecMenu(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client)) {
		ReplyToCommand(client, "[SM] You must be alive to use this command.");
		return Plugin_Handled;
	}

	if (!g_recorder || !g_partner) {
		ReplyToCommand(client, "[SM] There is no active recording.");
		return Plugin_Handled;
	}

	if (client != g_recorder) {
		ReplyToCommand(client, "[SM] You are not allowed to use this command.");
		return Plugin_Handled;
	}

	ShowRecMenu(client);
	return Plugin_Handled;
}

void ShowRecMenu(int client) {
	Menu menu = new Menu(Handler_RecMenu);
	menu.SetTitle(g_recFileName);
	menu.AddItem("save", "Save Checkpoint");
	menu.AddItem("load", "Load Checkpoint");

	if (g_checkpoints.Length > 1) {
		menu.AddItem("prelast", "Load Pre Last CP");
	} else {
		menu.AddItem("prelast", "Load Pre Last CP", ITEMDRAW_DISABLED);
	}

	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("", "", ITEMDRAW_NOTEXT);
	menu.AddItem("", "", ITEMDRAW_NOTEXT);
	menu.AddItem("stop", "Stop Recording");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_RecMenu(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		if (!g_recorder || !g_partner) {
			return 0;
		}

		char info[16];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "save")) {
			SaveCheckpoint();
		} else if (StrEqual(info, "load")) {
			AskLoadCP(param1);
		} else if (StrEqual(info, "prelast")) {
			AskLoadCP(param1, true);
		} else if (StrEqual(info, "stop")) {
			ServerCommand("tv_stoprecord");
			PrintToChat(g_recorder, "[SM] Recording was stopped.");
			PrintToChat(g_partner, "[SM] Recording was stopped.");
			g_recorder = 0;
			g_partner = 0;
			g_checkpoints.Clear();
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void AskLoadCP(int client, bool prelast=false) {
	Menu menu = new Menu(Handler_AskLoadCP);
	menu.SetTitle("ARE YOU SURE?\nYour current progress since the checkpoint will be discarded.");
	
	if (prelast) {
		menu.AddItem("prelast_yes", "Yes");
		menu.AddItem("prelast_no", "No");
	} else {
		menu.AddItem("load_yes", "Yes");
		menu.AddItem("load_no", "No");
	}

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_AskLoadCP(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		if (!g_recorder || !g_partner) {
			return 0;
		}

		char info[16];
		menu.GetItem(param2, info, sizeof(info));

		if (StrEqual(info, "load_yes")) {
			LoadCheckpoint();
		} else if (StrEqual(info, "prelast_yes")) {
			if (g_checkpoints.Length > 1) {
				LoadCheckpoint(true);
			} else {
				LoadCheckpoint();
			}
		} else {
			ShowRecMenu(param1);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void SaveCheckpoint() {
	int cp = g_checkpoints.Length;

	g_checkpoints.Resize(cp + 1);

	SaveRecorderCP(cp);
	SavePartnerCP(cp);

	if (cp) {
		ServerCommand("tv_stoprecord");
		FormatEx(g_recFileName, sizeof(g_recFileName), "%s%03d.dem", g_recName, cp + 1);
	}

	PauseRecording();

	if (cp) {
		PrintToChat(g_recorder, "[SM] Checkpoint saved.");
		PrintToChat(g_partner, "[SM] Checkpoint saved.");
	}

	ShowRecMenu(g_recorder);
}

void LoadCheckpoint(bool prelast=false) {
	ServerCommand("tv_stoprecord");

	int cp = g_checkpoints.Length - 1;

	if (prelast) {
		g_checkpoints.Resize(cp);
		FormatEx(g_recFileName, sizeof(g_recFileName), "%s%03d.dem", g_recName, cp);
		cp--;
	}

	LoadRecorderCP(cp);
	LoadPartnerCP(cp);

	PauseRecording();

	if (prelast) {
		PrintToChat(g_recorder, "[SM] Pre Last CP loaded.");
		PrintToChat(g_partner, "[SM] Pre Last CP loaded.");
	} else {
		PrintToChat(g_recorder, "[SM] Checkpoint loaded.");
		PrintToChat(g_partner, "[SM] Checkpoint loaded.");
	}

	ShowRecMenu(g_recorder);
}

void PauseRecording() {
	SetEntityMoveType(g_recorder, MOVETYPE_NONE);
	SetEntityMoveType(g_partner, MOVETYPE_NONE);

	SetEntityFlags(g_recorder, GetEntityFlags(g_recorder) | FL_ATCONTROLS);
	SetEntityFlags(g_partner, GetEntityFlags(g_partner) | FL_ATCONTROLS);

	g_recResumeTime = GetGameTime() + 1.5;
	g_recWaiting = true;

	CreateTimer(1.5, ResumeRecording, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResumeRecording(Handle timer) {
	if (!g_recorder || !g_partner) {
		return Plugin_Stop;
	}

	SetEntityMoveType(g_recorder, MOVETYPE_WALK);
	SetEntityMoveType(g_partner, MOVETYPE_WALK);

	SetEntityFlags(g_recorder, GetEntityFlags(g_recorder) & ~FL_ATCONTROLS);
	SetEntityFlags(g_partner, GetEntityFlags(g_partner) & ~FL_ATCONTROLS);

	g_recWaiting = false;

	PrintCenterText(g_recorder, "");
	PrintCenterText(g_partner, "");

	ServerCommand("tv_record %s", g_recFileName);
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (g_recWaiting && (client == g_recorder || client == g_partner)) {
		buttons = 0;
		impulse = 0;
		
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;

		if (client == g_recorder) {
			GetRecorderAngles(g_checkpoints.Length - 1, angles);
		} else {
			GetPartnerAngles(g_checkpoints.Length - 1, angles);
		}
		
		TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		
		weapon = 0;
		subtype = 0;
		mouse[0] = 0;
		mouse[1] = 0;
		
		float gameTime = GetGameTime();

		if (gameTime - g_displayTime[client] >= 0.1) {
			PrintCenterText(client, "Recording in %.1f", g_recResumeTime - gameTime);
			g_displayTime[client] = gameTime;
		}
	}
}

void SetRecorderOrigin(int index, const float origin[3]) {
	g_checkpoints.Set(index, origin[0], CP1_ORIGIN_X);
	g_checkpoints.Set(index, origin[1], CP1_ORIGIN_Y);
	g_checkpoints.Set(index, origin[2], CP1_ORIGIN_Z);
}

void SetRecorderAngles(int index, const float angles[3]) {
	g_checkpoints.Set(index, angles[0], CP1_ANGLES_X);
	g_checkpoints.Set(index, angles[1], CP1_ANGLES_Y);
	g_checkpoints.Set(index, angles[2], CP1_ANGLES_Z);
}

void SetRecorderVelocity(int index, const float velocity[3]) {
	g_checkpoints.Set(index, velocity[0], CP1_VELOCITY_X);
	g_checkpoints.Set(index, velocity[1], CP1_VELOCITY_Y);
	g_checkpoints.Set(index, velocity[2], CP1_VELOCITY_Z);
}

void SetPartnerOrigin(int index, const float origin[3]) {
	g_checkpoints.Set(index, origin[0], CP2_ORIGIN_X);
	g_checkpoints.Set(index, origin[1], CP2_ORIGIN_Y);
	g_checkpoints.Set(index, origin[2], CP2_ORIGIN_Z);
}

void SetPartnerAngles(int index, const float angles[3]) {
	g_checkpoints.Set(index, angles[0], CP2_ANGLES_X);
	g_checkpoints.Set(index, angles[1], CP2_ANGLES_Y);
	g_checkpoints.Set(index, angles[2], CP2_ANGLES_Z);
}

void SetPartnerVelocity(int index, const float velocity[3]) {
	g_checkpoints.Set(index, velocity[0], CP2_VELOCITY_X);
	g_checkpoints.Set(index, velocity[1], CP2_VELOCITY_Y);
	g_checkpoints.Set(index, velocity[2], CP2_VELOCITY_Z);
}

void GetRecorderOrigin(int index, float origin[3]) {
	origin[0] = g_checkpoints.Get(index, CP1_ORIGIN_X);
	origin[1] = g_checkpoints.Get(index, CP1_ORIGIN_Y);
	origin[2] = g_checkpoints.Get(index, CP1_ORIGIN_Z);
}

void GetRecorderAngles(int index, float angles[3]) {
	angles[0] = g_checkpoints.Get(index, CP1_ANGLES_X);
	angles[1] = g_checkpoints.Get(index, CP1_ANGLES_Y);
	angles[2] = g_checkpoints.Get(index, CP1_ANGLES_Z);
}

void GetRecorderVelocity(int index, float velocity[3]) {
	velocity[0] = g_checkpoints.Get(index, CP1_VELOCITY_X);
	velocity[1] = g_checkpoints.Get(index, CP1_VELOCITY_Y);
	velocity[2] = g_checkpoints.Get(index, CP1_VELOCITY_Z);
}

void GetPartnerOrigin(int index, float origin[3]) {
	origin[0] = g_checkpoints.Get(index, CP2_ORIGIN_X);
	origin[1] = g_checkpoints.Get(index, CP2_ORIGIN_Y);
	origin[2] = g_checkpoints.Get(index, CP2_ORIGIN_Z);
}

void GetPartnerAngles(int index, float angles[3]) {
	angles[0] = g_checkpoints.Get(index, CP2_ANGLES_X);
	angles[1] = g_checkpoints.Get(index, CP2_ANGLES_Y);
	angles[2] = g_checkpoints.Get(index, CP2_ANGLES_Z);
}

void GetPartnerVelocity(int index, float velocity[3]) {
	velocity[0] = g_checkpoints.Get(index, CP2_VELOCITY_X);
	velocity[1] = g_checkpoints.Get(index, CP2_VELOCITY_Y);
	velocity[2] = g_checkpoints.Get(index, CP2_VELOCITY_Z);
}

void SaveRecorderCP(int index) {
	float origin[3], angles[3], velocity[3];

	GetClientAbsOrigin(g_recorder, origin);
	GetClientEyeAngles(g_recorder, angles);
	GetAbsVelocity(g_recorder, velocity);

	SetRecorderOrigin(index, origin);
	SetRecorderAngles(index, angles);
	SetRecorderVelocity(index, velocity);
}

void LoadRecorderCP(int index) {
	float origin[3], angles[3], velocity[3];

	GetRecorderOrigin(index, origin);
	GetRecorderAngles(index, angles);
	GetRecorderVelocity(index, velocity);

	TeleportEntity(g_recorder, origin, angles, velocity);
}

void SavePartnerCP(int index) {
	float origin[3], angles[3], velocity[3];
	
	GetClientAbsOrigin(g_partner, origin);
	GetClientEyeAngles(g_partner, angles);
	GetAbsVelocity(g_partner, velocity);

	SetPartnerOrigin(index, origin);
	SetPartnerAngles(index, angles);
	SetPartnerVelocity(index, velocity);
}

void LoadPartnerCP(int index) {
	float origin[3], angles[3], velocity[3];

	GetPartnerOrigin(index, origin);
	GetPartnerAngles(index, angles);
	GetPartnerVelocity(index, velocity);

	TeleportEntity(g_partner, origin, angles, velocity);
}
