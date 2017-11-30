ConnectionsMutateChance = 0.5
LinkMutationChance = 2.0
NodeMutationChance = 1.0
BiasMutationChance = 0.8
EnableMutationChance = 0.4
DisableMutationChance = 0.4
StepSize = 0.1

function computeFitness()
	-- MegamanHP is Mega Man's health, which goes from 0 to 16 
	-- Rightmost is the position far to the right reached (-DiffRightmost is used to standardize the initial position as 0)
	-- Score is computed based on how many Mega Man shots hit the enemies
	local fitness = (2 * (Rightmost - DiffRightmost)) + (20 * Score) + (-150 * (16 - MegamanHP))
	if Rightmost >= 2900 then
		fitness = fitness + 4000 -- Bonus for climbing after the first checkpoint
	end
	if Rightmost >= 3500 then
		fitness = fitness + 4000 -- Bonus for climbing after the second checkpoint
	end
	return fitness
end