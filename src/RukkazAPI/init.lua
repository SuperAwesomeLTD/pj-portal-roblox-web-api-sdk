--[[

Rukkaz Web API

]]

local RunService = game:GetService("RunService")

local lib = require(script.Parent:WaitForChild("lib"))
local Promise = lib.Promise

local RukkazAPI = {}
RukkazAPI.__index = RukkazAPI
RukkazAPI.VERSION = "1.0.0"

-- ==== Defaults ====

-- Duration in seconds that the JWT returned from the /authenticate endpoint can be considered valid
RukkazAPI.DEFAULT_JWT_TIMEOUT = 30

-- ==== Environments ====

RukkazAPI.GROUP_ID = 12478861
RukkazAPI.Environments = {
	["Production"] = {
		urlBase = "https://sa-rukkaz-gamewithme-integrations.rukkaz.com";
		mainTokenAssetId = 7650250675;
	};
	["Staging"] = {
		urlBase = "https://api.gwm.staging.popjam.com";
		mainTokenAssetId = 7650254239;
	};
}

-- ==== Endpoints ====

RukkazAPI.EP_AUTHENTICATE = "/authenticate"
RukkazAPI.EP_UPCOMING_EVENTS = "/upcoming"
RukkazAPI.EP_CHALLENGE_STATUS = "/challenge-status"
RukkazAPI.EP_EVENT_SETUP = "/event-setup"

-- ==== Errors ====

-- Endpoint returned a non-200 response.
RukkazAPI.ERR_STATUS_CODE = "ErrStatusCode"

-- Endpoint did not return valid JSON
RukkazAPI.ERR_JSON_PARSE = "ErrJsonParse"

-- Provided Roblox username did nto have a matching Rukkaz user
RukkazAPI.ERR_RUKKAZ_USER_NOT_FOUND = "ErrRukkazUserNotFound"

-- No event has the provided setup code
RukkazAPI.ERR_SETUP_CODE_INVALID = "ErrSetupCode"
RukkazAPI.ERR_NO_MATCHING_EVENT = "ErrNoMatchingEvent"

-- Endpoint had a malformed response (missing JSON keys)
RukkazAPI.ERR_BAD_RESPONSE = "ErrBadResponse"

RukkazAPI.ERR_RESERVE_SERVER_FAILED = "ErrReserveServerFailed"

RukkazAPI.ERR_PLACE_ID_INVALID = "ErrPlaceIdInvalid"

function RukkazAPI.loadEnvironment(name)
	assert(typeof(name) == "string", "name should be a string")
	local environment = assert(RukkazAPI.Environments[name], "No such environment: " .. name)
	local urlBase = assert(environment.urlBase, "Environment missing urlBase")
	local useMainToken = RukkazAPI.isOfficial()
	if useMainToken then
		return Promise.new(function (resolve, _reject, _onCancel)
			resolve(require(assert(environment.mainTokenAssetId, "Environment missing mainTokenAssetId")))
		end):andThen(function (mainToken)
			local api = RukkazAPI.new(urlBase, mainToken)
			api._environment = name
			return Promise.resolve(api)
		end)
	else
		local api = RukkazAPI.new(urlBase, nil)
		api._environment = name
		return Promise.resolve(api)
	end
end

function RukkazAPI.isOfficial()
	return game.CreatorType == Enum.CreatorType.Group and game.CreatorId == RukkazAPI.GROUP_ID
end

function RukkazAPI.production()
	return RukkazAPI.loadEnvironment("Production")
end

function RukkazAPI.staging()
	return RukkazAPI.loadEnvironment("Staging")
end

function RukkazAPI.new(urlBase, mainToken)
	assert(typeof(urlBase) == "string", "urlBase should be a string")
	--assert(typeof(mainToken) == "string")
	local self = setmetatable({
		_environment = "Unknown";
		-- Protocol and hostname without trailing slash of request URLs
		_urlBase = urlBase;
		-- Token to provide the /authenticate endpoint
		_mainToken = mainToken;
		-- JWT returned by the /authenticate endpoint
		_jwt = nil;
		-- Timestamp (os.time()) that the JWT was received
		_jwtTimestamp = nil;
	}, RukkazAPI)
	if self._mainToken then
		self:authenticate(true)
	end
	return self
end

function RukkazAPI:getUrlBase()
	return self._urlBase
