local RunService = game:GetService("RunService")
local RukkazAPI = require(script.Parent)

local vUseStagingInStudio = script:WaitForChild("UseStagingInStudio")

local function shouldUseStagingInStudio()
	return vUseStagingInStudio.Value
end

local function selectEnvironment()
	return (shouldUseStagingInStudio() and RunService:IsStudio()) and "Staging" or "Production"
end

local function main()
	local environment = selectEnvironment()
	local rukkazAPI = RukkazAPI.loadEnvironment(environment):expect()
	return rukkazAPI
end

return main()
