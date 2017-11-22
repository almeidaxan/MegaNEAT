--- [func-auxiliary.lua]
-- Contains auxiliary functions that do not fall on other categories

-- Destroys a form
function destroyForm()
	forms.destroy(form)
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
