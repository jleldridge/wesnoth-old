return{
    init = function(ai)
        
        local total_defense = {}

        local H = wesnoth.require "lua/helper.lua"
        local W = H.set_wml_action_metatable {}
        local LS = wesnoth.require "lua/location_set.lua"
        local AH = wesnoth.require "ai/lua/ai_helper.lua"
        local BC = wesnoth.require "ai/lua/battle_calcs.lua" 
        local DBG = wesnoth.require "~/add-ons/Wesnoth_Lua_Pack/debug_utils.lua"

        ----------------------------------------------------
        ---------------Total Defense CAs--------------------
        ----------------------------------------------------

        --------Initialize Total Defense at beginning of turn----------
        
        function total_defense:initialize_total_defense_eval()
            local score = 999990
            return score
        end --of initialize_total_defense_eval

        function total_defense:initialize_total_defense_exec()
            --modify aspects and whatnot here
        end --of initialize_total_defense_exec

        function total_defense:defend_area_eval(cfg)
            cfg = cfg or {}
            
            local all_units = wesnoth.get_units{ side = wesnoth.current.side }
            --DBG.dbms(all_units)
            
            local units_with_mp = wesnoth.get_units{ side = wesnoth.current.side,
                formula = '$this_unit.moves > 0' }
            
            --in this simplified example defenders will be units without healing
            local defenders = {}
            for i,u in ipairs(all_units) do
                if (u.hitpoints/u.max_hitpoints > 0.5) then
                    if (not wesnoth.match_unit(u, {ability="healing"})) and (not wesnoth.match_unit(u, {canrecruit="yes"}))  then
                        table.insert(defenders, u)
                    end
                end
            end
            
            --in this simplified example vulnerable_units will be units with healing or less than 50% hp
            local vulnerable_units = wesnoth.get_units{ side = wesnoth.current.side,
               ability = "healing" }

            for i,u in ipairs(all_units) do
                if (u.hitpoints/u.max_hitpoints <= 0.5) then
                    table.insert(vulnerable_units, u)
                end
            end
            
            --temporary tables to hold the space to be defended
            local outer_radius_table = {}
            local inner_space_table = {}
            for i=0, cfg.radius, 1 do
                for j=0, cfg.radius, 1 do
                    local temp_point_1 = {}
                    local temp_point_2 = {}
                    local temp_point_3 = {}
                    local temp_point_4 = {}
                    temp_point_1.x = cfg.defend_x + i
                    temp_point_1.y = cfg.defend_y + j

                    temp_point_2.x = cfg.defend_x - i
                    temp_point_2.y = cfg.defend_y - j
                    
                    temp_point_3.x = cfg.defend_x + i
                    temp_point_3.y = cfg.defend_y - j
                    
                    temp_point_4.x = cfg.defend_x - i
                    temp_point_4.y = cfg.defend_y + j
                    if (i == cfg.radius) or (j == cfg.radius) then
                        table.insert(outer_radius_table, temp_point_1)
                        table.insert(outer_radius_table, temp_point_2)
                        table.insert(outer_radius_table, temp_point_3)
                        table.insert(outer_radius_table, temp_point_4)
                    else
                        table.insert(inner_space_table, temp_point_1)
                        table.insert(inner_space_table, temp_point_2)
                        table.insert(inner_space_table, temp_point_3)
                        table.insert(inner_space_table, temp_point_4)
                    end
                end
            end
            local outer_radius_map = LS.of_pairs(outer_radius_table)
            local inner_space_map = LS.of_pairs(inner_space_table)
            
            local enemies = wesnoth.get_units {
                { "filter_side", {{"enemy_of", {side = wesnoth.current.side} }} }
            }
            local enemy_attack_map = BC.get_attack_map(enemies)
            
            --if no units can move then exit this ai
            if (not units_with_mp[1]) then
                return 0
            end

            local best_hex
            local best_unit
             
            --move vulnerable units into inner space of defended area
            for i,u in ipairs(vulnerable_units) do
                for j,r in ipairs(wesnoth.find_reach(u)) do
                    if (u.moves > 0) and (not wesnoth.get_unit(r[1], r[2])) and (inner_space_map:get(r[1], r[2])) then
                        best_hex = {r[1], r[2]}
                        best_unit = u
                    end
                end
            end

            --move defenders into outer radius of defended area once vulnerable units are out of the way
            if (not best_hex) or (not best_unit) then
                for i,u in ipairs(defenders) do
                    for j,r in ipairs(wesnoth.find_reach(u)) do
                        if (u.moves > 0) and (not wesnoth.get_unit(r[1], r[2])) and (outer_radius_map:get(r[1], r[2])) then
                            best_hex = {r[1], r[2]}
                            best_unit = u
                            --if the enemy can attack the prospective hex it really needs a unit there to defend
                            if (enemy_attack_map.units:get(r[1], r[2])) then
                                break
                            end
                        end
                    end
                end
            end

            --if outer radius is not complete, don't move units to other places
            local radius_complete = true
            for i,r in ipairs(outer_radius_map) do
                if (not wesnoth.get_unit(r[1], r[2])) then
                    radius_complete = false
                end
            end

            if (not radius_complete) then
                W.modify_ai {
                    side = cfg.side,
                    action = "try_delete",
                    path = "stage[main_loop].candidate_action[goto]"
                }
            end

            if (not best_hex) or (not best_unit) then
                return 0
            end
            
            self.data.unit_to_move = best_unit
            self.data.target_hex = best_hex

            return 999989
        end --of defend_area_eval

        function total_defense:defend_area_exec()
            AH.movefull_outofway_stopunit(ai, self.data.unit_to_move, self.data.target_hex)
            self.data.unit_to_move = nil
            self.data.target_hex = nil
        end --of defend_area_exec

        return total_defense
    end --of init
}
