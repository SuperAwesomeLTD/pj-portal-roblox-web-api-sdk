local RunService = game:GetService("RunService")
local PopJamAPI = require(script.Parent)

local vUseStagingInStudio = script:WaitForChild("UseStagingInStudio")

local function shouldUseStagingInStudio()
	return vUseStagingInStudio.Value
end

local function selectEnvironment()
	return (shouldUseStagingInStudio() and RunService:IsStudio()) and "Staging" or "Production"
end

local function main()
	local environment = selectEnvironment()
	local popJamAPI = PopJamAPI.loadEnvironment(environment):expect()
	return popJamAPI
end

return main()