end

function RukkazAPI:getMainToken()
	return self._mainToken
end

function RukkazAPI:getEnvironment()
	return self._environment
end

do -- Authenticate and JWT methods
	function RukkazAPI.getJWTTimeout()
		return RukkazAPI.DEFAULT_JWT_TIMEOUT
	end

	--- Confidence check for JWT value
	function RukkazAPI.isJWT(value)
		return typeof(value) == "string"
	end
	
	function RukkazAPI:getAuthenticateEndpoint()
		return self:getUrlBase() .. RukkazAPI.EP_AUTHENTICATE
	end

	function RukkazAPI:isJWTValid()
		local timeout = RukkazAPI.getJWTTimeout()
		return assert(self._jwtTimestamp, "JWT Timestamp missing") + timeout > os.time()
	end

	function RukkazAPI:isJWTAuthenticated()
		return self._jwt and self:isJWTValid()
	end
	
	function RukkazAPI:getAuthorizationHeader()
		return ("Bearer %s"):format(self._jwt)
	end
	
	function RukkazAPI:getHeaders(includeAuth)
		local headers = {}
		if includeAuth then
			headers["Authorization"] = self:getAuthorizationHeader();
		end
		return headers
	end

	function RukkazAPI:authenticate(override)
		-- If the JWT is still good, then this is a no-op.
		if self:isJWTAuthenticated() and not override then return Promise.resolve(self._jwt) end
		
		-- Use an existing auth promise if it is still pending. 
		if self._authPromise then return self._authPromise end
		
		local mainToken = self:getMainToken()
		assert(typeof(mainToken) == "string", "Main token required for authentication")
		
		-- Build request data to send to HttpService:RequestAsync 
		-- https://developer.roblox.com/en-us/api-reference/function/HttpService/RequestAsync
		local requestData = {
			["Url"] = self:getAuthenticateEndpoint();
			["Headers"] = {
				["Authorization"] = "Bearer " .. mainToken
			};
			["Method"] = "GET";
		}
		
		-- Build promise
		local promise = lib.requestAsyncPromise(requestData)
		:andThen(function (responseData)
			-- Must have received a 200 OK
			if responseData["StatusCode"] ~= 200 then
				warn("RukkazAPI auth failed")
				return Promise.reject(RukkazAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
			end
			
			-- Check for existence of string "token" key in response
			local payload = lib.jsonDecode(responseData["Body"])
			local token = payload["token"]
			if RukkazAPI.isJWT(token) then
				self._jwt = token
				self._jwtTimestamp = os.time()
				return Promise.resolve(token)
			else
				return Promise.reject(RukkazAPI.ERR_BAD_RESPONSE)
			end
		end)
		--:catch(self.handleAuthFailure)
		
		-- Remember the promise so that if something else calls :authenticate(), it uses
		-- the in-progress promise we just built. When it resolves, forget about it.
		self._authPromise = promise
		promise:finally(function ()
			self._authPromise = nil
		end)
		return self._authPromise
	end
end

do -- Events
	local RukkazEvent = require(script:WaitForChild("RukkazEvent"))
	local Pagination = require(script:WaitForChild("Pagination"))
	
	function RukkazAPI:getUpcomingEventsEndpoint()
		return self:getUrlBase() .. RukkazAPI.EP_UPCOMING_EVENTS
	end
	
	function RukkazAPI:getUpcomingEvents()
		return self:authenticate():andThen(function (_jwt)
			local requestData = {
				["Url"] = self:getUpcomingEventsEndpoint();
				["Headers"] = self:getHeaders(true);
				["Method"] = "GET";
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				-- Must have received a 200 OK
				if responseData["StatusCode"] ~= 200 then
					return Promise.reject(RukkazAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end

				local payload = lib.jsonDecode(responseData["Body"])
				return Promise.resolve(Pagination.new(self, RukkazEvent.new, payload))
			end)
		end)
	end

	do -- User event registration status
		local UserStatusResult = require(script:WaitForChild("UserStatusResult"))

		function RukkazAPI:getUserStatusEndpoint(eventId)
			return self:getUrlBase() .. "/" .. eventId .. RukkazEvent.EP_USER_STATUS
		end

		function RukkazAPI:getUserStatusForEvent(username, eventId)
			return self:authenticate():andThen(function ()
				local requestData = {
					["Url"] = self:getUserStatusEndpoint(eventId) .. "?" .. lib.queryString{username=username};
					["Headers"] = self:getHeaders(true);
					["Method"] = "GET";
				}
				
				return lib.requestAsyncPromise(requestData):andThen(function (responseData)
					-- Must have received a 200 OK
					if responseData["StatusCode"] ~= 200 then
						local success, payload = lib.jsonDecode(responseData["Body"])
						if success and typeof(payload) == "table" then
							warn(payload)
						end
						return Promise.reject(self.ERR_STATUS_CODE .. responseData["StatusCode"])
					end

					local payload = lib.jsonDecode(responseData["Body"])
					return Promise.resolve(UserStatusResult.new(self, username, payload))
				end)
			end)
		end

		function RukkazAPI:isUserRegisteredForEvent(username, eventId)
			assert(RunService:IsServer())
			return self:getUserStatusForEvent(username, eventId):andThen(function (userStatusResult)
				return Promise.resolve(userStatusResult:isRegistered())
			end, function (err)
				warn(tostring(err))
				return Promise.resolve(nil)
			end)
		end

		function RukkazAPI:isUserRegisteredForEventAsync(...)
			return self:isUserRegisteredForEvent(...):await()
		end
	end
	
	do  -- In-app challenges
		local ChallengeStatusResult = require(script:WaitForChild("ChallengeStatusResult"))

		function RukkazAPI:getChallengeStatusEndpoint(challengeId)
			assert(typeof(challengeId) == "string", "challengeId should be a string")
			return self:getUrlBase() .. "/" .. challengeId .. RukkazAPI.EP_CHALLENGE_STATUS
		end

		function RukkazAPI:getChallengeStatusForUser(challengeId, username)
			assert(typeof(challengeId) == "string" and challengeId:len() > 0, "challengeId should be a nonempty string")
			return self:authenticate():andThen(function ()
				local requestData = {
					["Url"] = self:getChallengeStatusEndpoint(challengeId) .. "?" .. lib.queryString{username=username};
					["Headers"] = self:getHeaders(true);
					["Method"] = "GET";
					--["Body"] = nil;
				}
				return lib.requestAsyncPromise(requestData):andThen(function (responseData)
					-- Must have received a 200 OK
					if responseData["StatusCode"] == 404 then
						return Promise.reject(RukkazAPI.ERR_RUKKAZ_USER_NOT_FOUND)
					elseif responseData["StatusCode"] ~= 200 then
						--local success, payload = lib.jsonDecode(responseData["Body"])
						return Promise.reject(self.ERR_STATUS_CODE .. responseData["StatusCode"])
					end

					local payload = lib.jsonDecode(responseData["Body"])
					return Promise.resolve(ChallengeStatusResult.new(self, username, payload))
				end)
			end)
		end

		function RukkazAPI:hasUserCompletedChallenge(challengeId, username)
			assert(RunService:IsServer())
			return self:getChallengeStatusForUser(challengeId, username):andThen(function (challengeStatusResult)
				print(username, "Challenge status", challengeStatusResult:isCompleted())
				return Promise.resolve(challengeStatusResult:isCompleted())
			end, function (err)
				warn(tostring(err))
				return Promise.resolve(nil)
			end)
		end

		function RukkazAPI:hasUserCompletedChallengeAsync(...)
			return self:hasUserCompletedChallenge(...):await()
		end
	end
	
	do -- Event host module API
		local function isSetupCodeValid(setupCode)
			return typeof(setupCode) == "string" and setupCode:len() >= 6
		end
		
		function RukkazAPI:getEventIdBySetupCode(setupCode)
			assert(isSetupCodeValid(setupCode))
			local requestData = {
				["Url"] = self:getUrlBase() .. RukkazAPI.EP_EVENT_SETUP .. "?" .. lib.queryString{setupCode=setupCode};
				["Method"] = "GET";
				["Headers"] = self:getHeaders(false);
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				local payload = lib.jsonDecode(responseData["Body"])
				assert(payload, RukkazAPI.ERR_JSON_PARSE)
				if responseData["StatusCode"] == 200 then
					local eventId = payload["id"]
					assert(typeof(eventId) == "string" and eventId:len() > 0, "eventId should be a nonempty string")
					return Promise.resolve(eventId)
				elseif responseData["StatusCode"] == 400 then
					warn(table.concat(payload["message"],"\n"))
					return Promise.reject(RukkazAPI.ERR_SETUP_CODE_INVALID)
				elseif responseData["StatusCode"] == 404 then
					return Promise.reject(RukkazAPI.ERR_NO_MATCHING_EVENT)
				else
					return Promise.reject(RukkazAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end
			end)
		end

		function RukkazAPI:setTeleportDetailsForEvent(eventId, setupCode, placeId, privateServerId, privateServerAccessCode)
			assert(typeof(eventId) == "string" and eventId:len() > 0, "eventId should be a nonempty string")
			assert(isSetupCodeValid(setupCode), "valid setup code expected, got " .. tostring(setupCode))
			assert(typeof(placeId) == "number" and math.floor(placeId) == placeId and placeId > 0, "placeId should be valid")
			assert(typeof(privateServerAccessCode) == "string" and privateServerAccessCode:len() > 0, "privateServerAccessCode should be a nonempty string")
			local requestPayload = {
				["setupCode"] = setupCode;
				["placeId"] = placeId;
				["serverId"] = privateServerId;
				["serverAccessCode"] = privateServerAccessCode;
			}
			local headers = self:getHeaders(false)
			headers["Content-Type"] = "application/json"
			local requestData = {
				["Method"] = "PATCH";
				["Url"] = self:getUrlBase() .. "/" .. eventId .. RukkazEvent.EP_TELEPORT_DETAILS;
				["Headers"] = headers;
				["Body"] = lib.jsonEncode(requestPayload);
			}
			return lib.requestAsyncPromise(requestData):andThen(function (responseData)
				if responseData["StatusCode"] == 200 then
					return Promise.resolve(true)
				else
					warn("Failed to set event teleport details of event", setupCode, eventId, responseData["Body"])
					return Promise.reject(RukkazAPI.ERR_STATUS_CODE .. responseData["StatusCode"])
				end
			end)
		end

		function RukkazAPI:setEventHostPlaceIdCallback(callback)
			assert(typeof(callback) == "function", "callback should be a function")
			self._placeIdCallback = callback
		end
		
		local function isValidPlaceId(placeId)
			return typeof(placeId) == "number" and placeId > 0 and math.floor(placeId) == placeId
		end
		
		function RukkazAPI:setEventHostPlaceId(placeId)
			assert(isValidPlaceId(placeId), RukkazAPI.ERR_PLACE_ID_INVALID)
			self:setEventHostPlaceIdCallback(function (_eventId)
				return placeId
			end)
		end
		
		local function generatePhonyPrivateServerAccessCode()
			return "phony-access-code-" .. math.random(10000,99999)
		end
		
		local function generatePhonyPrivateServerId()
			return lib.generateGUID()
		end

		local TeleportService = game:GetService("TeleportService")
		local reserveServerPromise = Promise.promisify(function (...)
			if RunService:IsStudio() then
				local privateServerAccessCode = generatePhonyPrivateServerAccessCode()
				local privateServerId = generatePhonyPrivateServerId()
				warn("ReserveServer was called in Studio! Generating phony teleport details:", privateServerAccessCode, privateServerId) 
				return privateServerAccessCode, privateServerId 
			else
				return TeleportService:ReserveServer(...)
			end
		end)
		function RukkazAPI:setupEvent(setupCode)
			return self:getEventIdBySetupCode(setupCode):andThen(function (eventId)
				local placeIdPromise = self._placeIdCallback and Promise.promisify(self._placeIdCallback)(eventId) or Promise.resolve(game.PlaceId)
				return placeIdPromise:andThen(function (placeId)
					assert(isValidPlaceId(placeId), RukkazAPI.ERR_PLACE_ID_INVALID)
					return reserveServerPromise(placeId):catch(function (err)
						warn(err)
						return Promise.reject(RukkazAPI.ERR_RESERVE_SERVER_FAILED)
					end):andThen(function (privateServerAccessCode, privateServerId)
						return self:setTeleportDetailsForEvent(eventId, setupCode, placeId, privateServerId, privateServerAccessCode):andThen(function ()
							return Promise.resolve(placeId, eventId, privateServerId, privateServerAccessCode)
						end)
					end)
				end)
			end)
		end
	end
end

return RukkazAPI
