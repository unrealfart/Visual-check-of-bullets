#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <amxmisc>

#pragma semicolon 1

new const Title[] = "Visual check of bullets";
new const Version[] = "1.0.0";
new const Author[] = "unrealfart & the_hunter";

// Settings
const MIN_BULLET_TRACE = 1;
const MAX_BULLET_TRACE = 5;
const MIN_BULLET_TO_END = 2;
const MAX_BULLET_TO_END = 7; 


new const EVENTS[][] = 
{
	"events/ak47.sc",
	"events/aug.sc",
	"events/awp.sc",
	"events/deagle.sc",
	"events/elite_left.sc",
	"events/elite_right.sc",
	"events/famas.sc",
	"events/fiveseven.sc",
	"events/g3sg1.sc",
	"events/galil.sc",
	"events/glock18.sc",
	//"events/knife.sc",
	"events/m249.sc",
	//"events/m3.sc",
	"events/m4a1.sc",
	"events/mac10.sc",
	"events/mp5n.sc",
	"events/p228.sc",
	"events/p90.sc",
	"events/scout.sc",
	"events/sg550.sc",
	"events/sg552.sc",
	"events/tmp.sc",
	"events/ump45.sc",
	"events/usp.sc",
	//"events/xm1014.sc"
};

new g_iSpriteIndex;
new g_iFwdPrecacheEvent;

new g_iGunsEventBitsum = 0;

#define IsPlayer(%1)           	(0 < %1 <= MaxClients)
#define IsGunshotEvent(%1)    	(g_iGunsEventBitsum & (1 << %1))
#define IsBurstMode(%1)  		bool:(get_member(%1, m_Weapon_iWeaponState) & (WPNSTATE_GLOCK18_BURST_MODE | WPNSTATE_FAMAS_BURST_MODE))

#define IsConsistWeapon(%0,%1)		(%1 & (1<<%0))

#define SetUserSettings(%0,%1) 		(%0 |= %1)
#define ClearUserSettings(%0,%1)	(%0 &= ~%1)
#define GetUserSettings(%0,%1)		(%0 & %1)
		

const PISTOLS_BITSUM = (1<<_:WEAPON_P228|1<<_:WEAPON_ELITE|1<<_:WEAPON_FIVESEVEN|1<<_:WEAPON_USP|1<<_:WEAPON_GLOCK18|1<<_:WEAPON_DEAGLE);
const SUBMACHINEGUNS_BITSUM = (1<<_:WEAPON_TMP|1<<_:WEAPON_MAC10|1<<_:WEAPON_UMP45|1<<_:WEAPON_MP5N|1<<_:WEAPON_P90);
const RIFLES_BITSUM = (1<<_:WEAPON_FAMAS|1<<_:WEAPON_GALIL|1<<_:WEAPON_AK47|1<<_:WEAPON_M4A1|1<<_:WEAPON_AUG|1<<_:WEAPON_SG552);
const SNIPER_RIFLES_BITSUM = (1<<_:WEAPON_SCOUT|1<<_:WEAPON_AWP|1<<_:WEAPON_SG550|1<<_:WEAPON_G3SG1);
const MACHINEGUN_BITSUM = (1<<_:WEAPON_M249);

new Trie:g_tUserSettings;

enum _:SETTINGS
{
	ModeSwitch,
	Application,
	MenuSwitch,
	TraceType,
	BulletsAmount,
	BulletsToEnd
};
new g_aUserSettings[MAX_PLAYERS + 1][SETTINGS];

enum
{
	LastBullets,
	SomeBulletsToEnd,
	MiddleBullets
};

enum _:WeaponType(<<= 1)
{
	Pistols = 1,
	SubmachineGuns,
	Rifles,
	SniperRifles,
	MachineGun,
	All
};

new const g_szTraceType[][] = 
{
	"BULLET_TRACE_MENU_ITEM_2_TYPE_1",
	"BULLET_TRACE_MENU_ITEM_2_TYPE_2",
	"BULLET_TRACE_MENU_ITEM_2_TYPE_3"
};

public plugin_precache()
{
	g_iSpriteIndex = precache_model("sprites/dot.spr");
	g_iFwdPrecacheEvent = register_forward(FM_PrecacheEvent, "PrecacheEvent", true);
}

public PrecacheEvent(type, const szEventTitle[])
{
	for(new i = 0; i < sizeof EVENTS; i++) 
	{
		if(equali(szEventTitle, EVENTS[i]))
		{
			g_iGunsEventBitsum |= (1 << get_orig_retval());
			break;
		}
	}
}

