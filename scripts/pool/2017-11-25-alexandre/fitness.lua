function computeFitness(y, hp)
	-- y is the y-axis position (-DiffY is used to standardize the initial position as 0)
	-- hp is Mega Man's health, which goes from 0 to 16 
	-- Rightmost is the position far to the right reached (-DiffRightmost is used to standardize the initial position as 0)
	-- Score is computed based on how many Mega Man shots hit the enemies
	local fitness = (3 * (Rightmost - DiffRightmost)) + (100 * Score) + (-20 * (16 - hp))
	return fitness
end