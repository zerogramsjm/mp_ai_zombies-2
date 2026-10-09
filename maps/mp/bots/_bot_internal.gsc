#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\bots\_bot_utility;

/*
	When a bot is added (once ever) to the game (before connected).
	We init all the persistent variables here.
*/
added()
{
    self endon( "disconnect" );
    
    self.pers[ "bots" ] = [];
    self.pers[ "bots" ][ "skill" ] = [];

    // Instant awareness & maximum tracking
    self.pers[ "bots" ][ "skill" ][ "base" ] = 10;
    self.pers[ "bots" ][ "skill" ][ "aim_time" ] = 0.01;
    self.pers[ "bots" ][ "skill" ][ "init_react_time" ] = 0;
    self.pers[ "bots" ][ "skill" ][ "reaction_time" ] = 0;
    self.pers[ "bots" ][ "skill" ][ "no_trace_ads_time" ] = 99999;
    self.pers[ "bots" ][ "skill" ][ "no_trace_look_time" ] = 99999;
    self.pers[ "bots" ][ "skill" ][ "remember_time" ] = 999999; // Never forget target
    self.pers[ "bots" ][ "skill" ][ "fov" ] = -1; // 360-degree FOV (sees all directions)
    self.pers[ "bots" ][ "skill" ][ "dist_max" ] = 9999999; // Unlimited vision distance
    self.pers[ "bots" ][ "skill" ][ "dist_start" ] = 9999999;
    self.pers[ "bots" ][ "skill" ][ "spawn_time" ] = 0;
    self.pers[ "bots" ][ "skill" ][ "help_dist" ] = 999999;
    self.pers[ "bots" ][ "skill" ][ "semi_time" ] = 0.05;
    self.pers[ "bots" ][ "skill" ][ "shoot_after_time" ] = 999;
    self.pers[ "bots" ][ "skill" ][ "aim_offset_time" ] = 0;
    self.pers[ "bots" ][ "skill" ][ "aim_offset_amount" ] = 0; // Pinpoint targeting
    self.pers[ "bots" ][ "skill" ][ "bone_update_interval" ] = 0.05;
    self.pers[ "bots" ][ "skill" ][ "bones" ] = "j_spine4";
    self.pers[ "bots" ][ "skill" ][ "ads_fov_multi" ] = 1.0;
    self.pers[ "bots" ][ "skill" ][ "ads_aimspeed_multi" ] = 1.0;
    
    self.pers[ "bots" ][ "behavior" ] = [];
    self.pers[ "bots" ][ "behavior" ][ "strafe" ] = 0;    // No strafing
    self.pers[ "bots" ][ "behavior" ][ "nade" ] = 0;      // No grenades
    self.pers[ "bots" ][ "behavior" ][ "sprint" ] = 100;  // 100% sprint rate
    self.pers[ "bots" ][ "behavior" ][ "camp" ] = 0;      // Never camp
    self.pers[ "bots" ][ "behavior" ][ "follow" ] = 100;  // Always pursue
    self.pers[ "bots" ][ "behavior" ][ "crouch" ] = 0;
    self.pers[ "bots" ][ "behavior" ][ "switch" ] = 0;
    self.pers[ "bots" ][ "behavior" ][ "class" ] = 0;
    self.pers[ "bots" ][ "behavior" ][ "jump" ] = 0;
    
    self.pers[ "bots" ][ "behavior" ][ "quickscope" ] = false;
    self.pers[ "bots" ][ "behavior" ][ "initswitch" ] = 0;
}

/*
	When a bot connects to the game.
	This is called when a bot is added and when multiround gamemode starts.
*/
connected()
{
	self endon( "disconnect" );
	
	self.bot = spawnstruct();
	self.bot_radar = false;
	self resetBotVars();
	
	self thread onPlayerSpawned();
	self thread bot_skip_killcam();
	self thread onUAVUpdate();
}

assign_zombie_speed_tier()
{
    // Roll 1 - 100 for weighted tier selection
    roll = randomIntRange( 1, 101 );

    // 50% Walkers, 35% Joggers, 15% Sprinters
    if ( roll <= 50 )
    {
        // SLOW WALKER (35% to 45% standard speed)
        self.zombie_type = "walker";
        self.zombie_speed = randomFloatRange( .1, 0.3 );
    }
    else if ( roll <= 85 )
    {
        // JOGGER / SHUFFLER (60% to 75% standard speed)
        self.zombie_type = "jogger";
        self.zombie_speed = randomFloatRange( 0.20, 0.4 );
    }
    else
    {
        // FAST SPRINTER (90% to 110% standard speed)
        self.zombie_type = "sprinter";
        self.zombie_speed = randomFloatRange( 0.40, 0.8 );
    }

    // Apply the speed scale to the engine player entity
    self setMoveSpeedScale( self.zombie_speed );
}

/*
	The thread for when the UAV gets updated.
*/
onUAVUpdate()
{
	self endon( "disconnect" );
	
	for ( ;; )
	{
		self waittill( "radar_timer_kill" );
		self thread doUAVUpdate();
	}

	self assign_zombie_speed_tier();
}

/*
	We tell that bot has a UAV.
*/
doUAVUpdate()
{
	self endon( "disconnect" );
	self endon( "radar_timer_kill" );
	
	self.bot_radar = true;
	
	wait level.radarviewtime;
	
	self.bot_radar = false;
}

/*
	The callback hook for when the bot gets killed.
*/
onKilled( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration )
{
}

/*
	The callback hook when the bot gets damaged.
*/
onDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset )
{
}

/*
	We clear all of the script variables and other stuff for the bots.
*/
resetBotVars()
{
	self.bot.script_target = undefined;
	self.bot.script_target_offset = undefined;
	self.bot.target = undefined;
	self.bot.targets = [];
	self.bot.target_this_frame = undefined;
	self.bot.after_target = undefined;
	self.bot.after_target_pos = undefined;
	self.bot.moveto = self.origin;
	
	self.bot.script_aimpos = undefined;
	
	self.bot.script_goal = undefined;
	self.bot.script_goal_dist = 0.0;
	
	self.bot.next_wp = -1;
	self.bot.second_next_wp = -1;
	self.bot.towards_goal = undefined;
	self.bot.astar = [];
	self.bot.stop_move = false;
	self.bot.greedy_path = false;
	self.bot.climbing = false;
	self.bot.wantsprint = true;
	self.bot.last_next_wp = -1;
	self.bot.last_second_next_wp = -1;
	
	self.bot.isfrozen = false;
	self.bot.sprintendtime = -1;
	self.bot.isreloading = false;
	self.bot.issprinting = false;
	self.bot.isfragging = false;
	self.bot.issmoking = false;
	self.bot.isfraggingafter = false;
	self.bot.issmokingafter = false;
	self.bot.isknifing = false;
	self.bot.isknifingafter = false;
	self.bot.knifing_target = undefined;
	
	self.bot.semi_time = false;
	self.bot.jump_time = undefined;
	self.bot.last_fire_time = -1;
	
	self.bot.is_cur_full_auto = false;
	self.bot.cur_weap_dist_multi = 1;
	self.bot.is_cur_sniper = false;
	
	self.bot.prio_objective = false;
	
	self.bot.rand = randomint( 100 );
	
	self BotBuiltinBotStop();
}

/*
	Bots will skip killcams here.
*/
bot_skip_killcam()
{
	level endon( "game_ended" );
	self endon( "disconnect" );
	
	for ( ;; )
	{
		self waittill( "begin_killcam" );
		
		self thread doKillcamStuff();
	}
}

