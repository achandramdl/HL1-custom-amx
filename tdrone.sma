#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#pragma reqlib "dcapi"
native damagecar(id, damage)

#define ctdrone_ADMIN ADMIN_LEVEL_A

#define TASK_ROCKET 6740100

new ctdrones[33], camera[33], ctdrone_speed[33]
new boom, smoke
new bool:wait_rocket[33]
new g_ctdroneactive = 0
new maxentities
new cost, gravity;

public plugin_init()
{
	register_plugin("AMX CTdrone", "0.2.0", "KRoTaL, Fox-NL, man_s_our")
	
	register_clcmd("drop", "stop_ctdrone")
	register_clcmd("ctdrone", "create_ctdrone")
	
	cost = register_cvar("drone_cost", "4000",FCVAR_SERVER)
	gravity = register_cvar("grav", "1",FCVAR_SERVER)
	register_event("DeathMsg", "death_event", "a")
	register_event("ResetHUD", "resethud_event", "be")
	register_event("CurWeapon", "check_weapon", "be", "1=1")
	register_logevent("new_round", 2, "0=World triggered", "1=Round_Start")
	register_event("TextMsg", "game_restart", "a", "1=4", "2&#Game_C", "2&#Game_w")
	register_event("SendAudio", "round_end", "a", "2=%!MRAD_terwin", "2=%!MRAD_ctwin", "2=%!MRAD_rounddraw")
	register_forward(FM_EmitSound,"emitsound",0)
}

public client_connect(id)
{
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	ctdrones[id] = 0
	camera[id] = 0
	wait_rocket[id] = false
}

public client_disconnect(id)
{
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	if(ctdrones[id] > 0)
	{
		emit_sound(ctdrones[id], CHAN_VOICE, "drone/ap_rotor2.wav", 0.0, ATTN_NORM, 0, PITCH_NORM)
		remove_entity(ctdrones[id])
		ctdrones[id] = 0
	}
	if(camera[id] > 0)
	{
		remove_entity(camera[id])
		camera[id] = 0
	}
	wait_rocket[id] = false
}

public new_round()
{
	new ent	
	ent = find_ent_by_class(-1, "drone_rocket")
	new tempent
	while(ent > 0)
	{
		tempent = find_ent_by_class(ent, "drone_rocket")
		remove_entity(ent)
		ent = tempent
	}
	set_task(0.1, "set_speed", 875457545)
}

public round_end()
{
	set_task(4.0, "disable_sound", 212454212)
}

public game_restart()
{
	set_task(0.5, "disable_sound", 787454241)
}

public disable_sound()
{
	new players[32], inum;
	get_players(players, inum, "a")
	for(new i = 0 ; i < inum ; i++)
	{
		emit_sound(ctdrones[players[i]], CHAN_VOICE, "drone/ap_rotor2.wav", 0.0, ATTN_NORM, 0, PITCH_NORM);
	}
}

public death_event()
{
	g_ctdroneactive = 1
	new id = read_data(2)
	
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	if(ctdrones[id] > 0)
	{
		emit_sound(ctdrones[id], CHAN_VOICE, "drone/ap_rotor2.wav", 0.0, ATTN_NORM, 0, PITCH_NORM)
		remove_entity(ctdrones[id])
		ctdrones[id] = 0
	}
	if(camera[id] > 0)
	{
		attach_view(id, id)
		remove_entity(camera[id])
		camera[id] = 0
	}
	wait_rocket[id] = false
	client_cmd(id, "-left")
	client_cmd(id, "-right")
}

public resethud_event(id)
{
	g_ctdroneactive = 1
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	if(ctdrones[id] > 0)
	{
		cs_set_user_money(id, cs_get_user_money(id) + floatround((get_pcvar_float(cost) * 2 * entity_get_float(ctdrones[id], EV_FL_health) - 5000) / 30), 1)
		remove_entity(ctdrones[id])
		ctdrones[id] = 0
	}
	if(camera[id] > 0)
	{
		attach_view(id, id)
		remove_entity(camera[id])
		camera[id] = 0
	}
	wait_rocket[id] = false
	client_cmd(id, "-left")
	client_cmd(id, "-right")
}

