local lf = require("lib/love-frame")
local fn = require('funs')

local screens = lf.screens()
local v = lf.data()
local W = v.W
local H = v.H

local image
local launch

return {
	load = function()
		image = love.graphics.newImage('assets/cover.png')
		launch = fn.button(lf.get_texture('launch.png'), W/2, H*3/4)
	end,

	hide = function()
		-- we can safely dispose images here
		-- title is being shown only once
		image = nil
		launch = nil
	end,

	update = function(_, _)
		-- do nothing
	end,

	draw = function(_)
		local im = image
		local btn = launch
		love.graphics.draw(im, 0, 0, 0, W/im:getWidth(), H/im:getHeight())
		love.graphics.draw(btn.tex, btn.x, btn.y, 0, 1, 1, btn.width/2, btn.height/2)
	end,

	keyreleased = function(_, key, _)
		if key == 'space' then
			lf.switch_to(screens.moon)
		end
	end,

	clicked = function(_, gx, gy)
		local w, h = love.graphics.getPixelDimensions()
		love.graphics.origin()
		love.graphics.scale(w/W, h/H)
		local x, y = love.graphics.transformPoint(gx, gy)
		if fn.contains_centre(launch, x, y) then
			lf.switch_to(screens.moon)
		end
	end,
}