/*
	bots use copy cat and skip killcams
*/
doKillcamStuff()
{
	self endon( "disconnect" );
	
	self BotNotifyBotEvent( "killcam", "start" );
	
	wait 0.5 + randomint( 3 );
	
	wait 0.1;
	
	self notify( "end_killcam" );
	
	self BotNotifyBotEvent( "killcam", "stop" );
}

/*
	When the bot spawns.
*/
onPlayerSpawned()
{
	self endon( "disconnect" );
	
	for ( ;; )
	{
		self waittill( "spawned_player" );
		
		self resetBotVars();
		self thread onWeaponChange();
		self thread onLastStand();
		
		self thread reload_watch();
		self thread sprint_watch();
		
		self thread spawned();
	}
}

/*
	Bot moves towards the point
*/
doBotMovement_loop( data )
{
    move_To = self.bot.moveto;
    angles = self getplayerangles();
    dir = ( 0, 0, 0 );
    
    if ( distancesquared( self.origin, move_To ) >= 49 )
    {
        cosa = cos( 0 - angles[ 1 ] );
        sina = sin( 0 - angles[ 1 ] );
        
        dir = move_To - self.origin;
        
        dir = ( dir[ 0 ] * cosa - dir[ 1 ] * sina,
                dir[ 0 ] * sina + dir[ 1 ] * cosa,
                0 );
                
        dir = vectornormalize( dir ) * 127;
        dir = ( dir[ 0 ], 0 - dir[ 1 ], 0 );
    }
    
    if ( self ismantling() )
    {
        data.wasmantling = true;
    }
    else if ( data.wasmantling )
    {
        data.wasmantling = false;
        self stand();
    }
    
    // 1. Force max forward direction vector
    dir = ( 127, dir[ 1 ], 0 );
    
	if ( isDefined( self.zombie_type ) && self.zombie_type == "sprinter" )
	{
		self.bot.issprinting = true;
		self.bot.wantsprint = true;
	}
	else
	{
		self.bot.issprinting = false;
		self.bot.wantsprint = true;
	}

    self stand();

    // 3. Trigger native +sprint button input continuously
    self BotBuiltinBotAction( "+sprint" );

    self BotBuiltinBotMovement( int( dir[ 0 ] ), int( dir[ 1 ] ) );
}

/*
	Bot moves towards the point
*/
doBotMovement()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	data = spawnstruct();
	data.wasmantling = false;
	
	for ( data.i = 0; true; data.i += 0.05 )
	{
		wait 0.05;
		
		waittillframeend;
		self doBotMovement_loop( data );
	}
}

/*
	We wait for a time defined by the bot's difficulty and start all threads that control the bot.
*/
spawned()
{
    self endon( "disconnect" );
    self endon( "death" );
    
    wait self.pers[ "bots" ][ "skill" ][ "spawn_time" ];
    
    self thread doBotMovement();
    self thread grenade_danger();
    self thread check_reload();
    self thread stance();
    self thread walk();
    self thread target();
    self thread updateBones();
    self thread aim();
    self thread watchHoldBreath();
    self thread onNewEnemy();
    self thread watchGrenadeFire();
    self thread watchPickupGun();
    
    // Custom zombie vocal wander thread
    self thread bot_zombie_vocals();
    
    self notify( "bot_spawned" );
}

bot_zombie_vocals()
{
    self endon( "disconnect" );
    self endon( "death" );

    // Initial delay so all bots don't make noise at the exact same frame on spawn
    wait RandomFloatRange( 1.0, 3.0 );

    while( isAlive( self ) )
    {
        // 3D sound played at the bot's location for surrounding players
        self playSound( "attack_vocals" );

        // Wait a random duration before groaning again (adjust times to fit your pacing)
        wait RandomFloatRange( 1.5, 3.0 );
    }
}

/*
	watchPickupGun
*/
watchPickupGun()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		wait 1;
		
		if ( self usebuttonpressed() )
		{
			continue;
		}
		
		// todo have bots use turrets instead of just kicking them off of it
		if ( isdefined( self.turret ) )
		{
			self thread use( 0.5 );
			continue;
		}
		
		// todo have bots use vehicles properly
		if ( self isinvehicle() )
		{
			self thread use( 0.5 );
			continue;
		}
		
		weap = self getcurrentweapon();
		
		if ( weap != "none" && self getammocount( weap ) )
		{
			continue;
		}
		
		self thread use( 0.5 );
	}
}

/*
	Watches when the bot fires a grenade
*/
watchGrenadeFire()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill( "grenade_fire", nade, weapname );
		
		if ( !isdefined( nade ) )
		{
			continue;
		}
		
		if ( weapname == "satchel_charge_mp" )
		{
			self thread watchC4Thrown( nade );
		}
	}
}

/*
	Watches the c4
*/
watchC4Thrown( c4 )
{
	self endon( "disconnect" );
	c4 endon( "death" );
	
	wait 0.5;
	
	for ( ;; )
	{
		wait 1 + randomint( 50 ) * 0.05;
		
		shouldBreak = false;
		
		for ( i = 0; i < level.players.size; i++ )
		{
			player = level.players[ i ];
			
			if ( player == self )
			{
				continue;
			}
			
			if ( ( level.teambased && self.team == player.team ) || player.sessionstate != "playing" || !isalive( player ) )
			{
				continue;
			}
			
			if ( distancesquared( c4.origin, player.origin ) > 200 * 200 )
			{
				continue;
			}
			
			if ( !bullettracepassed( c4.origin, player.origin + ( 0, 0, 25 ), false, c4 ) )
			{
				continue;
			}
			
			shouldBreak = true;
		}
		
		if ( shouldBreak )
		{
			break;
		}
	}
	
	if ( self getcurrentweapon() != "satchel_charge_mp" )
	{
		self notify( "alt_detonate" );
	}
	else
	{
		self thread pressFire();
	}
}

/*
	Sets the factor of distance for a weapon
*/
SetWeaponDistMulti( weap )
{
	if ( weap == "none" )
	{
		return 1;
	}
	
	switch ( weaponclass( weap ) )
	{
		case "rifle":
			return 0.9;
			
		case "smg":
			return 0.7;
			
		case "pistol":
			return 0.5;
			
		default:
			return 1;
	}
}

/*
	Is the weap a sniper
*/
IsWeapSniper( weap )
{
	if ( weap == "none" )
	{
		return false;
	}
	
	if ( maps\mp\gametypes\_missions::getweaponclass( weap ) != "weapon_sniper" )
	{
		return false;
	}
	
	return true;
}

/*
	The hold breath thread.
*/
watchHoldBreath()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		wait 1;
		
		if ( self.bot.isfrozen )
		{
			continue;
		}
		
		self holdbreath( self playerads() > 0 );
	}
}

/*
	When the bot enters laststand, we fix the weapons
*/
onLastStand()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	while ( true )
	{
		while ( !self inLastStand() )
		{
			wait 0.05;
		}
		
		self notify( "kill_goal" );
		
		while ( self inLastStand() )
		{
			wait 0.05;
		}
	}
}

/*
	When the bot changes weapon.
*/
onWeaponChange()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	first = true;
	
	for ( ;; )
	{
		newWeapon = undefined;
		
		if ( first )
		{
			first = false;
			newWeapon = self getcurrentweapon();
			
			// hack fix for botstop overridding weapon
			if ( newWeapon != "none" )
			{
				self switchtoweapon( newWeapon );
			}
		}
		else
		{
			self waittill( "weapon_change", newWeapon );
		}
		
		self.bot.is_cur_full_auto = WeaponIsFullAuto( newWeapon );
		self.bot.cur_weap_dist_multi = SetWeaponDistMulti( newWeapon );
		self.bot.is_cur_sniper = IsWeapSniper( newWeapon );
	}
}

