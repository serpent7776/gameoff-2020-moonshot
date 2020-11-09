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

local function clamp(x, min, max)
	if x < min then
		return min
	elseif x > max then
		return max
	else
		return x
	end
end

local function spriteify(name, obj)
	local tex = lf.get_texture(name)
	obj.image = tex
	obj.width = tex:getWidth()
	obj.height = tex:getHeight()
	obj.width_2 = obj.width / 2
	obj.height_2 = obj.height / 2
	return obj
end

local function table_copy(src)
	local dst = {}
	for idx, value in pairs(src) do
		dst[idx] = value
	end
	return dst
end

local function deferred(timeout, reset_proc, func)
	return {
		initial_timeout = timeout,
		timeout = timeout,
		update = function(self, dt)
			self.timeout = self.timeout - dt
			if self.timeout <= 0 then
				func()
				reset_proc(self)
			end
		end,
	}
end

local function decayed(initial, half_life)
	return {
		initial = initial,
		value = initial,
		time = 0,
		half_life = half_life,
		update = function(self, dt)
			self.time = self.time + dt
		end,
		get = function(self)
			return self.initial * math.exp(-self.time / self.half_life)
		end,
		reset = function(self, new_initial)
			self.initial = new_initial
			self.value = new_initial
			self.time = 0
		end,
	}
end

local function continue(deferred)
	deferred.timeout = deferred.timeout + deferred.initial_timeout
	return deferred
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

launched_scene.spawn = function(obj)
	local y = (math.random() * 2 - 1) * H_2
	obj.x = W
	obj.y = y
	table.insert(launched_scene.objects, obj)
	return obj
end

launched_scene.spawn_meteorite = function()
	return spriteify('asteroid.png', launched_scene.spawn({
		vx = 250,
	}))
end

launched_scene.collected = function(obj)
	local rocket_x = launched_scene.rocket.x
	local rocket_y = launched_scene.rocket.y
	local x = math.abs(obj.x - rocket_x) < obj.width_2 + launched_scene.rocket.width_2
	local y = math.abs(obj.y - rocket_y) < obj.height_2 + launched_scene.rocket.height_2
	return x and y
end

launched_scene.hit = function()
	launched_scene.rocket.thrust = false
	launched_scene.rocket.hit = true
end

launched_scene.load = function()
	-- viewport origin is at centre, right and goes left and up
	lf.setup_viewport(-W, -H)
	launched_scene.rocket = spriteify('rocket.png', {
		x = 30,
		y = 0,
		vy = 0,
		ay = 0,
		dragy = decayed(0, 0.1)
	})
	launched_scene.objects = {}
	launched_scene.spawner = deferred(1, continue, launched_scene.spawn_meteorite)
end

launched_scene.keypressed = function(key, scancode, is_repeat)
	if key == 'space' then
		launched_scene.rocket.thrust = true
	end
end

launched_scene.keyreleased = function(key, scancode)
	if key == 'space' then
		launched_scene.rocket.thrust = false
	end
end

launched_scene.update = function(dt)
	-- objects
	for _, obj in ipairs(launched_scene.objects) do
		obj.x = obj.x - obj.vx * dt
	end
	-- colissions
	for _, obj in ipairs(launched_scene.objects) do
		if launched_scene.collected(obj) then
			launched_scene.hit()
		end
	end
	-- rocket
	local rocket = launched_scene.rocket
	local g = 300
	local a = 300
	local drag = 5000
	local vmax = 210
	if rocket.thrust then
		rocket.ay = a
	else
		rocket.ay = -g
	end
	if rocket.hit then
		rocket.hit = false
		rocket.dragy:reset(-drag)
	end
	rocket.vy = clamp(rocket.vy + (rocket.ay + rocket.dragy:get()) * dt, -vmax, vmax)
	rocket.y = rocket.y + rocket.vy * dt
	rocket.dragy:update(dt)
	-- spawner
	launched_scene.spawner:update(dt)
end

launched_scene.draw = function()
	love.graphics.translate(-W, -H_2)
	love.graphics.setColor(1, 1, 1)
	-- objects
	for _, obj in ipairs(launched_scene.objects) do
		love.graphics.draw(obj.image, obj.x, obj.y, 0, 1, 1, obj.width, obj.height_2)
	end
	-- rocket
	local rocket = launched_scene.rocket
	love.graphics.draw(rocket.image, rocket.x, rocket.y, 0, 1, 1, 0, rocket.height_2)
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
