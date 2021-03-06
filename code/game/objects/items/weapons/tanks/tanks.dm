#define TANK_MAX_RELEASE_PRESSURE (3*ONE_ATMOSPHERE)
#define TANK_DEFAULT_RELEASE_PRESSURE 24
#define TANK_IDEAL_PRESSURE 1015 //Arbitrary.

var/list/global/tank_gauge_cache = list()

/obj/item/weapon/tank
	name = "tank"
	icon = 'icons/obj/tank.dmi'

	var/gauge_icon = "indicator_tank"
	var/last_gauge_pressure
	var/gauge_cap = 6

	flags = CONDUCT
	slot_flags = SLOT_BACK
	w_class = 3

	force = WEAPON_FORCE_NORMAL
	throwforce = 10.0
	throw_speed = TRUE
	throw_range = 4

	var/datum/gas_mixture/air_contents = null
	var/distribute_pressure = ONE_ATMOSPHERE
	var/integrity = 3
	var/volume = 70
	var/manipulated_by = null		//Used by _onclick/hud/screen_objects.dm internals to determine if someone has messed with our tank or not.
						//If they have and we haven't scanned it with the PDA or gas analyzer then we might just breath whatever they put in it.
	var/my_tank_fragment_pressure = TANK_FRAGMENT_PRESSURE

/obj/item/weapon/tank/New()
	..()

	air_contents = new /datum/gas_mixture()
	air_contents.volume = volume //liters
	air_contents.temperature = T20C
	processing_objects.Add(src)
	update_gauge()
	return

/obj/item/weapon/tank/Destroy()
	if (air_contents)
		qdel(air_contents)

	processing_objects.Remove(src)
/*
	if (istype(loc, /obj/item/transfer_valve))
		var/obj/item/transfer_valve/TTV = loc
		TTV.remove_tank(src)*/

	..()

/obj/item/weapon/tank/examine(mob/user)
	. = ..(user, FALSE)
	if (.)
		var/celsius_temperature = air_contents.temperature - T0C
		var/descriptive
		switch(celsius_temperature)
			if (300 to INFINITY)
				descriptive = "furiously hot"
			if (100 to 300)
				descriptive = "hot"
			if (80 to 100)
				descriptive = "warm"
			if (40 to 80)
				descriptive = "lukewarm"
			if (20 to 40)
				descriptive = "room temperature"
			else
				descriptive = "cold"
		user << "<span class='notice'>\The [src] feels [descriptive].</span>"

/obj/item/weapon/tank/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	/*
	if (istype(loc, /obj/item/assembly))
		icon = loc*/

/*	if ((istype(W, /obj/item/analyzer)) && get_dist(user, src) <= 1)
		var/obj/item/analyzer/A = W
		A.analyze_gases(src, user)*/
//	if (istype(W, /obj/item/assembly_holder))
	//	bomb_assemble(W,user)

/obj/item/weapon/tank/attack_self(mob/user as mob)
	if (!(air_contents))
		return

	ui_interact(user)

/obj/item/weapon/tank/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/mob/living/carbon/location = null

	if (istype(loc, /mob/living/carbon))
		location = loc

	var/using_internal
	if (istype(location))
		if (location.internal==src)
			using_internal = TRUE

	// this is the data which will be sent to the ui
	var/data[0]
	data["tankPressure"] = round(air_contents.return_pressure() ? air_contents.return_pressure() : FALSE)
	data["releasePressure"] = round(distribute_pressure ? distribute_pressure : FALSE)
	data["defaultReleasePressure"] = round(TANK_DEFAULT_RELEASE_PRESSURE)
	data["maxReleasePressure"] = round(TANK_MAX_RELEASE_PRESSURE)
	data["valveOpen"] = using_internal ? TRUE : FALSE

	data["maskConnected"] = FALSE

	if (istype(location))
		var/mask_check = FALSE

		if (location.internal == src)	// if tank is current internal
			mask_check = TRUE
		else if (src in location)		// or if tank is in the mobs possession
			if (!location.internal)		// and they do not have any active internals
				mask_check = TRUE
		if (mask_check)
			if (location.wear_mask && (location.wear_mask.item_flags & AIRTIGHT))
				data["maskConnected"] = TRUE
			else if (istype(location, /mob/living/carbon/human))
				var/mob/living/carbon/human/H = location
				if (H.head && (H.head.item_flags & AIRTIGHT))
					data["maskConnected"] = TRUE

	// update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// the ui does not exist, so we'll create a new() one
        // for a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, "tanks.tmpl", "Tank", 500, 300)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()
		// auto update every Master Controller tick
		ui.set_auto_update(1)

/obj/item/weapon/tank/Topic(href, href_list)
	..()
	if (usr.stat|| usr.restrained())
		return FALSE
	if (loc != usr)
		return FALSE

	if (href_list["dist_p"])
		if (href_list["dist_p"] == "reset")
			distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE
		else if (href_list["dist_p"] == "max")
			distribute_pressure = TANK_MAX_RELEASE_PRESSURE
		else
			var/cp = text2num(href_list["dist_p"])
			distribute_pressure += cp
		distribute_pressure = min(max(round(distribute_pressure), FALSE), TANK_MAX_RELEASE_PRESSURE)
	if (href_list["stat"])
		if (istype(loc,/mob/living/carbon))
			var/mob/living/carbon/location = loc
			if (location.internal == src)
				location.internal = null
