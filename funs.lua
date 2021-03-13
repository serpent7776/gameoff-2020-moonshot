local fn = {}

fn.rep = function(n, f)
	while n > 0 do
		f()
		n = n - 1
	end
end

fn.lerp = function(x, y, a)
	return y * a + x * (1 - a)
end

fn.clamp = function(x, min, max)
	if x < min then
		return min
	elseif x > max then
		return max
	else
		return x
	end
end

fn.sgn = function(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

fn.curry1 = function(fun, arg)
	return function()
		return fun(arg)
	end
end

fn.contains = function(obj, x, y)
	if x < obj.x or x > obj.x + obj.width then
		return false
	end
	if y < obj.y or y > obj.y + obj.height then
		return false
	end
	return true
end

fn.contains_centre = function(obj, x, y)
	local dx = math.abs(obj.x - x)
	if dx > obj.width/2 then
		return false
	end
	local dy = math.abs(obj.y - y)
	if dy > obj.height/2 then
		return false
	end
	return true
end

fn.clickable = function()
	local objects = {}
	local handlers = {}
	local t =  {
		add = function(obj, handler)
			table.insert(objects, obj)
			table.insert(handlers, handler)
		end,
		click = function(x, y)
			for i, obj in ipairs(objects) do
				if fn.contains(obj, x, y) then
					handlers[i](x, y)
				end
			end
		end,
	}
	local mt = {
		__next = function(_, k)
			return next(objects, k)
		end,
	}
	return setmetatable(t, mt)
end

fn.button = function(tex, x, y)
	return {
		tex = tex,
		x = x,
		y = y,
		width = tex:getWidth(),
		height = tex:getHeight(),
	}
end

fn.table_sum = function(tab)
	local sum = 0
	for _, val in ipairs(tab) do
		sum = sum + val
	end
	return sum
end

fn.decayed = function(initial, half_life)
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

fn.transistor = function(initial_state)
	local t = {
		call = nil,
		call_on = function(fun)
			fun()
		end,
		call_off = function(_)
			-- do nothing
		end,
		set = function(self, state)
			if state then
				self.call = self.call_on
			else
				self.call = self.call_off
			end
		end,
	}
	t:set(initial_state)
	return setmetatable(t, {
		__call = function(tr, fun)
			tr.call(fun)
		end,
	})
end

fn.deferred = function(timeout, reset_proc, func)
	return {
		initial_timeout = timeout,
		timeout = timeout,
		update = function(self, dt)
			self.timeout = self.timeout - dt
			if self.timeout <= 0 then
				func(dt)
				reset_proc(self)
			end
		end,
	}
end

fn.conditional = function(deferred, predicate)
	return {
		parent = deferred,
		update = function(self, dt)
			if predicate() then
				self.parent:update(dt)
			end
		end,
	}
end

fn.reset = function(deferred)
	deferred.timeout = deferred.timeout + deferred.initial_timeout
	return deferred
end

fn.continue = function(deferred)
	deferred.timeout = 0
	return deferred
end

fn.stop = function(deferred)
	deferred.update = function(_, _)
		-- do nothing
	end
	return deferred
end

fn.group = function()
	local objects = {}
	return {
		add = function(deferred)
			table.insert(objects, deferred)
		end,
		update = function(dt)
			for _, obj in ipairs(objects) do
				obj:update(dt)
			end
		end,
	}
end

fn.get_value = function(upgrade)
	return upgrade.values[upgrade.current_level]
end

fn.get_value_2 = function(upgrade, level)
	return upgrade.values[level]
end

fn.get_level = function(upgrade)
	return upgrade.current_level
end

fn.get_max_level = function(upgrade)
	return #upgrade.values
end

fn.get_cost = function(upgrade)
	return upgrade.costs[upgrade.current_level]
end

return fn
