local lj_glfw = require "glfw3"
local ffi = require "ffi"
local bit = require "bit"
local gmp = require("gmp")("libgmp-10")
local rand, min, max, floor, log, abs = math.random, math.min, math.max, math.floor, math.log, math.abs

local width, height = 1000, 1000
local DOUBLEMODE = false--dont use this, gpus hate doubles and the whole thing seems to compile but doesnt work at all on my machine

--my attempts at trying to somewhat seperate stuff out so i dont have to scroll through one big file every time somethings not working
local lodepng = require(".\\lodepng.lua")
local OrbitTraps = require(".\\orbittraps.lua")()
local cffi = require("cffi")


--craziness, seed, isdark; or nil
--818429, 52105; craziness: 0.2, seed: 499072, isdark: 1; craziness: 0.2, seed: 468010, isdark: 0; 0.2, 123, 0; PINK AND YELLOW craziness: 0.2, seed: 292976, isdark: 0
local colorparams = {0.2, 292976, 0}--comment this line out if you want it to use a random color pallete

--print(lodepng.load("kurumi.png").w)--test

--mandelbrot, pmandelbrot, cmandelbar, shatteredheart, heart, pburningship, buffalo?, buffalo, cheart, quasiheart3rd+others, falsequasiheart4th
--quasiheart5th, quasiburningship5th, bship, trigsin, TEST, funky, funky2, cbship, partialcbshipi, cmandelbrot, mandelbrot4th, bshiptrue

local fractal = "mandelbrot"

--filepath or ""
local texture, smoothtex = "boobs.png", true
--texture-specific uniform: luaswag
local luaswagg = [[d = d * rotate(luaswag)]] --funny thing to do with textures, ex. d *= sin(u_time)
--extra functions pasted right before main() im lazy sorry
local extras = [[
mat2 rotate(float theta) {
	float c = cos(theta), s = sin(theta);
	return mat2(
		c, -s,
		s, c
	);
}
]]
--true or false
local orbitTrap = true
--valid ones: OrbitTraps.Point(re, im), OrbitTraps.Cross(re, im), OrbitTraps.Custom("equation for re, equation for im") ex: OrbitTraps.Custom("sin(zi), sin(zr)"); if multiple are used, then the distance is the minimum from all of them
--local orbitParams = {OrbitTraps.Point(0.4, 0.7)}
--pretty good: OrbitTraps.Custom([[-zr, -zi]]), [[d = d * rotate(luaswag)]]
local orbitParams = {OrbitTraps.Custom([[-zr, -zi]])} 
--orbit trap must be true to use texture; use "" for no texture

local textures = {} --loaded textures
local fractals = { --hardcode for the above fractals
	TEST = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = 2. * zr * zi + y;
    i++;
	]],
	mandelbrot = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = 2. * tzr * zi + y;
    i++;
	]],
	trigsinbship2 = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(-2. * abs(zi) * zr) + x;
    zi = cos(tzr * tzr + zi * zi) * sinh(-2. * abs(zi) * tzr) + y;
    i++;
	]],
	bshiptrue = [[
	float tzr = zr;
	zr = zr*zr - zi*zi + x;
	zi = abs(tzr * zi) * -2. + y;
	i++;
	]],
	shatteredheart = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = -2. * tzr * zi + y;
    i++;
	]],
	trigmasts = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(zi * zr) + x;
    zi = -2. * abs(cos(tzr * tzr + zi * zi)) * sinh(zi * tzr) + y;
    i++;
	]],
	attemptattrigstuff = [[
	float tzr = zr;
	float zisqr = zi*zi;
	float zrsqr = zr*zr;
    zr = sin(zrsqr * zrsqr + zisqr * zisqr - 6. * zrsqr * zisqr) * cosh(4. * tzr * zi * (zrsqr - zisqr)) + x;
    zi = -2. * abs(cos(zrsqr * zrsqr + zisqr * zisqr - 6. * zrsqr * zisqr) * sinh(4. * tzr * zi * (zrsqr - zisqr))) + y;
    i++;
	]], --supposed to be sin(z) + c for 4th power burning ship or something, but it seems too close to the original
	mandelbrot4th = [[
    float tzr = zr;
	float zisqr = zi*zi;
	float zrsqr = zr*zr;
    zr = zrsqr * zrsqr + zisqr * zisqr - 6. * zrsqr * zisqr + x;
    zi = 4. * tzr * zi * (zrsqr - zisqr) + y;
    i++;
	]],
	trigsintrue = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(2. * zi * zr) + x;
    zi = cos(tzr * tzr + zi * zi) * sinh(2. * zi * tzr) + y;
    i++;
	]],
	hearts = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(2. * zi * zr) + x;
    zi = -2. * abs(cos(tzr * tzr + zi * zi)) * sinh(2. * zi * tzr) + y;
    i++;
	]], --attempt at trigsinpmandelbrot
	pmandelbrot = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = -2. * abs(tzr) * zi + y;
    i++;
	]],
	["trigsinbship"] = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(2. * zi * zr) + x;
    zi = abs(cos(tzr * tzr + zi * zi) * sinh(2. * zi * tzr)) * -2. + y;
    i++;
	]],
	trigsin = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(2. * zi * zr) + x;
    zi = cos(tzr * tzr + zi * zi) * sinh(2. * zi * tzr) + y;
    i++;
	]],
	funnytest = [[
	float tzr = zr;
    zr = sin(zr * zr + zi * zi) * cosh(-2. * abs(zi * zr)) + x;
    zi = cos(tzr * tzr + zi * zi) * sinh(-2. * zi * zr) + y;
    i++;
	]],
	bship = [[
	float tzr = zr;
	zr = zr*zr - zi*zi + x;
	zi = abs(zr * zi) * -2. + y;
	i++;
	]],
	cmandelbrot = [[
    float tzr = zr;
    zr = (zr*zr - (zi*zi*3.)) * zr + x;
    zi = ((tzr*tzr * 3.) - zi*zi) * zi + y;
    i++;
	]],
	partialcbshipi = [[
    float tzr = zr;
    zr = (zr*zr - (zi*zi * 3.)) * zr + x;
    zi = ((tzr*tzr * 3.) - zi*zi) * abs(zi) + y;
    i++;
	]],
	cbship = [[
    float tzr = zr;
    zr = (zr*zr - (zi*zi * 3.)) * abs(zr) + x;
    zi = ((tzr*tzr * 3.) - zi*zi) * abs(zi) + y;
    i++;
	]],
	paintings = [[
	float zisqr = zi*zi;
	float zrsqr = zr*zr;
	float zisqrsqr = zisqr * zisqr;
	float zrsqrsqr = zrsqr * zrsqr;
	float zrzisqr = zrsqr * zisqr;
	float tzr = zr;
	zr = (zrsqr * zisqr + zrsqrsqr / 2.) / (2. - zrsqr * zisqr / 20.) - x;
	zi = (2. * tzr * zi) - y;
	i++;
	]],
	funky2 = [[
	float tzr = zr;
	zr = (zr * zr - zi * zi) - 1. - x;
	zi = -2. * tzr * zi - y;
	i++;
	]],
	funky = [[
	float tzr = zr;
	zr = (zr * zr - zi * zi) - 1. - x;
	zi = 2. * tzr * zi - y;
	i++;
	]],
	cmandelbar = [[
    float tzr = zr;
    zr = abs(zr * zr - zi * zi) + x;
    zi = -2. * tzr * zi + y;
    i++;
	]],
	heart = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = 2. * abs(tzr) * zi + y;
    i++;
	]],
	pburningship = [[
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = -2. * tzr * abs(zi) + y;
    i++;
	]],
	["buffalo?"] = [[
    float tzr = zr;
    zr = abs(zr * zr - zi * zi) + x;
    zi = 2. * abs(tzr) * abs(zi) + y;
    i++;
	]],
	buffalo = [[
    float tzr = zr;
    zr = abs(zr * zr - zi * zi) + x;
    zi = -2. * abs(tzr) * abs(zi) + y;
    i++;
	]],
	cheart = [[
    float tzr = zr;
    zr = abs(zr * zr - zi * zi) + x;
    zi = 2. * abs(tzr) * zi + y;
    i++;
	]],
	quasiheart3rdspiky = [[
    float tzr = zr;
    zr = (zr * zr - (zi*zi*3.)) + x;
    zi = abs((zr*zr*3.)-zi*zi) * zi + y;
    i++;
	]],
	quasiheart3rdweird = [[
    float tzr = zr;
    zr = (zr * zr - (zi*zi*3.)) * abs(zr) + x;
    zi = abs((zr*zr*3.)-zi*zi) * zi + y;
    i++;
	]],
	quasiheart3rd = [[
    float tzr = zr;
    zr = (zr * zr - (zi*zi*3.)) * abs(zr) + x;
    zi = abs((tzr*tzr*3.)-zi*zi) * zi + y;
    i++;
	]],
	quasiheart3rdcrazy = [[
    float tzr = zr;
    zr = (zr * zr - (zi*zi*3.)) * abs(zr) + x;
    zi = abs((zr*zr*3.)-zi*zi) * zi * zi + y;
    i++;
	]],
	falsequasiheart4th = [[
    float tzr = zr;
    zr = zr*zr*zr*zr + zi*zi*zi*zi - 6. * zr*zr*zi*zi + x;
    zi = 4. * tzr * zi * abs(tzr*tzr - zi*zi) + y;
    i++;
	]],
	quasiheart5th = [[
	float zisqr = zi*zi;
	float zrsqr = zr*zr;
	float zisqrsqr = zisqr * zisqr;
	float zrsqrsqr = zrsqr * zrsqr;
	float zrzisqr = zrsqr * zisqr;
    //float tzr = zr;
    zr = abs(zr) * (zrsqrsqr - 10. * zrzisqr + 5. * zisqrsqr) + x;
    zi = zi * abs(5. * zrsqrsqr - 10. * zrzisqr + zisqrsqr) + y;
    i++;
	]],
	quasiburningship5th = [[
	float zisqr = zi*zi;
	float zrsqr = zr*zr;
	float zisqrsqr = zisqr * zisqr;
	float zrsqrsqr = zrsqr * zrsqr;
	float zrzisqr = zrsqr * zisqr;
    //float tzr = zr;
    zr = abs(zr) * (zrsqrsqr - 10. * zrzisqr + 5. * zisqrsqr) + x;
    zi = -abs(zi * (5. * zrsqrsqr - 10. * zrzisqr + zisqrsqr)) + y;
    i++;
	]],
}

