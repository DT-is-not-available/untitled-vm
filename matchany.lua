return function(str, patterns)
	local i = 1
	local n = #patterns
	return function()
		while i <= n do
			local match = {string.match(str, patterns[i])}
			if #match > 0 then
				i = i + 1
				return i-1, unpack(match)
			else
				i = i + 1
			end
		end
		return nil
	end
end