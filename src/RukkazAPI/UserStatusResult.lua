local Players = game:GetService("Players")

local UserStatusResult = {}
UserStatusResult.__index = UserStatusResult

function UserStatusResult.new(event, username, payload)
	assert(event, "event expected")
	assert(typeof(username) == "string" and username:len() > 0, "username must be nonempty string")
	assert(typeof(payload) == "table", "payload must be a table")
	assert(typeof(payload["completed"]) == "boolean", "payload must include boolean \"registered\"")
	assert(typeof(payload["completed"]) == "boolean", "payload must include boolean \"verified\"")
	local self = setmetatable({
		event = event;
		username = username;
		
		payload = payload;
		registered = payload["registered"];
		verified = payload["verified"];
	}, UserStatusResult)
	self.player = nil;
	return self
end

function UserStatusResult:findPlayer()
	if not self.player then
		for _, player in pairs(Players:GetPlayers()) do
			if player.Name:lower() == self.username:lower() then
				self.player = player
				break
			end
		end
	end
	return self.player
end

function UserStatusResult:isRegistered()
	return self.registered
end

function UserStatusResult:isVerified()
	return self.verified
end

return UserStatusResult
