--[[ TODO:
	- If a pawn reaches row A or row H -> becomes a queen;
	- If one of kings is defeat -> the game stops;
	- Actions recording;
	- Counter per player.
--]]

realchess = {}

function realchess.init(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local slots = "listcolors[#00000000;#00000000;#00000000;#30434C;#FFF]"
	
	local rows = {
		{'A', 0}, {'B', 1}, {'C', 2}, {'D', 3}, {'E', 4}, {'F', 5}, {'G', 6}, {'H', 7}
	}
	local formspec = ""
	for _, n in pairs(rows) do
		local letter = n[1]
		local number = n[2]
		inv:set_size(letter, 8)
		formspec = formspec.."list[context;"..letter..";0,"..number..";8,1;false]"
	end
	
	meta:set_string("formspec", "size[8,8.6;]bgcolor[#080808BB;true]background[0,0;8,8;chess_bg.png]button[3.2,7.6;2,2;new;New game]"..formspec..slots)
	meta:set_string("infotext", "Chess Board")
	meta:set_string("playerOne", "")
	meta:set_string("playerTwo", "")
	meta:set_string("lastMove", "")
	meta:set_string("lastMoveTime", "")

	inv:set_list('A', {"realchess:rook_black_1 1", "realchess:knight_black_1 1", 
			"realchess:bishop_black_1 1", "realchess:king_black_1 1", 
			"realchess:queen_black_1 1", "realchess:bishop_black_2 1",
			"realchess:knight_black_2 1", "realchess:rook_black_2 1"})
			
	inv:set_list('H', {"realchess:rook_white_1 1", "realchess:knight_white_1 1", 
			"realchess:bishop_white_1 1", "realchess:queen_white_1 1", 
			"realchess:king_white_1 1", "realchess:bishop_white_2 1",
			"realchess:knight_white_2 1", "realchess:rook_white_2 1"})

	inv:set_list("C", {})
	inv:set_list("D", {})
	inv:set_list("E", {})
	inv:set_list("F", {})
	
	local bpawns, wpawns = {}, {}
	for i = 1, 8 do
		bpawns[#bpawns+1] = "realchess:pawn_black_"..i.." 1"
		wpawns[#wpawns+1] = "realchess:pawn_white_"..i.." 1"
		inv:set_list('B', bpawns)
		inv:set_list('G', wpawns)
	end
end

function realchess.move(pos, from_list, from_index, to_list, to_index, count, player)
	local inv = minetest.get_meta(pos):get_inventory()
	local meta = minetest.get_meta(pos)
	local pieceFrom = inv:get_stack(from_list, from_index):get_name()
	local pieceTo = inv:get_stack(to_list, to_index):get_name()
	local playerName = player:get_player_name()
	local lastMove = meta:get_string("lastMove")
	local playerWhite = meta:get_string("playerWhite")
	local playerBlack = meta:get_string("playerBlack")
	
	if pieceFrom:find("white") then
		if playerWhite == "" then
			meta:set_string("playerWhite", playerName)
		elseif playerWhite ~= "" and playerWhite ~= playerName then
			minetest.chat_send_player(playerName, "Someone else plays white pieces.")
			return 0
		end
		if lastMove ~= "white" then
			meta:set_string("lastMove", "white")
			meta:set_string("lastMoveTime", minetest.get_gametime())
		elseif lastMove == "white" then
			minetest.chat_send_player(playerName, "It's not your turn, wait for your opponent to play.")
			return 0
		end
	elseif pieceFrom:find("black") then
		if playerBlack == "" then
			meta:set_string("playerBlack", playerName)
		elseif playerBlack ~= "" and playerBlack ~= playerName then
			minetest.chat_send_player(playerName, "Someone else plays black pieces.")
			return 0
		end
		if lastMove ~= "black"  then
			meta:set_string("lastMove", "black")
			meta:set_string("lastMoveTime", minetest.get_gametime())
		elseif lastMove == "black" then
			minetest.chat_send_player(playerName, "It's not your turn, wait for your opponent to play.")
			return 0
		end
	end

	-- Don't replace pieces of same color
	if (pieceFrom:find("white") and pieceTo:find("white")) or 
		(pieceFrom:find("black") and pieceTo:find("black")) then
		return 0
	end

	-- DETERMINISTIC MOVING
	
	-- PAWNS
	if pieceFrom:find("pawn_white") then
		if from_index == to_index and
			inv:get_stack(string.char(string.byte(from_list)-1), from_index):get_name() == "" then
				if string.byte(to_list) == string.byte(from_list) - 1 then
					return 1
				elseif from_list == 'G' and
					string.byte(to_list) == string.byte(from_list) - 2 then
					return 1
				end
		elseif string.byte(from_list) > string.byte(to_list) and
			(from_index ~= to_index and pieceTo:find("black")) then
			return 1
		end
	elseif pieceFrom:find("pawn_black") then
		if from_index == to_index and
			inv:get_stack(string.char(string.byte(from_list)+1), from_index):get_name() == "" then
				if string.byte(to_list) == string.byte(from_list) + 1 then
					return 1
				elseif from_list == 'B' and
					string.byte(to_list) == string.byte(from_list) + 2 then
					return 1
				end
		elseif string.byte(from_list) < string.byte(to_list) and
			(from_index ~= to_index and pieceTo:find("white")) then
			return 1
		end
	end


	-- ROOKS
	if pieceFrom:find("rook") then
		for i = 1, 7 do
			if from_index == to_index and (string.byte(to_list) == string.byte(from_list) - i or
				string.byte(to_list) == string.byte(from_list) + i) then
				return 1
			elseif string.byte(to_list) == string.byte(from_list) and
				from_index ~= to_index then
				return 1
			end
		end
	end


	-- KNIGHTS
	local knight_dirs = {
		{-2, -1}, {-2, 1}, {2, 1}, {2, -1}, -- Moves type 1
		{-1, 2}, {-1, -2}, {1, -2}, {1, 2} -- Moves type 2
	}

	if pieceFrom:find("knight") then
		for _, d in pairs(knight_dirs) do
			if string.byte(to_list) == string.byte(from_list) + d[1] and
				(to_index == from_index + d[2]) then
				return 1
			end
		end
	end


	-- BISHOPS
	if pieceFrom:find("bishop") then
		for i = 1, 7 do
			if (to_index == from_index + i or to_index == from_index - i) and
				(string.byte(to_list) == string.byte(from_list) - i or
				string.byte(to_list) == string.byte(from_list) + i) then
				return 1
			end
		end
	end


	-- QUEENS
	if pieceFrom:find("queen") then
		for i = 1, 7 do
			if from_index == to_index and (string.byte(to_list) == string.byte(from_list) - i or
				string.byte(to_list) == string.byte(from_list) + i) then
				return 1
			elseif string.byte(to_list) == string.byte(from_list) and
				from_index ~= to_index then
				return 1
			elseif (to_index == from_index + i or to_index == from_index - i) and
				(string.byte(to_list) == string.byte(from_list) - i or
				string.byte(to_list) == string.byte(from_list) + i) then
				return 1
			end
		end
	end


	-- KINGS
	if pieceFrom:find("king") then
		if from_index == to_index and (string.byte(to_list) == string.byte(from_list) - 1 or
			string.byte(to_list) == string.byte(from_list) + 1) then
			return 1
		elseif string.byte(to_list) == string.byte(from_list) and
			from_index ~= to_index then
			return 1
		elseif (to_index == from_index + 1 or to_index == from_index - 1) and
			(string.byte(to_list) == string.byte(from_list) - 1 or
			string.byte(to_list) == string.byte(from_list) + 1) then
			return 1
		end
	end

	return 0
end
	
function realchess.fields(pos, formname, fields, sender)
	local playerName = sender:get_player_name()
	local meta = minetest.get_meta(pos)

	if fields.quit then return end

	-- If someone's playing, nobody except the players can reset the game
	if fields.new and (meta:get_string("playerWhite") == playerName or
			meta:get_string("playerBlack") == playerName) then
		realchess.init(pos)
	elseif fields.new and meta:get_string("lastMoveTime") ~= "" and
			minetest.get_gametime() >= tonumber(meta:get_string("lastMoveTime") + 250) and
			(meta:get_string("playerWhite") ~= playerName or
			meta:get_string("playerBlack") ~= playerName) then
		realchess.init(pos)
	else
		minetest.chat_send_player(playerName, "You can't reset the chessboard, a game has been started.\nIf you weren't playing it, try again after a while.")
	end
end

function realchess.dig(pos, player)
	local meta = minetest.get_meta(pos)
	local playerName = player:get_player_name()

	-- The chess can't be dug while playing unless if nobody has played since 500s
	if (meta:get_string("playerWhite") ~= "" or meta:get_string("playerBlack") ~= "") and
			meta:get_string("lastMoveTime") ~= "" and
			minetest.get_gametime() <= tonumber(meta:get_string("lastMoveTime") + 250) then
		minetest.chat_send_player(playerName, "You can't dug the chessboard, a game has been started.\nIf you weren't playing it, try again after a while.")
		return false
	end
	
	return true
end

minetest.register_node("realchess:chessboard", {
	description = "Chess Board",
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	inventory_image = "chessboard_top.png",
	wield_image = "chessboard_top.png",
	tiles = {"chessboard_top.png", "chessboard_top.png",
		"chessboard_sides.png", "chessboard_sides.png",
		"chessboard_top.png", "chessboard_top.png"},
	groups = {choppy=3, fammable=3},
	sounds = default.node_sound_wood_defaults(),
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}},
	sunlight_propagates = true,
	can_dig = realchess.dig,
	on_construct = realchess.init,
	on_receive_fields = realchess.fields,
	allow_metadata_inventory_move = realchess.move,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local inv = minetest.get_meta(pos):get_inventory()
		inv:set_stack(from_list, from_index, '')
	end
})

local pieces = {
	{name = "pawn", count = 8},
	{name = "rook", count = 2},
	{name = "knight", count = 2},
	{name = "bishop", count = 2},
	{name = "queen", count = 1},
	{name = "king", count = 1}
}
local colors = {"black", "white"}

for _, p in pairs(pieces) do
for _, c in pairs(colors) do
for i = 1, p.count do
	minetest.register_craftitem("realchess:"..p.name.."_"..c.."_"..i, {
		description = c:gsub("^%l", string.upper).." "..p.name:gsub("^%l", string.upper),
		inventory_image = p.name.."_"..c..".png",
		stack_max = 1,
		groups = {not_in_creative_inventory=1}
	})
end
end
end

minetest.register_craft({ 
	output = "realchess:chessboard",
	recipe = {
		{"dye:black", "dye:white", "dye:black"},
		{"stairs:slab_wood", "stairs:slab_wood", "stairs:slab_wood"}
	} 
})

