local Module = {}

local meta = {
	__index = Module
}

function Module.new ()
	local q = {
		first = 1,
		last = 0
	}
	setmetatable(q, meta)
	return q
end

function Module.peek (q)
	if q.first > q.last then
		log('Queue.peek: No elements')
		return nil
	end
	return q[q.first]
end

function Module.pop (q)
	if q.first > q.last then
		log('Queue.pop: No elements')
		return nil
	end

	local x = q[q.first]
	q[q.first] = nil
	q.first = q.first+1

	return x
end

function Module.add (q, x)
	q.last = q.last+1
	q[q.last] = x
end

function Module.empty (q)
	return q.first > q.last
end

function Module.size (q)
	return q.last - q.first + 1
end


function Module.iterator (q)
	return
		function (_queue, _key)
			local idx = _key + _queue.first
			if idx > _queue.last then
				return nil
			else
				return _key+1, _queue[idx]
			end
		end,
		q,
		0
end

-- Constructing Metatable
-- for k, v in pairs(Module) do
-- 	meta[k] = v
-- end


function Module.on_load (q)
	if q then
		setmetatable(q, meta)
	else
		log ("Queue.on_load: Argument must be a table")
	end
end

return Module