if not fractals[fractal] then error(fractal .. " isnt here") end

local title = {fractal, "", "float mode"} --fractal name, julia set, idk

--[[main glsl code]]local stcode = [[ 
#version 420
#ifdef GL_ES
precision highp float;
#endif
#define MAX_ITER 1000
#define COLORS 1000
#define product(a, b) vec2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x)
#define conjugate(a) vec2(a.x,-a.y)
#define divide(a, b) vec2(((a.x*b.x+a.y*b.y)/(b.x*b.x+b.y*b.y)),((a.y*b.x-a.x*b.y)/(b.x*b.x+b.y*b.y)))
#define AA /*LUAAA*/
//LUAFILLER
uniform vec2 u_resolution;
uniform float u_time;
uniform float zoom;
uniform float xo;
uniform float yo;
uniform float[COLORS * 3] pal;
#ifdef TEXTURE
uniform float luaswag;
uniform sampler2D tex;
#endif
//LUAEXTRAS
void main(){
  float x = (gl_FragCoord.x / u_resolution.x - 0.5) / zoom + xo;
  float y = (gl_FragCoord.y / u_resolution.y - 0.5) / zoom + yo;
  float zr = x, zi = y;
  #ifdef ORBIT
  
	  #ifdef TEXTURE
	  vec2 d = vec2(1000000., 1000000.);
	  #else
	  float d = 1000000.;
	  #endif
	  
  vec2 point;
  #endif
  int i = 0;
  while(i < MAX_ITER) {
  	if(zr * zr + zi * zi >= 4.) { break; }

  /*
    if(zr * zr + zi * zi >= 4.) { break; }
    float tzr = zr;
    zr = zr * zr - zi * zi + x;
    zi = 2. * tzr * zi + y;
    i++;
*/
//LUAEQ
	#ifdef ORBIT
	
	//LUAORBIT
	
	#endif
  }
  vec3 col;
  #ifndef ORBIT
  if (i < MAX_ITER) {
	float log_zn = log(zr * zr + zi * zi) / 2.;
	float nu = log(log_zn / log(2.)) / log(2.);
	float i2 = float(i) + 1. - nu;
	vec3 c1 = vec3(pal[int(floor(i2)*3)], pal[int(floor(i2)*3+1)], pal[int(floor(i2)*3+2)]);
	vec3 c2 = vec3(pal[int(floor(i2+1)*3)], pal[int(floor(i2+1)*3+1)], pal[int(floor(i2+1)*3+2)]);
	float r = fract(i2);
	float r2 = abs(1. - r);
	col = mix(c1, c2, r);
  } else {
	col = vec3(0., 0., 0.);
  }
  //gl_FragColor = i == MAX_ITER ? vec4(0., 0., 0., 1.) : vec4(pal[i*3], pal[i*3+1], pal[i*3+2], 1.);
  gl_FragColor = vec4(col, 1.);
  #else
	  #ifdef TEXTURE
	  if (i < MAX_ITER) {
		#ifdef TEXSMOOTH
		float log_zn = log(zr * zr + zi * zi) / 2.;
		float nu = log(log_zn / log(2.)) / log(2.);
		float i2 = float(i) + 1. - nu;
		float r = fract(i2);
		/*LUASWAGG*/;
		//gsubbed here: IMAGE_WIDTH, IMAGE_HEIGHT
		vec2 uv = fract(d);
		uv.x += floor(i2) / MAX_ITER / IMAGE_WIDTH;
		uv.y += (floor(i2) / MAX_ITER + 1) / IMAGE_HEIGHT;
		vec3 c1 = texture(tex, fract(d)).rgb;
		vec3 c2 = texture(tex, uv).rgb;
		col = mix(c1, c2, r);
		#else
		/*LUASWAGG*/;
		col = texture(tex, fract(d)).rgb;
		#endif
	  } else {
		col = vec3(0., 0., 0.);
	  }
	  #else
	  float i2 = d;
	  if (i < MAX_ITER) {
		vec3 c1 = vec3(pal[int(floor(i2)*3)], pal[int(floor(i2)*3+1)], pal[int(floor(i2)*3+2)]);
		vec3 c2 = vec3(pal[int(floor(i2+1)*3)], pal[int(floor(i2+1)*3+1)], pal[int(floor(i2+1)*3+2)]);
		col = mix(c1, c2, fract(d));
		//col = vec3(d, d, d);
		//col = texelFetch(texture, gl_FragCoord.x/u_resolution.x * TEXTURE_SIZE).xyz;
	  } else {
		col = vec3(0., 0., 0.);
	  }
	  //gl_FragColor = i == MAX_ITER ? vec4(0., 0., 0., 1.) : vec4(pal[i*3], pal[i*3+1], pal[i*3+2], 1.);
	  
	  #endif
  #endif
  gl_FragColor = vec4(col, 1.);
}
]]

