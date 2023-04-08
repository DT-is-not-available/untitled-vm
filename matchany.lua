return function(str, patterns)
	local i = 0
	
	return function()
		local next_start = i + 1
		local nearest_match
		local pattern_index = 0
		local groups = {}
		local matched = false
		for index, value in ipairs(patterns) do
			local pattern = value:gsub("%d+:%(", "("):gsub(" +", ""):gsub("%%_", " ")
			-- print(pattern)
			local st, en = str:find(pattern, i+1)
			-- print(pattern, st, en)
			if st and st > i and (not nearest_match or st < nearest_match) then
				nearest_match = st
				next_start = en
				local matched_groups = {str:sub(st, en):match(pattern)}
				-- print(unpack(matched_groups))
				local group_indexes = {}
				local g_index = 0
				for index, colon in value:gmatch("(%d*)(:?)%(") do
					if #index > 0 and #colon > 0 then
						g_index = assert(tonumber(index) - 1)
					end
					g_index = g_index + 1
					group_indexes[#group_indexes+1] = g_index
				end
				groups = {}
				if #group_indexes > 0 then
					for _, group in ipairs(matched_groups) do
						groups[group_indexes[_]] = group
					end
				end
				pattern_index = index
				matched = true
			end
		end
		i = next_start
		if matched then
			return pattern_index, unpack(groups, 1, table.maxn(groups))
		end
	end
end