//				location.internals.icon_state = "internal0"
				if (location.HUDneed.Find("internal"))
					var/obj/screen/HUDelm = location.HUDneed["internal"]
					HUDelm.icon_state = "internal0"
				usr << "<span class='notice'>You close the tank release valve.</span>"
/*				if (location.internals)
					location.internals.icon_state = "internal0"*/
			else

				var/can_open_valve
				if (location.wear_mask && (location.wear_mask.item_flags & AIRTIGHT))
					can_open_valve = TRUE
				else if (istype(location,/mob/living/carbon/human))
					var/mob/living/carbon/human/H = location
					if (H.head && (H.head.item_flags & AIRTIGHT))
						can_open_valve = TRUE

				if (can_open_valve)
					location.internal = src
					usr << "<span class='notice'>You open \the [src] valve.</span>"
					playsound(usr, 'sound/effects/Custom_internals.ogg', 100, FALSE)
/*					if (location.internals)
						location.internals.icon_state = "internal1"*/
					if (location.HUDneed.Find("internal"))
						var/obj/screen/HUDelm = location.HUDneed["internal"]
						HUDelm.icon_state = "internal1"
				else
					usr << "<span class='warning'>You need something to connect to \the [src].</span>"

	add_fingerprint(usr)
	return TRUE


/obj/item/weapon/tank/remove_air(amount)
	return air_contents.remove(amount)

/obj/item/weapon/tank/return_air()
	return air_contents

/obj/item/weapon/tank/assume_air(datum/gas_mixture/giver)
	air_contents.merge(giver)

	check_status()
	return TRUE

/obj/item/weapon/tank/proc/remove_air_volume(volume_to_return)
	if (!air_contents)
		return null

	var/tank_pressure = air_contents.return_pressure()
	if (tank_pressure < distribute_pressure)
		distribute_pressure = tank_pressure

	var/moles_needed = distribute_pressure*volume_to_return/(R_IDEAL_GAS_EQUATION*air_contents.temperature)

	return remove_air(moles_needed)

/obj/item/weapon/tank/process()
	//Allow for reactions
	air_contents.react() //cooking up air tanks - add plasma and oxygen, then heat above PLASMA_MINIMUM_BURN_TEMPERATURE
	if (gauge_icon)
		update_gauge()
	check_status()

/obj/item/weapon/tank/proc/update_gauge()
	var/gauge_pressure = FALSE
	if (air_contents)
		gauge_pressure = air_contents.return_pressure()
		if (gauge_pressure > TANK_IDEAL_PRESSURE)
			gauge_pressure = -1
		else
			gauge_pressure = round((gauge_pressure/TANK_IDEAL_PRESSURE)*gauge_cap)

	if (gauge_pressure == last_gauge_pressure)
		return

	last_gauge_pressure = gauge_pressure
	overlays.Cut()
	var/indicator = "[gauge_icon][(gauge_pressure == -1) ? "overload" : gauge_pressure]"
	if (!tank_gauge_cache[indicator])
		tank_gauge_cache[indicator] = image(icon, indicator)
	overlays += tank_gauge_cache[indicator]

/obj/item/weapon/tank/proc/check_status()
	//Handle exploding, leaking, and rupturing of the tank

	if (!air_contents)
		return FALSE

	var/pressure = air_contents.return_pressure()
	if (pressure > my_tank_fragment_pressure)
	/*	if (!istype(loc,/obj/item/transfer_valve))
			message_admins("Explosive tank rupture! last key to touch the tank was [fingerprintslast].")
			log_game("Explosive tank rupture! last key to touch the tank was [fingerprintslast].")*/

		//Give the gas a chance to build up more pressure through reacting
		air_contents.react()
		air_contents.react()
		air_contents.react()

		pressure = air_contents.return_pressure()
		var/range = (pressure-my_tank_fragment_pressure)/TANK_FRAGMENT_SCALE

		explosion(
			get_turf(loc),
			round(min(BOMBCAP_DVSTN_RADIUS, range*0.25)),
			round(min(BOMBCAP_HEAVY_RADIUS, range*0.50)),
			round(min(BOMBCAP_LIGHT_RADIUS, range*1.00)),
			round(min(BOMBCAP_FLASH_RADIUS, range*1.50)),
			)
		qdel(src)

	else if (pressure > TANK_RUPTURE_PRESSURE)
		#ifdef FIREDBG
		log_debug("<span class='warning'>[x],[y] tank is rupturing: [pressure] kPa, integrity [integrity]</span>")
		#endif

		if (integrity <= 0)
			var/turf/T = get_turf(src)
			if (!T)
				return
			T.assume_air(air_contents)
			playsound(loc, 'sound/effects/spray.ogg', 10, TRUE, -3)
			qdel(src)
		else
			integrity--

	else if (pressure > TANK_LEAK_PRESSURE)
		#ifdef FIREDBG
		log_debug("<span class='warning'>[x],[y] tank is leaking: [pressure] kPa, integrity [integrity]</span>")
		#endif

		if (integrity <= 0)
			var/turf/T = get_turf(src)
			if (!T)
				return
			var/datum/gas_mixture/leaked_gas = air_contents.remove_ratio(0.25)
			T.assume_air(leaked_gas)
		else
			integrity--

	else if (integrity < 3)
		integrity++