--[[main c double code]]local ccode = [[
#include <stdio.h>
#include <math.h>
//LUAFILLER
int fractal(const double xo, const double yo, const double zoom, const double* pal, float* colors) {
int total = 0;
for(int ys = 0; ys < height; ys++) {
	for(int xs = 0; xs < width; xs++) {
		double x = ((double) xs / height - 0.5) / zoom + xo, y = ((double) ys / width - 0.5) / zoom + yo;
		int i = 0;
		double zr = x, zi = y;
		while(i < MAX_ITER) {
			if(zr*zr+zi*zi >= 4) { break; }
			/*
			double tzr = zr;
			zr = zr * zr - zi * zi + x;
			zi = 2. * tzr * zi + y;
			i++;
			*/
			//LUAEQ
		}
		if(i == MAX_ITER) {
		colors[total * 3 + 0] = 0.;
		colors[total * 3 + 1] = 0.;
		colors[total * 3 + 2] = 0.;
		//colors[total * 4 + 3] = 255.;
		} else {
		//printf("here cunt\n");
		double log_zn = log10(abs(zr*zr+zi*zi)) / 2.;
		double nu = log10(log_zn / log10(2.)) / log10(2.);
		double i1;
		i1 = (double) (i + 1. - nu);
		int index = floor(i1) * 3;
		int index2 = index + 3;
		//printf("%i\n", index);
		//printf("%i\n", index2);
		double i;
		double r = modf(i1, &i);
		double r2 = 1 - r;
		//printf("%f, %f\n", r, i);
		//printf("%f", pal[index]);
		colors[total*3] = (pal[index] * r2 + pal[index2] * r);
		colors[total*3+1] = (pal[index+1] * r2 + pal[index2+1] * r);
		colors[total*3+2] = (pal[index+2] * r2 + pal[index2+2] * r);
		//colors[total * 4 + 3] = 255;
		//printf("done\n");
		}
		total++;
	}
}
printf("%i\n", total);
return 1;
}
]]

--[[renderer of the c output code]]local pngcode = [[
#version 420
#ifdef GL_ES
precision highp float;
#endif
uniform vec2 u_resolution;
uniform float u_time;
uniform float oxo;
uniform float oyo;
uniform float oz;
uniform sampler2D tex;
void main() {
	gl_FragColor = texture(tex, ((gl_FragCoord.xy / u_resolution - 0.5) / oz) + vec2(oxo, oyo) + vec2(0.5));
}
]]

--[[old lua code here
--b&w
local args = {...}
local width, height, total, xo, yo, zoom = args[1], args[2], 0, args[3], args[4], args[5]
local colors = ffi.new("float[" .. width * height * 3 .. "]")
local total = 0
for ys = 0, height-1 do
	for xs = 0, width-1 do
		local x, y = (xs / width - 0.5) / zoom + xo, (ys / height - 0.5) / zoom + yo
		local zr, zi, i = x, y, 0
		while i < MAX_ITER do
			if (zr*zr + zi*zi > 4) then break end
			zr, zi, i = zr * zr - zi * zi + x, 2 * zr * zi + y, i+1
		end
		if i == MAX_ITER then
			colors[total*3] = 0
			colors[total*3+1] = 0
			colors[total*3+2] = 0
		else
			colors[total*3] = 1
			colors[total*3+1] = 1
			colors[total*3+2] = 1
		end
		total = total + 1
	end
end

return colors
--old lua color code below
local args = {...}
local width, height, total, xo, yo, zoom = args[1], args[2], 0, args[3], args[4], args[5]
local log, abs, floor = math.log, math.abs, math.floor
local colors = ffi.new("float[" .. width * height * 3 .. "]")
local total = 0
for ys = 0, height-1 do
	for xs = 0, width-1 do
		local x, y = (xs / width - 0.5) / zoom + xo, (ys / height - 0.5) / zoom + yo
		local zr, zi, i = x, y, 0
		while i < MAX_ITER do
			if (zr*zr + zi*zi > 4) then break end
			zr, zi, i = zr * zr - zi * zi + x, 2 * zr * zi + y, i+1
		end
		if i == MAX_ITER then
			colors[total*3] = 0
			colors[total*3+1] = 0
			colors[total*3+2] = 0
		else
			local log_zn = log(zr*zr+zi*zi) / 2
			local nu = log(log_zn / log(2)) / log(2)
			local i2 = i + 1 - nu
			local r = i2 % 1
			local r2 = 1 - r
			local index = floor(i2) * 3
			local index2 = index + 3
			colors[total*3] = (pal[index] * r2 + pal[index2] * r)
			colors[total*3+1] = (pal[index+1] * r2 + pal[index2+1] * r)
			colors[total*3+2] = (pal[index+2] * r2 + pal[index2+2] * r)
		end
		total = total + 1
	end
end

return colors
]]