public plugin_init()
{
	register_plugin(Title, Version, Author);

	unregister_forward(FM_PrecacheEvent, g_iFwdPrecacheEvent, true);
	register_forward(FM_PlaybackEvent, "PlaybackEvent", true);

	register_clcmd("say /trace", "ClCmd_TraceSettingsMenu");

	register_menu("Show_TraceSettingsMenu", 1023, "Handle_TraceSettingsMenu");

	register_menu("Show_ApplicationToWeapon", 1023, "Handler_ApplicationToWeapon");

	g_tUserSettings = TrieCreate();

	register_dictionary("bullet_trace.txt");
}

public PlaybackEvent(Flags, iPlayer, iEventIndex)
{
	if (!IsGunshotEvent(iEventIndex) || !IsPlayer(iPlayer) || is_user_bot(iPlayer))
		return;

	if(!g_aUserSettings[iPlayer][ModeSwitch])
		return;

	new iClip;
	new iWeapon = get_user_weapon(iPlayer, iClip);
	new iMaxClip = rg_get_weapon_info(iWeapon, WI_GUN_CLIP_SIZE);

	if(IsConsistWeapon(iWeapon, g_aUserSettings[iPlayer][Application]))
	{
		switch(g_aUserSettings[iPlayer][TraceType])
		{
			case LastBullets:
			{
				if(iClip <= g_aUserSettings[iPlayer][BulletsAmount])
				{
					draw_bullet_trace(iPlayer);
				}
			}
			case SomeBulletsToEnd:
			{					
				if(iClip <= (g_aUserSettings[iPlayer][BulletsAmount] + g_aUserSettings[iPlayer][BulletsToEnd]) && iClip > g_aUserSettings[iPlayer][BulletsToEnd])
					draw_bullet_trace(iPlayer);
			}
			case MiddleBullets:
			{
				if(iClip <= (iMaxClip / 2) + (g_aUserSettings[iPlayer][BulletsAmount] / 2)
				&& iClip >= (iMaxClip / 2) - (g_aUserSettings[iPlayer][BulletsAmount] / 2))
					draw_bullet_trace(iPlayer);
			}
		}
	}
	return;
}


public client_authorized(iPlayer, const szAuthid[])
{
	if(TrieKeyExists(g_tUserSettings, szAuthid))                                    
	{
		TrieGetArray(g_tUserSettings, szAuthid, g_aUserSettings[iPlayer], charsmax(g_aUserSettings[]));
	}
	else
	{
		// Default settings
		g_aUserSettings[iPlayer][BulletsAmount] = MIN_BULLET_TRACE;
		g_aUserSettings[iPlayer][BulletsToEnd] = MIN_BULLET_TO_END;

		// All weapons
		SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], (Pistols|SubmachineGuns|Rifles|SniperRifles|MachineGun|All));
		SetUserSettings(g_aUserSettings[iPlayer][Application], (PISTOLS_BITSUM|SUBMACHINEGUNS_BITSUM|RIFLES_BITSUM|SNIPER_RIFLES_BITSUM|MACHINEGUN_BITSUM));
	}
}

public client_disconnected(iPlayer)
{
	new szSteam[MAX_AUTHID_LENGTH];                                            
	get_user_authid(iPlayer, szSteam, charsmax(szSteam));       

	TrieSetArray(g_tUserSettings, szSteam, g_aUserSettings[iPlayer], charsmax(g_aUserSettings[]));
}

public ClCmd_TraceSettingsMenu(iPlayer)
{
	Show_TraceSettingsMenu(iPlayer);

	return PLUGIN_HANDLED;
}

