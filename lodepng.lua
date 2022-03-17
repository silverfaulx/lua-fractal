local ffi = require "ffi"
local mod = {}

local lodepng
do
	--local lodepngh = io.open(".\\lodepng.i")
	--ffi.cdef(lodepngh:read("*a"):gsub())
	ffi.cdef([[
	unsigned lodepng_decode32_file(unsigned char** out, unsigned* w, unsigned* h,
                               const char* filename);
	const char* lodepng_error_text(unsigned code);
	unsigned lodepng_encode32_file(const char* filename,
                               const unsigned char* image, unsigned w, unsigned h);
	]])
	--lodepngh:close()
	lodepng = ffi.load("C:\\Users\\goldi\\Documents\\why\\gltest\\lodepng.dll")
end

function mod.load(path)
	local pwidth, pheight = ffi.new("unsigned int[1]"), ffi.new("unsigned int[1]")
	local image = ffi.new("unsigned char*[1]")
	local err = lodepng.lodepng_decode32_file(image, pwidth, pheight, path)
	if err ~= 0 then error(ffi.string(lodepng.lodepng_error_text(err))) end
	return {t = image[0], w = tonumber(pwidth[0]), h = tonumber(pheight[0])}
end

function mod.encode(path, data, width, height)
	print("here")
	print(path, data, width, height)
	local err = lodepng.lodepng_encode32_file(path, data, width, height)
	if err ~= 0 then error(ffi.string(lodepng.lodepng_error_text(err))) end
	return true
end

mod.lib = lodepng

return mod