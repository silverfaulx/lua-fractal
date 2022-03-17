return function()
	local cnt = 0
	return {
		Point = function(x, y)
			return ([[
				point = vec2(x, y);
			]]):gsub("x", x):gsub("y", y)
		end,
		Custom = function(s)
			return ([[
				point = vec2(WCEWCW);
			]]):gsub("WCEWCW", s)
		end
	}
end

--[[
cool custom orbit traps:
sin(zi), sin(zr): SAUSAGEBROT
zr / zi, zr / zi: kinda weird thing
]]