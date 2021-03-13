local lf = require("lib/love-frame")
local fn = require('funs')

local screens = lf.screens()

local W, H = 800, 600
local W_2, H_2 = W/2, H/2

lf.data({
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

--[[
   [ love/lf funs
   ]]

lf.init = function()
	love.graphics.setBackgroundColor(0, 0, 30 / 255)
	lf.load_screen('title', 'screens/title')
	lf.load_screen('moon', 'screens/moon')
	lf.load_screen('launched', 'screens/launched')
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