public Show_TraceSettingsMenu(iPlayer)
{
	SetGlobalTransTarget(iPlayer);

	new szMenu[MAX_MENU_LENGTH];
	new iKeys;
	new iLen;

	iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_0;

	iLen = formatex(szMenu, charsmax(szMenu), "\y%l^n^n", "BULLET_TRACE_MENU_TITLE");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%l [%l\w]^n", "BULLET_TRACE_MENU_ITEM_1", g_aUserSettings[iPlayer][ModeSwitch] ? "BULLET_TRACE_MENU_ITEM_1_ON" : "BULLET_TRACE_MENU_ITEM_1_OFF");
	
	if(g_aUserSettings[iPlayer][ModeSwitch])
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%l^n", "BULLET_TRACE_MENU_ITEM_2");

		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%l: [\y%l\w]^n", "BULLET_TRACE_MENU_ITEM_3", g_szTraceType[g_aUserSettings[iPlayer][TraceType]]);
		
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%l: [\y%d\w]^n", "BULLET_TRACE_MENU_ITEM_4", g_aUserSettings[iPlayer][BulletsAmount]);
		
		if(g_aUserSettings[iPlayer][TraceType] == SomeBulletsToEnd)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%l: [\y%d\w]^n", "BULLET_TRACE_MENU_ITEM_5", g_aUserSettings[iPlayer][BulletsToEnd]);
			iKeys |= MENU_KEY_5;
		}
	}
	else
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \d%l^n", "BULLET_TRACE_MENU_ITEM_2");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \d%l^n", "BULLET_TRACE_MENU_ITEM_3");
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \d%l^n", "BULLET_TRACE_MENU_ITEM_4");
		iKeys &= ~(MENU_KEY_2|MENU_KEY_3|MENU_KEY_4);
	}
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%l", "BULLET_TRACE_MENU_EXIT");
	show_menu(iPlayer, iKeys, szMenu, -1, "Show_TraceSettingsMenu");
}

public Handle_TraceSettingsMenu(iPlayer, iKey)
{
	SetGlobalTransTarget(iPlayer);
	
	switch(iKey)
	{
		case 0:
		{
			g_aUserSettings[iPlayer][ModeSwitch] = g_aUserSettings[iPlayer][ModeSwitch] ? false : true;
			client_print_color(iPlayer, print_team_default, "%l %l", "BULLET_TRACE_CHAT_PREFIX", g_aUserSettings[iPlayer][ModeSwitch] ? "BULLET_TRACE_CHAT_ENABLE" : "BULLET_TRACE_CHAT_DISABLE");
		}
		case 1:
		{
			if(g_aUserSettings[iPlayer][ModeSwitch])
			{
				Show_ApplicationToWeapon(iPlayer);
				return PLUGIN_HANDLED;
			}
		}
		case 2:
		{
			switch(g_aUserSettings[iPlayer][TraceType])
			{
				case LastBullets: g_aUserSettings[iPlayer][TraceType] = SomeBulletsToEnd;
				case SomeBulletsToEnd: g_aUserSettings[iPlayer][TraceType] = MiddleBullets;
				case MiddleBullets: g_aUserSettings[iPlayer][TraceType] = LastBullets;
			}
		}
		case 3:
		{
			g_aUserSettings[iPlayer][BulletsAmount]++;

			if(g_aUserSettings[iPlayer][BulletsAmount] > MAX_BULLET_TRACE)
				g_aUserSettings[iPlayer][BulletsAmount] = MIN_BULLET_TRACE;
		}
		case 4:
		{
			g_aUserSettings[iPlayer][BulletsToEnd]++;

			if(g_aUserSettings[iPlayer][BulletsToEnd] > MAX_BULLET_TO_END)
				g_aUserSettings[iPlayer][BulletsToEnd] = MIN_BULLET_TO_END;
		}
		case 9: return PLUGIN_HANDLED;
	}

	Show_TraceSettingsMenu(iPlayer);
	return PLUGIN_HANDLED;
}

public Show_ApplicationToWeapon(iPlayer)
{
	SetGlobalTransTarget(iPlayer);

	new szMenu[MAX_MENU_LENGTH];
	new iKeys;
	new iLen;

	iKeys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_0;

	iLen = formatex(szMenu, charsmax(szMenu), "\y%l:^n^n", "APPLICATION_TO_WEAPON_MENU_TITLE");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_1", g_aUserSettings[iPlayer][MenuSwitch] & Pistols ? "\yВкл" : "\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_2", g_aUserSettings[iPlayer][MenuSwitch] & SubmachineGuns ? "\yВкл" :"\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_3", g_aUserSettings[iPlayer][MenuSwitch] & Rifles ? "\yВкл" : "\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_4", g_aUserSettings[iPlayer][MenuSwitch] & SniperRifles ? "\yВкл" : "\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_5", g_aUserSettings[iPlayer][MenuSwitch] & MachineGun ? "\yВкл" : "\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \w%l: [\y%s\w]^n", "APPLICATION_TO_WEAPON_MENU_ITEM_6", g_aUserSettings[iPlayer][MenuSwitch] & All ? "\yВкл" : "\rВыкл");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r7. \w%l^n", "APPLICATION_TO_WEAPON_MENU_ITEM_7");

	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%l", "APPLICATION_TO_WEAPON_MENU_EXIT");
	show_menu(iPlayer, iKeys, szMenu, -1, "Show_ApplicationToWeapon");
}

