--Global variables
MinimapCenterX = 50 --Minimap center X position
MinimapCenterY = 50 --Minimap center Y position
MinimapRadius = 8 --Minimap box radius, in terms of its units
MinimapUnitSize = 5 --Size, in pixels, of the minimap square units (must be an odd number)
DimX = 256 --Screen X dimension
DimY = 224 --Screen Y dimension

--Reading from memory the Highway Stage tile information
local stageL = 32 --Lines = 2 scenes * 16 tiles = 32 lines of tiles
local stageC = 512 --Columns = 32 scenes * 16 tiles = 512 columns of tiles

local stageS = {01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16,
		  		17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 29, 30,
		  		00, 00, 00, 00, 00, 00, 00, 00, 00, 31, 32, 33, 34, 35, 00, 00,
		  		00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00}

--Initializing matrix with the stage tiles
StageTiles = {}
for i=1,stageL do
	StageTiles[i] = {}
	for j=1,stageC do
		StageTiles[i][j] = 0
	end
end

--Tiles that are solid (hexa):
function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return 1
        end
    end

    return 0
end

--Values that are solid, in decimal
solid = {68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 83, 84, 89, 90, 95, 96, 98, 99, 149, 150, 185, 189, 190, 193, 194, 198, 328, 329, 330, 335, 336, 337, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 360, 361, 362, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 381, 382, 383, 384, 385, 386, 400, 401, 404, 405, 406, 407, 412, 413, 414, 415, 419, 420, 421, 422, 423, 561, 562, 743, 744, 745, 748, 749, 750, 751, 752, 754, 755, 756, 757, 758, 759, 761, 762, 763, 764, 765, 766, 781, 783, 785, 786, 788, 790, 792, 793, 794, 795, 796, 797, 798, 799, 825}

--Reading tiles info from memory
for s=1,#stageS do
	local iStep = 16 * math.floor((s - 1)/32)
	local iL = 1 + iStep
	local iU = 16 + iStep
	for i=iL,iU do
		local jStep = 16 * ((s - 1) % 32)
		local jL = 1 + jStep
		local jU = 16 + jStep
		for j=jL,jU do
			local pos = ((i - iStep) - 1) * 16 + (j - jStep)
			StageTiles[i][j] = has_value(solid, memory.read_s16_le(0x2000 + stageS[s] * 512 + (pos - 1) * 2))
		end
	end
end

--Draw objects onto the minimap
function drawObjects(object, color)
	gui.drawBox(
		MinimapCenterX + MinimapUnitSize * object.x - math.floor(MinimapUnitSize / 2),
		MinimapCenterY + MinimapUnitSize * object.y - math.floor(MinimapUnitSize / 2),
		MinimapCenterX + MinimapUnitSize * object.x + math.floor(MinimapUnitSize / 2),
		MinimapCenterY + MinimapUnitSize * object.y + math.floor(MinimapUnitSize / 2),
		color,
		color
	)
end

