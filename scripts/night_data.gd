extends RefCounted
## Per-night configuration plus the little state that survives between nights. A line whose
## voice file does not exist yet is shown as a subtitle only.
##
## objective: what the phone call waits for ("spirit" = photograph spirits, "clue" = find clues).
## Night 2 hides her belongings under the lenses; night 3 is a footprint trail to one last clue.

static var current_night := 1
static var car_transform := Transform3D.IDENTITY
static var car_saved := false

const NIGHTS := {
	1: {
		"title": "NIGHT 1",
		"movement": false,
		"darkness": 0.0,
		"objective": "spirit",
		"objective_label": "SPIRITS",
		"needed": 3,
		"hint": "Hold RMB: raise camera   |   LMB: shoot   |   Q / E: change lens\nSome things are only visible through the lens.",
		"car_drops": true,
		"spirits": [
			{"pos": Vector3(-4.0, 0.0, -3.5), "lens": 0, "name": "Wandering Spirit"},
			{"pos": Vector3(5.5, 0.0, -6.0), "lens": 1, "name": "Moss Maiden"},
			{"pos": Vector3(-9.0, 0.0, 3.0), "lens": 2, "name": "Hollow Whisper"},
			{"pos": Vector3(9.0, 0.0, 8.5), "lens": 1, "name": "Keeper of Pines"},
			{"pos": Vector3(0.0, 0.0, -13.0), "lens": 0, "name": "Lost Lantern"},
		],
		"call": {"voice": "res://audio/call_voice.mp3", "text": "You're done with the ghosts?"},
		"yes": {"voice": "res://audio/call_yes.mp3", "text": "Alright, hop in the car."},
		"no": {"voice": "res://audio/call_no.mp3", "text": "Please don't lie to me."},
		"dream": {"voice": "res://audio/dream_voice.mp3", "text": "Dad, this is my dream."},
	},
	2: {
		"title": "NIGHT 2",
		"movement": true,
		"darkness": 0.75,
		"objective": "clue",
		"objective_label": "CLUES",
		"needed": 4,
		"hint": "Find her things. Each one shows up through a different lens.",
		"ambience": "res://audio/night_ambience.mp3",
		"car_drops": false,
		"spirits": [
			{"pos": Vector3(-14.0, 0.0, -8.0), "lens": 0, "name": "Her Schoolmate"},
			{"pos": Vector3(12.0, 0.0, -10.0), "lens": 1, "name": "The Bus Driver"},
			{"pos": Vector3(-6.0, 0.0, -18.0), "lens": 2, "name": "A Neighbor"},
			{"pos": Vector3(16.0, 0.0, 4.0), "lens": 2, "name": "Her Teacher"},
			{"pos": Vector3(2.0, 0.0, -22.0), "lens": 1, "name": "A Stranger"},
		],
		"clues": [
			{"pos": Vector3(-7.0, 0.0, -4.0), "lens": 0, "shape": "backpack", "name": "Her Backpack",
				"note": "Her school backpack. The zipper is torn, as if someone pulled it."},
			{"pos": Vector3(-15.0, 0.0, -16.0), "lens": 1, "shape": "coat", "name": "Her Red Coat",
				"note": "Her red coat. It was cold that night."},
			{"pos": Vector3(10.0, 0.0, -10.0), "lens": 2, "shape": "notebook", "name": "Her Notebook",
				"note": "Her notebook. The last page says: \"Dad, pick up.\""},
			{"pos": Vector3(16.0, 0.0, 5.0), "lens": 0, "shape": "phone", "name": "Her Phone",
				"note": "Her phone. The last three calls were to you."},
		],
		"call": {"voice": "res://audio/night2_call.mp3", "text": "You found my things, Dad. Do you remember the night I called you?"},
		"yes": {"voice": "res://audio/night2_yes.mp3", "text": "Then you know I asked you to come get me."},
		"no": {"voice": "res://audio/night2_no.mp3", "text": "You were asleep, Dad. I called three times."},
		"dream": {"voice": "res://audio/night2_dream.mp3", "text": "Follow my footprints, Dad."},
	},
	3: {
		"title": "NIGHT 3",
		"movement": true,
		"darkness": 0.9,
		"objective": "clue",
		"objective_label": "DESTINATION",
		"needed": 1,
		"hint": "Follow her footprints. Only one lens can see them.",
		"ambience": "res://audio/night_ambience.mp3",
		"car_drops": false,
		"spirits": [
			{"pos": Vector3(-20.0, 0.0, -14.0), "lens": 2, "name": "Her Friend"},
			{"pos": Vector3(18.0, 0.0, -16.0), "lens": 0, "name": "The Crossing Guard"},
			{"pos": Vector3(-8.0, 0.0, -28.0), "lens": 1, "name": "A Passerby"},
			{"pos": Vector3(22.0, 0.0, 6.0), "lens": 0, "name": "The Night Clerk"},
			{"pos": Vector3(9.0, 0.0, -34.0), "lens": 2, "name": "A Witness"},
		],
		"trail": {
			"lens": 2,
			"points": [
				Vector3(0.0, 0.0, 5.0),
				Vector3(-5.0, 0.0, -6.0),
				Vector3(-3.0, 0.0, -17.0),
				Vector3(6.0, 0.0, -25.0),
				Vector3(3.0, 0.0, -35.0),
				Vector3(-3.0, 0.0, -45.0),
			],
		},
		"clues": [
			{"pos": Vector3(-3.0, 0.0, -47.0), "lens": 2, "shape": "headlights", "name": "The End of the Road",
				"note": "Two headlights in the dark. This is where her footprints stop."},
		],
		"call": {"voice": "res://audio/night3_call.mp3", "text": "You followed me all the way here. Are you ready to know what happened?"},
		"yes": {"voice": "res://audio/night3_yes.mp3", "text": "I got into a car that wasn't yours, Dad."},
		"no": {"voice": "res://audio/night3_no.mp3", "text": "You can't keep running from this, Dad."},
		"dream": {"voice": "res://audio/night3_dream.mp3", "text": "I'm still waiting for you."},
	},
}


static func config() -> Dictionary:
	return NIGHTS[current_night]


static func has_next() -> bool:
	return NIGHTS.has(current_night + 1)
