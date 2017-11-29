--- [func-network.lua]
-- Contains functions related to the neural network and genetic evolution (NEAT) algorithm

function newInnovation()
	Pool.innovation = Pool.innovation + 1
	return Pool.innovation
end

-- Creates a new pool
function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = NumOutputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0

	return pool
end

-- Creates a new species
function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0

	return species
end

-- Creates a new genome
function newGenome()
	local genome = {}
	genome.genes = {}
	genome.network = {}
	genome.mutationRates = {}
	genome.fitness = 0
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates["connections"] = ConnectionsMutateChance
	genome.mutationRates["link"] = LinkMutationChance
	genome.mutationRates["bias"] = BiasMutationChance
	genome.mutationRates["node"] = NodeMutationChance
	genome.mutationRates["enable"] = EnableMutationChance
	genome.mutationRates["disable"] = DisableMutationChance
	genome.mutationRates["step"] = StepSize

	return genome
end

-- Creates a basic genome, to be used when initializing a population
function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = NumInputs
	mutate(genome)

	return genome
end

-- Creates a copy of a genome
function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]

	return genome2
end

-- Creates a new neuron (basic element of the neural network)
function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0

	return neuron
end

-- Creates a new gene (connection between neurons)
function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0

	return gene
end

-- Creates a copy of a gene
function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation

	return gene2
end

-- Generates the network of neurons and genes
function generateNetwork(genome)
	local network = {}
	network.neurons = {}

	for i=1,NumInputs do
		network.neurons[i] = newNeuron()
	end

	for o=1,NumOutputs do
		network.neurons[MaxNodes+o] = newNeuron()
	end

	table.sort(genome.genes,
		function (a,b)
			return (a.out < b.out)
		end
	)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end

	genome.network = network
end

-- Evaluates the network by providing the matrix of inputs
function evaluateNetwork(network)
	if #Inputs == 0 then
		return {}
	end

	-- Converts the inputs matrix to an array
	array = {}
	index = 1
	for _,Value in pairs(Inputs) do
		if type(Value) ~= 'table' then
			break
		end

		for i=1,#Value do
			array[index] = Value[i]
			index = index + 1
		end
	end

	-- Inserts the bias neuron into the array
	table.insert(array, 1)

	if #array ~= NumInputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end

	for i=1,NumInputs do
		network.neurons[i].value = array[i]
	end

	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end

		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end

	local outputs = {}
	for o=1,NumOutputs do
		local button = "P1 " .. ButtonNames[o]
		if network.neurons[MaxNodes + o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end

	return outputs
end

function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()

	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end

	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end

	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)

	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end

	return child
end

function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,NumInputs do
			neurons[i] = true
		end
	end
	for o=1,NumOutputs do
		neurons[MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > NumInputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > NumInputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)

	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end

	return 0
end

function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

function pointMutate(genome)
	local step = genome.mutationRates["step"]

	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < PerturbChance then
			gene.weight = gene.weight + math.random() * step * 2 - step
		else
			gene.weight = math.random() * 4 - 2
		end
	end
end

function linkMutate(genome, forceBias)
	local neuron1 = randomNeuron(genome.genes, false)
	local neuron2 = randomNeuron(genome.genes, true)

	local newLink = newGene()
	if neuron1 <= NumInputs and neuron2 <= NumInputs then
		-- Both input nodes
		return
	end
	if neuron2 <= NumInputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	if forceBias then
		newLink.into = NumInputs
	end

	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation()
	newLink.weight = math.random() * 4 - 2

	table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false

	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)

	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end

	if #candidates == 0 then
		return
	end

	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(0,1) == 1 then
			genome.mutationRates[mutation] = 0.90 * rate
		else
			genome.mutationRates[mutation] = 1.10 * rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end

	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(genome)
		end
		p = p - 1
	end

	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end

	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end

	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end

	local n = math.max(#genes1, #genes2)

	return disjointGenes / n
end

function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end

	return sum / coincident
end

function sameSpecies(genome1, genome2)
	local dd = DeltaDisjoint * disjoint(genome1.genes, genome2.genes)
	local dw = DeltaWeights * weights(genome1.genes, genome2.genes)
	return dd + dw < DeltaThreshold
end

function rankGlobally()
	local global = {}
	for s = 1,#Pool.species do
		local species = Pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)

	for g=1,#global do
		global[g].globalRank = g
	end
