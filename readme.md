# PopJam Portal Roblox Web API SDK v1.0.0

This is a Roblox Lua client for the PopJam Portal's web API. It is used by the [PopJam Portal Roblox Connect Module](https://github.com/SuperAwesomeLTD/pj-portal-roblox-connect-module).

## Installation

1. Open the Experience in Roblox Studio.
2. Under Home &rarr; Game Settings &rarr; Security, enable **Allow HTTP Requests** if it is not already on.
3. Insert the model file into the place using one of the following methods:
   - Take the Model on Roblox.com, and insert it using the [Toolbox](https://developer.roblox.com/en-us/resources/studio/Toolbox).
   - Download the model file from the releases section, then right-click ServerScriptService and select **Insert from File...**
4. Using the [Explorer](https://developer.roblox.com/en-us/resources/studio/Explorer), ensure the module is a child of [ServerScriptService](https://developer.roblox.com/en-us/api-reference/class/ServerScriptService).

## Dependencies

The module itself includes all dependencies, which is only [roblox-lua-promise](https://github.com/evaera/roblox-lua-promise).

## Development

- Built using [Rojo](https://github.com/rojo-rbx/rojo) 6. The main project file is [default.project.json](default.project.json).
- [selene](https://github.com/Kampfkarren/selene) is used as a linter. The files [selene.toml](selene.toml) and [roblox.toml](roblox.toml) are used by this.