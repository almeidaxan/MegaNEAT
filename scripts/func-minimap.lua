---[func-minimap.lua]
--Contains functions and variables related to the construction and drawing of the minimap/input matrix

--Minimap and screen parameters
MinimapOriginX = 25 --Minimap origin X position
MinimapOriginY = 10 --Minimap origin Y position
MinimapUnitSize = 5 --Size in pixels of the minimap square units (must be an odd number)
ScreenDimX = 256 --Screen X dimension in pixels
ScreenDimY = 224 --Screen Y dimension in pixels
SolidTiles = {68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 83, 84, 89,
			  90, 95, 96, 98, 99, 149, 150, 185, 189, 190, 193, 194, 198, 328, 329,
			  330, 335, 336, 337, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351,
			  352, 353, 354, 355, 356, 357, 358, 360, 361, 362, 367, 368, 369, 370,
			  371, 372, 373, 374, 375, 376, 377, 378, 381, 382, 383, 384, 385, 386,
			  400, 401, 404, 405, 406, 407, 412, 413, 414, 415, 419, 420, 421, 422,
			  423, 561, 562, 743, 744, 745, 748, 749, 750, 751, 752, 754, 755, 756,
			  757, 758, 759, 761, 762, 763, 764, 765, 766, 781, 783, 785, 786, 788,
			  790, 792, 793, 794, 795, 796, 797, 798, 799, 825} --Tiles IDs that are solid (decimal)

local stageR = 32 --Stage rows of tiles (2 scenes * 16 tiles = 32 rows of tiles)
local stageC = 512 --Stage columns of tiles (32 scenes * 16 tiles = 512 columns of tiles)
local stageS = {01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16,
				17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 29, 30,
				00, 00, 00, 00, 00, 00, 00, 00, 00, 31, 32, 33, 34, 35, 00, 00,
				00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00} --Ordering of stage scene IDs (decimal)

--Initializing the stage tiles matrix with zeroes
StageTiles = {}
for i=1,stageR do
	StageTiles[i] = {}
	for j=1,stageC do
		StageTiles[i][j] = 0
	end
end

--Reading Highway Stage tile information from the memory
for s=1,#stageS do
	local iStep = 16 * math.floor((s - 1) / 32)
	local iL = 1 + iStep
	local iU = 16 + iStep
	for i=iL,iU do
		local jStep = 16 * ((s - 1) % 32)
		local jL = 1 + jStep
		local jU = 16 + jStep
		for j=jL,jU do
			local pos = ((i - iStep) - 1) * 16 + (j - jStep)
			StageTiles[i][j] = hasValue(SolidTiles, memory.read_s16_le(0x2000 + stageS[s] * 512 + (pos - 1) * 2))
		end
	end
end

--Overwrite these specific positions as solid tiles, since they are wrongly masked by the up-layer
StageTiles[9][1] = 1; StageTiles[9][2] = 1; StageTiles[9][3] = 1
StageTiles[10][1] = 1; StageTiles[10][2] = 1; StageTiles[10][3] = 1
StageTiles[11][1] = 1; StageTiles[11][2] = 1; StageTiles[11][3] = 1

--Function to draw objects (enemies, bullets, items, and Mega Man) onto the minimap and update the input matrix
function drawObjects(object, color, screenX, screenY, MinimapOriginX, MinimapOriginY, inputMatrix, inputMatrixValue)
	local posX = math.floor((object.x - screenX) / 16)
	local posY = math.floor((object.y - screenY) / 16)

	if posX >= 0 and posX <= 15 and posY >= 0 and posY <= 13 then
		if inputMatrixValue ~= -1 then
			inputMatrix[posY + 1][posX + 1] = inputMatrixValue
		end

		gui.drawBox(
			MinimapOriginX + MinimapUnitSize * posX + 1,
			MinimapOriginY + MinimapUnitSize * posY + 1,
			MinimapOriginX + MinimapUnitSize * posX + MinimapUnitSize,
			MinimapOriginY + MinimapUnitSize * posY + MinimapUnitSize,
			color,
			color
		)
	end

	return inputMatrix
end

--Function to retrieve the top-left X,Y positions of all rendered enemies' bullets sprites
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

--Function to retrieve the top-left X,Y positions of all rendered enemies sprites
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

