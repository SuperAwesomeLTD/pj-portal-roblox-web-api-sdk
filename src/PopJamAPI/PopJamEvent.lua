local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local lib = require(script.Parent.Parent:WaitForChild("lib"))
local Promise = lib.Promise
local Timer = lib.Timer

local getUserInfosByUserIdsAsyncPromise = Promise.promisify(function (...)
	return UserService:GetUserInfosByUserIdsAsync(...)
end)

local PopJamEvent = {}
PopJamEvent.__index = PopJamEvent

PopJamEvent.EP_USER_STATUS = "/user-status"
PopJamEvent.EP_TELEPORT_DETAILS = "/teleport-details"

function PopJamEvent.new(api, payload)
	local self = setmetatable({
		api = nil;
		payload = nil;
	}, PopJamEvent)

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
	self.robloxUserId = payload["robloxUserId"]
	self.hasTeleportData = (self.placeId and self.privateServerAccessCode) and true or false 
	

	return self
end

function PopJamEvent:getId()
	return self.id
end

function PopJamEvent:__tostring()
	return ("<PopJamEvent:%s %s %s>"):format(
		self:getId(),
		self:getHostName(),
		self:getShortDescription()
	)
end

function PopJamEvent:getUrlBase()
	return self.api:getUrlBase() .. "/" .. self:getId()
end

function PopJamEvent:isFeatured()
	return self.featured
end

function PopJamEvent:getHostUserInfoAsync()
	local robloxUserId = self.robloxUserId
	return getUserInfosByUserIdsAsyncPromise({self.robloxUserId}):andThen(function (result)
		for _, userInfo in pairs(result) do
			if userInfo["Id"] == robloxUserId then
				return Promise.resolve(userInfo)
			end
		end
		return Promise.reject("Could not get host user info")
	end)
end

function PopJamEvent:getHostUserInfo(...)
	return PopJamEvent:getHostUserInfoAsync(...):expect()
end

function PopJamEvent:getHostUsernameAsync()
	return self:getHostUserInfoAsync():andThen(function (userInfo)
		return Promise.resolve(assert(userInfo["Username"], "Username expected"))
	end)
end

function PopJamEvent:getHostUsername()
	return self:getHostUsernameAsync():expect()
end

function PopJamEvent:getHostDisplayNameAsync()
	return self:getHostUserInfoAsync():andThen(function (userInfo)
		return Promise.resolve(assert(userInfo["DisplayName"], "DisplayName expected"))
	end)
end

function PopJamEvent:getHostDisplayName()
	return self:getHostDisplayNameAsync():expect()
end

function PopJamEvent:getDescription()
	return self.description
end

function PopJamEvent:getShortDescription()
	local desc = self:getDescription() or ""
	local s, _e = desc:find("[\n\r]+")
	if s then
		return desc:sub(1, s - 1)
	else
		return desc
	end
end

function PopJamEvent:getInstructions()
	return self.instructions
end

function PopJamEvent:getNumberOfRegisteredUsers()
	return self.numberOfRegisteredUsers
end

function PopJamEvent:isRegistered()
	return self.isRegistered
end

function PopJamEvent:isEventOngoing()
	local now = os.time()
	return self.eventTimestamp < now and now < self.endsAt
end

function PopJamEvent:isEventInFuture()
	local now = os.time()
	return self.eventTimestamp > now
end

function PopJamEvent:getStartTimer()
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

function PopJamEvent:getEndTimer()
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

function PopJamEvent:timeRemaining()
	return self.endsAt - os.time()
end

function PopJamEvent:isHost(player)
	return self.robloxUserId == player.UserId
end

do -- User event registration status
	function PopJamEvent:isUserRegisteredAsync(robloxUserId)
		lib.assertRobloxUserId(robloxUserId)
		assert(RunService:IsServer())
		return self.api:isUserRegisteredForEventAsync(robloxUserId, self:getId())
	end
	
	function PopJamEvent:isUserRegistered(...)
		return self:isUserRegisteredAsync(...):expect()
	end
end

function PopJamEvent:hasTeleportData()
	return self.hasTeleportData
end

return PopJamEvent
