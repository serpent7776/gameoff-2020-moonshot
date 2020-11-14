local lf = require("lib/love-frame")

local PI_2 = math.pi / 2
local Y_STEP = 50
local Y_INDEX_MIN = 1
local Y_INDEX_MAX = 10

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

local function sgn(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
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

local function conditional(deferred, predicate)
	return {
		parent = deferred,
		update = function(self, dt)
			if predicate() then
				self.parent:update(dt)
			end
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
	local SPAWN_OFSSET = W
	obj.x = W + launched_scene.rocket.x + SPAWN_OFSSET
	obj.y = Y_STEP * love.math.random(Y_INDEX_MIN, Y_INDEX_MAX)
	table.insert(launched_scene.objects, obj)
	return obj
end

launched_scene.spawn_meteorite = function()
	return spriteify('asteroid.png', launched_scene.spawn({
		vx = 50,
	}))
end

launched_scene.move_y = function(obj, dy)
	obj.y = clamp(obj.y + dy, Y_STEP * Y_INDEX_MIN, Y_STEP * Y_INDEX_MAX)
end

launched_scene.continue_rocket_movement = function()
	launched_scene.move_y(launched_scene.rocket, Y_STEP * launched_scene.rocket.dy)
end

launched_scene.collected = function(obj)
	local rocket_x = launched_scene.rocket.x
	local rocket_y = launched_scene.rocket.y
	local x = math.abs(obj.x - rocket_x) < obj.width_2 + launched_scene.rocket.width_2
	local y = math.abs(obj.y - rocket_y) < obj.height_2 + launched_scene.rocket.height_2
	return x and y
end

launched_scene.hit = function()
	launched_scene.rocket.hit = true
end

launched_scene.bounce = function(obj)
	local bottom = obj.y == Y_INDEX_MIN * Y_STEP
	local top = obj.y == Y_INDEX_MAX * Y_STEP
	if bottom then
		launched_scene.switch_dir_to(obj, 1)
	elseif top then
		launched_scene.switch_dir_to(obj, -1)
	end
end

launched_scene.switch_dir = function(obj)
	obj.dy = -sgn(obj.dy)
end

launched_scene.switch_dir_to = function(obj, dir)
	obj.dy = sgn(dir)
end

launched_scene.run_complete = function()
	return launched_scene.rocket.vx <= 0
end

launched_scene.end_run = function()
	switch_to(moon_scene)
end

launched_scene.reset = function()
	launched_scene.rocket = spriteify('rocket.png', {
		offset_x = 100,
		x = 0,
		y = 200,
		dy = -1,
		vx = 1200,
		ax = 100,
		gx = -250,
		fuel_max = 100,
		fuel = 100,
		hit = false,
		switch_dir = false,
	})
	launched_scene.rocket.offset_x = launched_scene.rocket.width + 10
	launched_scene.objects = {}
	launched_scene.rocket_mover = deferred(0.36329, continue, launched_scene.continue_rocket_movement)
	launched_scene.spawner = deferred(0.6, continue, launched_scene.spawn_meteorite)
	launched_scene.run_done = conditional(deferred(1, continue, launched_scene.end_run), launched_scene.run_complete)
end

launched_scene.load = function()
	launched_scene.game_time = 0
	-- viewport origin is at left, bottom and goes right and up
	lf.setup_viewport(W, -H)
	launched_scene.reset()
	lf.play_music('900652_pawles22---Run-2H-Challeng.mp3')
end

launched_scene.unload = function()
	lf.stop_music()
end

launched_scene.keypressed = function(key, scancode, is_repeat)
	if key == 'space' then
		launched_scene.rocket.switch_dir = true
	end
end

launched_scene.keyreleased = function(key, scancode)
	if key == 'r' then
		launched_scene.reset()
	end
end

launched_scene.update = function(dt)
	launched_scene.game_time = launched_scene.game_time + dt
	-- objects
	for _, obj in ipairs(launched_scene.objects) do
		obj.x = obj.x - obj.vx * dt
	end
	-- rocket
	local rocket = launched_scene.rocket
	local f_hit = 0.5
	local burn_rate_active = 16
	local burn_rate_passive = 4
	rocket.fuel = math.max(0, rocket.fuel - burn_rate_passive * dt)
	if rocket.switch_dir and rocket.fuel > 0 then
		rocket.switch_dir = false
		rocket.fuel = math.max(0, rocket.fuel - burn_rate_active * dt)
		launched_scene.switch_dir(rocket)
		launched_scene.move_y(rocket, Y_STEP * rocket.dy)
	end
	if rocket.fuel > 0 then
		launched_scene.bounce(rocket)
	end
	if rocket.hit then
		rocket.hit = false
		rocket.vx = rocket.vx - math.max(0, rocket.vx * (1 - f_hit))
	end
	local ax = rocket.fuel > 0 and rocket.ax or rocket.gx
	rocket.vx = math.max(0, rocket.vx + ax * dt)
	rocket.x = rocket.x + rocket.vx * dt
	-- colissions
	for idx, obj in ipairs(launched_scene.objects) do
		if launched_scene.collected(obj) then
			launched_scene.hit()
			table.remove(launched_scene.objects, idx)
			break
		end
	end
	-- deferred objects
	launched_scene.spawner:update(dt)
	launched_scene.rocket_mover:update(dt)
	launched_scene.run_done:update(dt)
	-- remove objects
	local has_objects = table.maxn(launched_scene.objects) > 0
	if has_objects and launched_scene.objects[1].x < rocket.x - rocket.width - rocket.offset_x then
		table.remove(launched_scene.objects, 1)
	end
end

launched_scene.draw = function()
	local rocket = launched_scene.rocket
	love.graphics.translate(0, -H)
	love.graphics.push()
	love.graphics.translate(-rocket.x + rocket.offset_x, 0)
	love.graphics.setColor(1, 1, 1)
	-- objects
	local phi = launched_scene.game_time * PI_2
	for _, obj in ipairs(launched_scene.objects) do
		if obj.x > rocket.x + W then
			local dx = obj.x - rocket.x - W
			local scale = clamp(1 - dx / W, 0, 0.5)
			love.graphics.draw(obj.image, rocket.x + W - rocket.width - 50, obj.y, phi, scale, scale, obj.width_2, obj.height_2)
		else
			love.graphics.draw(obj.image, obj.x, obj.y, 0, 1, 1, obj.width, obj.height_2)
		end
	end
	-- rocket
	love.graphics.draw(rocket.image, rocket.x, rocket.y, 0, 1, 1, rocket.width, rocket.height_2)
	love.graphics.pop()
	-- ui
	-- fuel bar
	local fuel_pc = rocket.fuel / rocket.fuel_max
	local r = lerp(2, 0, fuel_pc)
	local g = lerp(0, 2, fuel_pc)
	love.graphics.setColor(r, g, 0)
	love.graphics.rectangle('fill', 10, H-10, (W-20)*fuel_pc, -20)
	-- meters
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(string.format("%.2f", rocket.x), 10, 25, 0, 1, -1)
	love.graphics.print(string.format("%.2f", rocket.vx), 200, 25, 0, 1, -1)
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