--[[lua perturbation theory test]]local ptest = [[
--defined by environment: gmp, pallete
--gsubbed: MAX_ITER
--xo, yo, and zoom are all mpf()s
local args = {...}
local width, height, total, xo, yo, zoom, xr, xi = args[1], args[2], 0, args[3], args[4], args[5], args[6] or 0, args[7] or 0
print("xo, yo, zoom: ", gmp.f_get_d(xo), gmp.f_get_d(yo), gmp.f_get_d(zoom))
local log, abs, floor = math.log, math.abs, math.floor
local colors = ffi.new("float[" .. width * height * 3 .. "]")
local total = 0
local mpf = gmp.types.f
local radius
do
	local r = mpf()
	gmp.f_init(r)
	local cum = mpf()
	gmp.f_init_set_d(cum, 1)
	gmp.f_div(r, cum, zoom)
	radius = gmp.f_get_d(r)
end
print(radius)
--local radius = 1 / gmp.f_get_d(zoom)

local refZR, refZI, refI = mpf(), mpf(), {}
do
	gmp.f_init_set_d(refZR, 0) gmp.f_init_set_d(refZI, 0)
	local zrsqr, zisqr, zadd = mpf(), mpf(), mpf()
	local zrt = mpf() gmp.f_init(zrt)
	local zit = mpf() gmp.f_init(zit)
	gmp.f_init_set_d(zrsqr, 0)
	gmp.f_init_set_d(zisqr, 0)
	gmp.f_init_set_d(zadd, 0)
	local i = 0
	local x, y = mpf(), mpf()
	gmp.f_init(x) gmp.f_init(y)
	--gmp.f_div(x, xo, zoom)
	--gmp.f_div(y, yo, zoom)
	--[=[
	do
		local ad = mpf()
		gmp.f_init_set_d(ad, 0.3)
		gmp.f_add(x, x, ad)
		local ad2 = mpf()
		gmp.f_init_set_d(ad2, 0.3)
		gmp.f_add(y, y, ad2)
	end]=]
	
	--gmp.f_div(x, x, zoom)
	--gmp.f_div(y, y, zoom)
	gmp.f_add(x, x, xo)
	gmp.f_add(y, y, yo)
	
	while i < MAX_ITER do
		gmp.f_mul(zrsqr, refZR, refZR)
		gmp.f_mul(zisqr, refZI, refZI)
		gmp.f_add(zadd, zrsqr, zisqr)
		if gmp.f_cmp_d(zadd, 4) > 0 then break end
		gmp.f_sub(zrt, zrsqr, zisqr)
		gmp.f_mul(zit, refZR, refZI)
		gmp.f_mul_ui(zit, zit, 2)
		gmp.f_add(refZI, zit, y)
		gmp.f_add(refZR, zrt, x)
	--	local zr, zi = mpf(), mpf()
	--	gmp.f_init_set(zr, refZR)
	--	gmp.f_init_set(zi, refZI)
		refI[i*2] = gmp.f_get_d(refZR)
		refI[i*2+1] = gmp.f_get_d(refZI)
		i = i + 1
	end
	print("length of refI: ", #refI)
	if i ~= MAX_ITER then
		print("point escapes, filling with zeroes :3")
		for j = i*2, MAX_ITER*2-1 do
			refI[j] = 0
		end
	end
end
--print(table.concat(refI, ", "))

for xs = 0, height-1 do
	for ys = 0, width-1 do
		local dre = (radius * (2 * ys - height)) / height
		local dim = (-radius * (2 * xs - width)) / width
		local dre2 = ((radius * (2 * ys - height)) / height) - dre 
		local dre2 = ((radius * (2 * xs - width)) / width) - dim
		local zr = radius * (2 * ys - height) / height
		local zi = -radius * (2 * xs - width) / width
		local i = 0
		local zro, zio = zr + refI[0], zi - refI[1]
		--print(zr, zi, i)
		while i < MAX_ITER do
			if (zr*zr + zi*zi > 4) then break end
			--zr, zi, i = zr * (refI[i*2] + zr) + zro, zi * (refI[i*2+1] + zi) + zio, i+1
			--zr = zr * (zr*refI[i*2] - zi * refI[i*2+1]) + zro
			--zi = zi * 2 * (zi * refI[i*2] + zi * refI[i*2+1]) + zio
			zr, zi = zr*refI[i*2] + zr*zr - zi*refI[i*2+1] - zi*zi + zro, zr*refI[i*2+1] + 2*zr*zi + zi*refI[i*2] + zio
			i = i + 1
		end
		
		--[=[math reasoning here i think
		dn = dn * refI[i] + dn;
		dn = dn + d0;
		(zr, zi) = (zr, zi) * (refZR, refZI) + (zro, zio)
		zr = zr * (zr*refI[i*2] - zi * refI[i*2+1]) + zro
		zi = zi * 2 * (
		
		(zr + zi)(refZR + refZI)
		
		zr * refZR + 
		zr * refZI + 
		zi * refZR + 
		zi * refZI
		
		(zr, zi) = (zr, zi)(zr, zi) + (zro, zio)
		
		(zr + zi)(zr + zi)
		zr*zr + zr*zi + zi*zr + zi*zi
		zr*zr + zi*zi + 2*zr*zi
		]=]
		
		if i == MAX_ITER then
			colors[total*3] = 0
			colors[total*3+1] = 0
			colors[total*3+2] = 0
		else
			local log_zn = log(zr*zr+zi*zi) / 2
			local nu = log(log_zn / log(2)) / log(2)
			local i2 = i + 1 - nu
			local r = i2 % 1
			local r2 = 1 - r
			local index = floor(i2) * 3
			local index2 = index + 3
			colors[total*3] = (pal[index] * r2 + pal[index2] * r)
			colors[total*3+1] = (pal[index+1] * r2 + pal[index2+1] * r)
			colors[total*3+2] = (pal[index+2] * r2 + pal[index2+2] * r)
		end
		total = total + 1
	end
end
--[=[
for ys = 0, height-1 do
	for xs = 0, width-1 do
		local x, y = (xs / width - 0.5) / zoom + xo, (ys / height - 0.5) / zoom + yo
		local zr, zi, i = x, y, 0
		while i < MAX_ITER do
			if (zr*zr + zi*zi > 4) then break end
			zr, zi, i = zr * zr - zi * zi + x, 2 * zr * zi + y, i+1
		end
		if i == MAX_ITER then
			colors[total*3] = 0
			colors[total*3+1] = 0
			colors[total*3+2] = 0
		else
			local log_zn = log(zr*zr+zi*zi) / 2
			local nu = log(log_zn / log(2)) / log(2)
			local i2 = i + 1 - nu
			local r = i2 % 1
			local r2 = 1 - r
			local index = floor(i2) * 3
			local index2 = index + 3
			colors[total*3] = (pal[index] * r2 + pal[index2] * r)
			colors[total*3+1] = (pal[index+1] * r2 + pal[index2+1] * r)
			colors[total*3+2] = (pal[index+2] * r2 + pal[index2+2] * r)
		end
		total = total + 1
	end
end
]=]
return colors
]]

local code = stcode
local stcode2 = stcode

--[[zr, zi value tester(uncomment if needed i guess) do
local mi = 1000
local list = {}
local x, y = 0.3, 0
local zr, zi, i = 0, 0, 0
while i < mi do
	if (zr*zr + zi*zi > 4) then break end
	list[i*2] = zr
	list[i*2+1] = zi
	zr, zi, i = zr * zr - zi * zi + x, 2 * zr * zi + y, i+1
end
print(table.concat(list, ", "))
end]]

--[=[
if DOUBLEMODE then
	--code = code:gsub("main%(%).$", "double")
	code = code:gsub("float", "double")
	code = code:gsub("//LUAFILLER", [[
#define log(n) log(float(n))
//LUAFILLER
	]])
	code = code:gsub("vec3", "dvec3")
	code = code:gsub("uniform double", "uniform float")
	--code = code:gsub("log%(.+%)", "log(float(")
end]=]
--[[
if fractal == "mandelbrot" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "pmandelbrot" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "cmandelbar" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "shatteredheart" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "heart" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "pburningship" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "buffalo?" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "buffalo" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "cheart" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiheart3rdspiky" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiheart3rdweird" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiheart3rd" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiheart3rdcrazy" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "falsequasiheart4th" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiheart5th" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "quasiburningship5th" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "TEST" then
	code = code:gsub("//LUAEQ", )
elseif fractal == "bship" then
	code = code:gsub("//LUAEQ", )
end
]]
--[[
int i;
float zr, zi;
zr, zi = sin(zr) * cosh(zi), cos(zr) * sinh(zi)

float tzr = zr;
zr = zr * zr - zi * zi + x;
zi = 2. * tzr * zi + y;
i++;

--failed sin(z) + c
float tzr = zr;
    zr = sin(zr * zr) * cosh(zi * zi) + x;
    zi = 2. * cos(tzr * tzr) * sinh(zi * zi) + y;
    i++;
	
	
--click a pixel to create a julia set of that pixel
--some key to switch it to double mode for a single render
--another key to (maybe) switch it to gmp mode for a single render
]]
local gl, glc, glu, glfw, glext = lj_glfw.libraries()

lj_glfw.init()
local window = lj_glfw.Window(width, height, "LuaJIT-GLFW Test")

-- Initialize the context. This needs to be called before any OpenGL calls.
window:makeContextCurrent()

--[[
gl.glEnable(glc.GL_DEBUG_OUTPUT)
glext.glDebugMessageCallback(function(source, typ, id, severity, length, message, userparam)
	local sev = ""
	if severity == glc.GL_DEBUG_SEVERITY_HIGH then
		sev = "high"
	elseif severity == glc.GL_DEBUG_SEVERITY_MEDIUM then
		sev = "medium"
	elseif severity == glc.GL_DEBUG_SEVERITY_LOW then
		sev = "low"
	else
		sev = "other"
	end
	print(source, sev, ffi.string(message))
end, ffi.new("int[1]"))
]]
local w, h = window:getFramebufferSize()

local function getTexture(params, data, width, height) --get texture from c double stuff
	local tex = ffi.new("unsigned int[1]")
	gl.glGenTextures(1, tex)
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex[0])
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, glc.GL_CLAMP_TO_BORDER)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, glc.GL_CLAMP_TO_BORDER)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_LINEAR);
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_LINEAR);
	gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGB, width, height, 0, glc.GL_RGB, glc.GL_FLOAT, data)
	return tex[0]
