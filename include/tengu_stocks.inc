#if defined _tengu_stocks_included
 #endinput
#endif
#define _tengu_stocks_included

#define MAX_PLAYERS (MAXPLAYERS+1)

stock bool IsValidClient(int client, bool alive=false) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && (!alive || IsPlayerAlive(client));
}

stock ConVar GetConVar(const char[] name) {
	ConVar cvar = FindConVar(name);
	if (cvar == null) {
		SetFailState("ConVar '%s' not found.", name);
	}
	return cvar;
}

stock void StringToLower(char[] str) {
	for (int i; str[i]; i++) {
		str[i] = CharToLower(str[i]);
	}
}

stock bool StartsWith(const char[] str1, const char[] str2, bool caseSensitive=true) {
	return strncmp(str1, str2, strlen(str2), caseSensitive) == 0;
}

stock float AngleBetweenVectors2D(const float vec1[3], const float vec2[3]) {
	float tan1 = ArcTangent2(vec1[0], vec1[1]);
	float tan2 = ArcTangent2(vec2[0], vec2[1]);
	return RadToDeg(tan2 - tan1);
}

stock void GetMinPoint(const float point1[3], const float point2[3], float min[3]) {
	min[0] = (point1[0] < point2[0]) ? point1[0] : point2[0];
	min[1] = (point1[1] < point2[1]) ? point1[1] : point2[1];
	min[2] = (point1[2] < point2[2]) ? point1[2] : point2[2];
}

stock void GetMaxPoint(const float point1[3], const float point2[3], float max[3]) {
	max[0] = (point1[0] > point2[0]) ? point1[0] : point2[0];
	max[1] = (point1[1] > point2[1]) ? point1[1] : point2[1];
	max[2] = (point1[2] > point2[2]) ? point1[2] : point2[2];
}

stock void GetBoxCenter(const float point1[3], const float point2[3], float center[3]) {
	center[0] = (point1[0] + point2[0]) * 0.5;
	center[1] = (point1[1] + point2[1]) * 0.5;
	center[2] = (point1[2] + point2[2]) * 0.5;
}

stock void GetBoxOrigin(const float point1[3], const float point2[3], float origin[3]) {
	origin[0] = (point1[0] + point2[0]) * 0.5;
	origin[1] = (point1[1] + point2[1]) * 0.5;
	origin[2] = (point1[2] < point2[2]) ? point1[2] : point2[2];
}

stock void GetBoxBounds(const float point1[3], const float point2[3], float mins[3], float maxs[3]) {
	float min[3], max[3], origin[3];

	GetMinPoint(point1, point2, min);
	GetMaxPoint(point1, point2, max);
	GetBoxOrigin(point1, point2, origin);

	mins[0] = min[0] - origin[0];
	mins[1] = min[1] - origin[1];
	mins[2] = 0.0;

	maxs[0] = max[0] - origin[0];
	maxs[1] = max[1] - origin[1];
	maxs[2] = max[2] - origin[2];
}

stock void GetBoxCorners(const float point1[3], const float point2[3], float corners[8][3]) {
	float min[3], max[3];
	GetMinPoint(point1, point2, min);
	GetMaxPoint(point1, point2, max);

	// bottom left front
	corners[0][0] = min[0];
	corners[0][1] = min[1];
	corners[0][2] = min[2];

	// bottom right front
	corners[1][0] = max[0];
	corners[1][1] = min[1];
	corners[1][2] = min[2];

	// bottom right back
	corners[2][0] = max[0];
	corners[2][1] = max[1];
	corners[2][2] = min[2];

	// bottom left back
	corners[3][0] = min[0];
	corners[3][1] = max[1];
	corners[3][2] = min[2];

	// top left front
	corners[4][0] = min[0];
	corners[4][1] = min[1];
	corners[4][2] = max[2];

	// top right front
	corners[5][0] = max[0];
	corners[5][1] = min[1];
	corners[5][2] = max[2];

	// top right back
	corners[6][0] = max[0];
	corners[6][1] = max[1];
	corners[6][2] = max[2];

	// top left back
	corners[7][0] = min[0];
	corners[7][1] = max[1];
	corners[7][2] = max[2];
}

stock void GetEntityAbsOrigin(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
}

stock void GetAbsVelocity(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vec);
}

stock void GetEntityMins(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Send, "m_vecMins", vec);
}

stock void GetEntityMaxs(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vec);
}

stock void GetBaseVelocity(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", vec);
}

stock void SetBaseVelocity(int entity, const float vec[3]) {
	SetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", vec);
}

stock int GetOldButtons(int client) {
	return GetEntProp(client, Prop_Data, "m_nOldButtons");
}
