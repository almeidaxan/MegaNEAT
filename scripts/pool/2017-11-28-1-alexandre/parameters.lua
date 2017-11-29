ConnectionsMutateChance = 0.25
LinkMutationChance = 2.0
NodeMutationChance = 0.5
BiasMutationChance = 0.4
EnableMutationChance = 0.2
DisableMutationChance = 0.4
StepSize = 0.1

function computeFitness()
	-- MegamanHP is Mega Man's health, which goes from 0 to 16 
	-- Rightmost is the position far to the right reached (-DiffRightmost is used to standardize the initial position as 0)
	-- Score is computed based on how many Mega Man shots hit the enemies
	local fitness = (3 * (Rightmost - DiffRightmost)) + (20 * Score) + (-50 * (16 - MegamanHP))
	if Rightmost >= 2900 then
		fitness = fitness + 4000 -- Bonus for climbing after the first checkpoint
	end
	if Rightmost >= 3500 then
		fitness = fitness + 4000 -- Bonus for climbing after the second checkpoint
	end
	return fitness
end