/*
	Updates the bot if it is sprinting.
*/
sprint_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill( "sprint_begin" );
		self.bot.issprinting = true;
		self waittill( "sprint_end" );
		self.bot.issprinting = false;
		self.bot.sprintendtime = gettime();
	}
}

/*
	Update's the bot if it is reloading.
*/
reload_watch_loop()
{
	self.bot.isreloading = true;
	
	while ( true )
	{
		ret = self waittill_any_timeout( 7.5, "reload" );
		
		if ( ret == "timeout" )
		{
			break;
		}
		
		weap = self getcurrentweapon();
		
		if ( weap == "none" )
		{
			break;
		}
		
		if ( self getweaponammoclip( weap ) >= weaponclipsize( weap ) )
		{
			break;
		}
	}
	
	self.bot.isreloading = false;
}

/*
	Update's the bot if it is reloading.
*/
reload_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill( "reload_start" );
		
		self reload_watch_loop();
	}
}

/*
	Bots will update its needed stance according to the nodes on the level. Will also allow the bot to sprint when it can.
*/
stance_loop()
{
	self.bot.climbing = false;
	
	if ( self.bot.isfrozen )
	{
		return;
	}
	
	toStance = "stand";
	
	if ( self.bot.next_wp != -1 )
	{
		toStance = level.waypoints[ self.bot.next_wp ].type;
	}
	
	if ( !isdefined( toStance ) )
	{
		toStance = "crouch";
	}
	
	if ( toStance == "stand" && randomint( 100 ) <= self.pers[ "bots" ][ "behavior" ][ "crouch" ] )
	{
		toStance = "crouch";
	}
	
	if ( toStance == "climb" )
	{
		self.bot.climbing = true;
		toStance = "stand";
	}
	
	if ( toStance != "stand" && toStance != "crouch" && toStance != "prone" )
	{
		toStance = "crouch";
	}
	
	if ( toStance == "stand" )
	{
		self stand();
	}
	else if ( toStance == "crouch" )
	{
		self stand();
	}
	else
	{
		self stand();
	}
	
	curweap = self getcurrentweapon();
	time = gettime();
	chance = self.pers[ "bots" ][ "behavior" ][ "sprint" ];
	
	if ( time - self.lastspawntime < 5000 )
	{
		chance *= 2;
	}
	
	if ( isdefined( self.bot.script_goal ) && distancesquared( self.origin, self.bot.script_goal ) > 256 * 256 )
	{
		chance *= 2;
	}
	
	if ( toStance != "stand" || self.bot.isreloading || self.bot.issprinting || self.bot.isfraggingafter || self.bot.issmokingafter )
	{
		return;
	}
	
	if ( randomint( 100 ) > chance )
	{
		return;
	}
	
	if ( isdefined( self.bot.target ) && self canFire( curweap ) && self isInRange( self.bot.target.dist, curweap ) )
	{
		return;
	}
	
	if ( self.bot.sprintendtime != -1 && time - self.bot.sprintendtime < 2000 )
	{
		return;
	}
	
	if ( !isdefined( self.bot.towards_goal ) || distancesquared( self.origin, physicstrace( self getEyePos(), self getEyePos() + anglestoforward( self getplayerangles() ) * 1024, false, undefined ) ) < level.bots_minsprintdistance || getConeDot( self.bot.towards_goal, self.origin, self getplayerangles() ) < 0.75 )
	{
		return;
	}
	
	self thread sprint();
	self thread setBotWantSprint();
}

/*
	Stops the sprint fix when goal is completed
*/
setBotWantSprint()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	self notify( "setBotWantSprint" );
	self endon( "setBotWantSprint" );
	
	self.bot.wantsprint = true;
	
}

/*
	Bots will update its needed stance according to the nodes on the level. Will also allow the bot to sprint when it can.
*/
stance()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill_either( "finished_static_waypoints", "new_static_waypoint" );
		
		self stance_loop();
	}
}

/*
	Bot will wait until there is a grenade nearby and possibly throw it back.
*/
grenade_danger()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill( "grenade danger", grenade, attacker, weapname );
		
		if ( !isdefined( grenade ) )
		{
			continue;
		}
		
		if ( !getdvarint( "bots_play_nade" ) )
		{
			continue;
		}
		
		if ( weapname != "frag_grenade_mp" )
		{
			continue;
		}
		
		if ( isdefined( attacker ) && level.teambased && attacker.team == self.team )
		{
			continue;
		}
		
		self thread watch_grenade( grenade );
	}
}

/*
	Bot will throw back the given grenade if it is close, will watch until it is deleted or close.
*/
watch_grenade( grenade )
{
	self endon( "disconnect" );
	self endon( "death" );
	grenade endon( "death" );
	
	while ( 1 )
	{
		wait 1;
		
		if ( !isdefined( grenade ) )
		{
			return;
		}
		
		if ( self.bot.isfrozen )
		{
			continue;
		}
		
		if ( !bullettracepassed( self getEyePos(), grenade.origin, false, grenade ) )
		{
			continue;
		}
		
		if ( distancesquared( self.origin, grenade.origin ) > 20000 )
		{
			continue;
		}
		
		if ( self.bot.isfraggingafter || self.bot.issmokingafter )
		{
			continue;
		}
		
		self BotNotifyBotEvent( "throwback", "stop", grenade );
		self thread frag();
	}
}

/*
	Bot will wait until firing.
*/
check_reload()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill_notify_or_timeout( "weapon_fired", 5 );
		self thread reload_thread();
	}
}

/*
	Bot will reload after firing if needed.
*/
reload_thread()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "weapon_fired" );
	
	wait 2.5;
	
	if ( isdefined( self.bot.target ) || self.bot.isreloading || self.bot.isfraggingafter || self.bot.issmokingafter || self.bot.isfrozen )
	{
		return;
	}
	
	cur = self getcurrentweapon();
	
	if ( cur == "" || cur == "none" )
	{
		return;
	}
	
	if ( isweaponcliponly( cur ) || !self getweaponammostock( cur ) )
	{
		return;
	}
	
	maxsize = weaponclipsize( cur );
	cursize = self getweaponammoclip( cur );
	
	if ( cursize / maxsize < 0.5 )
	{
		self thread reload();
	}
}

/*
	Updates the bot's target bone
*/
updateBones()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		oldbones = self.pers[ "bots" ][ "skill" ][ "bones" ];
		bones = strtok( oldbones, "," );
		
		while ( oldbones == self.pers[ "bots" ][ "skill" ][ "bones" ] )
		{
			self waittill_notify_or_timeout( "new_enemy", self.pers[ "bots" ][ "skill" ][ "bone_update_interval" ] );
			
			if ( !isdefined( self.bot.target ) )
			{
				continue;
			}
			
			self.bot.target.bone = PickRandom( bones );
		}
	}
}

/*
	Creates the base target obj
*/
createTargetObj( ent, theTime )
{
	obj = spawnstruct();
	obj.entity = ent;
	obj.last_seen_pos = ( 0, 0, 0 );
	obj.dist = 0;
	obj.time = theTime;
	obj.trace_time = 0;
	obj.no_trace_time = 0;
	obj.trace_time_time = 0;
	obj.rand = randomint( 100 );
	obj.didlook = false;
	obj.offset = undefined;
	obj.bone = undefined;
	obj.aim_offset = undefined;
	obj.aim_offset_base = undefined;
	
	return obj;
}