end
local function getTexturePNG(png) --get texture from lodepng png
	local tex = ffi.new("unsigned int[1]")
	gl.glGenTextures(1, tex)
	gl.glBindTexture(glc.GL_TEXTURE_2D, tex[0])
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_S, glc.GL_CLAMP_TO_BORDER)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_WRAP_T, glc.GL_CLAMP_TO_BORDER)
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MIN_FILTER, glc.GL_LINEAR);
	gl.glTexParameteri(glc.GL_TEXTURE_2D, glc.GL_TEXTURE_MAG_FILTER, glc.GL_LINEAR);
	gl.glTexImage2D(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA, png.w, png.h, 0, glc.GL_RGBA, glc.GL_UNSIGNED_BYTE, png.t)
	return tex[0]
end
local zoom, xo, yo, re, im, sre, sim, funny, curC, cTex = 1, 0, 0, 0, 0, false, false, 0, false, false
local lpfunc = nil
local function c(n, min, max) --clamp function
	if n > max then return max
	elseif n < min then return min
	else return n end
end

local function remakepal(t, crazy, seed, dark, numcolors) --probably stupid way of making a color pallete but idc
dark = dark or 1
numcolors = numcolors or 1000
	print("craziness: " .. crazy .. ", seed: " .. seed .. ", isdark: " .. dark)
	if seed then math.randomseed(seed) end
	local pal = {}
	if dark == 1 then
	pal[0] = 0
	pal[1] = 0
	pal[2] = 0
	else
	pal[0] = rand()
	pal[1] = rand()
	pal[2] = rand()
	end
	for i = 3, numcolors*3-1, 3 do
		pal[i] = c(pal[i-3] + (rand() * 2 - 1) * crazy, 0, 1)
		pal[i+1] = c(pal[i-2] + (rand() * 2 - 1) * crazy, 0, 1)
		pal[i+2] = c(pal[i-1] + (rand() * 2 - 1) * crazy, 0, 1)
	end
	return ffi.new(t, pal), {crazy, seed, dark, numcolors}
end

local pal, palparams
if colorparams then
	pal, palparams = remakepal("float[3000]", table.unpack(colorparams))
