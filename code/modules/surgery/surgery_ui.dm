/obj/item/organ/external/CanUseTopic(mob/user)
	if(!is_open())
		return STATUS_CLOSE

	if(owner)
		return owner.CanUseTopic(user)

	return ..()


/obj/item/organ/external/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = NANOUI_FOCUS)
	if(is_open())
		try_autodiagnose(user)

	var/list/data = ui_data(user)

	ui = SSnano.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "surgery_organ.tmpl", name, 550, 400)
		ui.set_initial_data(data)
		ui.open()


/obj/item/organ/external/ui_data(mob/user)
	var/list/data = list()

	data["status"] = get_status_data()

	data["max_damage"] = max_damage
	data["brute_dam"] = brute_dam
	data["burn_dam"] = burn_dam

	data["conditions"] = get_conditions()
	data["diagnosed"] = diagnosed

	if(owner && !cannot_amputate)
		data["amputate_step"] = BP_IS_ROBOTIC(src) ? "[/datum/surgery_step/robotic/amputate]" : "[/datum/surgery_step/amputate]"

	data["insert_step"] = BP_IS_ROBOTIC(src) ? "[/datum/surgery_step/insert_item/robotic]" : "[/datum/surgery_step/insert_item]"

	var/list/contents_list = list()

	for(var/obj/item/organ/internal/organ in internal_organs)
		var/list/organ_data = list()

		organ_data["name"] = organ.name
		organ_data["ref"] = "\ref[organ]"
		organ_data["open"] = organ.is_open()

		organ_data["damage"] = organ.damage
		organ_data["max_damage"] = organ.max_damage
		organ_data["status"] = organ.get_status_data()
		organ_data["conditions"] = organ.get_conditions()

		var/list/actions_list = list()

		if(can_remove_item(organ))
			var/list/remove_action = list(
				"name" = "Extract",
				"target" = "\ref[organ]",
				"step" = BP_IS_ROBOTIC(src) ? "[/datum/surgery_step/robotic/remove_item]" : "[/datum/surgery_step/remove_item]"
			)

			actions_list.Add(list(remove_action))

		var/list/connect_action

		if(BP_IS_ROBOTIC(src))
			connect_action = list(
				"name" = (organ.status & ORGAN_CUT_AWAY) ? "Connect" : "Disconnect",
				"organ" = "\ref[organ]",
				"step" = "[/datum/surgery_step/robotic/connect_organ]"
			)
		else
			connect_action = list(
				"name" = (organ.status & ORGAN_CUT_AWAY) ? "Attach" : "Separate",
				"organ" = "\ref[organ]",
				"step" = (organ.status & ORGAN_CUT_AWAY) ? "[/datum/surgery_step/attach_organ]" : "[/datum/surgery_step/detach_organ]"
			)


		actions_list.Add(list(connect_action))
		organ_data["actions"] = actions_list

		contents_list.Add(list(organ_data))

	for(var/i in implants)
		var/atom/movable/implant = i
		if(QDELETED(implant))
			implants -= implant
			continue

		var/list/implant_data = list()

		implant_data["name"] = implant.name
		implant_data["ref"] = "\ref[implant]"
		implant_data["open"] = TRUE

		var/list/actions_list = list()

		if(can_remove_item(implant))
			var/list/remove_action = list(
				"name" = "Extract",
				"target" = "\ref[implant]",
				"step" = BP_IS_ROBOTIC(src) ? "[/datum/surgery_step/robotic/remove_item]" : "[/datum/surgery_step/remove_item]"
			)

			actions_list.Add(list(remove_action))

		implant_data["actions"] = actions_list

		contents_list.Add(list(implant_data))

	data["contents"] = contents_list
	return data


/obj/item/organ/external/Topic(href, href_list)
	if(..())
		return

	switch(href_list["command"])
		if("diagnose")
			if(diagnosed || try_autodiagnose(usr))
				return TRUE

			if(istype(usr, /mob/living))
				var/mob/living/user = usr
				var/target_stat = BP_IS_ROBOTIC(src) ? STAT_MEC : STAT_BIO
				var/diag_time = 70 * usr.stats.getMult(target_stat, STAT_LEVEL_EXPERT)
				var/target = get_surgery_target()

				to_chat(user, SPAN_NOTICE("You start examining [get_surgery_name()] for issues."))

				var/wait
				if(ismob(target))
					wait = do_mob(user, target, diag_time)
				else
					wait = do_after(user, diag_time, target, needhand = FALSE)

				if(wait)
					if(prob(100 - FAILCHANCE_VERY_EASY + usr.stats.getStat(target_stat)))
						diagnosed = TRUE
					else
						to_chat(user, SPAN_WARNING("You failed to diagnose [get_surgery_name()]!"))

			return TRUE

		if("step")
			var/step_path = text2path(href_list["step"])
			if(ispath(step_path, /datum/surgery_step))
				var/obj/item/organ/target_organ = locate(href_list["organ"])

				if(!target_organ)
					target_organ = src

				target_organ.try_surgery_step(step_path, usr, target = locate(href_list["target"]))

			return TRUE