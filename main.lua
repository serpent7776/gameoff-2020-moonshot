local lf = require("lib/love-frame")
local anim8 = require("lib/anim8/anim8")
local fn = require('funs')

local screens = lf.screens()

local Y_STEP = 50
local Y_INDEX_MIN = 1
local Y_INDEX_MAX = 10
local TIME_STEP = 0.36329 / 2
local DESTINATION_DISTANCE = 1000000
local STARS_COUNT = 25

local W, H = 800, 600
local W_2, H_2 = W/2, H/2
local v = lf.data({
	W = W,
	H = H,
	W_2 = W_2,
	H_2 = H_2,
	cash = 0,
	fuel = {
		current_level = 1,
		values = {100, 150, 250, 450, 750},
		costs = {750, 1500, 2500, 4500}
	},
	fuel_refill = {
		current_level = 1, -- check level of `fuel' upgrade
		values = {45, 75, 100, 150, 225},
		costs = {0, 0, 0, 0} -- not upgradeable directly
	},
	acceleration = {
		current_level = 1,
		values = {100, 150, 250, 500},
		costs = {1000, 1500, 2500}
	},
	durability = {
		current_level = 1,
		values = {0.50, 0.55, 0.60},
		costs = {2000, 3000}
	},
})

local SPAWN_DISTANCE = W * 4
local rocket_grid
local asteroid_grid
local fuel_grid
local cash_grid
local game_time

local moon_scene = {}
local launched_scene = {}

--[[
   [ utils
   ]]

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

--[[
   [ loading
   ]]

local function gen_grids()
	rocket_grid = anim8.newGrid(200, 50, 1000, 400)
	asteroid_grid = anim8.newGrid(50, 50, 250, 400)
	fuel_grid = anim8.newGrid(50, 50, 250, 200)
	cash_grid = anim8.newGrid(50, 50, 250, 50)
end

--[[
   [ common
   ]]

local function get_value(upgrade)
	return upgrade.values[upgrade.current_level]
end

local function get_value_2(upgrade, level)
	return upgrade.values[level]
end

local function get_level(upgrade)
	return upgrade.current_level
end

local function get_max_level(upgrade)
	return #upgrade.values
end

local function get_cost(upgrade)
	return upgrade.costs[upgrade.current_level]
end

--[[
   [ moon_scene
   ]]

moon_scene.prepare_data = function()
	moon_scene.bg = lf.get_texture('moon.png')
end

moon_scene.buy_upgrade = function(upgrade)
	local can_upgrade = upgrade.current_level < #upgrade.values
	if can_upgrade and v.cash >= upgrade.costs[upgrade.current_level] then
		v.cash = v.cash - upgrade.costs[upgrade.current_level]
		upgrade.current_level = upgrade.current_level + 1
		return true
	end
	return false
end

moon_scene.upgrade = function(upgrade)
	local ok = moon_scene.buy_upgrade(upgrade)
	if ok then
		lf.play_sound('click.wav')
	else
		lf.play_sound('no.wav')
	end
	moon_scene.update_upgrade_buttons()
end

moon_scene.create_button = function(image_name, x, y, handler)
	local btn = fn.button(lf.get_texture(image_name), x, y)
	moon_scene.buttons.add(btn, handler)
	return btn
end

moon_scene.create_upgrade_button = function(name, x, y, upgrade)
	local handler = fn.curry1(moon_scene.upgrade, upgrade)
	local btn = moon_scene.create_button('up-dummy.png', x, y, handler) -- image name will be updated in update_upgrade_button
	btn.upgrade = upgrade
	btn.name = name
	return btn
end

moon_scene.update_upgrade_button = function(button)
	local level = get_level(button.upgrade)
	local image = string.format('up-%s-%d.png', button.name, level)
	button.tex = lf.get_texture(image)
end

moon_scene.update_upgrade_buttons = function()
	moon_scene.update_upgrade_button(moon_scene.fuel_upgrade)
	moon_scene.update_upgrade_button(moon_scene.acceleration_upgrade)
	moon_scene.update_upgrade_button(moon_scene.durability_upgrade)
end

moon_scene.draw_button = function(btn)
	love.graphics.draw(btn.tex, btn.x, btn.y, 0, 1, -1, 0, btn.height)
end

moon_scene.draw_upgrade_button = function(btn)
	moon_scene.draw_button(btn)
	local current = get_level(btn.upgrade)
	local max = get_max_level(btn.upgrade)
	local level_str = string.format('%d/%d', current, max)
	love.graphics.printf(level_str, btn.x, btn.y, 100, 'right', 0, 1, -1)
	local cost = get_cost(btn.upgrade)
	if cost then
		local cost_str = string.format('$%d', cost)
		love.graphics.printf(cost_str, btn.x, btn.y-20, 100, 'right', 0, 1, -1)
	end
end

moon_scene.show = function()
	launched_scene.last_fuel_spawn = 0
	launched_scene.scroll_x = 0
	moon_scene.prepare_data()
	-- viewport origin is at bottom, centre and goes right and up
	lf.setup_viewport(W, -H)
	moon_scene.buttons = fn.clickable()
	moon_scene.fuel_upgrade = moon_scene.create_upgrade_button('fuel', 25, H-150-10, v.fuel)
	moon_scene.acceleration_upgrade = moon_scene.create_upgrade_button('acceleration', 350, H-150-10, v.acceleration)
	moon_scene.durability_upgrade = moon_scene.create_upgrade_button('durability', 650, H-150-10, v.durability)
	moon_scene.launch = moon_scene.create_button('launch.png', W/2-123, H*1/4-23, fn.curry1(lf.switch_to, launched_scene))
	moon_scene.update_upgrade_buttons()
end

moon_scene.keypressed = function(key, scancode, is_repeat)
end

moon_scene.keyreleased = function(key, scancode)
	if key == 'space' then
		lf.switch_to(screens.launched)
	elseif key == '1' then
		moon_scene.upgrade(v.fuel)
	elseif key == '2' then
		moon_scene.upgrade(v.acceleration)
	elseif key == '3' then
		moon_scene.upgrade(v.durability)
	end
end

moon_scene.clicked = function(gx, gy)
	local w, h = love.graphics.getPixelDimensions()
	love.graphics.origin()
	love.graphics.scale(w/W, h/-H)
	love.graphics.translate(0, -H)
	local x, y = love.graphics.transformPoint(gx, gy)
	moon_scene.buttons.click(x, y)
end

moon_scene.update = function(dt)
end

moon_scene.draw = function()
	love.graphics.translate(0, -H)
	love.graphics.push()
	love.graphics.translate(W_2, 0)
	local bg = moon_scene.bg
	love.graphics.draw(bg, 0, 0, 0, 1, -1, bg:getWidth()/2, bg:getHeight())
	love.graphics.pop()
	moon_scene.draw_upgrade_button(moon_scene.fuel_upgrade)
	moon_scene.draw_upgrade_button(moon_scene.acceleration_upgrade)
	moon_scene.draw_upgrade_button(moon_scene.durability_upgrade)
	moon_scene.draw_button(moon_scene.launch)
	local wallet = string.format('$%s', v.cash)
	love.graphics.printf(wallet, 25, 25, 100, 'left', 0, 1, -1)
end

--[[
   [ launched_scene
   ]]

launched_scene.spawn_star = function()
	local star = {
		x = W * 2 * love.math.random(),
		y = love.math.random(Y_STEP * Y_INDEX_MIN, Y_STEP * (Y_INDEX_MAX + 1)),
	}
	table.insert(launched_scene.stars, star)
	return star
end

launched_scene.rewind_star = function(star)
	star.x = W + launched_scene.scroll_x/4 + love.math.random() * SPAWN_DISTANCE
	star.y = love.math.random(Y_STEP * Y_INDEX_MIN, Y_STEP * (Y_INDEX_MAX + 1))
	return star
end

launched_scene.spawn_obj = function(obj)
	obj.x = W + launched_scene.scroll_x + SPAWN_DISTANCE
	obj.y = Y_STEP * love.math.random(Y_INDEX_MIN, Y_INDEX_MAX)
	table.insert(launched_scene.objects, obj)
	return obj
end

launched_scene.spawn_meteorite = function()
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
	return animateify(asteroids[idx], grid, frames, launched_scene.spawn_obj({
		vx = 50,
		on_hit = launched_scene.meteorite_hit
	}))
end

launched_scene.spawn_fuel = function()
	local grid = fuel_grid
	local frames = fuel_grid(
		'1-5',1,
		'1-5',2,
		'1-5',3,
		'1-5',4
	)
	return animateify('fuel.png', grid, frames, launched_scene.spawn_obj({
		vx = 10,
		on_hit = launched_scene.fuel_meteorite_hit
	}))
end

launched_scene.spawn_cash = function()
	local grid = cash_grid
	local frames = cash_grid('1-4',1)
	return animateify('cash.png', grid, frames, launched_scene.spawn_obj({
		vx = 0,
		on_hit = launched_scene.cash_meteorite_hit
	}))
end

local function make_randomizer()
	return {
		weight_total = 0,
		weights = {},
		things = {},

		recalc = function(self)
			self.weight_total = fn.table_sum(self.weights)
		end,

		add = function(self, weight, thing)
			table.insert(self.weights, weight)
			table.insert(self.things, thing)
			self:recalc()
		end,

		get = function(self)
			local val = love.math.random(1, self.weight_total)
			for idx, weight in ipairs(self.weights) do
				if val < weight then
					return self.things[idx]
				end
			end
		end,
	}
end

launched_scene.spawn_object = function(_)
	launched_scene.last_fuel_spawn = launched_scene.last_fuel_spawn + 1
	local w_fuel = math.min(10, math.floor(launched_scene.last_fuel_spawn / 6))
	local w_cash = 5
	local w_meteorite = 90
	local w_sum = w_fuel + w_cash + w_meteorite
	local prob_fuel = w_fuel
	local prob_cash = prob_fuel + w_cash
	local prob_meteorite = prob_cash + w_meteorite
	local val = love.math.random(1, w_sum)
	if val <= prob_fuel then
		launched_scene.spawn_fuel()
		launched_scene.last_fuel_spawn = 0
	elseif val <= prob_cash then
		launched_scene.spawn_cash()
	elseif val <= prob_meteorite then
		launched_scene.spawn_meteorite()
	else
		print('random out of range:', val)
	end
end

launched_scene.move_y = function(obj, dy)
	obj.y = fn.clamp(obj.y + dy, Y_STEP * Y_INDEX_MIN, Y_STEP * Y_INDEX_MAX)
end

launched_scene.continue_rocket_movement = function(_)
	launched_scene.move_y(launched_scene.rocket, Y_STEP * launched_scene.rocket.dy)
end

launched_scene.collected = function(obj)
	local rocket = launched_scene.rocket
	local rocket_x = rocket.x + rocket.offset_x - rocket.hitbox_offset_x
	local rocket_width = rocket.width - rocket.hitbox_offset_x
	local dx = obj.x - rocket_x
	local x = dx < 0 and -dx < obj.width + rocket_width
	local y = math.abs(obj.y - rocket.y) < obj.height_2 + rocket.hitbox_height_2
	return x and y
end

launched_scene.fuel_refill = function()
	local rocket = launched_scene.rocket
	local level = get_level(v.fuel)
	local refill = get_value_2(v.fuel_refill, level)
	rocket.fuel = math.min(rocket.fuel + refill, rocket.fuel_max)
end

launched_scene.earn_cash = function(boost)
	v.cash = v.cash + boost
end

launched_scene.meteorite_hit = function()
	launched_scene.rocket.hit = true
	lf.play_sound('hit.wav')
end

launched_scene.fuel_meteorite_hit = function()
	launched_scene.fuel_refill()
	lf.play_sound('pick.wav')
end

launched_scene.cash_meteorite_hit = function()
	launched_scene.earn_cash(100)
	lf.play_sound('pick.wav')
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

launched_scene.switch_dir_to = function(obj, dir)
	obj.dy = fn.sgn(dir)
end

launched_scene.run_failed = function()
	return launched_scene.rocket.vx <= 0
end

launched_scene.run_completed = function()
	return launched_scene.rocket.x >= DESTINATION_DISTANCE
end

launched_scene.to_the_moon = function(_)
	lf.switch_to(screens.moon)
end

launched_scene.back_to_life = function(_)
	local function warp(dt)
		launched_scene.rocket.offset_x = launched_scene.rocket.offset_x + W * dt
	end
	local function offscreen(_)
		return launched_scene.rocket.offset_x > W
	end
	local function game_complete(_)
		print('game done')
	end
	launched_scene.game_updater:set(false)
	fn.stop(launched_scene.rocket_mover)
	fn.stop(launched_scene.spawner)
	launched_scene.deferrer.add(fn.deferred(4, fn.continue, warp))
	launched_scene.deferrer.add(fn.conditional(fn.deferred(1, fn.stop, game_complete), offscreen))
end

launched_scene.reset = function()
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
	launched_scene.rocket = animateify('rocket.png', grid, frames, {
		offset_x = 100,
		hitbox_offset_x = 23,
		hitbox_height_2 = 14,
		x = 0,
		y = 200,
		dy = -1,
		vx = 1200,
		ax = get_value(v.acceleration),
		gx = -250,
		fuel_max = get_value(v.fuel),
		fuel = get_value(v.fuel),
		hit = false,
		switch_dir = 0,
		fuel_pc = function(self)
			return self.fuel / self.fuel_max
		end,
	})
	launched_scene.game_updater = fn.transistor(true)
	launched_scene.rocket.offset_x = launched_scene.rocket.width + 10
	launched_scene.objects = {}
	launched_scene.rocket_mover = fn.deferred(TIME_STEP, fn.reset, launched_scene.continue_rocket_movement)
	local spawn_delta = launched_scene.rocket.width * 4.5
	launched_scene.spawner = fn.deferred(spawn_delta, fn.reset, launched_scene.spawn_object)
	launched_scene.ender = fn.conditional(fn.deferred(1, fn.reset, launched_scene.to_the_moon), launched_scene.run_failed)
	launched_scene.completer = fn.conditional(fn.deferred(1, fn.stop, launched_scene.back_to_life), launched_scene.run_completed)
	launched_scene.deferrer = fn.group()
	launched_scene.deferrer.add(launched_scene.rocket_mover)
	-- launched_scene.deferrer.add(launched_scene.spawner) -- needs to updated separately
	launched_scene.deferrer.add(launched_scene.ender)
	launched_scene.deferrer.add(launched_scene.completer)
	launched_scene.stars = {}
	fn.rep(STARS_COUNT, launched_scene.spawn_star)
end

launched_scene.show = function()
	-- viewport origin is at left, bottom and goes right and up
	lf.setup_viewport(W, -H)
	launched_scene.reset()
	lf.play_music('900652_pawles22---Run-2H-Challeng.mp3')
end

launched_scene.hide = function()
	lf.stop_music()
end

launched_scene.keypressed = function(key, scancode, is_repeat)
	if key == 'up' or key == 'k' or key == 'x' then
		launched_scene.rocket.switch_dir = 1
	elseif key == 'down' or key =='j' or key == 'z' then
		launched_scene.rocket.switch_dir = -1
	end
end

launched_scene.keyreleased = function(key, scancode)
end

launched_scene.clicked = function(x, y)
end

launched_scene.update = function(dt)
	-- objects
	for _, obj in ipairs(launched_scene.objects) do
		obj.x = obj.x - obj.vx * dt
	end
	-- rocket
	local rocket = launched_scene.rocket
	launched_scene.game_updater(function()
		game_time = game_time + dt
		local f_hit = get_value(v.durability)
		local burn_rate_active = 16
		local burn_rate_passive = 4
		rocket.fuel = math.max(0, rocket.fuel - burn_rate_passive * dt)
		if rocket.switch_dir ~= 0 and rocket.fuel > 0 then
			rocket.fuel = math.max(0, rocket.fuel - burn_rate_active * dt)
			launched_scene.switch_dir_to(rocket, rocket.switch_dir)
			rocket.switch_dir = 0
		end
		if rocket.fuel > 0 then
			launched_scene.bounce(rocket)
		end
		if rocket.hit then
			rocket.hit = false
			rocket.vx  = rocket.vx - math.max(0, rocket.vx * f_hit)
		end
		local ax = rocket.fuel > 0 and rocket.ax or rocket.gx
		rocket.vx = math.max(0, rocket.vx + ax * dt)
		rocket.x = rocket.x + rocket.vx * dt
		-- colissions
		for idx, obj in ipairs(launched_scene.objects) do
			if launched_scene.collected(obj) then
				obj.on_hit()
				table.remove(launched_scene.objects, idx)
				break
			end
		end
	end)
	launched_scene.scroll_x = launched_scene.scroll_x + rocket.vx * dt
	-- deferred objects
	launched_scene.spawner:update(dt * rocket.vx)
	launched_scene.deferrer.update(dt)
	-- animations
	rocket.animation:update(dt)
	for _, obj in ipairs(launched_scene.objects) do
		obj.animation:update(dt)
	end
	-- remove objects
	local has_objects = table.maxn(launched_scene.objects) > 0
	if has_objects and launched_scene.objects[1].x < launched_scene.scroll_x then
		table.remove(launched_scene.objects, 1)
		v.cash = v.cash + 10
	end
	-- rewind stars
	for _, star in ipairs(launched_scene.stars) do
		if star.x < launched_scene.scroll_x/4 then
			launched_scene.rewind_star(star)
		end
	end
end

launched_scene.draw = function()
	local rocket = launched_scene.rocket
	love.graphics.translate(0, -H)
	love.graphics.push()
	love.graphics.translate(-launched_scene.scroll_x, 0)
	love.graphics.setColor(1, 1, 1)
	-- stars
	local star_scale = fn.clamp(rocket.vx / 1000 + 1, 1, 10) + love.math.random()
	for _, star in ipairs(launched_scene.stars) do
		love.graphics.draw(lf.get_texture('star.png'), star.x + launched_scene.scroll_x * 3/4, star.y, 0, star_scale, -1)
	end
	-- objects
	local y_offset = 20
	for _, obj in ipairs(launched_scene.objects) do
		if obj.x > launched_scene.scroll_x + W then
			local dx = obj.x - (launched_scene.scroll_x - rocket.width) - W
			local scale = fn.clamp(1 - dx / SPAWN_DISTANCE, 0, 1) * 0.75
			obj.animation:draw(obj.image, launched_scene.scroll_x + W - obj.width, obj.y + y_offset, 0, scale, -scale, obj.width_2, obj.height_2)
		else
			obj.animation:draw(obj.image, obj.x, obj.y + y_offset, 0, 1, -1, 0, obj.height_2)
		end
	end
	-- rocket
	rocket.animation:draw(rocket.image, launched_scene.scroll_x + rocket.offset_x, rocket.y + y_offset, 0, 1, -1, rocket.width, rocket.height_2)
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
end

--[[
   [ love/lf funs
   ]]

lf.init = function()
	game_time = 0
	gen_grids()
	love.graphics.setBackgroundColor(0, 0, 30 / 255)
	lf.load_screen('title', 'screens/title')
	lf.add_screen('moon', moon_scene)
	lf.add_screen('launched', launched_scene)
	lf.switch_to(screens.title)
end

love.keypressed = function(key, scancode, is_repeat)
	local screen = lf.current_screen()
	if screen.keypressed then
		screen.keypressed(key, scancode, is_repeat)
	end
end

love.keyreleased = function(key, scancode)
	local screen = lf.current_screen()
	if screen.keyreleased then
		screen.keyreleased(key, scancode)
	end
end

love.mousereleased = function(x, y, button, istouch, presses)
	if button == 1 then
		lf.current_screen().clicked(x, y)
	end
end

lf.update = function(dt)
	lf.current_screen().update(dt)
end

lf.draw = function()
	lf.current_screen().draw()
end