public Handler_ApplicationToWeapon(iPlayer, iKey)
{
	switch(iKey)
	{
		case 0:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Pistols))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Pistols);
				ClearUserSettings(g_aUserSettings[iPlayer][Application], PISTOLS_BITSUM);
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Pistols);
				SetUserSettings(g_aUserSettings[iPlayer][Application], PISTOLS_BITSUM);
			}
		}
		case 1:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SubmachineGuns))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SubmachineGuns);
				ClearUserSettings(g_aUserSettings[iPlayer][Application], SUBMACHINEGUNS_BITSUM);
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SubmachineGuns);
				SetUserSettings(g_aUserSettings[iPlayer][Application], SUBMACHINEGUNS_BITSUM);
			}
		}
		case 2:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Rifles))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Rifles);
				ClearUserSettings(g_aUserSettings[iPlayer][Application], RIFLES_BITSUM);
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], Rifles);
				SetUserSettings(g_aUserSettings[iPlayer][Application], RIFLES_BITSUM);
			}
		}
		case 3:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SniperRifles))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SniperRifles);
				ClearUserSettings(g_aUserSettings[iPlayer][Application], SNIPER_RIFLES_BITSUM);
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], SniperRifles);
				SetUserSettings(g_aUserSettings[iPlayer][Application], SNIPER_RIFLES_BITSUM);
			}
		}
		case 4:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], MachineGun))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], MachineGun);
				ClearUserSettings(g_aUserSettings[iPlayer][Application], MACHINEGUN_BITSUM);
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], MachineGun);
				SetUserSettings(g_aUserSettings[iPlayer][Application], MACHINEGUN_BITSUM);
			}
		}
		case 5:
		{
			if(GetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], All))
			{
				ClearUserSettings(g_aUserSettings[iPlayer][MenuSwitch], (Pistols|SubmachineGuns|Rifles|SniperRifles|MachineGun|All));
				ClearUserSettings(g_aUserSettings[iPlayer][Application], (PISTOLS_BITSUM|SUBMACHINEGUNS_BITSUM|RIFLES_BITSUM|SNIPER_RIFLES_BITSUM|MACHINEGUN_BITSUM));
			}
			else
			{
				SetUserSettings(g_aUserSettings[iPlayer][MenuSwitch], (Pistols|SubmachineGuns|Rifles|SniperRifles|MachineGun|All));
				SetUserSettings(g_aUserSettings[iPlayer][Application], (PISTOLS_BITSUM|SUBMACHINEGUNS_BITSUM|RIFLES_BITSUM|SNIPER_RIFLES_BITSUM|MACHINEGUN_BITSUM));
			}
		}
		case 6:
		{
			Show_TraceSettingsMenu(iPlayer);
			return PLUGIN_HANDLED;
		}
		case 9: return PLUGIN_HANDLED;
	}
	Show_ApplicationToWeapon(iPlayer);
	return PLUGIN_HANDLED;
}

stock draw_bullet_trace(iPlayer)
{
	new iActiveItem = get_member(iPlayer, m_pActiveItem);

	if(IsBurstMode(iActiveItem)) 
		return;

	static iEndPosition[3];
	get_user_origin(iPlayer, iEndPosition, Origin_AimEndEyes);

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, iEndPosition, iPlayer);
	{
		write_byte(TE_BEAMENTPOINT);
		write_short(iPlayer | 0x1000);     	// start entity
		write_coord(iEndPosition[0]);       // end position X
		write_coord(iEndPosition[1]);       // end position Y
		write_coord(iEndPosition[2]);       // end position Z
		write_short(g_iSpriteIndex);        // sprite index

		write_byte(1);                      // starting frame
		write_byte(5);                      // frame rate in 0.1's
		write_byte(1);                      // life in 0.1's
		write_byte(5);                      // line width in 0.1's
		write_byte(0);                      // noise amplitude in 0.01's 
		write_byte(255);                    // red
		write_byte(215);                    // green
		write_byte(0);                      // blue
		write_byte(200);                    // brightness
		write_byte(150);                    // scroll speed in 0.1's
	}
	message_end();
}