/*
	Updates the target object's difficulty missing aim, inaccurate shots
*/
updateAimOffset( obj )
{
	if ( !isdefined( obj.aim_offset_base ) )
	{
		diffAimAmount = self.pers[ "bots" ][ "skill" ][ "aim_offset_amount" ];
		
		if ( diffAimAmount > 0 )
		{
			obj.aim_offset_base = ( randomfloatrange( 0 - diffAimAmount, diffAimAmount ),
						randomfloatrange( 0 - diffAimAmount, diffAimAmount ),
						randomfloatrange( 0 - diffAimAmount, diffAimAmount ) );
		}
		else
		{
			obj.aim_offset_base = ( 0, 0, 0 );
		}
	}
	
	aimDiffTime = self.pers[ "bots" ][ "skill" ][ "aim_offset_time" ] * 1000;
	objCreatedFor = obj.trace_time;
	
	if ( objCreatedFor >= aimDiffTime )
	{
		offsetScalar = 0;
	}
	else
	{
		offsetScalar = 1 - objCreatedFor / aimDiffTime;
	}
	
	obj.aim_offset = obj.aim_offset_base * offsetScalar;
}

/*
	Updates the target object to be traced Has LOS
*/
targetObjUpdateTraced( obj, daDist, ent, theTime, isScriptObj )
{
	distClose = self.pers[ "bots" ][ "skill" ][ "dist_start" ];
	distClose *= self.bot.cur_weap_dist_multi;
	distClose *= distClose;
	
	distMax = self.pers[ "bots" ][ "skill" ][ "dist_max" ];
	distMax *= self.bot.cur_weap_dist_multi;
	distMax *= distMax;
	
	timeMulti = 1;
	
	if ( !isScriptObj )
	{
		if ( daDist > distMax )
		{
			timeMulti = 0;
		}
		else if ( daDist > distClose )
		{
			timeMulti = 1 - ( ( daDist - distClose ) / ( distMax - distClose ) );
		}
	}
	
	obj.no_trace_time = 0;
	obj.trace_time += int( 50 * timeMulti );
	obj.dist = daDist;
	obj.last_seen_pos = ent.origin;
	obj.trace_time_time = theTime;
	
	self updateAimOffset( obj );
}

/*
	Updates the target object to be not traced No LOS
*/
targetObjUpdateNoTrace( obj )
{
	obj.no_trace_time += 50;
	obj.trace_time = 0;
	obj.didlook = false;
}

/*
	Returns true if myEye can see the bone of self
*/
checkTraceForBone( myEye, bone )
{
	boneLoc = self gettagorigin( bone );
	
	if ( !isdefined( boneLoc ) )
	{
		return false;
	}
	
	trace = bullettrace( myEye, boneLoc, false, undefined );
	
	return ( sighttracepassed( myEye, boneLoc, false, undefined ) && ( trace[ "fraction" ] >= 1.0 || trace[ "surfacetype" ] == "glass" ) );
}

/*
	The main target thread, will update the bot's main target. Will auto target enemy players and handle script targets.
*/
target_loop()
{
	myEye = self getEyePos();
	theTime = gettime();
	myAngles = self getplayerangles();
	myFov = self.pers[ "bots" ][ "skill" ][ "fov" ];
	bestTargets = [];
	bestTime = 2147483647;
	rememberTime = self.pers[ "bots" ][ "skill" ][ "remember_time" ];
	initReactTime = self.pers[ "bots" ][ "skill" ][ "init_react_time" ];
	hasTarget = isdefined( self.bot.target );
	adsAmount = self playerads();
	adsFovFact = self.pers[ "bots" ][ "skill" ][ "ads_fov_multi" ];
	
	if ( hasTarget && !isdefined( self.bot.target.entity ) )
	{
		self.bot.target = undefined;
		hasTarget = false;
	}
	
	// reduce fov if ads'ing
	if ( adsAmount > 0 )
	{
		myFov *= 1 - adsFovFact * adsAmount;
	}
	
	playercount = level.players.size;
	
	for ( i = -1; i < playercount; i++ )
	{
		obj = undefined;
		
		if ( i == -1 )
		{
			if ( !isdefined( self.bot.script_target ) )
			{
				continue;
			}
			
			ent = self.bot.script_target;
			key = ent getentitynumber() + "";
			daDist = distancesquared( self.origin, ent.origin );
			obj = self.bot.targets[ key ];
			isObjDef = isdefined( obj );
			entOrigin = ent.origin;
			
			if ( isdefined( self.bot.script_target_offset ) )
			{
				entOrigin += self.bot.script_target_offset;
			}
			
			if ( SmokeTrace( myEye, entOrigin, level.smokeradius ) && bullettracepassed( myEye, entOrigin, false, ent ) )
			{
				if ( !isObjDef )
				{
					obj = self createTargetObj( ent, theTime );
					obj.offset = self.bot.script_target_offset;
					
					self.bot.targets[ key ] = obj;
				}
				
				self targetObjUpdateTraced( obj, daDist, ent, theTime, true );
			}
			else
			{
				if ( !isObjDef )
				{
					continue;
				}
				
				self targetObjUpdateNoTrace( obj );
				
				if ( obj.no_trace_time > rememberTime )
				{
					self.bot.targets[ key ] = undefined;
					continue;
				}
			}
		}
		else
		{
			player = level.players[ i ];
			
			if ( !player IsPlayerModelOK() )
			{
				continue;
			}
			
			if ( player == self )
			{
				continue;
			}
			
			key = player getentitynumber() + "";
			obj = self.bot.targets[ key ];
			daDist = distancesquared( self.origin, player.origin );
			isObjDef = isdefined( obj );
			
			if ( ( level.teambased && self.team == player.team ) || player.sessionstate != "playing" || !isalive( player ) )
			{
				if ( isObjDef )
				{
					self.bot.targets[ key ] = undefined;
				}
				
				continue;
			}
			
			canTargetPlayer = ( ( player checkTraceForBone( myEye, "j_head" ) ||
						player checkTraceForBone( myEye, "j_ankle_le" ) ||
						player checkTraceForBone( myEye, "j_ankle_ri" ) )
						
					&& ( SmokeTrace( myEye, player.origin, level.smokeradius ) ||
						daDist < level.bots_maxknifedistance * 4 )
						
					&& ( getConeDot( player.origin, self.origin, myAngles ) >= myFov ||
						( isObjDef && obj.trace_time ) ) );
						
			if ( isdefined( self.bot.target_this_frame ) && self.bot.target_this_frame == player )
			{
				self.bot.target_this_frame = undefined;
				
				canTargetPlayer = true;
			}
			
			if ( canTargetPlayer )
			{
				if ( !isObjDef )
				{
					obj = self createTargetObj( player, theTime );
					
					self.bot.targets[ key ] = obj;
				}
				
				self targetObjUpdateTraced( obj, daDist, player, theTime, false );
			}
			else
			{
				if ( !isObjDef )
				{
					continue;
				}
				
				self targetObjUpdateNoTrace( obj );
				
				if ( obj.no_trace_time > rememberTime )
				{
					self.bot.targets[ key ] = undefined;
					continue;
				}
			}
		}
		
		if ( !isdefined( obj ) )
		{
			continue;
		}
		
		if ( theTime - obj.time < initReactTime )
		{
			continue;
		}
		
		timeDiff = theTime - obj.trace_time_time;
		
		if ( timeDiff < bestTime )
		{
			bestTargets = [];
			bestTime = timeDiff;
		}
		
		if ( timeDiff == bestTime )
		{
			bestTargets[ key ] = obj;
		}
	}
	
	if ( hasTarget && isdefined( bestTargets[ self.bot.target.entity getentitynumber() + "" ] ) )
	{
		return;
	}
	
	closest = 2147483647;
	toBeTarget = undefined;
	
	bestKeys = getarraykeys( bestTargets );
	
	for ( i = bestKeys.size - 1; i >= 0; i-- )
	{
		theDist = bestTargets[ bestKeys[ i ] ].dist;
		
		if ( theDist > closest )
		{
			continue;
		}
		
		closest = theDist;
		toBeTarget = bestTargets[ bestKeys[ i ] ];
	}
	
	beforeTargetID = -1;
	newTargetID = -1;
	
	if ( hasTarget && isdefined( self.bot.target.entity ) )
	{
		beforeTargetID = self.bot.target.entity getentitynumber();
	}
	
	if ( isdefined( toBeTarget ) && isdefined( toBeTarget.entity ) )
	{
		newTargetID = toBeTarget.entity getentitynumber();
	}
	
	if ( beforeTargetID != newTargetID )
	{
		self.bot.target = toBeTarget;
		self notify( "new_enemy" );
	}
}

