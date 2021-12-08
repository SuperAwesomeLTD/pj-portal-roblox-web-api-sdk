local RunService = game:GetService("RunService")

local lib = require(script.Parent.Parent:WaitForChild("lib"))
local Timer = lib.Timer

local RukkazEvent = {}
RukkazEvent.__index = RukkazEvent

RukkazEvent.EP_USER_STATUS = "/user-status"
RukkazEvent.EP_TELEPORT_DETAILS = "/teleport-details"

function RukkazEvent.new(api, payload)
	local self = setmetatable({
		api = nil;
		payload = nil;
	}, RukkazEvent)

	self.api = api
	self.payload = payload
		
	self.id = assert(payload["id"], "id expected")
	self.userId = assert(payload["userId"], "userId expected")
	self.communityId = payload["communityId"]
	self.feedItemId = payload["feedItemId"]
	-- Note: timestamps are in milliseconds, convert to seconds for os.time compatibility
	self.eventTimestamp = assert(payload["eventTimestamp"], "eventTimestamp expected") / 1000
	self.endsAt = assert(payload["endsAt"], "endsAt expected") / 1000
	self.description = assert(payload["description"], "description expected")
	self.instructions = assert(payload["instructions"], "instructions expected")
	self.featured = assert(typeof(payload["featured"]) ~= nil, "featured expected") or payload["featured"]
	self.numberOfRegisteredUsers = assert(payload["numberOfRegisteredUsers"], "numberOfRegisteredUsers expected")
	self.gameType = assert(payload["gameType"], "gameType expected")
	
	-- TODO: add place ID and private server access code fields (do not replicate)
	self.placeId = payload["metadata"] and payload["metadata"]["placeId"]
	self.privateServerAccessCode = payload["metadata"] and payload["metadata"]["serverAccessCode"]
	self.robloxUsername = payload["robloxId"]
	self.hasTeleportData = (self.placeId and self.privateServerAccessCode) and true or false 
	

	return self
end

function RukkazEvent:getId()
	return self.id
end

function RukkazEvent:__tostring()
	return ("<RukkazEvent:%s %s %s>"):format(
		self:getId(),
		self:getHostName(),
		self:getShortDescription()
	)
end

function RukkazEvent:getUrlBase()
	return self.api:getUrlBase() .. "/" .. self:getId()
end

function RukkazEvent:isFeatured()
	return self.featured
end

function RukkazEvent:getHostName()
	return self.robloxUsername or "(No host)"
end

function RukkazEvent:getDescription()
	return self.description
end

function RukkazEvent:getShortDescription()
	local desc = self:getDescription() or ""
	local s, _e = desc:find("[\n\r]+")
	if s then
		return desc:sub(1, s - 1)
	else
		return desc
	end
end

function RukkazEvent:getInstructions()
	return self.instructions
end

function RukkazEvent:getNumberOfRegisteredUsers()
	return self.numberOfRegisteredUsers
end

function RukkazEvent:isRegistered()
	return self.isRegistered
end

function RukkazEvent:isEventOngoing()
	local now = os.time()
	return self.eventTimestamp < now and now < self.endsAt
end

function RukkazEvent:isEventInFuture()
	local now = os.time()
	return self.eventTimestamp > now
end

function RukkazEvent:getStartTimer()
	if self._startTimer then
		return self._startTimer
	end
	local now = os.time()
	local timeRemaining = self.eventTimestamp - now 
	assert(timeRemaining > 0, "Event has already started")
	local timer = Timer.new()
	timer:start(timeRemaining)
	self._startTimer = timer
	return self._startTimer
end

function RukkazEvent:getEndTimer()
	if self._endTimer then
		return self._endTimer
	end
	local now = os.time()
	local timeRemaining = self.endsAt - now 
	assert(timeRemaining > 0, "Event has already started")
	local timer = Timer.new()
	timer:start(timeRemaining)
	self._endTimer = timer
	return self._endTimer
end

function RukkazEvent:timeRemaining()
	return self.endsAt - os.time()
end

function RukkazEvent:isHost(player)
	return self.robloxUsername:lower() == player.Name:lower()
end

do -- User event registration status
	function RukkazEvent:isUserRegistered(username)
		assert(RunService:IsServer())
		return self.api:isUserRegisteredForEvent(username, self:getId())
	end
	
	function RukkazEvent:isUserRegisteredAsync(...)
		return self:isUserRegistered(...):await()
	end
end

function RukkazEvent:hasTeleportData()
	return self.hasTeleportData
end

return RukkazEvent
