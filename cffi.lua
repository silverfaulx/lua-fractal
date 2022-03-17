local ffi = require "ffi"

local mod = {}
local st = os.tmpname()
local iter = 0


function mod.compileRaw(dec, script, extras)
	iter = iter + 1
	local errs = os.tmpname()
	local err = io.open(errs, "w"):close()
	local tos = os.tmpname()
	local to = io.open(tos, "w"):close()
	local codes = "csource.c"
	io.open(codes, "w"):write(script):close()
	io.flush()
	local p = io.popen("gcc -shared -O3 " .. (extras or "") .. " -o helpme"..iter..".dll " .. codes .. "" .. " 2> " .. errs, "r")
	while p do
		local l = p:read("*l")
		if l then print(l) else break end
	end
	
	--print(io.open(tos .. ".dll", "r"):read("*a"))
	
	local errtext = io.open(errs, "r"):read("*a")
	if errtext ~= "" then
		error("you suck: " .. errtext)
	end
	
	ffi.cdef(dec:sub(#dec, #dec) == ";" and dec or dec .. ";")
	
	return ffi.load("helpme" .. iter)
end


return mod