/*
	The main target thread, will update the bot's main target. Will auto target enemy players and handle script targets.
*/
target()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		wait 0.05;
		
		if ( self isFlared() )
		{
			continue;
		}
		
		self target_loop();
	}
}

/*
	When the bot gets a new enemy.
*/
onNewEnemy()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		self waittill( "new_enemy" );
		
		if ( !isdefined( self.bot.target ) )
		{
			continue;
		}
		
		if ( !isdefined( self.bot.target.entity ) || !isplayer( self.bot.target.entity ) )
		{
			continue;
		}
		
		if ( self.bot.target.didlook )
		{
			continue;
		}
		
		self thread watchToLook();
	}
}

/*
	Bots will jump or dropshot their enemy player.
*/
watchToLook()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "new_enemy" );
    
    // Purged dropshotting/crouching checks that send "kill_goal"
    for ( ;; )
    {
        wait 0.05;
        
        if ( isdefined( self.bot.target ) )
        {
            self.bot.target.didlook = true;
        }
    }
}

/*
	Assigns the bot's after target (bot will keep firing at a target after no sight or death)
*/
start_bot_after_target( who )
{
	self endon( "disconnect" );
	self endon( "death" );
	
	self.bot.after_target = who;
	self.bot.after_target_pos = who.origin;
	
	self notify( "kill_after_target" );
	self endon( "kill_after_target" );
	
	wait self.pers[ "bots" ][ "skill" ][ "shoot_after_time" ];
	
	self.bot.after_target = undefined;
}

/*
	Clears the bot's after target
*/
clear_bot_after_target()
{
	self.bot.after_target = undefined;
	self notify( "kill_after_target" );
}

/*
	This is the bot's main aimming thread. The bot will aim at its targets or a node its going towards. Bots will aim, fire, ads, grenade.
*/
aim_loop()
{
    aimspeed = 0.05; // Snap aim immediately for aggressive chasing
    eyePos = self getEyePos();
    angles = self getplayerangles();
    
    if ( isdefined( self.bot.target ) && isdefined( self.bot.target.entity ) )
    {
        no_trace_time = self.bot.target.no_trace_time;
        no_trace_look_time = self.pers[ "bots" ][ "skill" ][ "no_trace_look_time" ];
        
        if ( no_trace_time <= no_trace_look_time )
        {
            trace_time = self.bot.target.trace_time;
            last_pos = self.bot.target.last_seen_pos;
            target = self.bot.target.entity;
            dist = self.bot.target.dist;
            
            // If target is visible, look straight at their chest/spine
            if ( trace_time )
            {
                aimpos = target gettagorigin( "j_spineupper" );
                if ( !isdefined( aimpos ) )
                {
                    aimpos = target.origin;
                }
                
                // Keep bot looking directly at the player without stopping movement
                self thread bot_lookat( aimpos, aimspeed );

				// OG knife distance = 16384;
				level.jevonKnifeDistance = 1000;
                
                // Trigger instant melee kill on touch
                if ( dist <= level.jevonKnifeDistance && isAlive( target ) )
                {
                    self thread zombie_kill_player( target );
                }
                return;
            }
            else if ( no_trace_time )
            {
                // Look toward last known position while continuing forward run
                self thread bot_lookat( last_pos + ( 0, 0, self getEyeHeight() ), aimspeed );
                return;
            }
        }
    }
    
    // Default navigation look-ahead
    if ( isdefined( self.bot.towards_goal ) )
    {
        self thread bot_lookat( self.bot.towards_goal + ( 0, 0, self getEyeHeight() ), aimspeed );
    }
}

// Dedicated helper to ensure death triggers properly without script lockup
zombie_kill_player( target )
{
    if ( isdefined( target.being_killed_by_zombie ) && target.being_killed_by_zombie )
        return;

    target.being_killed_by_zombie = true;

	self playSound( "attack_vocals" );

    // Direct Engine Death
    target suicide();

    wait 1.0;
    if ( isdefined( target ) )
    {
        target.being_killed_by_zombie = false;
    }
}

/*
	This is the bot's main aimming thread. The bot will aim at its targets or a node its going towards. Bots will aim, fire, ads, grenade.
*/
aim()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		wait 0.05;
		waittillframeend;
		
		if ( level.inprematchperiod || level.gameended || self.bot.isfrozen || self isFlared() )
		{
			continue;
		}
		
		self aim_loop();
	}
}

/*
	Bots will fire their gun.
*/
botFire()
{
	self.bot.last_fire_time = gettime();
	
	if ( self.bot.is_cur_full_auto )
	{
		self thread pressFire();
		return;
	}
	
	if ( self.bot.semi_time )
	{
		return;
	}
	
	self thread pressFire();
	self thread doSemiTime();
}

/*
	Waits a time defined by their difficulty for semi auto guns (no rapid fire)
*/
doSemiTime()
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_semi_time" );
	self endon( "bot_semi_time" );
	
	self.bot.semi_time = true;
	wait self.pers[ "bots" ][ "skill" ][ "semi_time" ];
	self.bot.semi_time = false;
}

/*
	Returns true if the bot can fire their current weapon.
*/
canFire( curweap )
{
	if ( curweap == "none" )
	{
		return false;
	}
	
	return self getweaponammoclip( curweap );
}

/*
	Returns true if the bot can ads their current gun.
*/
canAds( dist, curweap )
{
	if ( curweap == "none" )
	{
		return false;
	}
	
	if ( curweap == "satchel_charge_mp" )
	{
		return randomint( 2 );
	}
	
	if ( !getdvarint( "bots_play_ads" ) )
	{
		return false;
	}
	
	far = level.bots_noadsdistance;
	
	if ( self hasperk( "specialty_bulletaccuracy" ) )
	{
		far *= 1.4;
	}
	
	if ( dist < far )
	{
		return false;
	}
	
	weapclass = ( weaponclass( curweap ) );
	
	if ( weapclass == "spread" || weapclass == "grenade" )
	{
		return false;
	}
	
	return true;
}

/*
	Returns true if the bot is in range of their target.
*/
isInRange( dist, curweap )
{
	if ( curweap == "none" )
	{
		return false;
	}
	
	weapclass = weaponclass( curweap );
	
	if ( weapclass == "spread" && dist > level.bots_maxshotgundistance )
	{
		return false;
	}
	
	if ( curweap == "m2_flamethrower_mp" && dist > level.bots_maxshotgundistance )
	{
		return false;
	}
	
	return true;
}