public check_weapon(id)
{
	if(ctdrones[id] > 0)
	{
		client_cmd(id, "weapon_knife")
		set_user_maxspeed(id, -1.0)
	}
}

public set_speed(id)
{
	new players[32], inum
	get_players(players, inum, "a")
	for(new i = 0 ; i < inum ; i++)
	{
		if(ctdrones[players[i]] > 0)
		{
			set_user_maxspeed(players[i], -1.0)
		}
	}
}

public create_ctdrone(id,level,cid)
{		
	if(ctdrones[id] > 0)
	{
		console_print(id, "You already control a drone.")
		client_print(id, print_center, "You already control a drone.")
		return PLUGIN_HANDLED
	}
	
	if(!is_user_alive(id))
	{
		console_print(id, "You cannot control a drone when you are dead.")
		client_print(id, print_center, "You cannot control a drone when you are dead.")
		return PLUGIN_HANDLED
	}
	
	if(cs_get_user_team(id) != CS_TEAM_CT)
	{
		return PLUGIN_HANDLED
	}
	if(cs_get_user_money(id) < get_pcvar_num(cost) * 2)
	{
		console_print(id, "You don't have enough money ($%i needed)", get_pcvar_num(cost) * 2)
		client_print(id, print_center, "You don't have enough money ($%i needed)", get_pcvar_num(cost) * 2)
		return PLUGIN_HANDLED
	}
	cs_set_user_money(id, cs_get_user_money(id) - get_pcvar_num(cost) * 2, 1) 
	new Float:origin[3]
	new Float:angles[3]
	entity_get_vector(id, EV_VEC_origin, origin)
	entity_get_vector(id, EV_VEC_v_angle, angles)
	origin[2] += 50
	
	ctdrones[id] = create_entity("info_target")
	if(ctdrones[id] > 0)
	{
		entity_set_string(ctdrones[id], EV_SZ_classname, "amx_ctdrone")
		entity_set_model(ctdrones[id], "models/CTdrone.mdl")
		
		entity_set_size(ctdrones[id], Float:{-12.0,-12.0,-6.0}, Float:{12.0,12.0,6.0})
		
		entity_set_origin(ctdrones[id], origin)
		entity_set_vector(ctdrones[id], EV_VEC_angles, angles)
		
		entity_set_int(ctdrones[id], EV_INT_solid, 2)
		entity_set_int(ctdrones[id], EV_INT_movetype, 5)
		entity_set_edict(ctdrones[id], EV_ENT_owner, id)
		entity_set_int(ctdrones[id], EV_INT_sequence, 1)
		entity_set_float(ctdrones[id], EV_FL_takedamage, DAMAGE_AIM)
		entity_set_float(ctdrones[id], EV_FL_health, 5030.0)		
		emit_sound(ctdrones[id], CHAN_VOICE, "drone/ap_rotor2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	
	camera[id] = create_entity("info_target")
	if(camera[id] > 0)
	{
		entity_set_string(camera[id], EV_SZ_classname, "camera")
		entity_set_int(camera[id], EV_INT_solid, SOLID_NOT)
		entity_set_int(camera[id], EV_INT_movetype, MOVETYPE_NOCLIP)
		entity_set_size(camera[id], Float:{0,0,0}, Float:{0,0,0})
		entity_set_model(camera[id], "models/rocket.mdl")
		
		entity_set_origin(camera[id], origin)
		entity_set_vector(camera[id], EV_VEC_angles, angles)
		
		attach_view(id, camera[id])
	}
	
	engclient_cmd(id, "weapon_knife")
	set_user_maxspeed(id, -1.0)
	
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	
	wait_rocket[id] = false
	
	return PLUGIN_HANDLED
}

public destroy_ctdrone(id,level,cid)
{
	if (!cmd_access(id,level,cid,1))
	{
		return PLUGIN_HANDLED
	}
	
	if(ctdrones[id] > 0)
	{
		attach_view(id, id)
		emit_sound(ctdrones[id], CHAN_VOICE, "drone/ap_rotor2.wav", 0.0, ATTN_NORM, 0, PITCH_NORM)
		remove_entity(ctdrones[id])
		ctdrones[id] = 0
		set_user_maxspeed(id, 250.0)
	}
	if(camera[id] > 0)
	{
		attach_view(id, id)
		remove_entity(camera[id])
		camera[id] = 0
	}
	
	if(task_exists(54545454+id))
	{
		remove_task(54545454+id)
	}
	
	wait_rocket[id] = false
	client_cmd(id, "-left")
	client_cmd(id, "-right")
	
	return PLUGIN_HANDLED
}

public stop_ctdrone(id)
{
	if(ctdrones[id] > 0)
	{
		if(ctdrone_speed[id] <= 30 && ctdrone_speed[id] >= -30)
		{
			ctdrone_speed[id] = 0
		}
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public client_PreThink(id)
{
	if(g_ctdroneactive == 0)
	{
		return PLUGIN_CONTINUE
	}
	new Float:v[3], Float:a[3]
	new ent = ent = find_ent_by_class(-1, "drone_rocket")
	while(ent > 0)
	{
		pev(ent, pev_velocity, v)
		vector_to_angle(v, a)
		set_pev(ent, pev_angles, a)
		ent = find_ent_by_class(ent, "drone_rocket")
	}
	if(is_user_alive(id) && ctdrones[id] > 0 && camera[id] > 0)
	{
		new Float:forigin[3],  Float:camera_origin[3]
		new button, oldbutton
		new Float:frame
		new Float:angles[3], Float:velocity[3], Float:angle[3]
		if(entity_get_float(ctdrones[id], EV_FL_health) < 5000)
		{
			new Float:explosion[3]
			entity_get_vector(ctdrones[id], EV_VEC_origin, explosion)
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(3)
			write_coord(floatround(explosion[0]))
			write_coord(floatround(explosion[1]))
			write_coord(floatround(explosion[2]))
			write_short(boom)
			write_byte(50)
			write_byte(15)
			write_byte(0)
			message_end()
			
			HL_RadiusDamage(explosion, id,0,50.0,300.0)
			/*radius_damage(explosion,50,300)*/
			
			attach_view(id, id)
			if(camera[id] > 0)
			{
				remove_entity(camera[id])
				camera[id] = 0
			}
			emit_sound(ctdrones[id], CHAN_VOICE, "drone/ap_rotor2.wav", 0.0, ATTN_NORM, 0, PITCH_NORM)
			remove_entity(ctdrones[id])
			ctdrones[id] = 0
			set_user_maxspeed(id, 250.0)
			if(task_exists(54545454+id))
			{
				remove_task(54545454+id)
			}
			wait_rocket[id] = false
			return PLUGIN_CONTINUE
		}
		
		frame = entity_get_float(ctdrones[id], EV_FL_frame)
		if(frame < 0.0 || frame > 254.0)
		{
			entity_set_float(ctdrones[id], EV_FL_frame, 0.0)
		}
		else
		{
			entity_set_float(ctdrones[id], EV_FL_frame, frame + 1.0)
		}
		entity_get_vector(ctdrones[id], EV_VEC_origin, forigin)
		button = get_user_button(id)
		if(button & IN_RELOAD)
		{
			ctdrone_speed[id] += 5
		}
		if(button & IN_USE)
		{
			ctdrone_speed[id] -= 5
		}

		if(ctdrone_speed[id] > 1000)
		{
			ctdrone_speed[id] = 1000
		}
		if(ctdrone_speed[id] < 300)
		{
			ctdrone_speed[id] = 300
		}
		entity_get_vector(ctdrones[id], EV_VEC_origin, forigin)
		entity_get_vector(id, EV_VEC_v_angle, angles)
		pev(ctdrones[id], pev_angles, angle)
		angle[0] = -angle[0]
		angle_vector(angle, 1, velocity)
		angles[0] = - angles[0] - angle[0]
		angles[1] += angle[1]
		angles[2] += angle[2]
		velocity[0] *= ctdrone_speed[id]
		velocity[1] *= ctdrone_speed[id]
		velocity[2] *= ctdrone_speed[id]
		entity_set_vector(ctdrones[id], EV_VEC_velocity, velocity)
		entity_set_vector(camera[id], EV_VEC_angles, angles)
		oldbutton = get_user_oldbutton(id)
		
		if(PointContents(forigin) == CONTENTS_SOLID)
		{
			forigin[2] += 10.0
			if(PointContents(forigin) == CONTENTS_SOLID)
			{
				forigin[2] -= 60.0
			}
			entity_set_origin(ctdrones[id], forigin)
		}
		angle[0] += 90
		new Float:cam[3]
		angle_vector(angle, 1, cam)
		camera_origin[0] = forigin[0] + velocity[0] / 10 + 10 * cam[0]
		camera_origin[1] = forigin[1] + velocity[1] / 10 + 10 * cam[1]
		camera_origin[2] = forigin[2] + velocity[2] / 10 + 10 * cam[2]
		entity_set_origin(camera[id], camera_origin)
		camera_origin[0] += 10 * cam[0]
		camera_origin[1] += 10 * cam[1]
		camera_origin[2] += 10 * cam[2]
		angles[0] = - angles[0]
		entity_set_vector(camera[id], EV_VEC_angles, angles)
		if(button & IN_ATTACK && !wait_rocket[id])
		{
			new ent = create_entity("info_target")
			if(ent > 0)
			{
				entity_set_string(ent, EV_SZ_classname, "drone_rocket")
				entity_set_model(ent, "models/rocket.mdl")
				
				entity_set_size(ent, Float:{-1.0,-1.0,-1.0}, Float:{1.0,1.0,1.0})
				
				entity_set_origin(ent, camera_origin)
				entity_set_vector(ent, EV_VEC_angles, angles)
				
				entity_set_int(ent, EV_INT_solid, 1)
				entity_set_edict(ent, EV_ENT_owner, id)
				if(get_pcvar_num(gravity))
				{
					entity_set_int(ent, EV_INT_movetype, MOVETYPE_TOSS);
					set_pev(ent, pev_gravity, 0.1);
				}
				else
					entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
				velocity[0] *= 2000 / ctdrone_speed[id]
				velocity[1] *= 2000 / ctdrone_speed[id]
				velocity[2] *= 2000 / ctdrone_speed[id]
		
				entity_set_vector(ent, EV_VEC_velocity, velocity)
				
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_BEAMFOLLOW)
				write_short(ent)
				write_short(smoke)
				write_byte(3)
				write_byte(5)
				write_byte(100)
				write_byte(100)
				write_byte(100)
				write_byte(254)
				message_end()
				
				emit_sound(ent, CHAN_WEAPON, "weapons/rocketfire1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM)
			}
			wait_rocket[id] = true
			set_task(2.0, "reset_rocket", id+TASK_ROCKET)
		}
		pev(ctdrones[id], pev_angles, angles)
		//pev(camera[id], pev_angles, angle)
		if(button & IN_MOVELEFT || oldbutton & IN_MOVELEFT)
		{
			angles[1] += 1
		}
		if(button & IN_MOVERIGHT || oldbutton & IN_MOVERIGHT)
		{
			angles[1] -= 1
		}
		if(button & IN_FORWARD || oldbutton & IN_FORWARD)
		{
			angles[0] += 1
		}
		if(button & IN_BACK || oldbutton & IN_BACK)
		{
			angles[0] -= 1
		}
		set_pev(ctdrones[id], pev_angles, angles)
		set_hudmessage(255, 255, 255, -2.0, 0.76, 0, 1.0, 0.01, 0.1, 0.2, 4)
		show_hudmessage(id, " [drone] Speed: %i, Health: %i", ctdrone_speed[id], floatround(entity_get_float(ctdrones[id], EV_FL_health) - 5000))
	}
	
	return PLUGIN_CONTINUE
}

public reset_rocket(id)
{
	wait_rocket[id-TASK_ROCKET] = false
}

public pfn_touch(entity1, entity2)
{
	if(g_ctdroneactive == 0)
	{
		return PLUGIN_CONTINUE
	}
	
	if(entity1 > 0 && is_valid_ent(entity1))
	{
		new classname[32]
		entity_get_string(entity1, EV_SZ_classname, classname, 32)
		new classname2[32]
		if(entity2 > 0 && is_valid_ent(entity2))
		{
			entity_get_string(entity2, EV_SZ_classname, classname2, 32)
		}
		
		new attacker = entity_get_edict(entity1, EV_ENT_owner)
		if(equal(classname, "drone_rocket"))
		{
			new Float:explosion[3]
			entity_get_vector(entity1, EV_VEC_origin, explosion)
			HL_RadiusDamage(explosion, attacker,0,120.0,500.0)
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(3)
			write_coord(floatround(explosion[0]))
			write_coord(floatround(explosion[1]))
			write_coord(floatround(explosion[2]))
			write_short(boom)
			write_byte(50)
			write_byte(15)
			write_byte(0)
			message_end()
						
			remove_entity(entity1)
			if(equal(classname2, "func_vehicle") || equal(classname2, "func_tracktrain"))
				damagecar(entity2, 75)
		}
		if(equal(classname, "amx_ctdrone"))
		{
			set_pev(entity1, pev_health, 4999.0)
		}
	}
	
	return PLUGIN_CONTINUE
}

public emitsound(entity, const sample[])
{
	if(equal(sample, "common/wpn_denyselect.wav"))
	{
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public plugin_precache()
{
	smoke = precache_model("sprites/smoke.spr")
	boom = precache_model("sprites/zerogxplode.spr")
	
	precache_model("models/CTdrone.mdl")
	precache_model("models/rocket.mdl")
	
	precache_sound("weapons/rocketfire1.wav")
	precache_sound("drone/ap_rotor2.wav")
}

public get_num_ents()
{
	new i, count;
	for(i=1;i<maxentities;i++)
	{
		if(is_valid_ent(i))
			count++
	}
	return count;
}

///////////////// THANKS AVALANCHE!! ///////////////////

public HL_RadiusDamage( Float:vecSrc[3], pevAttacker, pevInflictor, Float:flDamage, Float:flRadius/*, iClassIgnore, bitsDamageType*/ )
{
	new pEntity;
	new tr;
	new Float:flAdjustedDamage, Float:falloff;
	new Float:vecSpot[3];
	
	// NEW
	new Float:vecAbsMin[3], Float:vecAbsMax[3], Float:vecAdjust[3],
	Float:vecEndPos[3], Float:flFraction, iWaterLevel, i;
	
	if( flRadius )
		falloff = flDamage / flRadius;
	else
		falloff = 1.0;
	
	new bInWater = (engfunc( EngFunc_PointContents, vecSrc ) == CONTENTS_WATER);
	
	vecSrc[2] += 1;// in case grenade is lying on the ground
	
	// iterate on all entities in the vicinity.
	while ((pEntity = engfunc( EngFunc_FindEntityInSphere, pEntity, vecSrc, flRadius )) != 0)
	{
		if ( pev( pEntity, pev_takedamage ) != DAMAGE_NO )
		{
			iWaterLevel = pev( pEntity, pev_waterlevel ); // NEW
			
			// blasts don't travel into or out of water
			if (bInWater && iWaterLevel == 0)
				continue;
			if (!bInWater && iWaterLevel == 3)
				continue;
			
			// OLD: vecSpot = pEntity->BodyTarget( vecSrc ); -- NEW:
			pev( pEntity, pev_absmin, vecAbsMin );
			pev( pEntity, pev_absmax, vecAbsMax );
			for( i = 0; i < 3; i++ ) vecSpot[i] = ( vecAbsMin[i] + vecAbsMax[i] ) * 0.5;
			
			engfunc( EngFunc_TraceLine, vecSrc, vecSpot, DONT_IGNORE_MONSTERS, pevInflictor, tr );
			
			get_tr2( tr, TR_flFraction, flFraction ); // NEW
			get_tr2( tr, TR_vecEndPos, vecEndPos ); // NEW
			
			if ( flFraction == 1.0 || get_tr2( tr, TR_pHit ) == pEntity )
				{// the explosion can 'see' this entity, so hurt them!
			if ( get_tr2( tr, TraceResult:TR_StartSolid ) )
			{
				// if we're stuck inside them, fixup the position and distance
				vecEndPos =  vecSrc;
				flFraction = 0.0;
			}
			
			// decrease damage for an ent that's farther from the bomb.
			
			// OLD: flAdjustedDamage = ( vecSrc - tr.vecEndPos ).Length() * falloff; -- NEW:
			for( i = 0; i < 3; i++ ) vecAdjust[i] = vecSrc[i] - vecEndPos[i];
			flAdjustedDamage = floatsqroot(vecAdjust[0]*vecAdjust[0] + vecAdjust[1]*vecAdjust[1] + vecAdjust[2]*vecAdjust[2]) * falloff;
			
			flAdjustedDamage = flDamage - flAdjustedDamage;
			
			if ( flAdjustedDamage < 0.0 )
			{
				flAdjustedDamage = 0.0;
			}
			
			// ALERT( at_console, "hit %s\n", STRING( pEntity->pev->classname ) );
			take_damage(pevAttacker, pEntity, flAdjustedDamage ); // NEW
		}
	}
}
}

public take_damage(attacker, victim, Float:damage)
{
	if(victim <= get_maxplayers() + 1)
	{
		if (get_user_health(victim) - damage <= 0)
			util_kill(attacker, victim);
		else
		{
			fm_fakedamage(victim, "drone", damage, DMG_BULLET);
			static origin[3];
			get_user_origin(victim, origin, 0);
			message_begin(MSG_ONE, get_user_msgid("Damage"), {0, 0, 0}, victim);
			write_byte(0);		 // Damage save
			write_byte(floatround(damage));	 // Damage take
			write_long(DMG_BLAST);	 // Damage type
			write_coord(origin[0]);	 // X
			write_coord(origin[1]);	 // Y
			write_coord(origin[2]);	 // Z
			message_end();
			if (get_user_team(attacker) == get_user_team(victim))
			{
				static name[32];
				get_user_name(attacker, name, sizeof(name));
				client_print(0, print_chat, "%s attacked a teammate", name);
			}
		}
	}
}

util_kill(killer, victim)
{
	if (get_user_team(killer) != get_user_team(victim))
	{
		user_silentkill(victim);
		make_deathmsg(killer, victim, 0, "drone");

		set_user_frags(killer, get_user_frags(killer) + 1);

		new money = cs_get_user_money(killer) + 300;
		if (money >= 16000)
			cs_set_user_money(killer, 16000);
		else
			cs_set_user_money(killer, money, 1);
	}
	else
	{
		user_silentkill(victim);
		make_deathmsg(killer, victim, 0, "drone");
		set_user_frags(killer, get_user_frags(killer) - 1);
		new money = cs_get_user_money(killer) - 3300;
		if (money <= 0)
			cs_set_user_money(killer, 0);
		else
			cs_set_user_money(killer, money, 1);
	}

	message_begin(MSG_BROADCAST, get_user_msgid("ScoreInfo"));
	write_byte(killer);			 // Destination
	write_short(get_user_frags(killer));	 // Frags
	write_short(cs_get_user_deaths(killer)); // Deaths
	write_short(0);				 // Player class
	write_short(get_user_team(killer));	 // Team
	message_end();
	message_begin(MSG_BROADCAST, get_user_msgid("ScoreInfo"));
	write_byte(victim);			 // Destination
	write_short(get_user_frags(victim));	 // Frags
	write_short(cs_get_user_deaths(victim)); // Deaths
	write_short(0);				 // Player class
	write_short(get_user_team(victim));	 // Team
	message_end();
	static kname[32];
	static vname[32];
	static kteam[10];
	static vteam[10];
	static kauthid[32];
	static vauthid[32];

	get_user_name(killer, kname, sizeof(kname));
	get_user_team(killer, kteam, sizeof(kteam));
	get_user_authid(killer, kauthid, sizeof(kauthid));

	get_user_name(victim, vname, sizeof(vname));
	get_user_team(victim, vteam, sizeof(vteam));
	get_user_authid(victim, vauthid, sizeof(vauthid));

	log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with drone", 
	kname, get_user_userid(killer), kauthid, kteam, 
 	vname, get_user_userid(victim), vauthid, vteam);
}
