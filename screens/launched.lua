local lf = require("lib/love-frame")
local anim8 = require("lib/anim8/anim8")
local fn = require('funs')

local screens = lf.screens()
local v = lf.data()
local W = v.W
local H = v.H

local Y_STEP = 50
local Y_INDEX_MIN = 1
local Y_INDEX_MAX = 10
local SPAWN_DISTANCE = W * 4
local TIME_STEP = 0.36329 / 2
local DESTINATION_DISTANCE = 1000000
local STARS_COUNT = 25

local rocket_grid
local asteroid_grid
local fuel_grid
local cash_grid
local game_time

local stars
local scroll_x
local objects
local last_fuel_spawn
local rocket
local game_updater
local rocket_mover
local spawner
local deferrer
local ender
local completer

local function gen_grids()
	rocket_grid = anim8.newGrid(200, 50, 1000, 400)
	asteroid_grid = anim8.newGrid(50, 50, 250, 400)
	fuel_grid = anim8.newGrid(50, 50, 250, 200)
	cash_grid = anim8.newGrid(50, 50, 250, 50)
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

local function animateify(name, grid, frames, obj)
	obj.image = lf.get_texture(name)
	obj.animation = anim8.newAnimation(frames, TIME_STEP / 2)
	obj.width = grid.frameWidth
	obj.height = grid.frameHeight
	obj.width_2 = grid.frameWidth / 2
	obj.height_2 = grid.frameHeight / 2
	return obj
end

local function collected(obj)
	local rocket_x = rocket.x + rocket.offset_x - rocket.hitbox_offset_x
	local rocket_width = rocket.width - rocket.hitbox_offset_x
	local dx = obj.x - rocket_x
	local x = dx < 0 and -dx < obj.width + rocket_width
	local y = math.abs(obj.y - rocket.y) < obj.height_2 + rocket.hitbox_height_2
	return x and y
end

local function fuel_refill()
	local level = fn.get_level(v.fuel)
	local refill = fn.get_value_2(v.fuel_refill, level)
	rocket.fuel = math.min(rocket.fuel + refill, rocket.fuel_max)
end

local function earn_cash(boost)
	v.cash = v.cash + boost
end

local function meteorite_hit()
	rocket.hit = true
	lf.play_sound('hit.wav')
end

local function fuel_meteorite_hit()
	fuel_refill()
	lf.play_sound('pick.wav')
end

local function cash_meteorite_hit()
	earn_cash(100)
	lf.play_sound('pick.wav')
end

local function spawn_star()
	local star = {
		x = W * 2 * love.math.random(),
		y = love.math.random(Y_STEP * Y_INDEX_MIN, Y_STEP * (Y_INDEX_MAX + 1)),
	}
	table.insert(stars, star)
	return star
end

local function rewind_star(star)
	star.x = W + scroll_x/4 + love.math.random() * SPAWN_DISTANCE
	star.y = love.math.random(Y_STEP * Y_INDEX_MIN, Y_STEP * (Y_INDEX_MAX + 1))
	return star
end

local function spawn_obj(obj)
	obj.x = W + scroll_x + SPAWN_DISTANCE
	obj.y = Y_STEP * love.math.random(Y_INDEX_MIN, Y_INDEX_MAX)
	table.insert(objects, obj)
	return obj
end