end

function calculateAverageFitness(species)
	local total = 0

	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end

	species.averageFitness = total / #species.genomes
end

function totalAverageFitness()
	local total = 0
	for s = 1,#Pool.species do
		local species = Pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function cullSpecies(cutToOne)
	for s = 1,#Pool.species do
		local species = Pool.species[s]

		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)

		local remaining = math.ceil(#species.genomes / 2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

function breedChild(species)
	local child = {}
	if math.random() < CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end

	mutate(child)

	return child
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#Pool.species do
		local species = Pool.species[s]

		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)

		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end

		if species.staleness < StaleSpecies or species.topFitness >= Pool.maxFitness then
			table.insert(survived, species)
		end
	end

	Pool.species = survived
end

function removeWeakSpecies()
	local survived = {}

	local sum = totalAverageFitness()
	for s = 1,#Pool.species do
		local species = Pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	Pool.species = survived
end

function addToSpecies(child)
	local foundSpecies = false
	for s=1,#Pool.species do
		local species = Pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end

	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(Pool.species, childSpecies)
	end
end

function newGeneration()
	cullSpecies(false) -- Cull the bottom half of each species
	rankGlobally()
	removeStaleSpecies()
	rankGlobally()
	for s = 1,#Pool.species do
		local species = Pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#Pool.species do
		local species = Pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true) -- Cull all but the top member of each species
	while #children + #Pool.species < Population do
		local species = Pool.species[math.random(1, #Pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end

	Pool.generation = Pool.generation + 1

	writeFile("pool/backup." .. Pool.generation .. ".pool")
end

function initializePool()
	Pool = newPool()

	for i=1,Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun()
end

function clearJoypad()
	Controller = {}

	for b = 1,NumOutputs do
		Controller["P1 " .. ButtonNames[b]] = false
	end

	joypad.set(Controller)
end

function initializeRun()
	-- local rand = math.random(1,2)
	local rand = 1
	savestate.loadslot(rand)
	
	-- Update the diff variables with initial Mega Man positions in each savestate
	DiffRightmost = memory.read_s16_le(0x0BAD) + 5

	clearJoypad()

	Score = 0
	Rightmost = 0
	Pool.currentFrame = 0
	Timeout = TimeoutConstant

	local species = Pool.species[Pool.currentSpecies]
	local genome = species.genomes[Pool.currentGenome]

	generateNetwork(genome)
	evaluateCurrent()
end

function evaluateCurrent()
	if Inputs == nil then
		return
	end

	local species = Pool.species[Pool.currentSpecies]
	local genome = species.genomes[Pool.currentGenome]

	Controller = evaluateNetwork(genome.network)

	if Controller["P1 Left"] and Controller["P1 Right"] then
		Controller["P1 Left"] = false
		Controller["P1 Right"] = false
	end 
  
	joypad.set(Controller)
end

function nextGenome()
	Pool.currentGenome = Pool.currentGenome + 1
	-- If no more genomes exists for the current species, then go to the next species
	if Pool.currentGenome > #Pool.species[Pool.currentSpecies].genomes then
		Pool.currentGenome = 1
		Pool.currentSpecies = Pool.currentSpecies + 1
		-- If no more species exists for the current generation, then go to the next generation
		if Pool.currentSpecies > #Pool.species then
			-- Prints some generation statistics
			console.writeline(
				"Generation: " .. Pool.generation ..
				" | Max Fitness: " .. Pool.maxFitness
			)
			newGeneration()
			Pool.currentSpecies = 1
		end
	end
end

function fitnessAlreadyMeasured()
	local species = Pool.species[Pool.currentSpecies]
	local genome = species.genomes[Pool.currentGenome]

	return genome.fitness ~= 0
end

function displayGenome(genome)
	local network = genome.network
	local cell = {}
	local cells = {}
	local biasCell = {}

	-- NumInputs
	local k = 1
	for i=0,13 do
		for j=0,15 do
			cell = {}
			cell.x = MinimapOriginX + MinimapUnitSize * j
			cell.y = MinimapOriginY + MinimapUnitSize * i
			cell.value = network.neurons[k].value
			cells[k] = cell
			k = k + 1
		end
	end

	-- Bias
	biasCell.x = MinimapOriginX + MinimapUnitSize * 15
	biasCell.y = MinimapOriginY + MinimapUnitSize * 15
	biasCell.value = network.neurons[NumInputs].value
	cells[NumInputs] = biasCell

	-- Outputs and its names
	for o = 1,NumOutputs do
		cell = {}
		cell.x = MinimapOriginX + MinimapUnitSize * 42
		cell.y = MinimapOriginY + 10 * o + 7
		cell.value = network.neurons[MaxNodes + o].value
		cells[MaxNodes + o] = cell
		local color
		if cell.value > 0 then
			color = 0xFFFFFFFF
		else
			color = 0xB0000000
		end
		gui.drawText(
			MinimapOriginX + MinimapUnitSize * 42 + 7,
			MinimapOriginY + 10 * o + 4,
			ButtonNamesMask[o],
			color,
			0x00000000,
			10
		)
	end

	-- Draws the minimap itself
	gui.drawBox(
		MinimapOriginX,
		MinimapOriginY,
		MinimapOriginX + MinimapUnitSize * 16 + 1,
		MinimapOriginY + MinimapUnitSize * 14 + 1,
		0x80000000,
		0x80808080
	)

	-- Networks neurons
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > NumInputs and n <= MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end

	-- Correctly positioning network neurons
	for n=1,4 do -- Why n=1,4???
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > NumInputs and gene.into <= MaxNodes then
					c1.x = 0.75 * c1.x + 0.25 * c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end

					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75 * c1.y + 0.25 * c2.y

				end
				if gene.out > NumInputs and gene.out <= MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end

	-- Draws the minimap cells
	for n,cell in pairs(cells) do
		if n < NumInputs and cell.value ~= 0 then
			local color = math.floor((cell.value + 1) / 2 * 256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			color = 0xFF000000 + color * 0x10000 + color * 0x100 + color
			gui.drawBox(
				cell.x,
				cell.y,
				cell.x + MinimapUnitSize + 1,
				cell.y + MinimapUnitSize + 1,
				0x00000000,
				color
			)
		elseif n >= NumInputs or cell.value ~= 0 then
			local color = math.floor((cell.value + 1) / 2 * 256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x30000000
			end
			color = opacity + color * 0x10000 + color * 0x100 + color
			gui.drawBox(
				cell.x,
				cell.y,
				cell.x + MinimapUnitSize + 1,
				cell.y + MinimapUnitSize + 1,
				opacity,
				color
			)
		end
	end

	-- Draws Mega Man on the minimap
	local mega = {
		["x"] = memory.read_s16_le(0x0BAD) + 5, -- Adding '5' to correct the X position
		["y"] = memory.read_s16_le(0x0BB0) + 10 -- Adding '10' to correct the Y position
	}
	local screenX = memory.read_s16_le(0x00B4)
	local screenY = memory.read_s16_le(0x00B6)
	mega.x = math.floor((mega.x - screenX) / 16)
	mega.y = math.floor((mega.y - screenY) / 16)
	if mega.x >= 0 and mega.x <= 15 and mega.y >= 0 and mega.y <= 13 then
		gui.drawBox(
			MinimapOriginX + MinimapUnitSize * mega.x,
			MinimapOriginY + MinimapUnitSize * mega.y,
			MinimapOriginX + MinimapUnitSize * mega.x + MinimapUnitSize + 1,
			MinimapOriginY + MinimapUnitSize * mega.y + MinimapUnitSize + 1,
			0x00000000,
			0xFF0000FF
		)
	end

	-- Draw the network connections/lines/genes
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end

			local color = 0x80 - math.floor(math.abs(sigmoid(gene.weight)) * 0x80)
			if gene.weight > 0 then
				color = opacity + 0x8000 + 0x10000 * color
			else
				color = opacity + 0x800000 + 0x100 * color
			end

			gui.drawLine(
				c1.x + 3,
				c1.y + 3,
				c2.x + 3,
				c2.y + 3,
				color
			)
		end
	end

	if forms.ischecked(showMutationRates) then
		local y = 150
		for mutation,rate in pairs(genome.mutationRates) do
			gui.drawText(100, y, mutation .. ": " .. rate, 0xFFFFFFFF, 0x00000000, 11)
			y = y + 8
		end
	end
end

function writeFile(filename)
	local file = io.open(filename, "w")
	file:write(Pool.generation .. "\n")
	file:write(Pool.maxFitness .. "\n")
	file:write(#Pool.species .. "\n")
	for n,species in pairs(Pool.species) do
		file:write(species.topFitness .. "\n")
		file:write(species.staleness .. "\n")
		file:write(#species.genomes .. "\n")
		for m,genome in pairs(species.genomes) do
			file:write(genome.fitness .. "\n")
			file:write(genome.maxneuron .. "\n")
			for mutation,rate in pairs(genome.mutationRates) do
				file:write(mutation .. "\n")
				file:write(rate .. "\n")
			end
			file:write("done\n")
			file:write(#genome.genes .. "\n")
			for l,gene in pairs(genome.genes) do
				file:write(gene.into .. " ")
				file:write(gene.out .. " ")
				file:write(gene.weight .. " ")
				file:write(gene.innovation .. " ")
				if(gene.enabled) then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end
		end
	end
	file:close()
end

function loadFile(filename)
	local file = io.open(filename, "r")
	Pool = newPool()
	Pool.generation = file:read("*number")
	Pool.maxFitness = file:read("*number")
	forms.settext(maxFitnessLabel, math.floor(Pool.maxFitness))
	local numSpecies = file:read("*number")
	for s=1,numSpecies do
		local species = newSpecies()
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		local numGenomes = file:read("*number")
		for g=1,numGenomes do
			local genome = newGenome()
			genome.fitness = file:read("*number")
			genome.maxneuron = file:read("*number")
			local line = file:read("*line")
			while line ~= "done" do
				genome.mutationRates[line] = file:read("*number")
				line = file:read("*line")
			end 
			local numGenes = file:read("*number")
			for n=1,numGenes do
				local gene = newGene()
				local enabled
				local strToNum = {}
				for i in string.gmatch(file:read("*line"), "%S+") do
					strToNum[#strToNum + 1] = tonumber(i)
				end
				gene.into = strToNum[1]
				gene.out = strToNum[2]
				gene.weight = strToNum[3]
				gene.innovation = strToNum[4]
				enabled = strToNum[5]
				if enabled == 0 then
					gene.enabled = false
				else
					gene.enabled = true
				end
				table.insert(genome.genes, gene)
			end
			table.insert(species.genomes, genome)
		end
		table.insert(Pool.species, species)
	end
	file:close()

	while fitnessAlreadyMeasured() do
		nextGenome()
	end

	initializeRun()

	Pool.currentFrame = Pool.currentFrame + 1
end

function savePool()
	local filename = forms.gettext(saveLoadFile)
	writeFile("pool/" .. filename)
end

function loadPool()
	local filename = forms.gettext(saveLoadFile)
	loadFile("pool/" .. filename)
end

function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(Pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end

	Pool.currentSpecies = maxs
	Pool.currentGenome = maxg
	Pool.maxFitness = maxfitness
	forms.settext(maxFitnessLabel, math.floor(Pool.maxFitness))
	initializeRun()
	Pool.currentFrame = Pool.currentFrame + 1
	return
end

function computeFitness()
	-- y is the y-axis position (-DiffY is used to standardize the initial position as 0)
		-- (Controller["P1 B"] and 1 or 0) serves to activate the use of y ONLY IF the player is jumping
	-- hp is Mega Man's health, which goes from 0 to 16 
	-- Rightmost is the position far to the right reached (-DiffRightmost is used to standardize the initial position as 0)
	-- Score is computed based on how many Mega Man shots hit the enemies
	-- local fitness = (Controller["P1 Right"] and Controller["P1 B"] and 1 or 0) * (-0.6 * (y - DiffY)) + (1.5 * (Rightmost - DiffRightmost)) + (100 * Score) + (-20 * (16 - hp))
	local fitness = (2 * (Rightmost - DiffRightmost)) + (20 * Score) + (-150 * (16 - MegamanHP))
	if Rightmost >= 2900 then
		fitness = fitness + 4000 -- Bonus for climbing after the first checkpoint
	end
	if Rightmost >= 3500 then
		fitness = fitness + 4000 -- Bonus for climbing after the second checkpoint
	end
	return fitness
end