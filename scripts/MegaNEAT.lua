-- NEAT metaparameters
Population = 300
DeltaDisjoint = 2.0
DeltaWeights = 0.4
DeltaThreshold = 1.0
StaleSpecies = 15
PerturbChance = 0.90
CrossoverChance = 0.75
ConnectionsMutateChance = 0.5 --0.25
LinkMutationChance = 2.0 --2.0
NodeMutationChance = 1.0 --0.5
BiasMutationChance = 0.8 --0.4
EnableMutationChance = 0.4 --0.2
DisableMutationChance = 0.4 --0.4
MaxNodes = 10000
StepSize = 0.1 --0.1
TimeoutConstant = 50
NumInputs = 16 * 14 + 1 -- 16 by 14 tiles in the minimap, +1 because of the bias
ButtonNames = {"B", "Y", "Left", "Right"}
ButtonNamesMask = {"Jump", "Shoot", "Left", "Right"}
NumOutputs = #ButtonNames
DiffRightmost = 0
LastFrameFitness = 0

-- Loading scripts with functions
dofile("func-auxiliary.lua")
dofile("func-minimap.lua")
dofile("func-network.lua")

-- Checks if the pool already exists; if not, initialize one
if Pool == nil then
	Inputs = getInputs()
	initializePool()
end

-- Creates a temporary file for the current pool
writeFile("pool/temp.pool")

-- Creates a form to enabling further evaluation of the outputs
form = forms.newform(350, 325, "")
playTopButton = forms.button(form, "Replay", playTop, 110, 10, 75, 40)
forms.label(form, "Max Fitness:", 5, 5) 
maxFitnessLabel = forms.label(form, math.floor(Pool.maxFitness), 5, 30)
forms.label(form, "Save/Load:", 5, 70)
saveLoadFile = forms.textbox(form, "example.pool", 150, 25, nil, 5, 95)
forms.button(form, "Save", savePool, 5, 122, 75, 40)
forms.button(form, "Load", loadPool, 80, 122, 75, 40)
showMutationRates = forms.checkbox(form, "Show M-Rates", 110, 180)
hideBanner = forms.checkbox(form, "Banner", 110, 205)
hideNetwork = forms.checkbox(form, "Network", 110, 230)
forms.label(form, "Restart:", 5, 180)
forms.button(form, "Restart", initializePool, 5, 205, 75, 40)
event.onexit(destroyForm) -- Destroys the form whenever the script is stopped or the emulator is closed

