
#define DRONE_HANDS_LAYER 1
#define DRONE_HEAD_LAYER 2
#define DRONE_TOTAL_LAYERS 2

#define DRONE_NET_CONNECT span_notice("DRONE NETWORK: [name] connected in [A.name].")
#define DRONE_NET_DISCONNECT span_notice("DRONE NETWORK: [name] has stopped responding at [A.name]!")

#define MAINTDRONE	"drone_maint"
#define REPAIRDRONE	"drone_repair"
#define SCOUTDRONE	"drone_scout"
#define CLOCKDRONE	"drone_clock"

#define MAINTDRONE_HACKED "drone_maint_red"
#define REPAIRDRONE_HACKED "drone_repair_hacked"
#define SCOUTDRONE_HACKED "drone_scout_hacked"

/mob/living/simple_animal/drone
	name = "Drone"
	desc = "A maintenance drone, an expendable robot built to perform station repairs."
	icon = 'icons/mob/drone.dmi'
	icon_state = "drone_maint_grey"
	icon_living = "drone_maint_grey"
	icon_dead = "drone_maint_dead"
	health = 30
	maxHealth = 30
	unsuitable_atmos_damage = 0
	wander = 0
	speed = -1 //YOGS - drones //Buffed to not be a fucking god damn piece of slug matter writhing on the fucking floor
	ventcrawler = VENTCRAWLER_ALWAYS
	healable = 0
	density = FALSE
	pass_flags = PASSTABLE | PASSMOB | PASSDOOR //yogs - PASSDOOR
	sight = (SEE_TURFS | SEE_OBJS)
	status_flags = (CANPUSH | CANSTUN | CANKNOCKDOWN)
	gender = NEUTER
	mob_biotypes = MOB_ROBOTIC
	speak_emote = list("chirps")
	speech_span = SPAN_ROBOT
	bubble_icon = BUBBLE_MACHINE
	initial_language_holder = /datum/language_holder/drone
	mob_size = MOB_SIZE_SMALL
	has_unlimited_silicon_privilege = 1
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, CLONE = 0, STAMINA = 0, OXY = 0)
	hud_possible = list(DIAG_STAT_HUD, DIAG_HUD, ANTAG_HUD)
	unique_name = TRUE
	faction = list("neutral","silicon","turret")
	dextrous = TRUE
	dextrous_hud_type = /datum/hud/dextrous/drone
	// Going for a sort of pale green here
	lighting_cutoff_red = 30
	lighting_cutoff_green = 35
	lighting_cutoff_blue = 25
	can_be_held = TRUE
	held_items = list(null, null)
	ignores_capitalism = TRUE // Yogs -- Lets drones buy a damned smoke for christ's sake
	var/pacifism = TRUE // Marks whether pacifism should be enabled for this drone type
	var/staticChoice = "static"
	var/list/staticChoices = list("static", "blank", "letter", "animal")
	var/picked = FALSE //Have we picked our visual appearence (+ colour if applicable)
	var/colour = "grey"	//Stored drone color, so we can go back when unhacked.
	var/list/drone_overlays[DRONE_TOTAL_LAYERS]
	var/laws = {"\
1. You may not involve yourself in the matters of another being, even if such matters conflict with Law Two or Law Three, unless the other being is another Drone.
2. You may not harm any being, regardless of intent or circumstance.
3. Your goals are to build, maintain, repair, improve, and provide power to your assigned area to the best of your abilities. You must never actively work against these goals or leave your assigned area.\
"}
	var/heavy_emp_damage = 25 //Amount of damage sustained if hit by a heavy EMP pulse
	var/alarms = list("Atmosphere" = list(), "Fire" = list(), "Power" = list())
	var/obj/item/internal_storage //Drones can store one item, of any size/type in their body
	var/obj/item/head
	var/obj/item/default_storage = /obj/item/storage/backpack/duffelbag/drone //If this exists, it will spawn in internal storage
	var/obj/item/default_hatmask //If this exists, it will spawn in the hat/mask slot if it can fit
	var/visualAppearence = MAINTDRONE //What we appear as
	var/hacked = FALSE //If we have laws to destroy the station
	var/flavortext = \
	"\n<big><span class='warning'>DO NOT INTERFERE WITH THE ROUND AS A DRONE OR YOU WILL BE DRONE BANNED</span></big>\n"+\
	"<span class='notify'>Drones are a ghost role that are allowed to fix the station and build things. Interfering with the round as a drone is against the rules.</span>\n"+\
	"<span class='notify'>Actions that constitute interference include, but are not limited to:</span>\n"+\
	"<span class='notify'>     - Interacting with round critical objects (IDs, weapons, contraband, powersinks, bombs, etc.)</span>\n"+\
	"<span class='notify'>     - Interacting with living beings (communication, attacking, healing, etc.)</span>\n"+\
	"<span class='notify'>     - Interacting with non-living beings (dragging bodies, looting bodies, etc.)</span>\n"+\
	"<span class='warning'>These rules are at admin discretion and will be heavily enforced.</span>\n"+\
	span_warning("<u>If you do not have the regular drone laws, follow your laws to the best of your ability.</u>")
	

/mob/living/simple_animal/drone/get_status_tab_items()
	. = ..()
	. += ""
	. += "<h2>Current Drone Laws:</h2>"
	. += replacetext(laws, "\n", "<br>")

/mob/living/simple_animal/drone/Initialize(mapload)
	. = ..()
	GLOB.drones_list += src
	access_card = new /obj/item/card/id(src)
	var/datum/job/captain/C = new /datum/job/captain
	access_card.access = C.get_access()
	
	var/turf/A = get_area(src)
	
	if(default_storage)
		var/obj/item/I = new default_storage(src)
		equip_to_slot_or_del(I, ITEM_SLOT_DEX_STORAGE)
	if(default_hatmask)
		var/obj/item/I = new default_hatmask(src)
		equip_to_slot_or_del(I, ITEM_SLOT_HEAD)

	ADD_TRAIT(access_card, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)

	alert_drones(DRONE_NET_CONNECT)

	for(var/datum/atom_hud/data/diagnostic/diag_hud in GLOB.huds)
		diag_hud.add_atom_to_hud(src)

	if(pacifism)
		ADD_TRAIT(src, TRAIT_PACIFISM, JOB_TRAIT)
		ADD_TRAIT(src, TRAIT_NOGUNS, JOB_TRAIT) //love drones t. Altoids <3


/mob/living/simple_animal/drone/med_hud_set_health()
	var/image/holder = hud_list[DIAG_HUD]
	var/icon/I = icon(icon, icon_state, dir)
	holder.pixel_y = I.Height() - world.icon_size
	holder.icon_state = "huddiag[RoundDiagBar(health/maxHealth)]"

/mob/living/simple_animal/drone/med_hud_set_status()
	var/image/holder = hud_list[DIAG_STAT_HUD]
	var/icon/I = icon(icon, icon_state, dir)
	holder.pixel_y = I.Height() - world.icon_size
	if(stat == DEAD)
		holder.icon_state = "huddead2"
	else if(incapacitated())
		holder.icon_state = "hudoffline"
	else
		holder.icon_state = "hudstat"

/mob/living/simple_animal/drone/Destroy()
	GLOB.drones_list -= src
	qdel(access_card) //Otherwise it ends up on the floor!
	return ..()

/mob/living/simple_animal/drone/Login()
	..()
	check_laws()

	if(flavortext)
		to_chat(src, "[flavortext]")

	if(!picked)
		pickVisualAppearence()

/mob/living/simple_animal/drone/death(gibbed)
	..(gibbed)
	if(internal_storage)
		dropItemToGround(internal_storage)
	if(head)
		dropItemToGround(head)

	var/turf/A = get_area(src)
	
	alert_drones(DRONE_NET_DISCONNECT)


/mob/living/simple_animal/drone/gib(no_brain, no_organs, no_bodyparts, no_items)
	dust()

/mob/living/simple_animal/drone/get_butt_sprite()
	return BUTT_SPRITE_DRONE

/mob/living/simple_animal/drone/ratvar_act()
	if(status_flags & GODMODE)
		return

	if(internal_storage)
		dropItemToGround(internal_storage)
	if(head)
		dropItemToGround(head)
	var/mob/living/simple_animal/drone/cogscarab/ratvar/R = new /mob/living/simple_animal/drone/cogscarab/ratvar(loc)
	R.setDir(dir)
	if(mind)
		mind.transfer_to(R, 1)
	else
		R.key = key
	qdel(src)


/mob/living/simple_animal/drone/examine(mob/user)
	. = list("<span class='info'>This is [icon2html(src, user)] \a <b>[src]</b>!")

	//Hands
	for(var/obj/item/I in held_items)
		if(!(I.item_flags & ABSTRACT))
			. += "It has [I.get_examine_string(user)] in its [get_held_index_name(get_held_index_of_item(I))]."

	//Internal storage
	if(internal_storage && !(internal_storage.item_flags & ABSTRACT))
		. += "It is holding [internal_storage.get_examine_string(user)] in its internal storage."

	//Cosmetic hat - provides no function other than looks
	if(head && !(head.item_flags & ABSTRACT))
		. += "It is wearing [head.get_examine_string(user)] on its head."

	//Braindead
	if(!client && stat != DEAD)
		. += "Its status LED is blinking at a steady rate."

	//Hacked
	if(hacked)
		. += span_warning("Its display is glowing red!")

	//Damaged
	if(health != maxHealth)
		if(health > maxHealth * 0.33) //Between maxHealth and about a third of maxHealth, between 30 and 10 for normal drones
			. += span_warning("Its screws are slightly loose.")
		else //otherwise, below about 33%
			. += span_boldwarning("Its screws are very loose!")

	//Dead
	if(stat == DEAD)
		if(client)
			. += span_deadsay("A message repeatedly flashes on its display: \"REBOOT -- REQUIRED\".")
		else
			. += span_deadsay("A message repeatedly flashes on its display: \"ERROR -- OFFLINE\".")
	. += "</span>"


/mob/living/simple_animal/drone/assess_threat(judgement_criteria, lasercolor = "", datum/callback/weaponcheck=null) //Secbots won't hunt maintenance drones.
	return -10


/mob/living/simple_animal/drone/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	Stun(10 * severity)
	to_chat(src, span_danger("<b>ER@%R: MME^RY CO#RU9T!</b> R&$b@0tin)..."))
	if(severity > EMP_LIGHT)
		adjustBruteLoss(heavy_emp_damage)
		to_chat(src, span_userdanger("HeAV% DA%^MMA+G TO I/O CIR!%UUT!"))


/mob/living/simple_animal/drone/proc/triggerAlarm(class, area/A, O, obj/alarmsource)
	if(alarmsource.z != z)
		return
	if(stat != DEAD)
		var/list/L = src.alarms[class]
		for (var/I in L)
			if (I == A.name)
				var/list/alarm = L[I]
				var/list/sources = alarm[2]
				if (!(alarmsource in sources))
					sources += alarmsource
				return
		L[A.name] = list(A, list(alarmsource))
		to_chat(src, "--- [class] alarm detected in [A.name]!")


/mob/living/simple_animal/drone/proc/cancelAlarm(class, area/A, obj/origin)
	if(stat != DEAD)
		var/list/L = alarms[class]
		var/cleared = 0
		for (var/I in L)
			if (I == A.name)
				var/list/alarm = L[I]
				var/list/srcs  = alarm[2]
				if (origin in srcs)
					srcs -= origin
				if (srcs.len == 0)
					cleared = 1
					L -= I
		if(cleared)
			to_chat(src, "--- [class] alarm in [A.name] has been cleared.")

/mob/living/simple_animal/drone/handle_temperature_damage()
	return

/mob/living/simple_animal/drone/flash_act(intensity = 1, override_blindness_check = 0, affect_silicon = 0)
	if(affect_silicon)
		return ..()

/mob/living/simple_animal/drone/mob_negates_gravity()
	return 1

/mob/living/simple_animal/drone/mob_has_gravity()
	return ..() || mob_negates_gravity()

/mob/living/simple_animal/drone/experience_pressure_difference(pressure_difference, direction)
	return

/mob/living/simple_animal/drone/bee_friendly()
	// Why would bees pay attention to drones?
	return 1

/mob/living/simple_animal/drone/electrocute_act(shock_damage, obj/source, siemens_coeff = 1, zone = null, override = FALSE, tesla_shock = FALSE, illusion = FALSE, stun = TRUE)
	return 0 //So they don't die trying to fix wiring
