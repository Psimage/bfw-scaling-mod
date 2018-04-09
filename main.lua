local helper = wesnoth.require "helper"
local wml_actions = wesnoth.wml_actions
local T = wml.tag
local V = wml.variables
local _ = wesnoth.textdomain "wesnoth-help"
local on_event = wesnoth.require "lua/on_event.lua"

function wesnoth.wml_conditionals.is_scalable(cfg)
	return wesnoth.game_config.debug and wesnoth.get_unit(V.x1, V.y1)
end

wml_actions.set_menu_item {
	id = "mi_scale_unit",
	description = "Scale unit",
	T.show_if {
		T.is_scalable {}
	},
	T.command {
		T.scale_unit_action {}
	}
}

local function scale_unit(unit, force)
	force = force or false

	if unit.variables["scaling_mod.is_scaled"] ~= true or force == true then
		-- 2x more hp (lua's proxy unit.max_hitpoints is read_only)
		wml_actions.modify_unit {
			T.filter {id = unit.id},
			hitpoints = unit.max_hitpoints * 2,
			max_hitpoints = unit.max_hitpoints * 2
		}

		-- 2x more number of attacks
		for i, a in ipairs(unit.attacks) do
			a.number = a.number * 2
		end

		-- Scale abilities
		local abilities_cfg = helper.get_child(unit.__cfg, "abilities")

		for i, ability_node in ipairs(abilities_cfg) do
			local tag = ability_node[1]
			local ability = ability_node[2]
			-- Scale any "heals" abiltity by 2x
			if tag == "heals" then
				if ability.value ~= nil then
					ability.value = ability.value * 2
				end
			end
			-- Scale "regenerate" abiltity by 2x
			if tag == "regenerate" then
				if ability.value ~= nil then
					ability.value = ability.value * 2
				end
			end
		end

		wml_actions.modify_unit {
			T.filter {id = unit.id},
			{"abilities", abilities_cfg}
		}
		-- Alternative way of unit modification:
		-- wesnoth.set_variable("wml_unit", unit_cfg)
		-- wml_actions.unstore_unit({variable = "wml_unit"})

		-- Mark as scaled to prevent scaling units again when recalling
		-- or when trasfering to the next scenario
		unit.variables.scaling_mod = {is_scaled = true}
	end
end

function wml_actions.scale_unit_action()
	scale_unit(wesnoth.get_unit(V.x1, V.y1), true)
end

on_event(
	"unit placed",
	function(ctx)
		scale_unit(wesnoth.get_unit(ctx.x1, ctx.y1), false)
	end
)

on_event(
	"pre advance",
	function(ctx)
		local u = wesnoth.get_unit(ctx.x1, ctx.y1)
		pre_advance_max_hitpoints = u.max_hitpoints
	end
)

on_event(
	"post advance",
	function(ctx)
		local u = wesnoth.get_unit(ctx.x1, ctx.y1)
		local mods = helper.get_child(u.__cfg, "modifications")

		-- WARNING: This works for default AMLA
		if helper.child_count(mods, "advancement") == 0 then
			scale_unit(u, true)
		else
			if u.max_hitpoints ~= pre_advance_max_hitpoints then
				wml_actions.modify_unit(
					{
						T.filter {id = u.id},
						hitpoints = u.max_hitpoints + (u.max_hitpoints - pre_advance_max_hitpoints),
						max_hitpoints = u.max_hitpoints + (u.max_hitpoints - pre_advance_max_hitpoints)
					}
				)
			end
		end
	end
)

on_event(
	"prestart",
	function(ctx)
		-- Scale villages healing amount (2x)
		local w, h = wesnoth.get_map_size()
		for x = 1, w do
			for y = 1, h do
				local ti = wesnoth.get_terrain_info(wesnoth.get_terrain(x, y))
				if ti.healing ~= nil and ti.healing > 0 then
					wesnoth.set_terrain(x, y, "^Tst", "overlay")
				end
			end
		end
	end
)

-- Constants are not saves in save files so we need to reapply our changes
on_event(
	"preload",
	function(ctx)
		-- Scale poison amount (2x)
		wesnoth.game_config.poison_amount = wesnoth.game_config.poison_amount * 2
		-- Scale rest heal amount (2x)
		wesnoth.game_config.rest_heal_amount = wesnoth.game_config.rest_heal_amount * 2
	end
)

-- Scale "feeding" ability by 2x
-- Make sure our event called after original "feeding" event handler
-- (give it low priority, default priority is 0)
on_event(
	"die",
	-999,
	function()
		local ec = wesnoth.current.event_context

		if not ec.x1 or not ec.y1 or not ec.x2 or not ec.y2 then
			return
		end

		local u_killer = wesnoth.get_unit(ec.x2, ec.y2)
		local u_victim = wesnoth.get_unit(ec.x1, ec.y1)

		if not u_killer or not u_killer:matches {ability = "feeding"} then
			return
		end
		if not u_victim or u_victim:matches {status = "unplagueable"} then
			return
		end
		local u_killer_cfg = u_killer.__cfg
		for i, v in ipairs(wml.get_child(u_killer_cfg, "modifications")) do
			if v[1] == "object" and v[2].feeding == true then
				local effect = wml.get_child(v[2], "effect")
				-- Don't increase effect total. It will be scaled x2 on advancement
				-- effect.increase_total = effect.increase_total + 1
				u_killer_cfg.max_hitpoints = u_killer_cfg.max_hitpoints + 1
				u_killer_cfg.hitpoints = u_killer_cfg.hitpoints + 1
				wesnoth.create_unit(u_killer_cfg):to_map()
				wesnoth.float_label(ec.x2, ec.y2, _ "+2 max HP", "0,255,0")
				return
			end
		end
	end
)
