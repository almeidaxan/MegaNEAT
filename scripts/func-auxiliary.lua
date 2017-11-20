--- [func-auxiliary.lua]
-- Contains auxiliary functions that do not fall on other categories

-- Destroys a form
function destroyForm()
	forms.destroy(form)
end

-- Returns a color based on a numeric input
function getColor(inputValue)
	local color

	inputValue = math.ceil(inputValue)

	if inputValue == 1 then
		color = 0xFFFFFFFF -- White
	elseif inputValue == 2 then
		color = 0xFFFF0000 -- Red
	elseif inputValue == 3 then
		color = 0xFFFFFF00 -- Yellow
	elseif inputValue == 4 then
		color = 0xFFFF00FF -- Magenta
	elseif inputValue == 5 then
		color = 0xFF0000FF -- Blue
	else
		color = 0xFF000000 -- Black
	end

	return color
end

-- Search for a specific value inside of a table/vector
function hasValue(tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return 1
		end
	end

	return 0
end

-- Sigmoid function
function sigmoid(x)
	return 2 / (1 + math.exp(-4.9 * x)) - 1
end