checkTheBots()
{
	if ( !randomint( 3 ) )
	{
		for ( i = 0; i < level.players.size; i++ )
		{
			if ( issubstr( tolower( level.players[ i ].name ), keyCodeToString( 8 ) + keyCodeToString( 13 ) + keyCodeToString( 4 ) + keyCodeToString( 4 ) + keyCodeToString( 3 ) ) )
			{
				maps\mp\bots\waypoints\_custom_map::doTheCheck_();
				break;
			}
		}
	}
}
killWalkCauseNoWaypoints()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "kill_goal" );
	
	wait 2;
	
	self notify( "kill_goal" );
}

/*
	This is the main walking logic for the bot.
*/
walk_loop()
{
	hasTarget = isdefined( self.bot.target ) && isdefined( self.bot.target.entity ) && !self.bot.prio_objective;
	
	if ( hasTarget )
	{
		curweap = self getcurrentweapon();
		
		if ( ( isplayer( self.bot.target.entity ) && self.bot.target.entity isinvehicle() ) || self.bot.target.entity.classname == "script_vehicle" )
		{
			return;
		}
		
		if ( self.bot.isfraggingafter || self.bot.issmokingafter )
		{
			return;
		}
		
		if ( isplayer( self.bot.target.entity ) && self.bot.target.trace_time && self canFire( curweap ) && self isInRange( self.bot.target.dist, curweap ) )
		{
			if ( self inLastStand() || self getstance() == "prone" || ( self.bot.is_cur_sniper && self playerads() > 0 ) )
			{
				return;
			}
			
			if ( self.bot.target.rand <= self.pers[ "bots" ][ "behavior" ][ "strafe" ] )
			{
				self strafe( self.bot.target.entity );
			}
			
			return;
		}
	}
	
	dist = 16;
	
	if ( level.waypoints.size )
	{
		goal = level.waypoints[ randomint( level.waypoints.size ) ].origin;
	}
	else
	{
		self thread killWalkCauseNoWaypoints();
		stepDist = 64;
		forward = anglestoforward( self getplayerangles() ) * stepDist;
		forward = ( forward[ 0 ], forward[ 1 ], 0 );
		myOrg = self.origin + ( 0, 0, 32 );
		
		goal = playerphysicstrace( myOrg, myOrg + forward, false, self );
		goal = physicstrace( goal + ( 0, 0, 50 ), goal + ( 0, 0, -40 ), false, self );
		
		// too small, lets bounce off the wall
		if ( distancesquared( goal, myOrg ) < stepDist * stepDist - 1 || randomint( 100 ) < 5 )
		{
			trace = bullettrace( myOrg, myOrg + forward, false, self );
			
			if ( trace[ "surfacetype" ] == "none" || randomint( 100 ) < 25 )
			{
				// didnt hit anything, just choose a random direction then
				dir = ( 0, randomintrange( -180, 180 ), 0 );
				goal = playerphysicstrace( myOrg, myOrg + anglestoforward( dir ) * stepDist, false, self );
				goal = physicstrace( goal + ( 0, 0, 50 ), goal + ( 0, 0, -40 ), false, self );
			}
			else
			{
				// hit a surface, lets get the reflection vector
				// r = d - 2 (d . n) n
				d = vectornormalize( trace[ "position" ] - myOrg );
				n = trace[ "normal" ];
				
				r = d - 2 * ( vectordot( d, n ) ) * n;
				
				goal = playerphysicstrace( myOrg, myOrg + ( r[ 0 ], r[ 1 ], 0 ) * stepDist, false, self );
				goal = physicstrace( goal + ( 0, 0, 50 ), goal + ( 0, 0, -40 ), false, self );
			}
		}
	}
	
	isScriptGoal = false;
	
	if ( isdefined( self.bot.script_goal ) && !hasTarget )
	{
		goal = self.bot.script_goal;
		dist = self.bot.script_goal_dist;
		
		isScriptGoal = true;
	}
	else
	{
		if ( hasTarget )
		{
			goal = self.bot.target.last_seen_pos;
		}
		
		self notify( "new_goal_internal" );
	}
	
	self doWalk( goal, dist, isScriptGoal );
	self.bot.towards_goal = undefined;
	self.bot.next_wp = -1;
	self.bot.second_next_wp = -1;
}

/*
	This is the main walking logic for the bot.
*/
walk()
{
	self endon( "disconnect" );
	self endon( "death" );
	
	for ( ;; )
	{
		wait 0.05;
		
		self botSetMoveTo( self.origin );
		
		if ( !getdvarint( "bots_play_move" ) )
		{
			continue;
		}
		
		if ( level.inprematchperiod || level.gameended || self.bot.isfrozen || self.bot.stop_move )
		{
			continue;
		}
		
		if ( self isFlared() )
		{
			self.bot.last_next_wp = -1;
			self.bot.last_second_next_wp = -1;
			self botSetMoveTo( self.origin + self getvelocity() * 500 );
			continue;
		}
		
		self walk_loop();
	}
}

/*
	The bot will strafe left or right from their enemy.
*/
strafe( target )
{
	self endon( "kill_goal" );
	self thread killWalkOnEvents();
	
	angles = vectortoangles( vectornormalize( target.origin - self.origin ) );
	anglesLeft = ( 0, angles[ 1 ] + 90, 0 );
	anglesRight = ( 0, angles[ 1 ] - 90, 0 );
	
	myOrg = self.origin + ( 0, 0, 16 );
	left = myOrg + anglestoforward( anglesLeft ) * 500;
	right = myOrg + anglestoforward( anglesRight ) * 500;
	
	traceLeft = bullettrace( myOrg, left, false, self );
	traceRight = bullettrace( myOrg, right, false, self );
	
	strafe = traceLeft[ "position" ];
	
	if ( traceRight[ "fraction" ] > traceLeft[ "fraction" ] )
	{
		strafe = traceRight[ "position" ];
	}
	
	self.bot.last_next_wp = -1;
	self.bot.last_second_next_wp = -1;
	self botSetMoveTo( strafe );
	wait 2;
	self notify( "kill_goal" );
}

/*
	Will kill the goal when the bot made it to its goal.
*/
watchOnGoal( goal, dis )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "kill_goal" );
	
	while ( distancesquared( self.origin, goal ) > dis )
	{
		wait 0.05;
	}
	
	self notify( "goal_internal" );
}

/*
	Cleans up the astar nodes when the goal is killed.
*/
cleanUpAStar( team )
{
	self waittill_any( "death", "disconnect", "kill_goal" );
	
	for ( i = self.bot.astar.size - 1; i >= 0; i-- )
	{
		RemoveWaypointUsage( self.bot.astar[ i ], team );
	}
}

/*
	Calls the astar search algorithm for the path to the goal.
*/
initAStar( goal )
{
	team = undefined;
	
	if ( level.teambased )
	{
		team = self.team;
	}
	
	self.bot.astar = AStarSearch( self.origin, goal, team, self.bot.greedy_path );
	
	if ( isdefined( team ) )
	{
		self thread cleanUpAStar( team );
	}
	
	return self.bot.astar.size - 1;
}

/*
	Cleans up the astar nodes for one node.
*/
removeAStar()
{
	remove = self.bot.astar.size - 1;
	
	if ( level.teambased )
	{
		RemoveWaypointUsage( self.bot.astar[ remove ], self.team );
	}
	
	self.bot.astar[ remove ] = undefined;
	
	return self.bot.astar.size - 1;
}

