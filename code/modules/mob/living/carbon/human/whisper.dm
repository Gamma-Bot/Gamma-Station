//Lallander was here
/mob/living/carbon/human/whisper(message as text)
	var/alt_name = ""

	if(say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, "\red Speech is currently admin-disabled.")
		return

	log_whisper("[src.name]/[src.key] : [message]")

	if(src.client)
		if (src.client.prefs.muted & MUTE_IC)
			to_chat(src, "\red You cannot whisper (muted).")
			return

		if (src.client.handle_spam_prevention(message,MUTE_IC))
			return

	if(!speech_allowed && usr == src)
		to_chat(usr, "\red You can't speak.")
		return

	if (src.stat == DEAD)
		if(fake_death) //Our changeling with fake_death status must not speak in dead chat!!
			return
		return src.say_dead(message)

	if(src.stat)
		return

	message = sanitize(message)	//made consistent with say

	if(name != GetVoice())
		alt_name = "(as [get_id_name("Unknown")])"

	//parse the language code and consume it
	var/datum/language/speaking = parse_language(message)
	if(speaking)
		message = copytext(message,2+length(speaking.key))

	whisper_say(message, speaking, alt_name)


//This is used by both the whisper verb and human/say() to handle whispering
/mob/living/carbon/human/proc/whisper_say(var/message, var/datum/language/speaking = null, var/alt_name="", var/verb="whispers")
	var/message_range = 1
	var/eavesdropping_range = 2
	var/watching_range = 5
	var/italics = 1

	if (speaking)
		verb = speaking.speech_verb + pick(" quietly", " softly")

	message = capitalize(trim(message))

	//TODO: handle_speech_problems for silent
	if(!message || silent || miming)
		return

	// Mute disability
	//TODO: handle_speech_problems
	if(src.sdisabilities & MUTE)
		return

	//TODO: handle_speech_problems
	if(istype(src.wear_mask, /obj/item/clothing/mask/muzzle))
		return

	if(src.species.name == ABDUCTOR)
		return

	//TODO: handle_speech_problems
	if(src.stuttering)
		message = stutter(message)

	var/list/listening = hearers(message_range, src)
	listening |= src

	//ghosts
	for(var/mob/M in dead_mob_list)	//does this include players who joined as observers as well?
		if (!(M.client))
			continue
		if(M.stat == DEAD && M.client && (M.client.prefs.chat_toggles & CHAT_GHOSTEARS))
			listening |= M

	//Pass whispers on to anything inside the immediate listeners.
	for(var/mob/L in listening)
		for(var/mob/C in L.contents)
			if(istype(C,/mob/living))
				listening += C

	//pass on the message to objects that can hear us.
	for(var/obj/O in view(message_range, src))
		spawn (0)
			if (O)
				O.hear_talk(src, message, verb, speaking)

	var/list/eavesdropping = hearers(eavesdropping_range, src)
	eavesdropping -= src
	eavesdropping -= listening

	var/list/watching  = hearers(watching_range, src)
	watching  -= src
	watching  -= listening
	watching  -= eavesdropping

	//now mobs
	//speech bubble
	var/list/speech_bubble_recipients = list()
	for(var/mob/M in listening)	//TODO Refactor speech pls, it's disgusting
		if(M.client)
			speech_bubble_recipients.Add(M.client)
	for(var/mob/M in eavesdropping)
		if(M.client)
			speech_bubble_recipients.Add(M.client)
	var/speech_bubble_test = say_test(message)
	var/image/I = image('icons/mob/talk.dmi', src, "h[speech_bubble_test]", MOB_LAYER+1)
	I.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	spawn(0)
		flick_overlay(I, speech_bubble_recipients, 30)

	for(var/mob/M in listening)
		M.hear_say(message, verb, speaking, alt_name, italics, src)

	if(eavesdropping.len)
		var/new_message = stars(message)	//hopefully passing the message twice through stars() won't hurt... I guess if you already don't understand the language, when they speak it too quietly to hear normally you would be able to catch even less.
		for(var/mob/M in eavesdropping)
			M.hear_say(new_message, verb, speaking, alt_name, italics, src)

	if(watching.len)
		var/rendered = "<span class='game say'><span class='name'>[src.name]</span> whispers something.</span>"
		for (var/mob/M in watching)
			M.show_message(rendered, 2)