else
	pal, palparams = remakepal("float[3000]", 0.2, math.random(1, 999999), math.random(0, 1))
	--pal = remakepal(ffi.new("float[3000]"), 0.2, 123, 0)
end




local function base() --dumb function to get default global whatever stuff idk
	return {double = DOUBLEMODE, orbitTrap = orbitTrap, orbitParams = orbitParams, fractal = fractal, height = height, width = width,
	xo = xo, yo = yo, zoom = zoom, pal = pal, texture = texture
	}
end
local function getCCode(params)
	local code, fractal = ccode, params.fractal
	code = code:gsub([[//LUAFILLER]], "#define width " .. width .. "\n#define height " .. height .. "\n#define MAX_ITER 1000" .. "\n//LUAFILLER")
	code = code:gsub([[//LUAEQ]], fractals[fractal]:gsub("float", "double"):gsub("abs", "fabs"))
	--print(code .. "\n\n")
	local cuw = cffi.compileRaw("int fractal(const double xo, const double yo, const double zoom, const double* pal, float* colors)", code)
	return cuw
	--lodepng.encode("C:\\Users\\goldi\\Documents\\why\\gltest\\test.png", colors, width, height)
end

local function runCCode(cuw, params)
	local colors = ffi.new("float[" .. params.height * params.width * 3 .. "]")
	local ret = cuw.fractal(params.xo, params.yo, params.zoom, params.pal, colors)
	print(params.width, params.height)
	local tex = getTexture(nil, colors, params.width, params.height)
	
	print(tex)
	return tex
end
local otex = false
--params: {double = true/nil, orbitTrap = true/nil, texture = 'texture'/nil, orbitParams = {list of orbit traps to be concatenated}, julia = true/nil}
local function getCode(params) --converts the base glsl code into the actual working code
	local code, fractal = stcode, params.fractal
	code = code:gsub("//LUAEXTRAS", extras)
	if params.orbitTrap then
		code = code:gsub("//LUAFILLER", [[
#define ORBIT 1
//LUAFILLER
		]])
		if params.texture and params.texture ~= "" then
			local textu
			if not textures[params.texture] then --load the texture
				textu = lodepng.load(params.texture)
				assert(textu, "failed to load texture " .. params.texture)
				textu[1] = getTexturePNG(textu)
			end
			local text = textures[params.texture]
			code = code:gsub("//LUAFILLER", [[
#define TEXTURE 1
//LUAFILLER
			]])
			local cuny = table.concat(params.orbitParams, [[
			d = min(d, abs(point - vec2(zr, zi)));
			]])
			code = code:gsub("/%*LUASWAGG%*/", luaswagg)
			code = code:gsub("//LUAORBIT", cuny:sub(1, #cuny-1))--idk why it needs the :sub(1, #cunt-1) but it does because theres a rogue 1 otherwise
			if smoothtex then
				print("beware the texture is smoothed or whatever")
				code = code:gsub("//LUAFILLER", [[
#define TEXSMOOTH 1
//LUAFILLER]])
				code = code:gsub("IMAGE_HEIGHT", tostring(textu.h))
				code = code:gsub("IMAGE_WIDTH", tostring(textu.w))
			end
			otex = text
			
		else
			local cunt = table.concat(params.orbitParams, [[
			d = min(d, abs(length(vec2(zr, zi) - point)));
			]])--make the code take the minimum of all provided orbit traps
			code = code:gsub("//LUAORBIT", cunt:sub(1, #cunt-1))--idk why it needs the :sub(1, #cunt-1) but it does because theres a rogue 1 otherwise
		end
	end
	
	if params.julia then --make the equation a julia set and also make re and im uniform floats
		code = code:gsub(
		"//LUAEQ",fractals[fractal]:gsub("x", "re"):gsub("y", "im")
			):gsub("//LUAFILLER", [[
			uniform float re;
			uniform float im;
			//LUAFILLER
			]])
	else
		code = code:gsub("//LUAEQ", fractals[fractal])--put the actual fractal code inside
	end
	
	if params.double then --logic for double mode i think, but dont use it
	--code = code:gsub("main%(%).$", "double")
	code = code:gsub("float", "double")
	code = code:gsub("//LUAFILLER", [[
#define log(n) log(float(n))
//LUAFILLER
	]])
	code = code:gsub("vec3", "dvec3")
	code = code:gsub("uniform double", "uniform float")
	end
	
	return code
end
--[[
	#version 420
	#ifdef GL_ES
	precision highp float;
	#endif
	#define MAX_ITER 1000
	#define COLORS 1000

	uniform vec2 u_resolution;
	uniform float u_time;
	uniform float zoom;
	uniform float xo;
	uniform float yo;
	uniform float[COLORS * 3] pal;
	void main() {
	  float zr = 0., zi = 0.;
	  float x = (gl_FragCoord.x / u_resolution.x - 0.5) / zoom + xo;
	  float y = (gl_FragCoord.y / u_resolution.y - 0.5) / zoom + yo;
	  int i = 0;
	  while(i < MAX_ITER) {
		if(zr * zr + zi * zi >= 4.) { break; }
		float tzr = zr;
		zr = zr * zr - zi * zi + x;
		zi = 2. * tzr * zi + y;
		i++;
	  }
	  
	  gl_FragColor = i == MAX_ITER ? vec4(0., 0., 0., 1.) : vec4(pal[i*3], pal[i*3+1], pal[i*3+2], 1.);
	}
	]]

local function getLCode(params)
	local code = ptest
	code = code:gsub("MAX_ITER", "1000")
	return code, {gmp = gmp, pal = params.pal, ffi = ffi, math = math, _G = _G, table = table, print = print}
end

local function recompileShaders(code)--compile the shaders and report any errors
	local shader = glext.glCreateShader(glc.GL_FRAGMENT_SHADER)
	local vshader = glext.glCreateShader(glc.GL_VERTEX_SHADER)
	glext.glShaderSource(shader, 1, ffi.new("const char*[1]", {
	code
	}), nil)
	glext.glShaderSource(vshader, 1, ffi.new("const char*[1]", {[[
	#version 330 core
	const vec2 quadVertices[4] = { vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0) };
	void main()
	{
		//texcoord = (quadVertices[gl_VertexID] + 1.) / 2.;
		gl_Position = vec4(quadVertices[gl_VertexID], 1.0, 1.0);
		
	}
	]]}), nil)
	glext.glCompileShader(shader)
	glext.glCompileShader(vshader)
	local s = ffi.new("int[1]", {0})
	glext.glGetShaderiv(shader, glc.GL_COMPILE_STATUS, s)
	if tostring(s[0]) == "0" then
		glext.glGetShaderiv(shader, glc.GL_INFO_LOG_LENGTH, s)
		local erlog = ffi.new("char[" .. s[0] .. "]")
		glext.glGetShaderInfoLog(shader, s[0], nil, erlog)
		error("failed to compile shader\nlog length: " .. tostring(s[0]) .. "\n\n" .. ffi.string(erlog) .. "\n\ncode:\n\n" .. code)
	end
	local program = glext.glCreateProgram()
	glext.glAttachShader(program, shader)
	glext.glAttachShader(program, vshader)
	glext.glLinkProgram(program)
	glext.glGetProgramiv(program, glc.GL_LINK_STATUS, s)
	if tostring(s[0]) == "0" then
		error("failed to link program")
	end
	return program
end



local useProgram = glext.glUseProgram

local uniform1f = glext.glUniform1f
local uniform2f = glext.glUniform2f
local uniform3f = glext.glUniform3f
local uniform4f = glext.glUniform4f
local uniform1i = glext.glUniform1i
local uniform1fv = glext.glUniform1fv
local getUniformLocation = glext.glGetUniformLocation



local istextured = false
local gltex, gltex2, tex
if texture ~= "" then
	istextured = true
	tex = lodepng.load(texture)
	code = code:gsub("//LUAFILLER", [[
	#define TEXTURE 1
	#define TEXTURE_SIZE ]] .. tex.w * tex.h .. [[
	uniform samplerBuffer texture;
	//LUAFILLER
	]])
	
	gltex = ffi.new("int[1]")
	gltex2 = ffi.new("int[1]")
	glext.glGenBuffers(1, gltex)
	glext.glBindBuffer(glc.GL_TEXTURE_BUFFER, gltex[0])
	glext.glBufferData(glc.GL_TEXTURE_BUFFER, ffi.sizeof(tex.t), tex.t, glc.GL_STATIC_DRAW)
	gl.glGenTextures(1, gltex2)
	glext.glBindBuffer(glc.GL_TEXTURE_BUFFER, 0)
	code = code:gsub("//LUAFILLER", [[
	#define TEXTURE 1
	//LUAFILLER
	]])
end

local program = recompileShaders(getCode(base()))



do
local t = base()
t.pal = remakepal("const double[3000]", 0.2, 123, 0)
print(getCCode(t))
end



local speed = 1
local dt = 0
local luaswag = 0
local function updateTitle()
	title[2] = "(julia, Re = " .. re .. ", Im = " .. im .. ")"
	window:setTitle(table.concat(title, " "))
end
local posx, posy, mousedebounce = 0, 0, true

window:setSizeCallback(function(window, w, h)
	width, height = w, h
end)
window:setCursorPosCallback(function(window, xpos, ypos)
	state = window:getMouseButton(glc.GLFW_MOUSE_BUTTON_2)--if holding right click, mess with re and im parameters for julia sets
	if state == glc.GLFW_PRESS then
		if not sre then
			sre, sim = re, im
		end
		re = sre + (xpos - height / 2) / height
		im = sim + (ypos - width / 2) / width
		updateTitle()
		--[[
		dirw = prevxpos - xpos
		prevxpos = xpos
		]]
		--dirw = xpos / width
	elseif state == glc.GLFW_RELEASE then
		sre, sim = false, false
	end
	--print("changing w", dirw)
		
	
	
	posx = xpos / width
	posy = ypos / height
	--print(posx, posy)
end)

local function split(s) --string split function
	local t = {}
	for token in string.gmatch(s, "[^%s]+") do
	   t[#t+1] = token
	end
	return t
end

local mpf, xr, xi = gmp.types.f, nil, nil
local oxo, oyo, oz
updateTitle()
while not window:shouldClose() do
	local fs = os.clock()
	do --keyboard logic, i dont wanna use callbacks for this
	local keyw = window:getKey(glc.GLFW_KEY_W)
	if keyw == glc.GLFW_PRESS then
		if oyo then oyo = oyo + (speed / oz) * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			gmp.f_div(spd, spd, zoom)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_add(yo, yo, spd)
			--print(yo)
			--print(gmp.f_get_str(nil, ffi.new("int"), 10, 0, yo))
		else
			yo = yo + (speed / zoom) * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_S)
	if keyw == glc.GLFW_PRESS then
		if oyo then oyo = oyo - (speed / oz) * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			gmp.f_div(spd, spd, zoom)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_sub(yo, yo, spd)
		else
			yo = yo - (speed / zoom) * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_A)
	if keyw == glc.GLFW_PRESS then
		if oxo then oxo = oxo - (speed / oz) * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			gmp.f_div(spd, spd, zoom)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_sub(xo, xo, spd)
		else
			xo = xo - (speed / zoom) * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_D)
	if keyw == glc.GLFW_PRESS then
		if oxo then oxo = oxo + (speed / oz) * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			gmp.f_div(spd, spd, zoom)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_add(xo, xo, spd)
		else
			xo = xo + (speed / zoom) * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_E)
	if keyw == glc.GLFW_PRESS then
		if oz then oz = oz + oz * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_add(zoom, zoom, spd)
		else
			zoom = zoom + zoom * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_Q)
	if keyw == glc.GLFW_PRESS then
		if oz then oz = oz - oz * dt end
		if funny == 2 then
			local spd = mpf()
			gmp.f_init_set_d(spd, speed)
			local dt2 = mpf()
			gmp.f_init_set_d(dt2, dt)
			gmp.f_mul(spd, spd, dt2)
			gmp.f_sub(zoom, zoom, spd)
		else
			zoom = zoom - zoom * dt
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_UP)
	if keyw == glc.GLFW_PRESS then
		im = im + (speed / zoom) * dt * 0.5
	end
	keyw = window:getKey(glc.GLFW_KEY_DOWN)
	if keyw == glc.GLFW_PRESS then
		im = im - (speed / zoom) * dt * 0.5
	end
	keyw = window:getKey(glc.GLFW_KEY_LEFT)
	if keyw == glc.GLFW_PRESS then
		re = re + (speed / zoom) * dt * 0.5
	end
	keyw = window:getKey(glc.GLFW_KEY_RIGHT)
	if keyw == glc.GLFW_PRESS then
		re = re - (speed / zoom) * dt * 0.5
	end
	keyw = window:getKey(glc.GLFW_KEY_R)
	if keyw == glc.GLFW_PRESS then
		zoom, xo, yo = 1, 0, 0
	end
	keyw = window:getKey(glc.GLFW_KEY_Z)
	if keyw == glc.GLFW_PRESS then
		print("z pressed")
		if funny == 0 then
			print("the funny is on")
			funny = 1
			local t = base()
			t.pal = remakepal("const double[3000]", table.unpack(colorparams))
			curC = getCCode(t)
			oxo, oyo, oz = 0, 0, 1
			cTex = runCCode(curC, t)
			
			program = recompileShaders(pngcode)
		elseif funny == 1 then
			local t = base()
			t.pal = remakepal("const double[3000]", table.unpack(colorparams))
			
			oxo, oyo, oz = 0, 0, 1
			cTex = runCCode(curC, t)
			print(xo, yo, zoom)
		--[[
		elseif funny == 1 then
			print("the funny is off")
			funny = 0
			io.read()
			curC = false
			cTex = false
			program = recompileShaders(getCode(base()))]]
		elseif funny == 2 then
			--make thing
			oxo, oyo, oz = 0, 0, 1
			cTex = getTexture(nil, curC(width, height, xo, yo, zoom, xr, xi), width, height)
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_ENTER) --commands
	if keyw == glc.GLFW_PRESS then
		io.write("do something (its not responding now)\n>")
		local ans = io.read()
		if ans then
			local ret = split(ans)
			if ret[1] == "recolor" then
				pal = remakepal(pal, tonumber(ret[2] or 0.1) or 0.1, tonumber(ret[3] or rand(1, 999999)) or rand(1, 999999), tonumber(ret[4] or rand(0, 1)) or rand(0, 1))
				recompileShaders(code)
			elseif ret[1] == "help" then
				print("recolor [craziness (0.0-1.0)] [seed] [dark (1/0)]\nhelp")
			elseif ret[1] == "ptest" then
				if funny == 2 then
					--turn it off
				else
					funny = 2
					local code, env = getLCode(base())
					local err
					curC, err = load(code, "lua mandelbrot thing", "t", env)
					if not curC then error(err) end
					--local cb = curC(width, height, xo, yo, zoom) hopefully i will look back on this as the 'good times' because now i have to make this work with gmp things
					do
					local xo2, yo2, zoom2, xr2, xi2 = mpf(), mpf(), mpf(), mpf(), mpf()
					gmp.f_init_set_d(xo2, xo)
					gmp.f_init_set_d(yo2, yo)
					gmp.f_init_set_d(zoom2, zoom)
					gmp.f_init_set_d(xr2, 0)
					gmp.f_init_set_d(xi2, 0)
					xo, yo, zoom, xr, xi = xo2, yo2, zoom2, xr2, xi2
					end
					local cb = curC(width, height, xo, yo, zoom)
					if not cb then error("cb failed") end
					oxo, oyo, oz = 0, 0, 1
					--for i = 0, width*height*3-1, 3 do print(cb[i], cb[i+1], cb[i+2]) end
					cTex = getTexture(nil, cb, width, height)
					print(cTex)
					program = recompileShaders(pngcode)
				end
			end
		end
	end
	keyw = window:getKey(glc.GLFW_KEY_O)
	if keyw == glc.GLFW_PRESS then
		luaswag = luaswag + speed * dt
	end
	keyw = window:getKey(glc.GLFW_KEY_P)
	if keyw == glc.GLFW_PRESS then
		luaswag = luaswag - speed * dt
	end
	end
	do
		local state = window:getMouseButton(glc.GLFW_MOUSE_BUTTON_1) --if left button clicked, make a julia set of that position
		if state == glc.GLFW_PRESS and mousedebounce then
			mousedebounce = false
			if funny == 2 then
				local x = mpf()
				gmp.f_init_set_d(x, (posx - 0.5)*width)
				gmp.f_div(x, x, zoom)
				gmp.f_add(xr, x, xo)
				local y = mpf()
				gmp.f_init_set_d(y, (posy - 0.5)*height)
				gmp.f_div(y, y, zoom)
				gmp.f_add(xi, y, yo)
				print("xr, xi: ", gmp.f_get_d(xr), gmp.f_get_d(xi))
			else
				re = ((posx - 0.5) * width) / zoom + xo
				im = ((posy - 0.5) * height) / zoom + yo
				
				local t = base()
				t.julia = true
				local code2 = getCode(t)
				program = recompileShaders(code2)
				updateTitle()
				end
		elseif state == glc.GLFW_RELEASE then
			mousedebounce = true
		end
	end
	if funny == 0 then
	gl.glClearColor(0.2, 0.3, 0.3, 1.0);
	--gl.glClear(glc.GL_COLOR_BUFFER_BIT);
	gl.glDrawArrays(glc.GL_TRIANGLE_STRIP, 0, 4);

	uniform1f(getUniformLocation(program, "u_time"), os.clock())
	uniform2f(getUniformLocation(program, "u_resolution"), width, height)
	uniform1f(getUniformLocation(program, "zoom"), zoom)
	uniform1f(getUniformLocation(program, "xo"), xo)
	uniform1f(getUniformLocation(program, "yo"), yo)
	uniform1f(getUniformLocation(program, "re"), re)
	uniform1f(getUniformLocation(program, "im"), im)
	uniform1fv(getUniformLocation(program, "pal"), 3000, pal)
	--glext.glActiveTexture(glc.GL_TEXTURE0)
	uniform1f(getUniformLocation(program, "luaswag"), luaswag)
	if otex then
		--print(getUniformLocation(program, "luaswag"), luaswag)
		
		gl.glBindTexture(glc.GL_TEXTURE_2D, otex[1])
	end
	useProgram(program)
	
	else

		gl.glClearColor(0.2, 0.3, 0.3, 1.0);
		--gl.glClear(glc.GL_COLOR_BUFFER_BIT);
		gl.glDrawArrays(glc.GL_TRIANGLE_STRIP, 0, 4);
		uniform1f(getUniformLocation(program, "u_time"), os.clock())
		uniform2f(getUniformLocation(program, "u_resolution"), width, height)
		uniform1f(getUniformLocation(program, "oxo"), oxo)
		uniform1f(getUniformLocation(program, "oyo"), oyo)
		uniform1f(getUniformLocation(program, "oz"), oz)
		gl.glBindTexture(glc.GL_TEXTURE_2D, cTex)
		
		
		--glext.glTexBuffer(glc.GL_TEXTURE_2D, glc.GL_RGB, cTex)
		--uniform1i(getUniformLocation(program, "tex"), 0)
		useProgram(program)
		
	end
	window:swapBuffers()
	local ft = os.clock() - fs
	if ft > 0.2 then
	updateTitle()
	end
	dt = ft
	--window:setTitle(tostring(ft * 60))
	lj_glfw.pollEvents()
end