--Function to retrieve the top-left X,Y positions of all rendered items sprites
function getItems()
	local items = {}

	for slot=0,15 do
		--Status is used to determine if the object is currently rendered
		local status = memory.readbyte(0x1628 + slot * 48)
		if status ~= 0 and memory.readbyte(0x1628 + slot * 48 + 10) == 2 then
			local itemsX = memory.read_s16_le(0x1628 + slot * 48 + 5)
			local itemsY = memory.read_s16_le(0x1628 + slot * 48 + 8)
			items[#items+1] = {["x"] = itemsX, ["y"] = itemsY}
		end
	end

	return items
end

--Get the tiles indexes from StageTiles based on the current screen extent
function getTiles(screenX, screenY)
	local xL = math.ceil((screenX + 1) / 16)
	local xU = xL + 15
	local yL = math.ceil((screenY - 256 + 1) / 16)
	local yU = yL + 13

	return {xL, xU, yL, yU}
end

--Observe specific dynamic tiles and update StageTiles matrix if they chage from a non-solid to a solid tile
function observeTiles(sceneID, iL, iU, jL, jU)
	for i=iL,iU do
		for j=jL,jU do
			local pos = ((i - 1) % 16) * 16 + ((j - 1) % 16 + 1)
			StageTiles[i][j] = hasValue(SolidTiles, memory.read_s16_le(0x2000 + sceneID * 512 + (pos - 1) * 2))
		end
	end
end

--Runs observeTiles for specific tile ranges
function updateTiles()
	observeTiles(5, 7, 9, 65, 70)
	observeTiles(5, 7, 9, 73, 78)
	observeTiles(6, 8, 10, 89, 94)
	observeTiles(7, 8, 10, 97, 102)
	observeTiles(7, 8, 10, 105, 110)
	observeTiles(8, 8, 10, 113, 118)
	observeTiles(8, 8, 10, 121, 126)
	observeTiles(9, 8, 10, 129, 134)
	observeTiles(11, 8, 10, 161, 174)
	observeTiles(13, 10, 12, 201, 208)
	observeTiles(14, 10, 12, 209, 214)
	observeTiles(16, 8, 10, 249, 250)
	observeTiles(17, 8, 10, 265, 266)
	observeTiles(18, 6, 8, 273, 274)
	observeTiles(18, 6, 8, 277, 278)
	observeTiles(18, 6, 8, 283, 286)
	observeTiles(19, 6, 8, 289, 294)
	observeTiles(19, 8, 10,  301, 302)
	observeTiles(32, 19, 19, 168, 172)
	observeTiles(32, 20, 21, 167, 172)
	observeTiles(32, 22, 24, 162, 173)
	observeTiles(34, 19, 19, 208, 208)
	observeTiles(34, 20, 21, 207, 208)
	observeTiles(34, 22, 24, 202, 208)
	observeTiles(35, 19, 21, 209, 212)
	observeTiles(35, 22, 24, 209, 213)
end

--Function to draw the minimap, get all inputs, draw them onto the minimap, and return a matrix of inputs
function getInputs()
	--Screen top-left X,Y positions
	local screenX = memory.read_s16_le(0x00B4)
	local screenY = memory.read_s16_le(0x00B6)

	--Screen center X,Y positions
	local screenCenterX = math.floor(screenX + ScreenDimX / 2)
	local screenCenterY = math.floor(screenY + ScreenDimY / 2)

	--Initializing the input matrix
	inputs = {}
	for i=1,14 do
		inputs[i] = {}
		for j=1,16 do
			inputs[i][j] = 0
		end
	end

	--Draws the minimap itself
	gui.drawBox(
		MinimapOriginX,
		MinimapOriginY,
		MinimapOriginX + MinimapUnitSize * 16 + 1,
		MinimapOriginY + MinimapUnitSize * 14 + 1,
		0x80000000,
		0x80808080
	)

	--Draws solid tiles on the minimap (white, value = 1)
	local tiles = getTiles(screenX, screenY)
	for i=tiles[3],tiles[4] do
		for j=tiles[1],tiles[2] do
			if i >= 1 and j >= 1 and i <= #StageTiles and j <= #StageTiles[i] and StageTiles[i][j] == 1 then --If tile is solid, then draw it
				inputs[i - tiles[3] + 1][(j - tiles[1]) + 1] = 1

				gui.drawBox(
					MinimapOriginX + MinimapUnitSize * (j - tiles[1]) + 1,
					MinimapOriginY + MinimapUnitSize * (i - tiles[3]) + 1,
					MinimapOriginX + MinimapUnitSize * (j - tiles[1]) + MinimapUnitSize,
					MinimapOriginY + MinimapUnitSize * (i - tiles[3]) + MinimapUnitSize,
					0xFFFFFFFF,
					0xFFFFFFFF
				)
			end
		end
	end

	--Draws enemies on the minimap (black, value = 2)
	local enemies = getEnemies()
	for i=1,#enemies do
		inputs = drawObjects(enemies[i], 0xFF000000, screenX, screenY, MinimapOriginX, MinimapOriginY, inputs, 2)
	end

	--Draws enemies' bullets on the minimap (red, value = 3)
	local bullets = getBullets()
	for i=1,#bullets do
		inputs = drawObjects(bullets[i], 0xFFFF0000, screenX, screenY, MinimapOriginX, MinimapOriginY, inputs, 3)
	end

	--Draws items on the minimap (magenta, value = 4)
	local items = getItems()
	for i=1,#items do
		inputs = drawObjects(items[i], 0xFFFF00FF, screenX, screenY, MinimapOriginX, MinimapOriginY, inputs, 4)
	end

	--Draws Mega Man on the minimap (blue, value = 5)
	local mega = {["x"] = memory.read_s16_le(0x0BAD) + 5, --Adding '15' to correct the X position
				  ["y"] = memory.read_s16_le(0x0BB0) + 10} --Adding '10' to correct the Y position
	inputs = drawObjects(mega, 0xFF0000FF, screenX, screenY, MinimapOriginX, MinimapOriginY, inputs, 5)

	return inputs
end
