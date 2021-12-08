local Players = game:GetService("Players")

local ChallengeStatusResult = {}
ChallengeStatusResult.__index = ChallengeStatusResult

function ChallengeStatusResult.new(challengeId, username, payload)
	assert(typeof(challengeId) == "string" and challengeId:len() > 0, "challengeId must be nonempty string")
	assert(typeof(username) == "string" and username:len() > 0, "username must be nonempty string")
	assert(typeof(payload) == "table", "payload must be a table")
	assert(typeof(payload["completed"]) == "boolean", "payload must include boolean \"completed\"")
	local self = setmetatable({
		challengeId = challengeId;
		username = username;
		player = nil;
		
		payload = payload;
		completed = payload["completed"];
	}, ChallengeStatusResult)
	return self
end

function ChallengeStatusResult:findPlayer()
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

function ChallengeStatusResult:isCompleted()
	return self.completed
end

return ChallengeStatusResult