-- Main execution loop
while true do
	-- Converts minimap info into a matrix of inputs
	-- Inputs = getInputs()
	-- LABELS OF THE INPUT MATRIX:
	--  0 = Empty
	--  1 = Floor (ground)
	-- -1 = Enemies, enemies bullets/shots, items

	MegamanX = memory.read_s16_le(0x0BAD) + 5
	MegamanY = memory.read_s16_le(0x0BB0) + 10
	MegamanHP = memory.readbyte(0x0BCF)

	-- Fixes HP overflowing
	if MegamanHP >= 128 then
		MegamanHP = MegamanHP - 128
	end

	-- Updates rightmost with the maximum x-position achieved
	if MegamanX > Rightmost then
		Rightmost = MegamanX
	end

	-- For every 5 frames
	if Pool.currentFrame % 5 == 0 then
		Inputs = getInputs()
		updateTiles() -- Watches and updates dynamic tiles
		evaluateCurrent() -- Re-evaluate the inputs 
	end

	-- Define the species and genomes of the current pool
	local species = Pool.species[Pool.currentSpecies]
	local genome = species.genomes[Pool.currentGenome]

	-- Display the current neural network, with its connections and neurons
	if not forms.ischecked(hideNetwork) then
		displayGenome(genome)
	end

	-- Do not hold the fire button, because that's not efficient
	if Controller["P1 Y"] and Pool.currentFrame % 2 == 0 then
		local tmpController = {}
		for o=1,NumOutputs do
			local button = "P1 " .. ButtonNames[o]
			if Controller[button] then
				tmpController[button] = true
			else
				tmpController[button] = false
			end
		end
		tmpController["P1 Y"] = false
		joypad.set(tmpController)
	else
		joypad.set(Controller)
	end

	-- Resets the timeout if the fitness is increasing, and updates the fitness from the last frame
	local fitness = computeFitness()
	if fitness > LastFrameFitness then
		Timeout = TimeoutConstant
	end
	LastFrameFitness = fitness
	Timeout = Timeout - 1
	local timeoutBonus = Pool.currentFrame / 4

	-- Draws a clock and displays timeout value
	if not forms.ischecked(hideNetwork) then
		gui.drawEllipse(6, 212, 8, 8, 0xC0000000, 0xFFFFFFFF)
		gui.drawLine(10, 214, 10, 216, 0xFF000000)
		gui.drawLine(10, 216, 11, 217, 0xFF000000)
		gui.drawText(15, 209, math.ceil(Timeout + timeoutBonus), 0xFFFFFFFF, 0x00000000, 11)
	end

	-- Define a score based on shots that hit enemies
	local bulletsx = getBulletsX()
	local etc = getEtc()
	if Score == nil then
		Score = 0
	else 
		for i=1,#bulletsx do
			if bulletsx[i].action1 == 8 and bulletsx[i].action2 == 4 and bulletsx[i].action3 == 0 then
				if bulletsx[i].id == 1 then
					Score = Score + 2
				else
					Score = Score + 4
				end
			end
		end
		for i=1,#etc do
			if etc[i].action1 == 0 and etc[i].id == 9 then
				Score = Score + 1
			end
		end
	end

	-- Restarts the run if the individual dies or times out
	if MegamanHP == 0 or Timeout + timeoutBonus <= 0 then
		if fitness <= 0 then
			fitness = -1
		end

		genome.fitness = fitness

		if fitness > Pool.maxFitness then
			console.writeline(
				"Max Fitness increased from " .. Pool.maxFitness ..
				" to " .. fitness
			)
			Pool.maxFitness = fitness
			forms.settext(maxFitnessLabel, math.floor(Pool.maxFitness))
			writeFile("pool/backup." .. Pool.generation .. ".pool")
		end

		-- Finds the next individual whose fitness wasn't yet measured
		Pool.currentSpecies = 1
		Pool.currentGenome = 1
		while fitnessAlreadyMeasured() do
			nextGenome()
		end

		-- Resets the max achieved fitness
		LastFrameFitness = 0

		-- Restart the individual
		initializeRun()
	end

	-- Computes the percentage of genomes that already had their fitness evaluated
	local measured = 0
	local total = 0
	for _,species in pairs(Pool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then 
				measured = measured + 1
			end
		end
	end

	-- Draws a banner onto which to display evolution info
	if not forms.ischecked(hideBanner) then
		gui.drawBox(0, 0, 300, 33, 0x80C0C0C0, 0x80C0C0C0)
		gui.drawText(1, -1,
			"Generation " .. Pool.generation,
			0xFF000000, 0x00000000, 11, "Courier New", "Bold")
		gui.drawText(0, 10,
			"Spec. " .. Pool.currentSpecies,
			0xFF000000, 0x00000000, 11)
		gui.drawText(0, 20,
			"Geno. " .. Pool.currentGenome,
			0xFF000000, 0x00000000, 11)
		gui.drawText(65, 14,
			"(" .. math.floor(measured / total * 100) .. "%)",
			0xFF000000, 0x00000000, 12)
		gui.drawText(143, 2,
			"Fitness: " .. math.floor(computeFitness()),
			0xFF000000, 0x00000000, 12)
		gui.drawText(173, 15,
			"Max: " .. math.floor(Pool.maxFitness),
			0xFF000000, 0x00000000, 12)
	end

	-- Advances an emulator frame
	Pool.currentFrame = Pool.currentFrame + 1
	emu.frameadvance()
end
