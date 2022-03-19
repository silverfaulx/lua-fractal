# lua-fractal
my pet fractal renderer

very unfinished and probably really unoptimized but i mean it sorta works so yeah (i'm eternally postponing improving it)

runs on luvit (because i was making lua discord bots) but i don't see why it wouldn't work with luajit if you fix the require stuff

requires a few things:
- https://github.com/ColonelThirtyTwo/LuaJIT-GLFW for opengl (this is rad and the only way i've been able to use opengl)
- https://github.com/Playermet/luajit-gmp for arbitrary precision stuff i don't really use yet but plan to
- lodepng dll if you want to texture it
- i don't really like downloading 13948710932478134 dependancies because nothing ever seems to work, so ill try to keep this low idk

do whatever you want with this 

controls:
- WASD: move
- E/Q: zoom/unzoom
- click: create a julia set of the mouse's location (kinda wonky sorry)
- right click: change RE/IM of the julia set (relative to the center of the screen i think)
- Z: switch to C double mode, or re-render the scene if already in it
- enter: io.read()s a command, either recolor {craziness} {seed} {isdark} for rechanging the colors, or ptest to change it to lua perturbation thing test (does NOT work sowwy)
- O/P: influence the luaswag uniform for use in textured fractals
- arrow keys: change RE/IM of the julia set

i think i fixed the thing with the 3000 uniforms lol

have fun and feel free to spam message me if you want something fixed or added or explained, i'll hopefully do my best to do it because i'm likely not doing anything better at the moment!!!!!!