local function spawn_meteorite()
	local grid = asteroid_grid
	local frames = asteroid_grid(
		'1-5',1,
		'1-5',2,
		'1-5',3,
		'1-5',4,
		'1-5',5,
		'1-5',6,
		'1-5',7,
		'1-5',8
	)
	local asteroids = {'asteroid_1.png', 'asteroid_2.png'}
	local idx = love.math.random(1, #asteroids)
	return animateify(asteroids[idx], grid, frames, spawn_obj({
		vx = 50,
		on_hit = meteorite_hit
	}))
end

local function spawn_fuel()
	local grid = fuel_grid
	local frames = fuel_grid(
		'1-5',1,
		'1-5',2,
		'1-5',3,
		'1-5',4
	)
	return animateify('fuel.png', grid, frames, spawn_obj({
		vx = 10,
		on_hit = fuel_meteorite_hit
	}))
end

local function spawn_cash()
	local grid = cash_grid
	local frames = cash_grid('1-4',1)
	return animateify('cash.png', grid, frames, spawn_obj({
		vx = 0,
		on_hit = cash_meteorite_hit
	}))
end

local function spawn_object(_)
	last_fuel_spawn = last_fuel_spawn + 1
	local w_fuel = math.min(10, math.floor(last_fuel_spawn / 6))
	local w_cash = 5
	local w_meteorite = 90
	local w_sum = w_fuel + w_cash + w_meteorite
	local prob_fuel = w_fuel
	local prob_cash = prob_fuel + w_cash
	local prob_meteorite = prob_cash + w_meteorite
	local val = love.math.random(1, w_sum)
	if val <= prob_fuel then
		spawn_fuel()
		last_fuel_spawn = 0
	elseif val <= prob_cash then
		spawn_cash()
	elseif val <= prob_meteorite then
		spawn_meteorite()
	else
		print('random out of range:', val)
	end
end

local function move_y(obj, dy)
	obj.y = fn.clamp(obj.y + dy, Y_STEP * Y_INDEX_MIN, Y_STEP * Y_INDEX_MAX)
end

local function continue_rocket_movement(_)
	move_y(rocket, Y_STEP * rocket.dy)
end

local function switch_dir_to(obj, dir)
	obj.dy = fn.sgn(dir)
end

local function bounce(obj)
	local bottom = obj.y == Y_INDEX_MIN * Y_STEP
	local top = obj.y == Y_INDEX_MAX * Y_STEP
	if bottom then
		switch_dir_to(obj, 1)
	elseif top then
		switch_dir_to(obj, -1)
	end
end

local function run_failed()
	return rocket.vx <= 0
end

local function run_completed()
	return rocket.x >= DESTINATION_DISTANCE
end

local function to_the_moon(_)
	lf.switch_to(screens.moon)
end

local function back_to_life(_)
	local function warp(dt)
		rocket.offset_x = rocket.offset_x + W * dt
	end
	local function offscreen(_)
		return rocket.offset_x > W
	end
	local function game_complete(_)
		print('game done')
	end
	game_updater:set(false)
	fn.stop(rocket_mover)
	fn.stop(spawner)
	deferrer.add(fn.deferred(4, fn.continue, warp))
	deferrer.add(fn.conditional(fn.deferred(1, fn.stop, game_complete), offscreen))
end

local function reset()
	last_fuel_spawn = 0
	scroll_x = 0
	local grid = rocket_grid
	local frames = rocket_grid(
		'1-5',1,
		'1-5',2,
		'1-5',3,
		'1-5',4,
		'1-5',5,
		'1-5',6,
		'1-5',7,
		'1-5',8
	)
	rocket = animateify('rocket.png', grid, frames, {
		offset_x = 100,
		hitbox_offset_x = 23,
		hitbox_height_2 = 14,
		x = 0,
		y = 200,
		dy = -1,
		vx = 1200,
		ax = fn.get_value(v.acceleration),
		gx = -250,
		fuel_max = fn.get_value(v.fuel),
		fuel = fn.get_value(v.fuel),
		hit = false,
		switch_dir = 0,
		fuel_pc = function(self)
			return self.fuel / self.fuel_max
		end,
	})
	game_updater = fn.transistor(true)
	rocket.offset_x = rocket.width + 10
	objects = {}
	rocket_mover = fn.deferred(TIME_STEP, fn.reset, continue_rocket_movement)
	local spawn_delta = rocket.width * 4.5
	spawner = fn.deferred(spawn_delta, fn.reset, spawn_object)
	ender = fn.conditional(fn.deferred(1, fn.reset, to_the_moon), run_failed)
	completer = fn.conditional(fn.deferred(1, fn.stop, back_to_life), run_completed)
	deferrer = fn.group()
	deferrer.add(rocket_mover)
	-- deferrer.add(spawner) -- needs to updated separately
	deferrer.add(ender)
	deferrer.add(completer)
	stars = {}
	fn.rep(STARS_COUNT, spawn_star)
end

return {
	load = function()
		game_time = 0
		gen_grids()
	end,

	show = function()
		-- viewport origin is at left, bottom and goes right and up
		lf.setup_viewport(W, -H)
		reset()
		lf.play_music('900652_pawles22---Run-2H-Challeng.mp3')
	end,

	hide = function()
		lf.stop_music()
	end,

	keypressed = function(key, scancode, is_repeat)
		if key == 'up' or key == 'k' or key == 'x' then
			rocket.switch_dir = 1
		elseif key == 'down' or key =='j' or key == 'z' then
			rocket.switch_dir = -1
		end
	end,

	keyreleased = function(key, scancode)
	end,

	clicked = function(x, y)
	end,

	update = function(dt)
		-- objects
		for _, obj in ipairs(objects) do
			obj.x = obj.x - obj.vx * dt
		end
		-- rocket
		game_updater(function()
			game_time = game_time + dt
			local f_hit = fn.get_value(v.durability)
			local burn_rate_active = 16
			local burn_rate_passive = 4
			rocket.fuel = math.max(0, rocket.fuel - burn_rate_passive * dt)
			if rocket.switch_dir ~= 0 and rocket.fuel > 0 then
				rocket.fuel = math.max(0, rocket.fuel - burn_rate_active * dt)
				switch_dir_to(rocket, rocket.switch_dir)
				rocket.switch_dir = 0
			end
			if rocket.fuel > 0 then
				bounce(rocket)
			end
			if rocket.hit then
				rocket.hit = false
				rocket.vx  = rocket.vx - math.max(0, rocket.vx * f_hit)
			end
			local ax = rocket.fuel > 0 and rocket.ax or rocket.gx
			rocket.vx = math.max(0, rocket.vx + ax * dt)
			rocket.x = rocket.x + rocket.vx * dt
			-- colissions
			for idx, obj in ipairs(objects) do
				if collected(obj) then
					obj.on_hit()
					table.remove(objects, idx)
					break
				end
			end
		end)
		scroll_x = scroll_x + rocket.vx * dt
		-- deferred objects
		spawner:update(dt * rocket.vx)
		deferrer.update(dt)
		-- animations
		rocket.animation:update(dt)
		for _, obj in ipairs(objects) do
			obj.animation:update(dt)
		end
		-- remove objects
		local has_objects = table.maxn(objects) > 0
		if has_objects and objects[1].x < scroll_x then
			table.remove(objects, 1)
			v.cash = v.cash + 10
		end
		-- rewind stars
		for _, star in ipairs(stars) do
			if star.x < scroll_x/4 then
				rewind_star(star)
			end
		end
	end,

	draw = function()
		love.graphics.translate(0, -H)
		love.graphics.push()
		love.graphics.translate(-scroll_x, 0)
		love.graphics.setColor(1, 1, 1)
		-- stars
		local star_scale = fn.clamp(rocket.vx / 1000 + 1, 1, 10) + love.math.random()
		for _, star in ipairs(stars) do
			love.graphics.draw(lf.get_texture('star.png'), star.x + scroll_x * 3/4, star.y, 0, star_scale, -1)
		end
		-- objects
		local y_offset = 20
		for _, obj in ipairs(objects) do
			if obj.x > scroll_x + W then
				local dx = obj.x - (scroll_x - rocket.width) - W
				local scale = fn.clamp(1 - dx / SPAWN_DISTANCE, 0, 1) * 0.75
				obj.animation:draw(obj.image, scroll_x + W - obj.width, obj.y + y_offset, 0, scale, -scale, obj.width_2, obj.height_2)
			else
				obj.animation:draw(obj.image, obj.x, obj.y + y_offset, 0, 1, -1, 0, obj.height_2)
			end
		end
		-- rocket
		rocket.animation:draw(rocket.image, scroll_x + rocket.offset_x, rocket.y + y_offset, 0, 1, -1, rocket.width, rocket.height_2)
		-- ui
		love.graphics.pop()
		-- fuel bar
		local fuel_pc = rocket:fuel_pc()
		local r = fn.lerp(2, 0, fuel_pc)
		local g = fn.lerp(0, 2, fuel_pc)
		love.graphics.setColor(r, g, 0)
		love.graphics.rectangle('fill', 10, H-10, (W-20)*fuel_pc, -20)
		-- distance bar
		love.graphics.setColor(1, 1, 1)
		local distance_pc = fn.clamp(rocket.x / DESTINATION_DISTANCE, 0, 1)
		local distance_width = W - 20
		local distance_travelled = distance_width * distance_pc
		love.graphics.rectangle('fill', 10, 10, distance_width, 1)
		love.graphics.circle('fill', 10+distance_travelled, 10, 5)
		-- meters
		local wallet = string.format('$%s', v.cash)
		love.graphics.print(wallet, 10, H-35, 0, 1, -1)
		local time = string.format('%.1f', game_time)
		love.graphics.printf(time, 0, H-35, W-10, 'right', 0, 1, -1)
	end,
}
