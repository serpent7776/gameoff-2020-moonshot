local lf = require("lib/love-frame")

local W, H, W_2, H_2
local moon_top_h
local scene

local moon_scene = {}

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
		scene:unload()
	end
	scene = table_copy(new_scene)
	scene:load()
end

moon_scene.prepare_data = function(self)
	moon_top_h = H * 0.1
	self.moon_vertices = {}
	local max_i = 10
	for i = 0, max_i do
		local c = max_i / 2
		local x = (i - c) / c * W_2
		local y = sinc(0, moon_top_h, i / c)
		self.moon_vertices[i * 2 + 1] = x
		self.moon_vertices[i * 2 + 2] = y
	end
end

moon_scene.load = function(self)
	self:prepare_data()
end

moon_scene.keypressed = function(self, key, scancode, is_repeat)
end

moon_scene.keyreleased = function(self, key, scancode)
end

moon_scene.update = function(self, dt)
end

moon_scene.draw = function(self)
	love.graphics.translate(W_2, -H)
	love.graphics.setColor(0.86, 0.86, 0.86)
	love.graphics.polygon('fill', self.moon_vertices)
	love.graphics.setColor(0.1, 0, 0.86)
	love.graphics.rectangle('fill', -10, moon_top_h*0.9, 20, moon_top_h*0.5)
end


lf.init = function()
	W, H = 800, 600
	W_2, H_2 = W / 2, H / 2
	-- viewport origin is at bottom, centre and goes right and up
	lf.setup_viewport(W, -H)
	switch_to(moon_scene)
end

love.keypressed = function(key, scancode, is_repeat)
	scene:keypressed(key, scancode, is_repeat)
end

love.keyreleased = function(key, scancode)
	scene:keyreleased(key, scancode)
end

lf.update = function(dt)
	scene:update(dt)
end

lf.draw = function()
	scene:draw()
end
