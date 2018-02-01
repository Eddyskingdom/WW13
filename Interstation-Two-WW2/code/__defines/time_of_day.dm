//#define ALWAYS_DAY
var/time_of_day = "Morning"
var/list/times_of_day = list("Early Morning", "Morning", "Afternoon", "Midday", "Evening", "Night", "Midnight")
// from lightest to darkest: midday, afternoon, morning, early morning, evening, night, midnight
var/list/time_of_day2luminosity = list(
	"Early Morning" = 0.4,
	"Morning" = 0.6,
	"Afternoon" = 0.7,
	"Midday" = 1.0,
	"Evening" = 0.5,
	"Night" = 0.3,
	"Midnight" = 0.2)

var/list/time_of_day2ticks = list(
	"Early Morning" = 20*60,
	"Morning" = 20*60,
	"Afternoon" = 20*60,
	"Midday" = 20*60,
	"Evening" = 20*60,
	"Night" = 25*60,
	"Midnight" = 15*60)

/proc/isDarkOutside()
	if (list("Early Morning", "Evening", "Night", "Midnight").Find(time_of_day))
		return 1
	return 0

/proc/pick_TOD()
	// attempt to fix broken BYOND probability

	// do not shuffle the actual list, we need it to stay in order
	var/list/c_times_of_day = shuffle(times_of_day)
	#ifdef ALWAYS_DAY
	return "Midday"
	#else
	// chance of midday: ~52%. Chance of afternoon: ~27%. Chance of any other: ~21%
	if (prob(50))
		if (prob(75))
			return "Midday"
		else
			return "Afternoon"
	else
		return pick(c_times_of_day)
	#endif

/proc/progress_time_of_day(var/caller = null)

	var/TOD_position_in_list = 1
	for (var/v in 1 to times_of_day.len)
		if (times_of_day[v] == time_of_day)
			TOD_position_in_list = v

	++TOD_position_in_list
	if (TOD_position_in_list > times_of_day.len)
		TOD_position_in_list = 1

	for (var/v in 1 to times_of_day.len)
		if (v == TOD_position_in_list)
			update_lighting(times_of_day[v], admincaller = caller)

/proc/TOD_loop()
	spawn while (1)
		if (TOD_may_automatically_change)
			TOD_may_automatically_change = FALSE
			progress_time_of_day()
		sleep (50)