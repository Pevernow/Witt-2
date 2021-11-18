Witt = {}

local player_to_id_text = {} -- Storage of players so the mod knows what huds to update
local player_to_id_dig = {}
local player_to_id_mtext = {}
local player_to_id_image = {}
local player_to_cnode = {} -- Get the current looked at node
local player_to_animtime = {} -- For animation
local player_to_animon = {} -- For disabling animation
local player_to_enabled = {} -- For disabling WiTT
local player_to_id_bg={} -- background image

local ypos = 0.1

Witt.on_step = function(dtime)
    for _, player in ipairs(minetest:get_connected_players()) do -- Do everything below for each player in-game
        if player_to_enabled[player] == nil then player_to_enabled[player] = true end -- Enable by default
        if not player_to_enabled[player] then return end -- Don't do anything if they have it disabled
        local lookat = Witt.get_looking_node(player) -- Get the node they're looking at

        player_to_animtime[player] = math.min((player_to_animtime[player] or 0.4) + dtime, 0.5) -- Animation calculation

        if player_to_animon[player] then -- If they have animation on, display it
            Witt.update_player_hud_pos(player, player_to_animtime[player])
        end

        if lookat then 
            if player_to_cnode[player] ~= lookat.name then -- Only do anything if they are looking at a different type of block than before
                player_to_animtime[player] = nil -- Reset the animation
                local nodename, mod = Witt.describe_node(lookat) -- Get the details of the block in a nice looking way
                player:hud_change(player_to_id_text[player], "text", nodename) -- If they are looking at something, display that
                
                if Witt.can_dig(lookat,player:get_wielded_item()) == true then
                    player:hud_change(player_to_id_dig[player], "text", "Can dig")
                else
                    player:hud_change(player_to_id_dig[player], "text", "Can not dig")
                end
                player:hud_change(player_to_id_mtext[player], "text", mod)
                
                player:hud_change(player_to_id_bg[player], "text", "witt_bg.png")
                local node_object = minetest.registered_nodes[lookat.name] -- Get information about the block
                player:hud_change(player_to_id_image[player], "text", Witt.handle_tiles(node_object)) -- Pass it to handle_tiles which will return a texture of that block (or nothing if it can't create it)
            end
            player_to_cnode[player] = lookat.name -- Update the current node
        else
            Witt.blank_player_hud(player) -- If they are not looking at anything, do not display the text
            player_to_cnode[player] = nil -- Update the current node
        end

    end
end

minetest.register_globalstep(function(dtime) -- This will run every tick, so around 20 times/second
    Witt.on_step(dtime)
end)

minetest.register_on_joinplayer(function(player) -- Add the hud to all players
    player_to_id_text[player] = player:hud_add({ -- Add the block name text
        hud_elem_type = "text",
        text = "test",
        number = 0xffffff,
        alignment = {x = 1, y = 0},
        position = {x = 0.5, y = ypos-0.025},
    })

    player_to_id_dig[player] = player:hud_add({ -- Add the block name text
        hud_elem_type = "text",
        text = "test",
        number = 0xffffff,
        alignment = {x = 1, y = 0},
        position = {x = 0.5, y = ypos},
    })

    player_to_id_mtext[player] = player:hud_add({ -- Add the mod name text
        hud_elem_type = "text",
        text = "test",
        number = 0x2d62b7,
        alignment = {x = 1, y = 0},
        position = {x = 0.5, y = ypos+0.025},
    })
    player_to_id_image[player] = player:hud_add({ -- Add the block image
        hud_elem_type = "image",
        text = "",
        scale = {x = 0.3, y = 0.3},
        alignment = 0,
        position = {x = 0.45, y = ypos},
    })
    player_to_id_bg[player] = player:hud_add({ -- Add the block image
        hud_elem_type = "image",
        text = "witt_bg.png",
        scale = {x = -20, y = -10},
        alignment = 0,
        position = {x = 0.5, y = ypos},        
        z_index = -400
    })
end)

minetest.register_chatcommand("wanim", { -- Command to turn witt animations on/off
	params = "<on/off>",
	description = "Turn WiTT animations on/off",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
        --player_to_animon[player] = param == "on"
        return true
	end
})

minetest.register_chatcommand("witt", { -- Command to turn witt on/off
	params = "<on/off>",
	description = "Turn WiTT on/off",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false end
        player_to_enabled[player] = param == "on"
        blank_player_hud(player)
        player_to_cnode[player] = nil
        return true
	end
})

Witt.can_dig = function(node,tool)
   local tool_cap = tool.get_tool_capabilities(tool)
   for key,value in pairs(tool_cap.groupcaps) do
       local rate = minetest.get_item_group(node.name, key)
       if rate ~= 0 and value.times[rate] ~= nil then
           return true
       end
   end
  
   -- tool can not dig but hand may dig (For example,digging dirt with pickaxe)
   local tool_cap = tool.get_tool_capabilities(ItemStack(""))
   for key,value in pairs(tool_cap.groupcaps) do
       local rate = minetest.get_item_group(node.name, key)
       if rate ~= 0 and value.times[rate] ~= nil then
           return true
       end
   end
   
   -- node is not registered
   if not minetest.registered_nodes[node.name] then
       return true
   end

   return false
end

Witt.get_looking_node = function (player) -- Return the node the given player is looking at or nil
    local lookat
    local camera_pos = vector.add(player:get_pos(),vector.new(0, 1.5, 0))
    local lookvector = vector.add( -- This add function applies the camera's position to the look vector
                vector.multiply( -- This multiply function adjusts the distance from the camera by the iteration of the loop we're in
                    player:get_look_dir(), 
                    4
                ), 
                camera_pos
            )
    local ray = Raycast(camera_pos,lookvector)
    for pointed_thing in ray do
        if pointed_thing.type=="node" then
            lookat = minetest.get_node_or_nil(pointed_thing.under)
            if lookat ~= nil and lookat.name ~= "air" and lookat.name ~= "walking_light:light" then break else lookat = nil end
        end
    end
    return lookat
end

local function remove_unneeded(str) -- Remove characters like '-' and '_' to make the string look better
    return str:gsub("[_-]", " ")
end

local function capitalize(str) -- Capitalize every word in a string, looks good for node names
    --return str
    return string.gsub(" "..str, "%W%l", string.upper):sub(2)
end

Witt.describe_node = function (node) -- Return a string that describes the node and mod
	if not minetest.registered_nodes[node.name] then -- indexing a nil value will cause a crash, so only continue with the function if the node actually exists in the registered_nodes table
		-- if the node doesn't exist in the registered_nodes table, return the technical name and "Unknown Node" as the mod
		return node.name, "Unknown Node" -- "Unknown Node" isn't really a mod but hopefully that's not a problem
	end
	
    local mod, nodename = minetest.registered_nodes[node.name].mod_origin, minetest.registered_nodes[node.name].description -- Get basic (not pretty) info
    if nodename == "" then -- If it doesn't have a proper name, just use the technical one
        nodename = node.name
    end
    mod = remove_unneeded(capitalize(mod)) -- Make it look good
    nodename = remove_unneeded(nodename)
    
    return nodename, mod
end

Witt.handle_tiles =  function (node) -- Return an image of the tile
	if not node then -- indexing a nil value (with node.tiles) will cause a crash, so only continue with the function if the node actually exists
		return minetest.inventorycube("unknown_node.png", "unknown_node.png", "unknown_node.png") -- if node is nil, return the unknown node texture
	end
	
    local tiles = node.tiles
    local resize_string = ""

    if tiles then -- Make sure every tile is a string
        for i,v in pairs(tiles) do
            if type(v) == "table" then
                if tiles[i].name then
                    tiles[i] = tiles[i].name
                else
                    return ""
                end
            end
        end

        -- These are the types it can draw correctly
        if node.drawtype == "normal" or node.drawtype == "allfaces" or node.drawtype == "allfaces_optional" or node.drawtype == "glasslike" or node.drawtype == "glasslike_framed" or node.drawtype == "glasslike_framed_optional" then
            if #tiles == 1 then -- This type of block has only 1 image, so it must be on all faces
                return minetest.inventorycube(tiles[1], tiles[1], tiles[1]) .. resize_string
            elseif #tiles == 3 then -- This type of block has 3 images, so it's probably 1 on top, 1 on bottom, the rest on the side
                return minetest.inventorycube(tiles[1], tiles[3], tiles[3]) .. resize_string
            elseif #tiles == 6 then -- This one has 6 images, so display the ones we can
                return minetest.inventorycube(tiles[1], tiles[6], tiles[5]) .. resize_string -- Not actually sure if 5 is the correct number but it's basically the same thing most of the time
            end
        end
    end

    return "" -- If it can't do anything, return with a blank image
end

local function update_player_hud_pos(player, to_x, to_y) -- Change position of hud elements
    to_y = to_y or ypos
    player:hud_change(player_to_id_text[player], "position", {x = to_x, y = to_y})
    player:hud_change(player_to_id_image[player], "position", {x = to_x, y = to_y})
    player:hud_change(player_to_id_mtext[player], "position", {x = to_x, y = to_y+0.015})
end

Witt.blank_player_hud = function (player) -- Make hud appear blank
    player:hud_change(player_to_id_text[player], "text", "")
    player:hud_change(player_to_id_mtext[player], "text", "")
    player:hud_change(player_to_id_image[player], "text", "")
    player:hud_change(player_to_id_bg[player], "text", "")
    player:hud_change(player_to_id_dig[player], "text", "")
end
