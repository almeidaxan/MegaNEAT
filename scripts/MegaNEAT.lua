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
TimeoutConstant = 15
NumInputs = 16 * 14 + 1 -- 16 by 14 tiles in the minimap, +1 because of the bias
ButtonNames = {"B", "Y", "Left", "Right"}
ButtonNamesMask = {"Jump", "Shoot", "Left", "Right"}
NumOutputs = #ButtonNames
DiffY = 0
DiffRightmost = 0
-- SavestateSlot = 1

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

	joypad.set(controller)

	local megamanX = memory.read_s16_le(0x0BAD) + 5
	local megamanY = memory.read_s16_le(0x0BB0) + 10
	local megamanHP = memory.readbyte(0x0BCF)

	if megamanX > Rightmost then
		Rightmost = megamanX
		Timeout = TimeoutConstant
	end

	Timeout = Timeout - 1

	local timeoutBonus = Pool.currentFrame / 4

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
	if megamanHP == 0 or Timeout + timeoutBonus <= 0 then
		local fitness = computeFitness(megamanY, megamanHP)

		if fitness <= 0 then
			fitness = -1
		end

		genome.fitness = fitness

		if fitness > Pool.maxFitness then
			Pool.maxFitness = fitness
			forms.settext(maxFitnessLabel, math.floor(Pool.maxFitness))
			writeFile("pool/backup." .. Pool.generation .. ".pool")
			-- writeFile("pool/backup." .. Pool.generation .. "." .. SavestateSlot .. ".pool")
		end

		-- Prints the indivual results to the console
		console.writeline(
			"Gen " .. Pool.generation ..
			" species " .. Pool.currentSpecies ..
			" genome " .. Pool.currentGenome ..
			" fitness: " .. fitness
		)

		-- Finds the next individual whose fitness wasn't yet measured
		Pool.currentSpecies = 1
		Pool.currentGenome = 1
		while fitnessAlreadyMeasured() do
			nextGenome()
		end

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
			"Fitness: " .. math.floor(computeFitness(megamanY, megamanHP)),
			0xFF000000, 0x00000000, 12)
		gui.drawText(173, 15,
			"Max: " .. math.floor(Pool.maxFitness),
			0xFF000000, 0x00000000, 12)
	end

	-- Advances an emulator frame
	Pool.currentFrame = Pool.currentFrame + 1
	emu.frameadvance()
end
