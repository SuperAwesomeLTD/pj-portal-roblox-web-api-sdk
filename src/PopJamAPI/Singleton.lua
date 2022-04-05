local PopJamAPI = require(script.Parent)

local PopJamAPISingleton = {}
PopJamAPISingleton.config = script
PopJamAPISingleton.ATTR_ENVIRONMENT = "Environment"
PopJamAPISingleton.ATTR_DEBUG_MAIN_TOKEN = "DebugMainToken"
PopJamAPISingleton.ATTR_DEBUG_URL_BASE = "DebugUrlBase"

PopJamAPISingleton.popJamAPI = nil
PopJamAPISingleton.DEFAULT_ENVIRONMENT = "Production"

function PopJamAPISingleton:getDebugMainToken()
	return self.config:GetAttribute(PopJamAPISingleton.ATTR_DEBUG_MAIN_TOKEN)
end

function PopJamAPISingleton:getDebugUrlBase()
	return self.config:GetAttribute(PopJamAPISingleton.ATTR_DEBUG_URL_BASE)
end

function PopJamAPISingleton:getEnvironment()
	return self.config:GetAttribute(PopJamAPISingleton.ATTR_ENVIRONMENT) or PopJamAPISingleton.DEFAULT_ENVIRONMENT
end

function PopJamAPISingleton:main()
	if not self.popJamAPI then
		local debugMainToken = self:getDebugMainToken()
		local debugUrlBase = self:getDebugUrlBase()
		if debugMainToken ~= nil and debugUrlBase ~= nil then
			assert(typeof(debugUrlBase) == "string", PopJamAPISingleton.ATTR_DEBUG_URL_BASE .. " should be a string")
			assert(typeof(debugMainToken) == "string", PopJamAPISingleton.ATTR_DEBUG_MAIN_TOKEN .. " should be a string")
			warn(("PopJamAPISingleton debug: using url base %s with main token %s - remember to remove this!"):format(
				debugUrlBase,
				debugMainToken
			))
			return PopJamAPI.new(debugUrlBase, debugMainToken)
		else
			local environment = PopJamAPISingleton:getEnvironment()
			self.popJamAPI = PopJamAPI.loadEnvironment(environment):expect()
		end
	end
	return self.popJamAPI
end

return PopJamAPISingleton:main()