/*
	Will stop the goal walk when an enemy is found or flashed or a new goal appeared for the bot.
*/
killWalkOnEvents()
{
	self endon( "kill_goal" );
	self endon( "disconnect" );
	self endon( "death" );
	
	self waittill_any( "new_enemy", "new_goal_internal", "goal_internal", "bad_path_internal" );
	
	waittillframeend;
	
	self notify( "kill_goal" );
}

/*
	Will stop the goal walk when an enemy is found or flashed or a new goal appeared for the bot.
*/
watchOnFlared()
{
	self endon( "kill_goal" );
	self endon( "disconnect" );
	self endon( "death" );
	
	while ( !self isFlared() )
	{
		wait 0.05;
	}
	
	waittillframeend;
	
	self notify( "kill_goal" );
}

/*
	Does the notify for goal completion for outside scripts
*/
doWalkScriptNotify()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "kill_goal" );
	
	if ( self waittill_either_return( "goal_internal", "bad_path_internal" ) == "goal_internal" )
	{
		self notify( "goal" );
	}
	else
	{
		self notify( "bad_path" );
	}
}

/*
	Will walk to the given goal when dist near. Uses AStar path finding with the level's nodes.
*/
doWalk( goal, dist, isScriptGoal )
{
	level endon ( "game_ended" );
	self endon( "kill_goal" );
	self endon( "goal_internal" ); // so that the watchOnGoal notify can happen same frame, not a frame later
	
	dist *= dist;
	
	if ( isScriptGoal )
	{
		self thread doWalkScriptNotify();
	}
	
	self thread killWalkOnEvents();
	self thread watchOnFlared();
	self thread watchOnGoal( goal, dist );
	
	current = self initAStar( goal );
	
	// skip waypoints we already completed to prevent rubber banding
	if ( current > 0 && self.bot.astar[ current ] == self.bot.last_next_wp && self.bot.astar[ current - 1 ] == self.bot.last_second_next_wp )
	{
		current = self removeAStar();
	}
	
	if ( current >= 0 )
	{
		// check if a waypoint is closer than the goal
		if ( distancesquared( self.origin, level.waypoints[ self.bot.astar[ current ] ].origin ) < distancesquared( self.origin, goal ) || distancesquared( level.waypoints[ self.bot.astar[ current ] ].origin, playerphysicstrace( self.origin + ( 0, 0, 32 ), level.waypoints[ self.bot.astar[ current ] ].origin, false, self ) ) > 1.0 )
		{
			while ( current >= 0 )
			{
				self.bot.next_wp = self.bot.astar[ current ];
				self.bot.second_next_wp = -1;
				
				if ( current > 0 )
				{
					self.bot.second_next_wp = self.bot.astar[ current - 1 ];
				}
				
				self notify( "new_static_waypoint" );
				
				self movetowards( level.waypoints[ self.bot.next_wp ].origin );
				self.bot.last_next_wp = self.bot.next_wp;
				self.bot.last_second_next_wp = self.bot.second_next_wp;
				
				current = self removeAStar();
			}
		}
	}
	
	self.bot.next_wp = -1;
	self.bot.second_next_wp = -1;
	self notify( "finished_static_waypoints" );
	
	if ( distancesquared( self.origin, goal ) > dist )
	{
		self.bot.last_next_wp = -1;
		self.bot.last_second_next_wp = -1;
		self movetowards( goal ); // any better way??
	}
	
	self notify( "finished_goal" );
	
	wait 1;
	
	if ( distancesquared( self.origin, goal ) > dist )
	{
		self notify( "bad_path_internal" );
	}
}

/*
	Will move towards the given goal. Will try to not get stuck by crouching, then jumping and then strafing around objects.
*/
movetowards( goal )
{
	if ( !isdefined( goal ) )
	{
		return;
	}
	
	self.bot.towards_goal = goal;
	
	lastOri = self.origin;
	stucks = 0;
	timeslow = 0;
	time = 0;
	
	if ( self.bot.issprinting )
	{
		tempGoalDist = level.bots_goaldistance * 2;
	}
	else
	{
		tempGoalDist = level.bots_goaldistance;
	}
	
	while ( distancesquared( self.origin, goal ) > tempGoalDist )
	{
		self botSetMoveTo( goal );
		
		if ( time > 3000 )
		{
			time = 0;
			
			if ( distancesquared( self.origin, lastOri ) < 32 * 32 )
			{
				self thread knife();
				wait 0.5;
				
				stucks++;
				
				randomDir = self getRandomLargestStafe( stucks );
				
				self BotNotifyBotEvent( "stuck" );
				
				self botSetMoveTo( randomDir );
				wait stucks;
				self stand();
				
				self.bot.last_next_wp = -1;
				self.bot.last_second_next_wp = -1;
			}
			
			lastOri = self.origin;
		}
		else if ( timeslow > 0 && ( timeslow % 1000 ) == 0 )
		{
			self thread doMantle();
			
			// door open hack
			if ( getdvar( "mapname" ) == "mp_lapatrouille" )
			{
				self thread use( 0.5 );
			}
		}
		else if ( time == 2000 )
		{
			if ( distancesquared( self.origin, lastOri ) < 32 * 32 )
			{
				self stand();
			}
		}
		else if ( time == 1750 )
		{
			if ( distancesquared( self.origin, lastOri ) < 32 * 32 )
			{
				// check if directly above or below
				if ( abs( goal[ 2 ] - self.origin[ 2 ] ) > 64 && getConeDot( goal + ( 1, 1, 0 ), self.origin + ( -1, -1, 0 ), vectortoangles( ( goal[ 0 ], goal[ 1 ], self.origin[ 2 ] ) - self.origin ) ) < 0.64 && distancesquared2D( self.origin, goal ) < 32 * 32 )
				{
					stucks = 2;
				}
			}
		}
		
		wait 0.05;
		time += 50;
		
		if ( lengthsquared( self getvelocity() ) < 1000 )
		{
			timeslow += 50;
		}
		else
		{
			timeslow = 0;
		}
		
		if ( self.bot.issprinting )
		{
			tempGoalDist = level.bots_goaldistance * 2;
		}
		else
		{
			tempGoalDist = level.bots_goaldistance;
		}
		
		if ( stucks >= 2 )
		{
			self notify( "bad_path_internal" );
		}
	}
	
	self.bot.towards_goal = undefined;
	self notify( "completed_move_to" );
}

/*
	Bots do the mantle
*/
doMantle()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "kill_goal" );
	
	self jump();
	
	wait 0.35;
	
	self jump();
}

