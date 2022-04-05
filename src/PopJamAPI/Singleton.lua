local PopJamAPI = require(script.Parent)

local PopJamAPISingleton = {}
PopJamAPISingleton.config = script
PopJamAPISingleton.ATTR_ENVIRONMENT = "Environment"
PopJamAPISingleton.popJamAPI = nil
PopJamAPISingleton.DEFAULT_ENVIRONMENT = "Production"

function PopJamAPISingleton:getEnvironment()
	return self.config:GetAttribute(PopJamAPISingleton.ATTR_ENVIRONMENT) or PopJamAPISingleton.DEFAULT_ENVIRONMENT
end

function PopJamAPISingleton:main()
	if not self.popJamAPI then
		local environment = PopJamAPISingleton:getEnvironment()
		self.popJamAPI = PopJamAPI.loadEnvironment(environment):expect()
	end
	return self.popJamAPI
end

return PopJamAPISingleton:main()
