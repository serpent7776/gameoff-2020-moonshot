local lf = require("lib/love-frame")
local fn = require('funs')

local screens = lf.screens()
local v = lf.data()
local W = v.W
local H = v.H
local W_2 = v.W_2

local bg
local buttons
local fuel_upgrade
local acceleration_upgrade
local durability_upgrade
local launch

local function buy_upgrade(upgrade)
	local can_upgrade = upgrade.current_level < #upgrade.values
	if can_upgrade and v.cash >= upgrade.costs[upgrade.current_level] then
		v.cash = v.cash - upgrade.costs[upgrade.current_level]
		upgrade.current_level = upgrade.current_level + 1
		return true
	end
	return false
end

local function update_upgrade_button(button)
	local level = fn.get_level(button.upgrade)
	local image = string.format('up-%s-%d.png', button.name, level)
	button.tex = lf.get_texture(image)
end

local function update_upgrade_buttons()
	update_upgrade_button(fuel_upgrade)
	update_upgrade_button(acceleration_upgrade)
	update_upgrade_button(durability_upgrade)
end

local function do_upgrade(upgrade)
	local ok = buy_upgrade(upgrade)
	if ok then
		lf.play_sound('click.wav')
	else
		lf.play_sound('no.wav')
	end
	update_upgrade_buttons()
end

local function create_button(image_name, x, y, handler)
	local btn = fn.button(lf.get_texture(image_name), x, y)
	buttons.add(btn, handler)
	return btn
end

local function create_upgrade_button(name, x, y, upgrade)
	local handler = fn.curry1(do_upgrade, upgrade)
	local btn = create_button('up-dummy.png', x, y, handler) -- image name will be updated in update_upgrade_button
	btn.upgrade = upgrade
	btn.name = name
	return btn
end

local function draw_button(btn)
	love.graphics.draw(btn.tex, btn.x, btn.y, 0, 1, -1, 0, btn.height)
end

local function draw_upgrade_button(btn)
	draw_button(btn)
	local current = fn.get_level(btn.upgrade)
	local max = fn.get_max_level(btn.upgrade)
	local level_str = string.format('%d/%d', current, max)
	love.graphics.printf(level_str, btn.x, btn.y, 100, 'right', 0, 1, -1)
	local cost = fn.get_cost(btn.upgrade)
	if cost then
		local cost_str = string.format('$%d', cost)
		love.graphics.printf(cost_str, btn.x, btn.y-20, 100, 'right', 0, 1, -1)
	end
end

return {
	load = function()
		bg = lf.get_texture('moon.png')
	end,

	show = function()
		-- viewport origin is at bottom, centre and goes right and up
		lf.setup_viewport(W, -H)
		buttons = fn.clickable()
		fuel_upgrade = create_upgrade_button('fuel', 25, H-150-10, v.fuel)
		acceleration_upgrade = create_upgrade_button('acceleration', 350, H-150-10, v.acceleration)
		durability_upgrade = create_upgrade_button('durability', 650, H-150-10, v.durability)
		launch = create_button('launch.png', W/2-123, H*1/4-23, fn.curry1(lf.switch_to, screens.launched_scene))
		update_upgrade_buttons()
	end,

	keyreleased = function(key, scancode)
		if key == 'space' then
			lf.switch_to(screens.launched)
		elseif key == '1' then
			do_upgrade(v.fuel)
		elseif key == '2' then
			do_upgrade(v.acceleration)
		elseif key == '3' then
			do_upgrade(v.durability)
		end
	end,

	clicked = function(gx, gy)
		local w, h = love.graphics.getPixelDimensions()
		love.graphics.origin()
		love.graphics.scale(w/W, h/-H)
		love.graphics.translate(0, -H)
		local x, y = love.graphics.transformPoint(gx, gy)
		buttons.click(x, y)
	end,

	update = function(dt)
	end,

	draw = function()
		love.graphics.translate(0, -H)
		love.graphics.push()
		love.graphics.translate(W_2, 0)
		love.graphics.draw(bg, 0, 0, 0, 1, -1, bg:getWidth()/2, bg:getHeight())
		love.graphics.pop()
		draw_upgrade_button(fuel_upgrade)
		draw_upgrade_button(acceleration_upgrade)
		draw_upgrade_button(durability_upgrade)
		draw_button(launch)
		local wallet = string.format('$%s', v.cash)
		love.graphics.printf(wallet, 25, 25, 100, 'left', 0, 1, -1)
	end,
}