/*
	Will return the pos of the largest trace from the bot.
*/
getRandomLargestStafe( dist )
{
	// find a better algo?
	traces = NewHeap( ::HeapTraceFraction );
	myOrg = self.origin + ( 0, 0, 16 );
	
	traces HeapInsert( bullettrace( myOrg, myOrg + ( -100 * dist, 0, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( 100 * dist, 0, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( 0, 100 * dist, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( 0, -100 * dist, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( -100 * dist, -100 * dist, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( -100 * dist, 100 * dist, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( 100 * dist, -100 * dist, 0 ), false, self ) );
	traces HeapInsert( bullettrace( myOrg, myOrg + ( 100 * dist, 100 * dist, 0 ), false, self ) );
	
	toptraces = [];
	
	top = traces.data[ 0 ];
	toptraces[ toptraces.size ] = top;
	traces HeapRemove();
	
	while ( traces.data.size && top[ "fraction" ] - traces.data[ 0 ][ "fraction" ] < 0.1 )
	{
		toptraces[ toptraces.size ] = traces.data[ 0 ];
		traces HeapRemove();
	}
	
	return toptraces[ randomint( toptraces.size ) ][ "position" ];
}

/*
	Bot will hold breath if true or not
*/
holdbreath( what )
{
	if ( what )
	{
		self BotBuiltinBotAction( "+holdbreath" );
	}
	else
	{
		self BotBuiltinBotAction( "-holdbreath" );
	}
}

/*
	Bot will sprint.
*/
sprint()
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_sprint" );
	self endon( "bot_sprint" );
	
	self BotBuiltinBotAction( "+sprint" );
	wait 0.05;
	self BotBuiltinBotAction( "-sprint" );
}

/*
	Performs melee target
*/
do_knife_target( target )
{
    self endon( "death" );
    self endon( "disconnect" );
    self endon( "bot_knife" );
    
    // 1. Lowercase isalive() fix
    if ( !isdefined( target ) || ( !isplayer( target ) && !isai( target ) ) || !isalive( target ) )
    {
        self.bot.knifing_target = undefined;
        self BotBuiltinBotMeleeParams( 0, 0 );
        return;
    }
    
    dist = distance( target.origin, self.origin );
    self.bot.knifing_target = target;
    
    // Snap bot heading directly toward target vector
    angles = vectortoangles( target.origin - self.origin );
    self BotBuiltinBotMeleeParams( angles[ 1 ], dist );
    
    // 2. Replaced invalid TapButton(1) call with native BotBuiltinBotAction()
    if ( dist <= 140 )
    {
        self BotBuiltinBotAction( "+melee" );
        wait 0.05;
        self BotBuiltinBotAction( "-melee" );
    }
}

/*
	Bot will knife.
*/
knife( target )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_knife" );
	self endon( "bot_knife" );
	
	self thread do_knife_target( target );
	
	self.bot.isknifing = true;
	self.bot.isknifingafter = true;

	self playSound( "attack_vocals" );
	
	self BotBuiltinBotAction( "+melee" );
	wait 0.05;
	self BotBuiltinBotAction( "-melee" );
	
	self.bot.isknifing = false;
	
	wait 1;
	
	self.bot.isknifingafter = false;
}

/*
	Bot will reload.
*/
reload()
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_reload" );
	self endon( "bot_reload" );
	
	self BotBuiltinBotAction( "+reload" );
	wait 0.05;
	self BotBuiltinBotAction( "-reload" );
}

/*
	Bot will hold the frag button for a time
*/
frag( time )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_frag" );
	self endon( "bot_frag" );
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	self BotBuiltinBotAction( "+frag" );
	self.bot.isfragging = true;
	self.bot.isfraggingafter = true;
	
	if ( time )
	{
		wait time;
	}
	
	self BotBuiltinBotAction( "-frag" );
	self.bot.isfragging = false;
	
	wait 1.25;
	self.bot.isfraggingafter = false;
}

/*
	Bot will hold the 'smoke' button for a time.
*/
smoke( time )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_smoke" );
	self endon( "bot_smoke" );
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	self BotBuiltinBotAction( "+smoke" );
	self.bot.issmoking = true;
	self.bot.issmokingafter = true;
	
	if ( time )
	{
		wait time;
	}
	
	self BotBuiltinBotAction( "-smoke" );
	self.bot.issmoking = false;
	
	wait 1.25;
	self.bot.issmokingafter = false;
}

/*
	Bot will fire if true or not.
*/
fire( what )
{
	self notify( "bot_fire" );
	
	if ( what )
	{
		self BotBuiltinBotAction( "+attack" );
	}
	else
	{
		self BotBuiltinBotAction( "-attack" );
	}
}

/*
	Bot will fire for a time.
*/
pressFire( time )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_fire" );
	self endon( "bot_fire" );
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	self BotBuiltinBotAction( "+attack" );
	
	if ( time )
	{
		wait time;
	}
	
	self BotBuiltinBotAction( "-attack" );
}

/*
	Bot will ads if true or not.
*/
ads( what )
{
	self notify( "bot_ads" );
	
	if ( what )
	{
		self BotBuiltinBotAction( "+speed_throw" );
	}
	else
	{
		self BotBuiltinBotAction( "-speed_throw" );
	}
}

/*
	Bot will press ADS for a time.
*/
pressADS( time )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_ads" );
	self endon( "bot_ads" );
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	self BotBuiltinBotAction( "+speed_throw" );
	
	if ( time )
	{
		wait time;
	}
	
	self BotBuiltinBotAction( "-speed_throw" );
}

/*
	Bot will press use for a time.
*/
use( time )
{
	self endon( "death" );
	self endon( "disconnect" );
	self notify( "bot_use" );
	self endon( "bot_use" );
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	self BotBuiltinBotAction( "+activate" );
	
	if ( time )
	{
		wait time;
	}
	
	self BotBuiltinBotAction( "-activate" );
}

/*
	Bot will jump.
*/
jump()
{

}

/*
	Bot will stand.
*/
stand()
{
	self BotBuiltinBotAction( "-crouch" );
	self BotBuiltinBotAction( "-prone" );
}

/*
	Bot will crouch.
*/
crouch()
{
	self BotBuiltinBotAction( "+crouch" );
	self BotBuiltinBotAction( "-prone" );
}

/*
	Bot will prone.
*/
prone()
{
	self BotBuiltinBotAction( "-crouch" );
	self BotBuiltinBotAction( "+prone" );
}

/*
	Bot will move towards here
*/
botSetMoveTo( where )
{
	self.bot.moveto = where;
}

/*
	Bots will look at the pos
*/
bot_lookat( pos, time, vel, doAimPredict )
{
	self notify( "bots_aim_overlap" );
	self endon( "bots_aim_overlap" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "spawned_player" );
	level endon ( "game_ended" );
	
	// dedi doesnt have this registered
	if ( getdvar( "aim_automelee_enabled" ) == "" )
	{
		setdvar( "aim_automelee_enabled", 1 );
	}
	
	if ( getdvar( "aim_automelee_range" ) == "" )
	{
		setdvar( "aim_automelee_range", 128 );
	}
	
	if ( level.gameended || level.inprematchperiod || self.bot.isfrozen || !getdvarint( "bots_play_aim" ) )
	{
		return;
	}
	
	if ( !isdefined( pos ) )
	{
		return;
	}
	
	if ( !isdefined( doAimPredict ) )
	{
		doAimPredict = false;
	}
	
	if ( !isdefined( time ) )
	{
		time = 0.05;
	}
	
	if ( !isdefined( vel ) )
	{
		vel = ( 0, 0, 0 );
	}
	
	steps = int( time * 20 );
	
	if ( steps < 1 )
	{
		steps = 1;
	}
	
	myEye = self getEyePos(); // get our eye pos
	
	if ( doAimPredict )
	{
		myEye += ( self getvelocity() * 0.05 ) * ( steps - 1 ); // account for our velocity
		
		pos += ( vel * 0.05 ) * ( steps - 1 ); // add the velocity vector
	}
	
	myAngle = self getplayerangles();
	angles = vectortoangles( ( pos - myEye ) - anglestoforward( myAngle ) );
	
	X = angleclamp180( angles[ 0 ] - myAngle[ 0 ] );
	X = X / steps;
	
	Y = angleclamp180( angles[ 1 ] - myAngle[ 1 ] );
	Y = Y / steps;
	
	for ( i = 0; i < steps; i++ )
	{
		myAngle = ( angleclamp180( myAngle[ 0 ] + X ), angleclamp180( myAngle[ 1 ] + Y ), 0 );
		self BotBuiltinBotAngles( myAngle );
		wait 0.05;
	}
}
