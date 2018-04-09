local test = {}

function test.assert(b, m)
	if b == false then
		if m then wesnoth.log("error", m) end
		wesnoth.wml_actions.endlevel({result="defeat"})
	end
end

function test.success()
	wesnoth.wml_actions.endlevel({result="victory"})
end

return test
