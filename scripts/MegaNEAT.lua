-- NEAT metaparameters
Population = 300
DeltaDisjoint = 2.0
DeltaWeights = 0.4
DeltaThreshold = 1.0
StaleSpecies = 15
MutateConnectionsChance = 0.25
PerturbChance = 0.90
CrossoverChance = 0.75
LinkMutationChance = 2.0
NodeMutationChance = 0.50
BiasMutationChance = 0.40
EnableMutationChance = 0.2
DisableMutationChance = 0.4
MaxNodes = 1000000
StepSize = 0.1
TimeoutConstant = 20
Inputs = (16 * 14) + 1 -- 16 by 14 tiles in the minimap, +1 because of the intercept
ButtonNames = {"B", "Y", "Left", "Right"}
Outputs = #ButtonNames
SavestateSlot = 1

-- Loading scripts with functions
dofile("func-auxiliary.lua")
dofile("func-minimap.lua")
dofile("func-network.lua")

-- Checks if a pool already exists; if not, initialize one
if pool == nil then
	local inputs = getInputs()
	initializePool(inputs)
end

-- Creates a temporary file with the current pool
writeFile("temp.pool")

-- Creates a form to enabling further evaluation of the outputs
form = forms.newform(400, 270, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 8)
showMutationRates = forms.checkbox(form, "Show M-Rates", 5, 52)
restartButton = forms.button(form, "Restart", initializePool, 5, 77)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
saveLoadFile = forms.textbox(form, SavestateSlot .. ".pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)
playTopButton = forms.button(form, "Play Top", playTop, 5, 170)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 190)
hideNetwork = forms.checkbox(form, "Hide Network", 5, 210)
event.onexit(destroyForm) -- Destroys the form whenever the script is stopped or the emulator is closed

-- Main execution loop
while true do
	-- Watches and updates dynamic tiles
    updateTiles()

    -- Converts minimap info into a matrix of inputs
	local inputs = getInputs()
	-- LABELS OF THE INPUT MATRIX:
	-- 0 = Empty
	-- 1 = Floor (ground)
	-- 2 = Enemies
	-- 3 = Enemies' bullets/shots
	-- 4 = Health recovery items
	-- 5 = Mega Man

	-- For every 5 frames, re-evaluate the inputs
	if pool.currentFrame % 5 == 0 then
        evaluateCurrent(inputs)
	end

	-- Define the species and genomes of the current pool
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]

	-- Display the current neural network, with its connections and neurons
	if not forms.ischecked(hideNetwork) then
		displayGenome(genome)
	end

	joypad.set(controller)

	megamanX = memory.read_s16_le(0x0BAD) + 5
	megamanY = memory.read_s16_le(0x0BB0) + 10
	megamanHP = memory.read_s8(0x0BCF)

	if megamanX > rightmost then
		rightmost = megamanX
		timeout = TimeoutConstant
	end

	timeout = timeout - 1

	local timeoutBonus = pool.currentFrame / 4

	-- -- Get total of enemies HP
	-- enemiesTotalHP = 0
	-- local enemies = getEnemies()
	-- for i=1,#enemies do
	-- 	enemiesTotalHP = enemiesTotalHP + enemies[i].hp
	-- end

	-- gui.drawText(20, 150, "Antes: " .. enemiesTotalHPBefore)
	-- gui.drawText(20, 170, "Atual: " .. enemiesTotalHP)
	-- gui.drawText(20, 190, "Diff: " .. enemiesCumDiffHP)

	-- local enemiesCumDiffHP
	-- if enemiesCumDiffHP == nil then
	-- 	enemiesCumDiffHP = 0
	--  countEnemies = #enemies
	-- else
	-- 		if countEnemies == #enemies then
	-- 			enemiesCumDiffHP = enemiesCumDiffHP + enemiesTotalHP - enemiesTotalHPBefore 
	--		else
	--			countEnemies = #enemies
	--		end
	-- end

	-- enemiesTotalHPBefore = enemiesTotalHP

	if timeout + timeoutBonus <= 0 then
		-- local fitness = computeFitness(megamanX, megamanHP, pool.currentFrame)
        local fitness = computeFitness(megamanX, megamanY, megamanHP, 0)

		if fitness == 0 then
			fitness = -1
		end

		genome.fitness = fitness

		if fitness > pool.maxFitness then
			pool.maxFitness = fitness
			-- forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
			-- writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
		end

		console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
		pool.currentSpecies = 1
		pool.currentGenome = 1

		-- Advances through the genomes of the species
		while fitnessAlreadyMeasured() do
			nextGenome()
		end

		-- Restart
		initializeRun(inputs)
	end

	local measured = 0
	local total = 0
	for _,species in pairs(pool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then
				measured = measured + 1
			end
		end
	end

	-- Draws banner onto which to display evolution info
	if not forms.ischecked(hideBanner) then
		gui.drawBox(0, 0, 300, 26, 0xD0FFFFFF, 0xD0FFFFFF)
		gui.drawText(0, 0, "Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " (" .. math.floor(measured/total*100) .. "%)", 0xFF000000, 11)
		gui.drawText(0, 12, "Fitness: " .. math.floor(computeFitness(megamanX, megamanY, megamanHP, 0)), 0xFF000000, 11)
		gui.drawText(100, 12, "Max Fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
	end

	-- Advances an emulator frame
	pool.currentFrame = pool.currentFrame + 1
	emu.frameadvance()
end
