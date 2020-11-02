local lf = require("lib/love-frame")

local W, H, W_2, H_2
local moon_top_h
local moon_vertices

local function lerp(x, y, a)
	return y * a + x * (1 - a)
end

local function sinc(x, y, a)
	return lerp(x, y, math.sin(a * math.pi / 2))
end

local function prepare_data()
	moon_top_h = H * 0.1
	moon_vertices = {}
	local max_i = 10
	for i = 0, max_i do
		local c = max_i / 2
		local x = (i - c) / c * W_2
		local y = sinc(0, moon_top_h, i / c)
		moon_vertices[i * 2 + 1] = x
		moon_vertices[i * 2 + 2] = y
	end
end

lf.init = function()
	W, H = 800, 600
	W_2, H_2 = W / 2, H / 2
	-- viewport origin is at bottom, centre and goes right and up
	lf.setup_viewport(W, -H)
	prepare_data()
end

lf.update = function(dt)
end

lf.draw = function()
	love.graphics.translate(W_2, -H)
	love.graphics.polygon('fill', moon_vertices)
end
