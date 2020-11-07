local lf = require("lib/love-frame")

local W, H, W_2, H_2
local scene

local moon_scene = {}
local launched_scene = {}

--[[
   [ utils
   ]]

local function lerp(x, y, a)
	return y * a + x * (1 - a)
end

local function sinc(x, y, a)
	return lerp(x, y, math.sin(a * math.pi / 2))
end

local function table_copy(src)
	local dst = {}
	for idx, value in pairs(src) do
		dst[idx] = value
	end
	return dst
end

local function switch_to(new_scene)
	if scene and scene.unload then
		scene.unload()
	end
	scene = table_copy(new_scene)
	scene.load()
end

--[[
   [ moon_scene
   ]]

moon_scene.prepare_data = function()
	moon_scene.moon_top_h = H * 0.1
	moon_scene.moon_vertices = {}
	local max_i = 10
	for i = 0, max_i do
		local c = max_i / 2
		local x = (i - c) / c * W_2
		local y = sinc(0, moon_scene.moon_top_h, i / c)
		moon_scene.moon_vertices[i * 2 + 1] = x
		moon_scene.moon_vertices[i * 2 + 2] = y
	end
end

moon_scene.load = function()
	moon_scene.prepare_data()
	-- viewport origin is at bottom, centre and goes right and up
	lf.setup_viewport(W, -H)
end

moon_scene.keypressed = function(key, scancode, is_repeat)
end

moon_scene.keyreleased = function(key, scancode)
	if key == 'space' then
		switch_to(launched_scene)
	end
end

moon_scene.update = function(dt)
end

moon_scene.draw = function()
	love.graphics.translate(W_2, -H)
	love.graphics.setColor(0.86, 0.86, 0.86)
	love.graphics.polygon('fill', moon_scene.moon_vertices)
	love.graphics.setColor(0.1, 0, 0.86)
	love.graphics.rectangle('fill', -10, moon_scene.moon_top_h*0.9, 20, moon_scene.moon_top_h*0.5)
end

--[[
   [ launched_scene
   ]]

launched_scene.load = function()
	-- viewport origin is at centre, right and goes left and up
	lf.setup_viewport(-W, H)
end

launched_scene.keypressed = function(key, scancode, is_repeat)
end

launched_scene.keyreleased = function(key, scancode)
end

launched_scene.update = function(dt)
end

launched_scene.draw = function()
	love.graphics.translate(-W, H_2)
	love.graphics.setColor(0.1, 0, 0.86)
	love.graphics.rectangle('fill', 30, -20, 60, 40)
end

--[[
   [ love/lf funs
   ]]

lf.init = function()
	W, H = 800, 600
	W_2, H_2 = W / 2, H / 2
	switch_to(moon_scene)
end

love.keypressed = function(key, scancode, is_repeat)
	scene.keypressed(key, scancode, is_repeat)
end

love.keyreleased = function(key, scancode)
	scene.keyreleased(key, scancode)
end

lf.update = function(dt)
	scene.update(dt)
end

lf.draw = function()
	scene.draw()
end