--Retrieve the top-left X,Y positions of all rendered enemies sprites
function getEnemies()
	local enemies = {}

	for slot=0,14 do
		--Status is used to determine if the object is currently rendered
		local status = memory.readbyte(0x0E68 + slot * 64)
		if status ~= 0 then
			local enemiesX = memory.read_s16_le(0x0E68 + slot * 64 + 5)
			local enemiesY = memory.read_s16_le(0x0E68 + slot * 64 + 8)
			enemies[#enemies+1] = {["x"] = enemiesX, ["y"] = enemiesY}
		end
	end

	return enemies
end

--Retrieve the top-left X,Y positions of all rendered enemies' bullets sprites
function getBullets()
	local bullets = {}

	for slot=0,7 do
		--Status is used to determine if the object is currently rendered
		local status = memory.readbyte(0x1428 + slot * 64)
		if status ~= 0 then
			local bulletsX = memory.read_s16_le(0x1428 + slot * 64 + 5)
			local bulletsY = memory.read_s16_le(0x1428 + slot * 64 + 8)
			bullets[#bullets+1] = {["x"] = bulletsX, ["y"] = bulletsY}
		end
	end

	return bullets
end

--Retrieve the top-left X,Y positions of all rendered items sprites
function getItems()
	local items = {}

	for slot=0,15 do
		--Status is used to determine if the object is currently rendered
		local status = memory.readbyte(0x1628 + slot * 48)
		if status ~= 0 then
			local itemsX = memory.read_s16_le(0x1628 + slot * 48 + 5)
			local itemsY = memory.read_s16_le(0x1628 + slot * 48 + 8)
			items[#items+1] = {["x"] = itemsX, ["y"] = itemsY}
		end
	end

	return items
end

--Maps true screen positions of objects to the minimap coordinate system
function getPosMap(objX, objY, screenCenterX, screenCenterY)
	local pos = {}

	pos.x = math.floor((MinimapRadius * 2) * (objX - screenCenterX) / DimX)
	pos.y = math.floor((MinimapRadius * 2 - 2) * (objY - screenCenterY) / DimY)

	if pos.x < -MinimapRadius		then pos.x = 100 end
	if pos.x > MinimapRadius		then pos.x = 100 end
	if pos.y < (-MinimapRadius + 1)	then pos.y = 100 end
	if pos.y > (MinimapRadius - 2)	then pos.y = 100 end

	return pos
end

--TODO
function getTiles(screenX, screenY)
	local xL = math.ceil((screenX + 1) / 16)
	local xU = xL + 15
	local yL = math.ceil((screenY - 256 + 1) / 16)
	local yU = yL + 13

	return {xL, xU, yL, yU}
end

function getInputs()
	--Screen top-left X,Y positions
	local screenX = memory.read_s16_le(0x00B4)
	local screenY = memory.read_s16_le(0x00B6)

	--Screen center X,Y positions
	local screenCenterX = math.floor(screenX + DimX / 2)
	local screenCenterY = math.floor(screenY + DimY / 2)

	--Origin of the minimap
	local minimapOriginX = MinimapCenterX - MinimapUnitSize * (MinimapRadius - 1) - math.ceil(MinimapUnitSize / 2)
	local minimapOriginY = MinimapCenterY - MinimapUnitSize * (MinimapRadius - 1) - math.ceil(MinimapUnitSize / 2)

	--Draws the minimap itself
	gui.drawBox(
		minimapOriginX,
		minimapOriginY,
		MinimapCenterX + MinimapUnitSize * MinimapRadius + math.ceil(MinimapUnitSize / 2),
		MinimapCenterY + MinimapUnitSize * (MinimapRadius - 2) + math.ceil(MinimapUnitSize / 2),
		0xFF000000,
		0x80808080
	)

	--Draws solid tiles on the minimap (white)
	local tiles = getTiles(screenX, screenY)
	for i=tiles[3],tiles[4] do
		for j=tiles[1],tiles[2] do
			if StageTiles[i][j] == 1 then --If tile is solid, then draw
				gui.drawBox(
					minimapOriginX + MinimapUnitSize * (j - tiles[1]) + 1,
					minimapOriginY + MinimapUnitSize * (i - tiles[3]) + 1,
					minimapOriginX + MinimapUnitSize * (j - tiles[1]) + MinimapUnitSize,
					minimapOriginY + MinimapUnitSize * (i - tiles[3]) + MinimapUnitSize,
					0xFFFFFFFF,
					0xFFFFFFFF
				)
			end
		end
	end

	--Draws enemies on the minimap (black)
	local enemies = getEnemies()
	local posEnemies = {}
	for i=1,#enemies do
		posEnemies[i] = getPosMap(enemies[i]["x"], enemies[i]["y"], screenCenterX, screenCenterY)
		if posEnemies[i].x ~= 100 and posEnemies[i].y ~= 100 then
			drawObjects(posEnemies[i], 0xFF000000)
		end
	end

	--Draws enemies' bullets on the minimap (blue)
	local bullets = getBullets()
	local posBullets = {}
	for i=1,#bullets do
		posBullets[i] = getPosMap(bullets[i]["x"], bullets[i]["y"], screenCenterX, screenCenterY)
		if posBullets[i].x ~= 100 and posBullets[i].y ~= 100 then
			drawObjects(posBullets[i], 0xFF0000FF)
		end
	end

	--Draws items on the minimap (magenta)
	local items = getItems()
	local posItems = {}
	for i=1,#items do
		posItems[i] = getPosMap(items[i]["x"], items[i]["y"], screenCenterX, screenCenterY)
		if posItems[i].x ~= 100 and posItems[i].y ~= 100 then
			drawObjects(posItems[i], 0xFFFF00FF)
		end
	end

	--Draws Megaman on the minimap (red)
	local megaX = memory.read_s16_le(0x0BAD) + 15 -- +15 corrects Megaman's sprite X position to the center
	local megaY = memory.read_s16_le(0x0BB0)
	local posMega = getPosMap(megaX, megaY, screenCenterX, screenCenterY)
	gui.drawBox(
		MinimapCenterX + MinimapUnitSize * posMega.x - 1,
		MinimapCenterY + MinimapUnitSize * posMega.y - math.ceil(MinimapUnitSize / 2),
		MinimapCenterX + MinimapUnitSize * posMega.x + 1,
		MinimapCenterY + MinimapUnitSize * posMega.y + math.ceil(MinimapUnitSize / 2),
		0x00FF0000,
		0xFFFF0000
	)
end

--Main loop
while true do
	--Retrieves all the inputs and plots them onto the minimap
	getInputs()


	--Advances a frame, otherwise the emulator freezes
	emu.frameadvance()
end

--[[
UNUSED CODE

--Health
gui.text(x, y, 'Health: ' .. memory.read_s8(0x0BCF))

--Random
gui.text(x, y, 'Random: ' .. memory.read_s8(0x0BA6))

for i=1,#sprites do
	gui.text(220, 14*(i-1), 'x: ' .. sprites[i]["x"])
	gui.text(270, 14*(i-1), 'y: ' .. sprites[i]["y"])
end
]]
