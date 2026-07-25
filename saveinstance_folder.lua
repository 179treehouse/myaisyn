--!native
--!optimize 2
--!divine-intellect
-- https://discord.gg/wx4ThpAsmw
-- Fork: ScriptsToFolder mode - saves decompiled scripts to a folder structure instead of XML place file

local function string_find(s, pattern, init)
	return string.find(s, pattern, init, true)
end

local function ArrayToDict(t, hydridMode, valueOverride, typeStrict)
	local tmp = {}

	if hydridMode then
		for any1, any2 in next, t do
			if type(any1) == "number" then
				tmp[any2] = valueOverride or true
			elseif type(any2) == "table" then
				tmp[any1] = ArrayToDict(any2, hydridMode) -- any1 is Class, any2 is Name
			else
				tmp[any1] = any2
			end
		end
	else
		for _, key in next, t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

local global_container
do
	local filename = "UniversalMethodFinder"

	local finder
	finder, global_container = loadstring(
		game:HttpGet("https://raw.githubusercontent.com/luau/SomeHub/main/" .. filename .. ".luau", true),
		filename
	)()

	finder({
		base64encode = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"encode")and(c(b,"base64")or c(string.lower(tostring(a[2])),"base64"))',
		gethiddenproperty = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"prop",nil,true) and string.sub(...,#...) ~= "s"',
		gethui = 'string.find(...,"get",nil,true) and string.find(...,"h",nil,true) and string.find(...,"ui",nil,true)',
		getnilinstances = 'string.find(...,"nil",nil,true) and string.find(...,"get",nil,true) and string.sub(...,#...) == "s"',
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"script",nil,true) and string.find(...,"bytecode",nil,true)',
		protectgui = 'string.find(...,"protect",nil,true) and string.find(...,"ui",nil,true) and not string.find(...,"un",nil,true)',
	}, true, 10)
end

local identify_executor = identifyexecutor or getexecutorname or whatexecutor

local EXECUTOR_NAME = identify_executor and identify_executor() or ""

local gethiddenproperty = global_container.gethiddenproperty

-- These should be universal enough
local appendfile = appendfile
local isfile = isfile
local readfile = readfile
local writefile = writefile
local makefolder = makefolder
local delfolder = delfolder
local listfiles = listfiles

local getscriptbytecode = global_container.getscriptbytecode
local base64encode = global_container.base64encode

local service = setmetatable({}, {
	__index = function(self, serviceName)
		local o, s = pcall(Instance.new, serviceName)
		local Service = o and s
			or game:GetService(serviceName)
			or settings():GetService(serviceName)
			or UserSettings():GetService(serviceName)

		if Service then
			self[serviceName] = Service
		end
		return Service
	end,
})

local FULL_VERSION

if not pcall(function()
	FULL_VERSION = version()
end) then
	if not pcall(function()
		FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion
	end) then
		if not pcall(function()
			FULL_VERSION = service.RunService:GetRobloxVersion()
		end) then
			FULL_VERSION = "UNKNOWN"
		end
	end
end

local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9
local __BREAK = "__BREAK" .. service.HttpService:GenerateGUID(false)

local inherited_properties = {}
local default_instances = {}

local GLOBAL_ENV = getgenv and getgenv() or _G or shared

--[=[
    @class SynSaveInstance
    Represents the options for saving instances with custom settings using the synsaveinstance function.
]=]

--- @interface CustomOptions table
--- * Structure of the main CustomOptions table.
--- * Note: Options are case-insensitive, meaning you can type `NilInstances` option as `nilInStaNces` and it still will be valid.
--- @within SynSaveInstance
--- @field __DEBUG_MODE boolean -- This will print debug logs to console about unusual scenarios. Recommended to enable if you wish to help us improve our products and find bugs / issues with it! ___Default:___ false
--- @field ReadMe boolean --___Default:___ true
--- @field SafeMode boolean -- Kicks you before Saving, which keeps you safe. **HIGHLY RECOMMENDED TO KEEP ENABLED**. ___Default:___ true
--- @field KillAllScripts boolean -- Kills all scripts to further protect you. SafeMode also enables this by default. **HIGHLY RECOMMENDED TO KEEP ENABLED**. ___Default:___ true
--- @field BoostFPS boolean -- Massively boosts FPS by disabling 3D rendering. Other options also enable it, like: SafeMode. ___Default:___ false
--- @field ShutdownWhenDone boolean -- Shuts the game down after saveinstance is finished. ___Default:___ false
--- @field AntiIdle boolean -- Prevents the 20-minute-Idle Kick. ___Default:___ true
--- .Anonymous {boolean|table{UserId = string, Name = string}} -- * **RISKY:** Cleans the file of any info related to your account like: Name, UserId. This is useful for some games that might store that info in GUIs or other Instances. Might potentially mess up parts of strings that contain characters that match your Name or parts of numbers that match your UserId. Can also be a table with UserId & Name keys. ___Default:___ false
--- @field ShowStatus boolean -- ___Default:___ true
--- @field Callback function -- If set, the serialized data will be sent to the callback function instead of to file. ___Default:___ false
--- @field mode string -- Valid modes: full, optimized, scripts. Change this to invalid mode like "invalid" if you only want ExtraInstances. "optimized" mode is **NOT** supported with *@Object* option. ___Default:___ `"optimized"`
--- @field Decompile boolean -- Script decompiling. ___Default:___ true
--- @field scriptcache boolean -- Use decompiled script cache to avoid decompiling duplicate scripts. ___Default:___ true
--- @field DecompileTimeout number -- If the decompilation run time exceeds this value it gets cancelled. Set to -1 to disable timeout (unreliable). ___Default:___ 10
--- @field DecompileJobless boolean -- Includes already decompiled code in the output. No new scripts are decompiled. ___Default:___ false
--- @field SaveBytecode boolean -- Includes bytecode in the output. Useful if you wish to be able to decompile it yourself later. ___Default:___ false
--- .DecompileIgnore {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- * Ignores match & it's descendants by default. To Ignore only the instance itself set the value to `= false`. Examples: "Chat", - Matches any instance with "Chat" ClassName, Players = {"MyPlayerName"} - Matches "Players" Class AND "MyPlayerName" Name ONLY, `workspace` - matches Instance by reference, `[workspace] = false` - matches Instance by reference and only ignores the instance itself and not it's descendants. ___Default:___ {TextChatService}
--- .IgnoreList {Instance | Instance.ClassName | [Instance.ClassName] = {Instance.Name}} -- Structure is similar to **@DecompileIgnore** except `= false` meaning if you ignore one instance it will automatically ignore it's descendants. ___Default:___ {CoreGui, CorePackages}
--- .ExtraInstances {Instance} -- If used with any invalid mode (like "invalidmode") it will only save these instances. ___Default:___ {}
--- @field IgnoreProperties table -- Ignores properties by Name. ___Default:___ {}
--- @field SaveCacheInterval number -- The less the value the more often it saves, but that would mean less performance due to constantly saving. ___Default:___ 0x1600 * 10
--- @field FilePath string -- Must only contain the name (can include path) of the file, no file extension. ___Default:___ false
--- @field AvoidFileOverwrite boolean -- Prevents writing to place file that already exists. ___Default:___ true
--- @field Object Instance -- * If provided, saves as .rbxmx (Model file) instead. If Object is game, it will be saved as a .rbxl file. **MUST BE AN INSTANCE REFERENCE, FOR EXAMPLE - *game.Workspace***. `"optimized"` mode is **NOT** supported with this option. If IsModel is set to false then Object specified here will be saved as a place file. ___Default:___ false
--- @field IsModel boolean -- If Object is specified then sets to true automatically, unless you set it to false. ___Default:___ false
--- @field NilInstances boolean -- Save instances that aren't Parented (Parented to nil). ___Default:___ false
--- .NilInstancesFixes {[Instance.ClassName] = function} -- * This can cause some Classes to be fixed even though they might not need the fix (better be safe than sorry though). For example, Bones inherit from Attachment if we dont define them in the NilInstancesFixes then this will catch them anyways. **TO AVOID THIS BEHAVIOR USE THIS EXAMPLE:** {ClassName_That_Doesnt_Need_Fix = false}. ___Default:___ {Animator = function, AdPortal = function, BaseWrap = function, Attachment = function}
--- @field IgnoreDefaultProperties boolean -- Ignores default properties during saving.  ___Default:___ true
--- @field IgnoreNotArchivable boolean -- Ignores the Archivable property and saves Non-Archivable instances. ___Default:___ true
--- @field IgnorePropertiesOfNotScriptsOnScriptsMode boolean -- Ignores property of every instance that is not a script in "scripts" mode. ___Default:___ false
--- @field IgnoreSpecialProperties boolean -- Prevents calls to `gethiddenproperty` and uses fallback methods instead. This also helps with crashes. If your file is corrupted after saving, you can try turning this on. ___Default:___ false
--- @field IsolateStarterPlayer boolean -- Saves StarterPlayer as separate folder, children of the original instance will be ignored. ___Default:___ false
--- @field IsolatePlayers boolean -- Saves All Players as separate folder, children of the original instance will be ignored. ___Default:___ false
--- @field IsolateLocalPlayer boolean -- Saves LocalPlayer as separate folder, original instance will be ignored. ___Default:___ false
--- @field IsolateLocalPlayerCharacter boolean -- Saves LocalPlayer.Character as separate folder, original instance will be ignored. ___Default:___ false
--- @field SavePlayerCharacters boolean -- Ignore player characters while saving. ___Default:___ false
--- @field SaveNotCreatable boolean -- * Includes non-serializable instances as Folder objects (Name is misleading as this is mostly a fix for certain NilInstances and isn't always related to NotCreatable). Other options also enable it, like: IsolatePlayers, IsolateLocalPlayer, etc. ___Default:___ false
--- .NotCreatableFixes table<Instance.ClassName> -- * {"Player"} is the same as {Player = "Folder"}; Format like {SpawnLocation = "Part"} is only to be used when SpawnLocation inherits from "Part" AND "Part" is Creatable. ___Default:___ { "", "Player", "PlayerScripts", "PlayerGui", "TouchTransmitter" }
--- @field AlternativeWritefile boolean -- * Splits file content string into segments and writes them using appendfile. This might help with crashes when it starts writing to file. Though there is a risk of appendfile working incorrectly on some executors. ___Default:___ true
--- @field IgnoreDefaultPlayerScripts boolean -- * **RISKY: Ignores Default PlayerScripts like PlayerModule & RbxCharacterSounds. Prevents crashes on certain Executors. ___Default:___ true
--- @field IgnoreSharedStrings boolean -- * **RISKY: FIXES CRASHES (TEMPORARY, TESTED ON ROEXEC ONLY). FEEL FREE TO DISABLE THIS TO SEE IF IT WORKS FOR YOU**. ___Default:___ true
--- @field SharedStringOverwrite boolean -- * **RISKY:** if the process is not finished aka crashed then none of the affected values will be available. SharedStrings can also be used for ValueTypes that aren't `SharedString`, this behavior is not documented anywhere but makes sense (Could create issues though, due to _potential_ ValueType mix-up, only works on certain types which are all base64 encoded so far). Reason: Allows for potential smaller file size (can also be bigger in some cases). ___Default:___ false
--- @field TreatUnionsAsParts boolean -- * **RISKY:** Converts all UnionOperations to Parts. Useful if your Executor isn't able to save (read) Unions, because otherwise they will be invisible. ___Default:___ false (except Solara)
--- @field ScriptsToFolder boolean -- * **NEW FORK:** Instead of saving to an XML place file, saves decompiled scripts to a folder structure in the workspace. Each script becomes a .lua file in a directory hierarchy mirroring the Roblox instance hierarchy. ___Default:___ false

--- @interface OptionsAliases
--- @within SynSaveInstance
--- @field timeout string -- DecompileTimeout
--- @field FileName string -- FilePath
--- @field IgnoreArchivable string -- IgnoreNotArchivable
--- @field IgnoreDefaultProps string -- IgnoreDefaultProperties
--- @field InstancesBlacklist string -- IgnoreList
--- @field SaveLocalPlayer string -- IsolateLocalPlayer
--- @field IsolatePlayerGui string -- IsolateLocalPlayer
--- @field SavePlayerGui string -- IsolateLocalPlayer
--- @field SavePlayers string -- IsolatePlayers
--- @field SaveNonCreatable string -- SaveNotCreatable
--- @field SaveCharacters string -- SavePlayerCharacters

--- @interface OptionsAliasesInverse
--- @within SynSaveInstance
--- @field noscripts string -- Decompile
--- @field RemovePlayers string -- IsolatePlayers
--- @field RemovePlayerCharacters string -- SavePlayerCharacters

--[=[
	@function saveinstance
	Saves instances with specified options. Example:
	```lua
	local Params = {
		RepoURL = "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/",
		SSI = "saveinstance",
	}

	local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

	local CustomOptions = { SafeMode = true, DecompileTimeout = 15, SaveBytecode = true, ScriptsToFolder = true }

	synsaveinstance(CustomOptions)
	```
	@within SynSaveInstance
	@yields
	@param Parameter_1 variant<table, table<Instance>> -- Can either be [SynSaveInstance.CustomOptions table] or a filled with instances ({Instance}), (then it will be treated as ExtraInstances with an invalid mode and IsModel will be true).
	@param Parameter_2 table -- [OPTIONAL] If present, then Parameter_2 will be assumed to be [SynSaveInstance.CustomOptions table]. And then if the Parameter_1 is an Instance, then it will be assumed to be [SynSaveInstance.CustomOptions table].Object. If Parameter_1 is a table filled with instances ({Instance}), then it will be assumed to be [SynSaveInstance.CustomOptions table].ExtraInstances and IsModel will be true). This exists for sake compatibility with `saveinstance(game, {})`
]=]

local function synsaveinstance(CustomOptions, CustomOptions2)
	if GLOBAL_ENV.USSI then
		return
	end
	GLOBAL_ENV.USSI = true

	local totalsize, chunks = 0, table.create(1)
	local savebuffer, savebuffer_size = {}, 1
	local header =
		'<!-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw --><roblox version="4">'

	local StatusText

	local OPTIONS = {
		mode = "optimized",
		Decompile = EXECUTOR_NAME ~= "Velocity",
		scriptcache = true,
		DecompileTimeout = 10,
		__DEBUG_MODE = false,

		Callback = false,

		DecompileJobless = false,
		DecompileIgnore = {
			"TextChatService",
			ModuleScript = nil,
		},
		IgnoreDefaultPlayerScripts = true,
		SaveBytecode = false,

		IgnoreProperties = {},

		IgnoreList = { "CoreGui", "CorePackages" },

		ExtraInstances = {},
		NilInstances = false,
		NilInstancesFixes = {},

		SaveCacheInterval = 0x1600 * 10,
		ShowStatus = true,
		KillAllScripts = true,
		SafeMode = true,
		BoostFPS = false,
		ShutdownWhenDone = false,
		AntiIdle = true,
		Anonymous = false,
		ReadMe = true,
		FilePath = false,
		AvoidFileOverwrite = true,
		Object = false,
		IsModel = false,

		IgnoreDefaultProperties = true,
		IgnoreNotArchivable = true,
		IgnorePropertiesOfNotScriptsOnScriptsMode = false,
		IgnoreSpecialProperties = ArrayToDict({ "Fluxus", "Delta", "Solara" })[EXECUTOR_NAME] or false,

		IsolateLocalPlayer = false,
		IsolateLocalPlayerCharacter = false,
		IsolatePlayers = false,
		IsolateStarterPlayer = false,
		SavePlayerCharacters = false,

		SaveNotCreatable = false,
		NotCreatableFixes = {
			"",
			"AdvancedDragger",
			"AnimationTrack",
			"Dragger",
			"Player",
			"PlayerGui",
			"PlayerMouse",
			"PlayerMouse",
			"PlayerScripts",
			"ScreenshotHud",
			"StudioData",
			"TextChatMessage",
			"TextSource",
			"TouchTransmitter",
			"Translator",
			CloudLocalizationTable = "LocalizationTable",
			Platform = "Part",
			Status = "Model",
		},

		-- ! Risky

		IgnoreSharedStrings = EXECUTOR_NAME ~= "Wave",
		SharedStringOverwrite = false,
		TreatUnionsAsParts = EXECUTOR_NAME == "Solara",
		AlternativeWritefile = not ArrayToDict({ "WRD", "Xeno", "Zorara" })[EXECUTOR_NAME],

		-- ! NEW FORK OPTION
		ScriptsToFolder = false,

		OptionsAliases = {
			timeout = "DecompileTimeout",
			FileName = "FilePath",
			IgnoreArchivable = "IgnoreNotArchivable",
			IgnoreDefaultProps = "IgnoreDefaultProperties",
			InstancesBlacklist = "IgnoreList",
			SaveLocalPlayer = "IsolateLocalPlayer",
			IsolatePlayerGui = "IsolateLocalPlayer",
			SavePlayerGui = "IsolateLocalPlayer",
			SaveNonCreatable = "SaveNotCreatable",
			SavePlayers = "IsolatePlayers",
			SaveCharacters = "SavePlayerCharacters",
		},
		OptionsAliasesInverse = {
			noscripts = "Decompile",
			RemovePlayers = "IsolatePlayers",
			RemovePlayerCharacters = "SavePlayerCharacters",
		},
	}
	local OPTIONS_lowercase, OptionsAliasesInverse_lowercase, CustomOptions_valid = {}, {}, {}

	do
		local function buildMap(dest, source, warnLabel)
			for k, v in next, source do
				local key = string.lower(k)

				if dest[key] then
					warn("DUPLICATE " .. warnLabel, k)
				else
					dest[key] = v
				end
			end
		end

		-- base options
		for o in next, OPTIONS do
			local option = string.lower(o)
			if OPTIONS_lowercase[option] then
				warn("DUPLICATE OPTION", o)
			else
				OPTIONS_lowercase[option] = o
			end
		end

		-- aliases
		buildMap(OPTIONS_lowercase, OPTIONS.OptionsAliases, "ALIAS")

		-- inverse aliases
		buildMap(OptionsAliasesInverse_lowercase, OPTIONS.OptionsAliasesInverse, "INVERSE ALIAS")
	end

	do -- * Load Settings
		local function construct_NilinstanceFix(Name, ClassName, Separate)
			return function(instance, instancePropertyOverrides)
				local Exists

				if not Separate then
					Exists = OPTIONS.NilInstancesFixes[Name]
				end

				local Fix

				local DoesntExist = not Exists
				if DoesntExist then
					Fix = Instance.new(ClassName)
					if not Separate then
						OPTIONS.NilInstancesFixes[Name] = Fix
					end

					instancePropertyOverrides[Fix] =
						{ __SaveSpecific = true, __Children = { instance }, Properties = { Name = Name } }
				else
					Fix = Exists
					table.insert(instancePropertyOverrides[Fix].__Children, instance)
				end

				if DoesntExist then
					return Fix
				end
			end
		end

		OPTIONS.NilInstancesFixes.Animator = construct_NilinstanceFix(
			"Animator has to be placed under Humanoid or AnimationController",
			"AnimationController"
		)
		OPTIONS.NilInstancesFixes.AdPortal = construct_NilinstanceFix("AdPortal must be parented to a Part", "Part")
		OPTIONS.NilInstancesFixes.Attachment =
			construct_NilinstanceFix("Attachments must be parented to a BasePart or another Attachment", "Part")
		OPTIONS.NilInstancesFixes.BaseWrap =
			construct_NilinstanceFix("BaseWrap must be parented to a MeshPart", "MeshPart")
		OPTIONS.NilInstancesFixes.PackageLink =
			construct_NilinstanceFix("Package already has a PackageLink", "Folder", true)

		if CustomOptions2 and type(CustomOptions2) == "table" then
			local tmp = CustomOptions
			local Type = typeof(tmp)
			CustomOptions = CustomOptions2
			if Type == "Instance" then
				CustomOptions.Object = tmp
			elseif Type == "table" and typeof(tmp[1]) == "Instance" then
				CustomOptions.ExtraInstances = tmp
				OPTIONS.IsModel = true
			end
		end

		local Type = typeof(CustomOptions)

		if Type == "table" then
			if typeof(CustomOptions[1]) == "Instance" then
				OPTIONS.mode = "invalidmode"
				OPTIONS.ExtraInstances = CustomOptions
				OPTIONS.IsModel = true
				CustomOptions = {}
			else
				for key, value in next, CustomOptions do
					local k = string.lower(key)

					local option = OPTIONS_lowercase[k]
					local invert = false

					if not option then
						option = OptionsAliasesInverse_lowercase[k]
						invert = option ~= nil
					end

					if option then
						local finalValue
						if invert then
							finalValue = not value
						else
							finalValue = value
						end

						OPTIONS[option] = finalValue
						CustomOptions_valid[option] = true
					end
				end
			end
		elseif Type == "Instance" then
			OPTIONS.mode = "invalidmode"
			OPTIONS.Object = CustomOptions
			CustomOptions = {}
		else
			CustomOptions = {}
		end
	end

	if not writefile and not OPTIONS.Callback then
		local function coreCall(method, ...)
			local StarterGui = service.StarterGui
			method = StarterGui[method]
			if not method then
				return
			end

			for _ = 1, 10 do
				local success, result = pcall(method, StarterGui, ...)
				if success then
					return result
				end
				task.wait(1)
			end
		end

		local text = 'Function "writefile" is NOT available\nUse the Option "Callback" instead for now (check docs)'

		coreCall("SetCore", "SendNotification", {
			Title = "SAVEINSTANCE ERROR",
			Text = text,
			Duration = 15,
			Icon = "rbxassetid://9072920609",
		})
		coreCall("SetCore", "SendNotification", {
			Title = "SAVEINSTANCE ERROR",
			Text = "Please ask your executor's developers to add writefile",
			Duration = 15,
			Icon = "rbxassetid://9072920609",
		})

		warn(text)

		GLOBAL_ENV.USSI = nil
		return
	end

	if OPTIONS.IgnoreDefaultPlayerScripts then
		local DecompileIgnore = OPTIONS.DecompileIgnore

		local default_scripts = ArrayToDict({
			ModuleScript = { "PlayerModule" },
			LocalScript = {
				"BubbleChat",
				"ChatScript",
				"PlayerScriptsLoader",
				"RbxCharacterSounds",
			},
		}, true)

		local function ignorePath(path)
			if path then
				for _, child in next, path:GetChildren() do
					local class_match = default_scripts[child.ClassName]
					if class_match then
						local name_match = class_match[child.Name]
						if name_match then
							table.insert(DecompileIgnore, child)
						end
					end
				end
			end
		end

		ignorePath(service.StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts"))

		local LocalPlayer = service.Players.LocalPlayer
		if LocalPlayer then
			ignorePath(LocalPlayer:FindFirstChildOfClass("PlayerScripts"))
		end
	end

	local InstancesOverrides = {}

	local DecompileIgnore, IgnoreList, IgnoreProperties, NotCreatableFixes =
		ArrayToDict(OPTIONS.DecompileIgnore, true),
		ArrayToDict(OPTIONS.IgnoreList, true),
		ArrayToDict(OPTIONS.IgnoreProperties),
		ArrayToDict(OPTIONS.NotCreatableFixes, true, "Folder")

	local __DEBUG_MODE = OPTIONS.__DEBUG_MODE

	if __DEBUG_MODE and type(__DEBUG_MODE) ~= "function" then
		__DEBUG_MODE = warn
	end

	local LP_UserId, LP_Name, ANON_UserId, ANON_Name, AnonymizableTypes

	do
		local anonymous = OPTIONS.Anonymous
		local lp = service.Players.LocalPlayer

		if anonymous and lp then
			AnonymizableTypes = ArrayToDict({ "double", "float", "int", "int64", "string" })
			LP_UserId, LP_Name = lp.UserId, lp.Name

			local istable = type(anonymous) == "table"
			ANON_UserId = istable and anonymous.UserId or 1
			ANON_Name = istable and anonymous.Name or "Roblox"
		end
	end

	local FilePath = OPTIONS.FilePath
	local SaveCacheInterval = OPTIONS.SaveCacheInterval
	local ToSaveInstance = OPTIONS.Object
	local IsModel = OPTIONS.IsModel

	if ToSaveInstance and CustomOptions.IsModel == nil then
		IsModel = true
	end

	local IgnoreDefaultProperties = OPTIONS.IgnoreDefaultProperties
	local IgnoreNotArchivable = not OPTIONS.IgnoreNotArchivable
	local IgnorePropertiesOfNotScriptsOnScriptsMode = OPTIONS.IgnorePropertiesOfNotScriptsOnScriptsMode

	local old_gethiddenproperty
	if OPTIONS and gethiddenproperty then
		old_gethiddenproperty = gethiddenproperty
		gethiddenproperty = nil
	end

	local SaveNotCreatable = OPTIONS.SaveNotCreatable
	local TreatUnionsAsParts = OPTIONS.TreatUnionsAsParts

	local DecompileJobless = OPTIONS.DecompileJobless
	if DecompileJobless then
		OPTIONS.scriptcache = true
	end
	local ScriptCache = OPTIONS.scriptcache and getscriptbytecode

	local DecompileTimeout = OPTIONS.DecompileTimeout

	local IgnoreSharedStrings = OPTIONS.IgnoreSharedStrings
	local SharedStringOverwrite = OPTIONS.SharedStringOverwrite

	local ldeccache = GLOBAL_ENV.scriptcache

	local DecompileIgnoring, ToSaveList, ldecompile, placename, elapse_t, SaveNotCreatableWillBeEnabled, RecoveredScripts

	if OPTIONS.ReadMe then
		RecoveredScripts = {}
	end

	if ScriptCache and not ldeccache then
		ldeccache = {}
		GLOBAL_ENV.scriptcache = ldeccache
	end

	if ToSaveInstance == game then
		OPTIONS.mode = "full"
		ToSaveInstance = nil
		IsModel = nil
	end

	local function isLuaSourceContainer(instance)
		return instance:IsA("LuaSourceContainer")
	end

	do
		local mode = string.lower(OPTIONS.mode)
		local tmp = table.clone(OPTIONS.ExtraInstances)

		local PlaceName = game.PlaceId

		pcall(function()
			PlaceName = PlaceName .. " " .. service.MarketplaceService:GetProductInfoAsync(PlaceName).Name
		end)

		local function sanitizeFileName(str)
			return string.sub(string.gsub(string.gsub(string.gsub(str, "[^%w _]", ""), " +", " "), " +$", ""), 1, 240)
		end

		if ToSaveInstance then
			if mode == "optimized" then
				mode = "full"
			end

			for _, key in
				next,
				{
					"IsolateLocalPlayer",
					"IsolateLocalPlayerCharacter",
					"IsolatePlayers",
					"IsolateStarterPlayer",
					"NilInstances",
				}
			do
				if CustomOptions_valid[key] == nil then
					OPTIONS[key] = false
				end
			end
		end

		local filetype = IsModel and ".rbxmx" or ".rbxlx"

		if FilePath then
			placename = FilePath
		elseif IsModel then
			placename =
				sanitizeFileName("model " .. PlaceName .. " " .. (ToSaveInstance or tmp[1] or game):GetFullName())
		else
			placename = sanitizeFileName("place " .. PlaceName)
		end

		if OPTIONS.AvoidFileOverwrite and isfile then
			local counter = 0
			local temp = placename

			while isfile(temp .. filetype) do
				counter = counter + 1
				temp = placename .. "(" .. counter .. ")"
			end

			placename = temp .. filetype
		else
			placename = placename .. filetype
		end

		if GLOBAL_ENV[placename] then
			return
		end

		GLOBAL_ENV[placename] = true
		GLOBAL_ENV.USSI = nil

		if mode ~= "scripts" then
			IgnorePropertiesOfNotScriptsOnScriptsMode = nil
		end

		local TempRoot = ToSaveInstance or game

		if mode == "full" then
			if not ToSaveInstance then
				local Children = TempRoot:GetChildren()
				if 0 < #Children then
					local tmp_dict = ArrayToDict(tmp)
					for _, child in next, Children do
						if not tmp_dict[child] then
							table.insert(tmp, child)
						end
					end
				end
			end
		elseif mode == "optimized" then
			local tmp_dict = ArrayToDict(tmp)

			for _, serviceName in
				next,
				{
					"Workspace",
					"Players",
					"Lighting",
					"MaterialService",
					"ReplicatedFirst",
					"ReplicatedStorage",

					"ServerScriptService",
					"ServerStorage",

					"StarterGui",
					"StarterPack",
					"StarterPlayer",
					"Teams",
					"SoundService",
					"Chat",
					"TextChatService",

					"LocalizationService",
					"JointsService",
				}
			do
				local _service = game:FindService(serviceName)
				if _service and not tmp_dict[_service] then
					table.insert(tmp, _service)
				end
			end
		elseif mode == "scripts" then
			local unique = {}
			for _, instance in next, TempRoot:GetDescendants() do
				if isLuaSourceContainer(instance) then
					local Parent = instance.Parent
					while Parent and Parent ~= TempRoot do
						instance = instance.Parent
						Parent = instance.Parent
					end
					if Parent then
						unique[instance] = true
					end
				end
			end
			for instance in next, unique do
				table.insert(tmp, instance)
			end
		end

		ToSaveList = tmp

		if ToSaveInstance then
			table.insert(ToSaveList, 1, ToSaveInstance)
		end
	end

	local IsolateLocalPlayer = OPTIONS.IsolateLocalPlayer
	local IsolateLocalPlayerCharacter = OPTIONS.IsolateLocalPlayerCharacter
	local IsolatePlayers = OPTIONS.IsolatePlayers
	local IsolateStarterPlayer = OPTIONS.IsolateStarterPlayer
	local NilInstances = OPTIONS.NilInstances

	if NilInstances and enablenilinstances then
		enablenilinstances()
	end
	local function get_size_format()
		local Size

		for i, unit in
			next,
			{
				"B",
				"KB",
				"MB",
				"GB",
				"TB",
			}
		do
			if totalsize < 0x400 ^ i then
				Size = math.floor(totalsize / (0x400 ^ (i - 1)) * 10) / 10 .. " " .. unit
				break
			end
		end

		return Size
	end

	local RunService = service.RunService
	local function wait_for_render()
		RunService.RenderStepped:Wait()
	end

	local Loading
	local function run_with_loading(text, keepStatus, waitForRender, taskFunction, ...)
		local previousStatus

		if StatusText then
			if keepStatus then
				previousStatus = StatusText.Text
			end
			Loading = task.spawn(function()
				local spinner_count = 0
				local chars = { "|", "/", "—", "\\" }
				local chars_size = #chars

				local function getLoadingText()
					spinner_count = spinner_count + 1

					if chars_size < spinner_count then
						spinner_count = 1
					end

					return chars[spinner_count]
				end

				text = text .. " "

				while true do
					StatusText.Text = text .. getLoadingText()
					task.wait(0.25)
				end
			end)
			if waitForRender then
				wait_for_render()
			end
		end

		local result = { taskFunction(...) }

		if Loading then
			task.cancel(Loading)
			Loading = nil
			if previousStatus then
				StatusText.Text = previousStatus
			end
		end

		return unpack(result)
	end

	local function construct_TimeoutHandler(timeout, f, timeout_return)
		return timeout < 0 and function(script)
			return pcall(f, script)
		end or function(script)
			local thread = coroutine.running()
			local timeoutThread, isCancelled

			timeoutThread = task.delay(timeout, function()
				isCancelled = true
				coroutine.resume(thread, nil, timeout_return)
			end)

			task.spawn(function()
				local ok, result = pcall(f, script)

				if isCancelled then
					return
				end

				task.cancel(timeoutThread)

				while coroutine.status(thread) ~= "suspended" do
					task.wait()
				end

				coroutine.resume(thread, ok, result)
			end)

			return coroutine.yield()
		end
	end

	local getbytecode
	if getscriptbytecode then
		getbytecode = construct_TimeoutHandler(3, getscriptbytecode)
	end

	local SaveBytecode
	if OPTIONS.SaveBytecode and getscriptbytecode then
		SaveBytecode = function(script)
			local s, bytecode = getbytecode(script)

			if s and bytecode and bytecode ~= "" then
				return "-- Bytecode (Base64):\n-- " .. base64encode(bytecode) .. "\n\n"
			end
		end
	end

	do
		if not OPTIONS.Decompile then
			ldecompile = function()
				return "-- Decompiling is disabled"
			end
		elseif decompile then
			local decomp = construct_TimeoutHandler(DecompileTimeout, decompile, "Decompiler timed out")

			ldecompile = function(script)
				local bytecode
				if ScriptCache then
					local s
					s, bytecode = getbytecode(script)
					local cached

					if s then
						if not bytecode or bytecode == "" then
							return "-- The Script is Empty"
						end
						cached = ldeccache[bytecode]
					else
						bytecode = nil
					end

					if cached then
						if __DEBUG_MODE then
							__DEBUG_MODE("Found in Cache", script:GetFullName())
						end
						return cached
					end
				else
					if DecompileJobless then
						return "-- Not found in already decompiled ScriptCache"
					end
				end

				local ok, result = run_with_loading("Decompiling " .. script.Name, true, nil, decomp, script)
				if not result then
					ok, result = false, "Empty Output"
				end

				local output
				if ok then
					result = string.gsub(result, "\0", "\\0")
					output = result
				else
					output = "--[[ Failed to decompile. Reason:\n" .. (result or "") .. "\n]]"
				end

				if ScriptCache and bytecode then
					ldeccache[bytecode] = output
					if __DEBUG_MODE then
						__DEBUG_MODE("Cached", script:GetFullName())
					end
				end

				return output
			end
		else
			ldecompile = function()
				return "-- Your Executor does NOT have a Decompiler"
			end
		end
	end

	local function GetLocalPlayer()
		return service.Players.LocalPlayer
			or service.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
			or service.Players.LocalPlayer
	end

	local function filterLinkedSource(str)
		local o, r = pcall(service.HttpService.JSONDecode, service.HttpService, str)
		if o and r.errors then
			return
		end
		return true
	end

	local function replaceClassName(instance, InstanceName, ClassName)
		local InstanceOverride
		if InstanceName ~= ClassName then
			InstanceOverride = InstancesOverrides[instance]
			if not InstanceOverride then
				InstanceOverride = { Properties = { Name = "[" .. ClassName .. "] " .. InstanceName } }
				InstancesOverrides[instance] = InstanceOverride
			end
		end
		return InstanceOverride
	end

	local function gsubCaseInsensitive(input, search, replacement)
		local inputLower = string.lower(input)
		search = string.lower(search)

		if not string_find(input, search) then
			return input
		end

		local lastFinish = 0
		local subStrings = {}
		local search_len = #search
		local input_len = #input
		while search_len <= input_len - lastFinish do
			local init = lastFinish + 1

			local start, finish = string_find(inputLower, search, init)

			if start == nil then
				break
			end

			table.insert(subStrings, string.sub(input, init, start - 1))

			lastFinish = finish
		end

		if lastFinish == 0 then
			return input
		end

		table.insert(subStrings, string.sub(input, lastFinish + 1))

		return table.concat(subStrings, replacement)
	end

	local function filterPropVal(result, propertyName, category)
		return result == nil
			or result == "can't get value"
			or type(result) == "string"
				and (category == "Enum" or string_find(result, "Unable to get property " .. propertyName))
	end

	local function ReadProperty(instance, property, propertyName, special, category, optional)
		local raw = __BREAK

		local InstanceOverride = InstancesOverrides[instance]
		if InstanceOverride then
			local PropertiesOverride = InstanceOverride.Properties
			if PropertiesOverride then
				local PropertyOverride = PropertiesOverride[propertyName]
				if PropertyOverride ~= nil then
					return PropertyOverride
				end
			end
		end

		local CanRead = property.CanRead

		if CanRead == false then
			return __BREAK
		end

		if special then
			if gethiddenproperty then
				local ok, result = pcall(gethiddenproperty, instance, propertyName)

				if ok then
					raw = result
				end

				if filterPropVal(raw, propertyName, category) then
					if result ~= nil or not optional then
						if __DEBUG_MODE then
							__DEBUG_MODE("Filtered", propertyName)
						end
						property.CanRead = false
					end

					return __BREAK
				end
			end
		else
			if CanRead then
				raw = instance[propertyName]
			else
				local ok, result = pcall(index, instance, propertyName)

				if ok then
					raw = result
				elseif gethiddenproperty then
					ok, result = pcall(gethiddenproperty, instance, propertyName)

					if ok then
						raw = result

						property.Special = true
					end
				end

				property.CanRead = ok

				if not ok or filterPropVal(raw, propertyName, category) then
					return __BREAK
				end
			end
		end

		return raw
	end

	-- ============================================================
	-- NEW FORK: ScriptsToFolder functions
	-- ============================================================

	local ScriptsToFolder = OPTIONS.ScriptsToFolder
	local ScriptsBaseDir

	local function sanitizePathComponent(name)
		-- Remove characters that are invalid in file paths
		return string.gsub(name, '[<>:"/\\|?*]', "_")
	end

	local function ensureDir(dirPath)
		if not isfile(dirPath) then
			local success, err = pcall(makefolder, dirPath)
			if not success then
				warn("Failed to create directory:", dirPath, err)
			end
		end
	end

	local function getScriptExtension(instance)
		if instance:IsA("ModuleScript") then
			return ".module.lua"
		elseif instance:IsA("LocalScript") then
			return ".client.lua"
		else -- Script
			return ".server.lua"
		end
	end

	local function getScriptFilePath(instance, baseDir)
		-- Build path from instance hierarchy
		local pathParts = {}
		local current = instance
		while current and current ~= game do
			table.insert(pathParts, 1, sanitizePathComponent(current.Name))
			current = current.Parent
		end

		local dirPath = baseDir
		for i = 1, #pathParts - 1 do
			dirPath = dirPath .. "/" .. pathParts[i]
		end

		local fileName = pathParts[#pathParts] .. getScriptExtension(instance)
		return dirPath, fileName
	end

	local function writeScriptToFile(instance, source)
		local dirPath, fileName = getScriptFilePath(instance, ScriptsBaseDir)
		ensureDir(dirPath)

		local fullPath = dirPath .. "/" .. fileName

		-- Handle duplicate file names
		if isfile(fullPath) then
			local counter = 1
			local ext = getScriptExtension(instance)
			local nameWithoutExt = string.sub(fileName, 1, #fileName - #ext)
			while isfile(fullPath) do
				fullPath = dirPath .. "/" .. nameWithoutExt .. "(" .. counter .. ")" .. ext
				counter = counter + 1
			end
		end

		local header = "-- Saved by UniversalSynSaveInstance (ScriptsToFolder Fork)\n"
			.. "-- Original Path: "
			.. instance:GetFullName()
			.. "\n-- Class: "
			.. instance.ClassName
			.. "\n\n"

		local success, err = pcall(writefile, fullPath, header .. source)
		if success then
			if StatusText then
				StatusText.Text = "Saved: " .. fullPath
			end
		else
			warn("Failed to write script:", fullPath, err)
		end

		return fullPath
	end

	-- ============================================================
	-- END NEW FORK
	-- ============================================================

	local function ReturnItem(className, instance)
		return '<Item class="' .. className .. '" referent="' .. tostring(instance) .. '"><Properties>'
	end

	local function ReturnProperty(tag, propertyName, value)
		return "<" .. tag .. ' name="' .. propertyName .. '">' .. value .. "</" .. tag .. ">"
	end

	local function ReturnValueAndTag(raw, valueType, descriptor)
		local value, tag = (descriptor or XML_Descriptors[valueType])(raw)
		return value, tag or valueType
	end

	local function InheritsFix(fixes, className, instance)
		local Fix = fixes[className]
		if Fix then
			return Fix
		elseif Fix == nil then
			for class_name, fix in next, fixes do
				if instance:IsA(class_name) then
					return fix
				end
			end
		end
	end

	local function GetInheritedProps(className)
		local cached = inherited_properties[className]
		if cached then
			return cached
		end

		local prop_list = {}
		local layer = ClassList[className]
		while layer do
			local layer_props = layer.Properties
			table.move(layer_props, 1, #layer_props, #prop_list + 1, prop_list)
			layer = ClassList[layer.Superclass]
		end
		inherited_properties[className] = prop_list
		return prop_list
	end

	local function save_cache()
		local savestr = table.concat(savebuffer)

		local savestr_len = #savestr
		totalsize = totalsize + savestr_len

		table.insert(chunks, savestr)

		table.clear(savebuffer)
		savebuffer_size = 1

		if StatusText then
			StatusText.Text = "Saving.. Size: " .. get_size_format()
		end

		wait_for_render()
	end

	local function save_specific(className, properties)
		local Ref = Instance.new(className)
		local Item = ReturnItem(Ref.ClassName, Ref)

		for propertyName, val in next, properties do
			local whitelisted, value, tag

			if propertyName == "Source" then
				tag = "ProtectedString"
				value = XML_Descriptors.__PROTECTEDSTRING(val)
				whitelisted = true
			elseif propertyName == "Name" then
				whitelisted = true
				value, tag = ReturnValueAndTag(val, "string")
			end

			if whitelisted then
				Item = Item .. ReturnProperty(tag, propertyName, value)
			end
		end
		Item = Item .. "</Properties>"
		return Item
	end

	local gethiddenproperty_fallback

	-- ============================================================
	-- MODIFIED FORK: save_hierarchy with ScriptsToFolder support
	-- ============================================================

	local function save_hierarchy(hierarchy)
		for _, instance in next, hierarchy do
			local __DARKLUA_CONTINUE_68 = false
			repeat
				local InstanceOverride, ClassTagOverride, ClassNameOverride

				if not InstanceOverride then
					InstanceOverride = InstancesOverrides[instance]
					if InstanceOverride then
						ClassTagOverride = InstanceOverride.__ClassName
					end
				end
				local ClassName = instance.ClassName

				local InstanceName = instance.Name
				local SkipEntirely

				if not ClassTagOverride then
					if IgnoreNotArchivable and not instance.Archivable then
						__DARKLUA_CONTINUE_68 = true
						break
					end

					SkipEntirely = IgnoreList[instance]
					if SkipEntirely then
						__DARKLUA_CONTINUE_68 = true
						break
					end

					do
						local OnIgnoredList = IgnoreList[ClassName]
						if OnIgnoredList and (OnIgnoredList == true or OnIgnoredList[InstanceName]) then
							__DARKLUA_CONTINUE_68 = true
							break
						end
					end

					if not DecompileIgnoring then
						DecompileIgnoring = DecompileIgnore[instance]

						if DecompileIgnoring == nil then
							local DecompileIgnored = DecompileIgnore[ClassName]
							if DecompileIgnored then
								DecompileIgnoring = DecompileIgnored == true or DecompileIgnored[InstanceName]
							end
						end

						if DecompileIgnoring then
							DecompileIgnoring = instance
						elseif DecompileIgnoring == false then
							DecompileIgnoring = 1
						end
					end

					do
						local Fix = NotCreatableFixes[ClassName]

						if Fix then
							if SaveNotCreatable then
								ClassName, InstanceOverride = Fix, replaceClassName(instance, InstanceName, ClassName)
							else
								__DARKLUA_CONTINUE_68 = true
								break
							end
						else
							if TreatUnionsAsParts and instance:IsA("PartOperation") then
								ClassName, InstanceOverride =
									"Part", replaceClassName(instance, InstanceName, ClassName)
								ClassNameOverride = "BasePart"
							elseif not ClassList[ClassName] then
								if __DEBUG_MODE then
									__DEBUG_MODE("Class not Found", ClassName)
								end

								ClassTagOverride = ClassName
								ClassName = "Folder"
							end
						end
					end
				end

				-- ============================================================
				-- NEW FORK: ScriptsToFolder handling
				-- ============================================================
				if ScriptsToFolder then
					if isLuaSourceContainer(instance) then
						-- Decompile and write this script to a file
						local source = ldecompile(instance)

						if SaveBytecode then
							local bytecodeOutput = SaveBytecode(instance)
							if bytecodeOutput then
								source = bytecodeOutput .. source
							end
						end

						writeScriptToFile(instance, source)
					end
					-- For non-script instances in ScriptsToFolder mode, we still traverse children
					-- but don't write anything for the instance itself
				else
					-- Original XML saving logic
					if InstanceOverride and InstanceOverride.__SaveSpecific then
						savebuffer[savebuffer_size] = save_specific(ClassName, InstanceOverride.Properties)
						savebuffer_size = savebuffer_size + 1
					else
						savebuffer[savebuffer_size] = ReturnItem(ClassTagOverride or ClassName, instance)
						savebuffer_size = savebuffer_size + 1
						if not (IgnorePropertiesOfNotScriptsOnScriptsMode and not isLuaSourceContainer(instance)) then
							local default_instance, new_def_inst

							if IgnoreDefaultProperties then
								default_instance = default_instances[ClassName]
								if not default_instance then
									local Class = ClassList[ClassName]
									if not Class.NotCreatable then
										local ok, result = pcall(Instance.new, ClassName)

										if ok then
											new_def_inst = result

											default_instance = {}

											default_instances[ClassName] = default_instance
										else
											Class.NotCreatable = true
											if __DEBUG_MODE then
												__DEBUG_MODE("Failed to create default Instance", ClassName, result)
											end
										end
									elseif __DEBUG_MODE then
										__DEBUG_MODE("Unable to create default Instance (NotCreatable)", ClassName)
									end
								end
							end

							for _, Property in next, GetInheritedProps(ClassNameOverride or ClassName) do
								local __DARKLUA_CONTINUE_69 = false
								repeat
									local PropertyName = Property.Name

									if IgnoreProperties[PropertyName] then
										__DARKLUA_CONTINUE_69 = true
										break
									end

									local ValueType = Property.ValueType

									if IgnoreSharedStrings and ValueType == "SharedString" then
										__DARKLUA_CONTINUE_69 = true
										break
									end

									local Special, Category, Optional =
										Property.Special, Property.Category, Property.Optional
									local raw
									if
										not (
											ValueType == "ProtectedString"
											and PropertyName == "Source"
											and isLuaSourceContainer(instance)
										)
									then
										raw = ReadProperty(instance, Property, PropertyName, Special, Category, Optional)

										if raw == __BREAK then
											local GHPFFailed, Fallback = Property.GHPFFailed, Property.Fallback
											if GHPFFailed and not Fallback then
												__DARKLUA_CONTINUE_69 = true
												break
											end

											if not GHPFFailed then
												local ok, result = pcall(gethiddenproperty_fallback, instance, PropertyName)
												if result == nil and not Optional then
													ok = nil
												end

												if ok then
													raw = result
												else
													GHPFFailed = true
													Property.GHPFFailed = GHPFFailed
												end
											end

											if GHPFFailed and Fallback then
												local ok, result = pcall(Fallback, instance)

												if ok then
													raw = result
												else
													Property.Fallback = nil
													if __DEBUG_MODE then
														__DEBUG_MODE("Fix Failed", PropertyName, result)
													end
													__DARKLUA_CONTINUE_69 = true
													break
												end
											end

											if raw == __BREAK then
												__DARKLUA_CONTINUE_69 = true
												break
											end
										end

										if
											default_instance
											and Property.CanRead
											and not Property.Special
										then
											if new_def_inst then
												default_instance[PropertyName] = index(new_def_inst, PropertyName)
											end
											if default_instance[PropertyName] == raw then
												__DARKLUA_CONTINUE_69 = true
												break
											end
										end
									end

									if SharedStringOverwrite and ValueType == "BinaryString" then
										ValueType = "SharedString"
									end

									if AnonymizableTypes and AnonymizableTypes[ValueType] then
										if ValueType == "string" then
											raw = gsubCaseInsensitive(raw, LP_Name, ANON_Name)
										elseif raw == LP_UserId then
											raw = ANON_UserId
										end
									end

									local tag, value
									if Category == "Class" then
										tag = "Ref"
										if raw then
											if SaveNotCreatableWillBeEnabled then
												local Fix = NotCreatableFixes[raw.ClassName]
												if
													Fix
													and (
														PropertyName == "PlayerToHideFrom"
														or ValueType ~= "Instance" and ValueType ~= Fix
													)
												then
													__DARKLUA_CONTINUE_69 = true
													break
												end
											end

											value = tostring(raw)
										else
											value = "null"
										end
									elseif Category == "Enum" then
										value, tag = XML_Descriptors.EnumItem(raw)
									else
										local Descriptor = XML_Descriptors[ValueType]

										if Descriptor then
											value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
										elseif ValueType == "ProtectedString" then
											tag = ValueType

											if PropertyName == "Source" then
												if DecompileIgnoring then
													if DecompileIgnoring == 1 then
														DecompileIgnoring = nil
													end
													value = "-- Ignored"
												else
													local should_decompile = true
													local LinkedSource
													local o, LinkedSource_Url = pcall(index, instance, "LinkedSource")
													if not o then
														LinkedSource_Url = ""
													end
													local hasLinkedSource = LinkedSource_Url ~= ""
													local LinkedSource_type
													if hasLinkedSource then
														local Path = instance:GetFullName()
														if RecoveredScripts then
															table.insert(RecoveredScripts, Path)
														end

														LinkedSource = string.match(LinkedSource_Url, "%w+$")
														if LinkedSource then
															if ScriptCache then
																local cached = ldeccache[LinkedSource]

																if cached then
																	value = cached
																	should_decompile = nil
																end
															end
															if should_decompile then
																if DecompileJobless then
																	value = "-- Not found in LinkedSource ScriptCache"
																	should_decompile = nil
																end

																LinkedSource_type = string.find(LinkedSource, "%a")
																		and "hash"
																	or "id"

																local asset = LinkedSource_type .. "=" .. LinkedSource

																local ok, source = pcall(function()
																	return game:HttpGet(
																		"https://assetdelivery.roproxy.com/v1/asset/?"
																			.. asset
																	)
																end)

																if ok and filterLinkedSource(source) then
																	if ScriptCache then
																		ldeccache[LinkedSource] = source
																	end

																	value = source

																	should_decompile = nil
																end
															end
														else
															warn(
																"FAILED TO EXTRACT ORIGINAL SCRIPT SOURCE (OPEN A GITHUB ISSUE): ",
																instance:GetFullName(),
																LinkedSource_Url
															)
														end
													end

													if should_decompile then
														local isLocalScript = instance:IsA("LocalScript")
														if
															isLocalScript
																and instance.RunContext == Enum.RunContext.Server
															or not isLocalScript
																and instance:IsA("Script")
																and instance.RunContext ~= Enum.RunContext.Client
														then
															value =
																"-- [FilteringEnabled] Server Scripts are IMPOSSIBLE to save"
														else
															value = ldecompile(instance)
															if SaveBytecode then
																local output = SaveBytecode(instance)
																if output then
																	value = output .. value
																end
															end
														end
													end

													value = "-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw\n\n"
														.. (hasLinkedSource and "-- Original Source: https://assetdelivery.roblox.com/v1/asset/?" .. (LinkedSource_type or "id") .. "=" .. (LinkedSource or LinkedSource_Url) .. "\n\n" or "")
														.. value
												end
											end
											value = XML_Descriptors.__PROTECTEDSTRING(value)
										else
											if Optional then
												Descriptor = XML_Descriptors[Optional]

												if Descriptor then
													if raw == nil then
														__DARKLUA_CONTINUE_69 = true
														break
													else
														value, tag = ReturnValueAndTag(raw, ValueType, Descriptor)
													end
												end
											end
										end
									end

									if tag then
										savebuffer[savebuffer_size] = ReturnProperty(tag, PropertyName, value)
										savebuffer_size = savebuffer_size + 1
									else
										warn("UNSUPPORTED TYPE (OPEN A GITHUB ISSUE): ", ValueType, ClassName, PropertyName)
									end
									__DARKLUA_CONTINUE_69 = true
								until true
								if not __DARKLUA_CONTINUE_69 then
									break
								end
							end
						end
						savebuffer[savebuffer_size] = "</Properties>"
						savebuffer_size = savebuffer_size + 1

						if SaveCacheInterval < savebuffer_size then
							save_cache()
						end
					end
				end
				-- ============================================================
				-- END NEW FORK
				-- ============================================================

				if SkipEntirely ~= false then
					local Children = InstanceOverride and InstanceOverride.__Children or instance:GetChildren()

					if #Children ~= 0 then
						save_hierarchy(Children)
					end
				end

				if DecompileIgnoring and DecompileIgnoring == instance then
					DecompileIgnoring = nil
				end

				if not ScriptsToFolder then
					savebuffer[savebuffer_size] = "</Item>"
					savebuffer_size = savebuffer_size + 1
				end
				__DARKLUA_CONTINUE_68 = true
			until true
			if not __DARKLUA_CONTINUE_68 then
				break
			end
		end
	end

	local function save_extra(name, instanceOrTable, saveProps, customClassName, source)
		if not customClassName then
			customClassName = "Folder"
		end

		local properties = { Name = name, Source = source }
		local hierarchy

		if instanceOrTable then
			if type(instanceOrTable) == "table" then
				hierarchy = instanceOrTable
			else
				hierarchy = instanceOrTable:GetChildren()
				if saveProps then
					InstancesOverrides[instanceOrTable] = {
						__ClassName = customClassName,
						Properties = properties,
					}

					save_hierarchy({ instanceOrTable })
				end
			end
		end

		if not saveProps then
			savebuffer[savebuffer_size] = save_specific(customClassName, properties)
			savebuffer_size = savebuffer_size + 1
			if hierarchy then
				save_hierarchy(hierarchy)
			end
			savebuffer[savebuffer_size] = "</Item>"
			savebuffer_size = savebuffer_size + 1
		end
	end

	local function save_game()
		do
			if IsModel then
				header = header .. '<Meta name="ExplicitAutoJoints">true</Meta>'
			end
			if writefile and not OPTIONS.Callback and not ScriptsToFolder then
				writefile(placename, header)
			end
		end

		-- ============================================================
		-- NEW FORK: Initialize ScriptsToFolder base directory
		-- ============================================================
		if ScriptsToFolder then
			ScriptsBaseDir = sanitizeFileName(placename)
			-- Remove file extension if present
			ScriptsBaseDir = string.gsub(ScriptsBaseDir, "%.rbxlx$", "")
			ScriptsBaseDir = string.gsub(ScriptsBaseDir, "%.rbxmx$", "")

			-- Delete existing directory if it exists (clean start)
			pcall(delfolder, ScriptsBaseDir)
			ensureDir(ScriptsBaseDir)

			if StatusText then
				StatusText.Text = "Saving scripts to folder: " .. ScriptsBaseDir
			end
		end
		-- ============================================================
		-- END NEW FORK
		-- ============================================================

		SaveNotCreatableWillBeEnabled = SaveNotCreatable
			or (IsolateLocalPlayer or IsolateLocalPlayerCharacter) and IsolateLocalPlayer
			or IsolatePlayers
			or NilInstances and global_container.getnilinstances

		save_hierarchy(ToSaveList)

		if IsolateLocalPlayer or IsolateLocalPlayerCharacter then
			local LocalPlayer = service.Players.LocalPlayer
			if LocalPlayer then
				if IsolateLocalPlayer then
					SaveNotCreatable = true
					save_extra("LocalPlayer", LocalPlayer, true)
				end
				if IsolateLocalPlayerCharacter then
					local LocalPlayerCharacter = LocalPlayer.Character
					if LocalPlayerCharacter then
						save_extra("LocalPlayer Character", LocalPlayerCharacter, true, "Model")
					end
				end
			end
		end

		if IsolateStarterPlayer then
			save_extra("StarterPlayer", service.StarterPlayer)
		end

		if IsolatePlayers then
			SaveNotCreatable = true
			save_extra("Players", service.Players)
		end

		if NilInstances and global_container.getnilinstances then
			local nil_instances, nil_instances_size = {}, 1

			local NilInstancesFixes = OPTIONS.NilInstancesFixes

			for _, instance in next, global_container.getnilinstances() do
				if instance == game then
					instance = nil
				else
					local ClassName = instance.ClassName

					local Fix = InheritsFix(NilInstancesFixes, ClassName, instance)

					if Fix then
						instance = Fix(instance, InstancesOverrides)
					end

					local Class = ClassList[ClassName]
					if Class then
						if Class.Service then
							instance = nil
						end
					end
				end
				if instance then
					nil_instances[nil_instances_size] = instance
					nil_instances_size = nil_instances_size + 1
				end
			end
			SaveNotCreatable = true
			save_extra("Nil Instances", nil_instances)
		end

		-- ============================================================
		-- NEW FORK: Save README for ScriptsToFolder mode
		-- ============================================================
		if OPTIONS.ReadMe then
			if ScriptsToFolder then
				-- Write a README.txt in the output folder
				local readmeContent = "Scripts extracted by UniversalSynSaveInstance (ScriptsToFolder Fork)\n"
					.. "https://discord.gg/wx4ThpAsmw\n\n"
					.. "Original Place: " .. tostring(game.PlaceId) .. "\n"
					.. "Client Version: " .. FULL_VERSION .. "\n"
					.. "Executor: " .. (identify_executor and table.concat({ identify_executor() }, " ") or "Unknown") .. "\n"
					.. "Date (UTC): " .. DateTime.now():FormatUniversalTime("LL LTS", "en-gb") .. "\n\n"
					.. "Notes:\n"
					.. "- Server Scripts are IMPOSSIBLE to save because of FilteringEnabled.\n"
					.. "- Scripts are saved with extensions: .server.lua (Script), .client.lua (LocalScript), .module.lua (ModuleScript)\n"
					.. "- The folder structure mirrors the Roblox instance hierarchy.\n"

				if #RecoveredScripts ~= 0 then
					readmeContent = readmeContent .. "\nRecovered Original Sources:\n"
					for _, path in next, RecoveredScripts do
						readmeContent = readmeContent .. "- " .. path .. "\n"
					end
				end

				pcall(writefile, ScriptsBaseDir .. "/README.txt", readmeContent)
			else
				save_extra(
					"README",
					nil,
					nil,
					"Script",
					"--[[\n"
						.. (#RecoveredScripts ~= 0 and "\t\tIMPORTANT: Original Source of these Scripts was Recovered: " .. service.HttpService:JSONEncode(
							RecoveredScripts
						) .. "\n" or "")
						.. [[
		Thank you for using UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw.

		If you didn't save in Binary (rbxl) - it's recommended to save the game right away to take advantage of the binary format & to preserve values of certain properties if you used IgnoreDefaultProperties setting (as they might change in the future).
		You can do that by going to FILE -> Save to File As -> Make sure File Name ends with .rbxl -> Save

		ServerStorage, ServerScriptService and Server Scripts are IMPOSSIBLE to save because of FilteringEnabled.

		If your player cannot spawn into the game, please move the scripts in StarterPlayer somewhere else or delete them. Then run `game:GetService("Players").CharacterAutoLoads = true`.
		And use "Play Here" to start game instead of "Play" to spawn your Character where your Camera currently is.

		If the chat system does not work, please use the explorer and delete everything inside the TextChatService/Chat service(s). 
		Or run `game:GetService("Chat"):ClearAllChildren() game:GetService("TextChatService"):ClearAllChildren()`
				
		If Union and MeshPart collisions don't work, run the script below in the Studio Command Bar:
				
				
		local C = game:GetService("CoreGui")
		local D = Enum.CollisionFidelity.Default
				
		for _, v in next, game:GetDescendants() do
			if v:IsA("TriangleMeshPart") and not v:IsDescendantOf(C) then
				v.CollisionFidelity = D
			end
		end
		print("Done")
				
		If you can't move the Camera, run this script in the Studio Command Bar:
			
		workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
		
		Or Destroy the Camera.

		This file was generated with the following settings:
		]]
							.. service.HttpService:JSONEncode(OPTIONS)
							.. "\n\n\t\tElapsed time: "
							.. os.clock() - elapse_t
							.. " Date (UTC): "
							.. DateTime.now():FormatUniversalTime("LL LTS", "en-gb")
							.. " PlaceId: "
							.. game.PlaceId
							.. " PlaceVersion: "
							.. game.PlaceVersion
							.. " Client Version: "
							.. FULL_VERSION
							.. " Platform: "
							.. (
								select(
									2,
									pcall(function()
										return service.UserInputService:GetPlatform().Name
									end)
								) or "Unknown"
							)
							.. " Executor: "
							.. (identify_executor and table.concat({ identify_executor() }, " ") or "Unknown")
							.. "\n]]"
				)
			end
		end
		-- ============================================================
		-- END NEW FORK
		-- ============================================================

		if not ScriptsToFolder then
			do
				local tmp = { "<SharedStrings>" }
				for value, identifier in next, SharedStrings do
					table.insert(tmp, '<SharedString md5="' .. identifier .. '">' .. value .. "</SharedString>")
				end

				if 1 < #tmp then
					savebuffer[savebuffer_size] = table.concat(tmp)
					savebuffer_size = savebuffer_size + 1
					savebuffer[savebuffer_size] = "</SharedStrings>"
					savebuffer_size = savebuffer_size + 1
				end
			end

			savebuffer[savebuffer_size] =
				"</roblox><!-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw -->"
			savebuffer_size = savebuffer_size + 1
			save_cache()
			do
				local function buildFinalString(chunks)
					local parts = table.create(#chunks + 1)
					parts[1] = header

					table.move(chunks, 1, #chunks, 2, parts)

					return table.concat(parts)
				end

				local Callback = OPTIONS.Callback
				if Callback then
					Callback(buildFinalString(chunks), chunks)
				elseif OPTIONS.AlternativeWritefile and appendfile then
					local SEGMENT_SIZE = 4145728
					local totallen = 0
					for _, chunk in next, chunks do
						totallen = totallen + math.ceil(#chunk / SEGMENT_SIZE)
					end

					local currentlen = 0

					for _, chunk in next, chunks do
						local chunk_len = #chunk
						local offset = 1

						while offset <= chunk_len do
							local savestr = string.sub(chunk, offset, offset + SEGMENT_SIZE - 1)

							run_with_loading(
								"Writing to File " .. math.round(currentlen / totallen * 100) .. "% (Depends on Exec)",
								nil,
								true,
								appendfile,
								placename,
								savestr
							)

							currentlen = currentlen + 1
							offset = offset + SEGMENT_SIZE

							if offset <= chunk_len then
								task.wait()
							end
						end
					end
				else
					run_with_loading(
						"Writing " .. get_size_format() .. " to File (Depends on Exec)",
						nil,
						true,
						writefile,
						placename,
						buildFinalString(chunks)
					)
				end
			end
		end
	end

	local Connections = {}
	local function Connect(event, func)
		table.insert(Connections, event:Connect(func))
	end
	local function Cleanup()
		for _, connection in next, Connections do
			connection:Disconnect()
		end
		GLOBAL_ENV[placename] = nil
	end
	do
		local Players = service.Players

		if IgnoreList.Model ~= true then
			local function ignoreCharacter(player)
				Connect(player.CharacterAdded, function(character)
					IgnoreList[character] = true
				end)

				local Character = player.Character
				if Character then
					IgnoreList[Character] = true
				end
			end

			if not OPTIONS.SavePlayerCharacters then
				Connect(Players.PlayerAdded, function(player)
					ignoreCharacter(player)
				end)

				for _, player in next, Players:GetPlayers() do
					ignoreCharacter(player)
				end
			else
				IgnoreNotArchivable = false
				if IsolateLocalPlayerCharacter then
					task.spawn(function()
						ignoreCharacter(GetLocalPlayer())
					end)
				end
			end
		end
		if IsolateLocalPlayer and IgnoreList.Player ~= true then
			task.spawn(function()
				IgnoreList[GetLocalPlayer()] = true
			end)
		end
	end

	if OPTIONS.KillAllScripts and not GLOBAL_ENV.USSI_KAS then
		GLOBAL_ENV.USSI_KAS = true
		game:GetService("ScriptContext"):SetTimeout(math.clamp(SaveCacheInterval * 0.000047, 20, 30))

		local self = coroutine.running()
		do
			local islclosure = islclosure
			local isexecutorclosure = isexecutorclosure or checkclosure or isourclosure
			local hookfunction = not ArrayToDict({ "SirHurt", "Volt" })[EXECUTOR_NAME] and hookfunction

			local function filterNkill(f)
				if not f then
					return
				end

				for _, v in next, table.clone(f()) do
					local _type = type(v)
					if _type == "thread" then
						if v ~= self then
							pcall(coroutine.close, v)
						end
					elseif _type == "function" then
						if
							(not islclosure or islclosure(v)) and (not isexecutorclosure or not isexecutorclosure(v))
						then
							if hookfunction then
								pcall(hookfunction, v, coroutine.yield)
							end
						end
					end
				end
			end

			filterNkill(debug and debug.getregistry or getreg or getregistry)
			filterNkill(getallthreads)
			filterNkill(getgc)
		end
	end

	if IsolateStarterPlayer then
		IgnoreList.StarterPlayer = false
	end

	if IsolatePlayers then
		IgnoreList.Players = false
	end

	if OPTIONS.ShowStatus then
		do
			local Exists = GLOBAL_ENV._statustext
			if Exists then
				Exists:Destroy()
			end
		end

		local StatusGui = Instance.new("ScreenGui")

		GLOBAL_ENV._statustext = StatusGui

		StatusGui.DisplayOrder = 2e9
		pcall(function()
			StatusGui.OnTopOfCoreBlur = true
		end)

		StatusText = Instance.new("TextLabel")

		StatusText.Text = "Saving..."

		StatusText.BackgroundTransparency = 1
		StatusText.Font = Enum.Font.Code
		StatusText.AnchorPoint = Vector2.new(1)
		StatusText.Position = UDim2.new(1)
		StatusText.Size = UDim2.new(0.3, 0, 0, 20)

		StatusText.TextColor3 = Color3.new(1, 1, 1)
		StatusText.TextScaled = true
		StatusText.TextStrokeTransparency = 0.7
		StatusText.TextXAlignment = Enum.TextXAlignment.Right
		StatusText.TextYAlignment = Enum.TextYAlignment.Top

		StatusText.Parent = StatusGui

		local function randomString()
			local length = math.random(10, 20)
			local randomarray = table.create(length)
			for i = 1, length do
				randomarray[i] = string.char(math.random(32, 126))
			end
			return table.concat(randomarray)
		end

		if global_container.gethui then
			StatusGui.Name = randomString()
			StatusGui.Parent = global_container.gethui()
		else
			if global_container.protectgui then
				StatusGui.Name = randomString()
				global_container.protectgui(StatusGui)
				StatusGui.Parent = game:GetService("CoreGui")
			else
				local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
				if RobloxGui then
					StatusGui.Parent = RobloxGui
				else
					StatusGui.Name = randomString()
					StatusGui.Parent = game:GetService("CoreGui")
				end
			end
		end
	end

	do
		if OPTIONS.SafeMode then
			task.spawn(function()
				local LocalPlayer = GetLocalPlayer()

				local PlayerScripts = LocalPlayer:FindFirstChildOfClass("PlayerScripts")
				if PlayerScripts then
					local function construct_InstanceOverride(instance)
						local children = instance:GetChildren()
						InstancesOverrides[instance] = {
							__Children = children,
						}
						for _, child in next, children do
							construct_InstanceOverride(child)
						end
					end
					construct_InstanceOverride(PlayerScripts)

					InstancesOverrides[LocalPlayer] = {
						__Children = LocalPlayer:GetChildren(),
						Properties = { Name = "[" .. LocalPlayer.ClassName .. "] " .. LocalPlayer.Name },
					}
				end
				local msg =
					"[SAVEINSTANCE SAFEMODE]\nSaving..\nDo NOT leave\nLVL7 Executor RECOMMENDED for more SAFETY\nTo Disable this: SafeMode=false (Less Protection)"
				local function Kick()
					LocalPlayer:Kick(msg)
				end

				Kick()
				pcall(function()
					Connect(service.GuiService.ErrorMessageChanged, function()
						if service.GuiService:GetErrorMessage() ~= msg then
							Kick()
						end
					end)
				end)
				wait_for_render()
			end)

			if CustomOptions_valid["BoostFPS"] == nil then
				OPTIONS.BoostFPS = true
			end
		end

		if OPTIONS.BoostFPS then
			pcall(function()
				service.RunService:Set3dRenderingEnabled(false)
			end)
		end

		if OPTIONS.AntiIdle then
			local Idled = GetLocalPlayer().Idled
			Connect(Idled, function()
				service.VirtualInputManager:SendMouseWheelEvent(
					service.UserInputService:GetMouseLocation().X,
					service.UserInputService:GetMouseLocation().Y,
					true,
					game
				)
			end)
		end

		if not ClassList then
			do
				local UGCValidationService

				gethiddenproperty_fallback = function(instance, propertyName)
					if not UGCValidationService then
						UGCValidationService = service.UGCValidationService
					end
					return UGCValidationService:GetPropertyValue(instance, propertyName)
				end
				if gethiddenproperty then
					local o, r = pcall(gethiddenproperty, workspace, "StreamOutBehavior")
					if not o or r ~= nil and typeof(r) ~= "EnumItem" then
						gethiddenproperty = nil
					else
						o, r =
							pcall(gethiddenproperty, Instance.new("AnimationRigData", Instance.new("Folder")), "parent")

						if o and r ~= nil and type(r) ~= "string" then
							gethiddenproperty = nil
						end
					end
				end
				local function benchmark(funcs, ...)
					local ranking = table.create(2)
					for i, f in next, funcs do
						local start = os.clock()
						for _ = 1, 50 do
							f(...)
						end
						ranking[i] = { t = os.clock() - start, f = f }
					end
					table.sort(ranking, function(a, b)
						return a.t < b.t
					end)
					return ranking[1].f
				end

				local test_str = string.rep("\1\0\0\0\1\2\3\4\5\6\7", 50)

				do
					if
						not bit32.byteswap
						or not (function()
							local o, r = pcall(bit32.byteswap, 2712847316)
							if not o then
								return
							end
							return r == 3569595041
						end)()
					then
						local b32 = table.clone(bit32)

						b32.byteswap = function(n)
							return bit32.bor(
								bit32.lshift(n, 24),
								bit32.band(bit32.lshift(n, 8), 0xFF0000),
								bit32.band(bit32.rshift(n, 8), 0xFF00),
								bit32.rshift(n, 24)
							)
						end
						if table.isfrozen(bit32) then
							b32 = table.freeze(b32)
						end
						GLOBAL_ENV.bit32 = b32
					end

					local rbxcrypt_base64encode
					pcall(function()
						local b64_enc_buf = loadstring(
							game:HttpGet(
								"https://raw.githubusercontent.com/daily3014/rbx-cryptography/refs/heads/main/src/Utilities/Base64.luau",
								true
							),
							"Base64"
						)().Encode
						rbxcrypt_base64encode = function(raw)
							return buffer.tostring(b64_enc_buf(buffer.fromstring(raw)))
						end
					end)

					local EncodingService = game:GetService("EncodingService")
					local EncodingService_base64encode = function(raw)
						return buffer.tostring(EncodingService:Base64Encode(buffer.fromstring(raw)))
					end

					if base64encode and base64encode("\1\0\0\0\1") == "AQAAAAE=" then
						if rbxcrypt_base64encode then
							base64encode = benchmark(
								{ base64encode, rbxcrypt_base64encode, EncodingService_base64encode },
								test_str
							)
						end
					else
						base64encode = rbxcrypt_base64encode
					end

					if not base64encode then
						warn("base64encode not found")
						Cleanup()
						return
					end
				end
			end
			do
				local ok, result = pcall(FetchAPI)
				if ok then
					ClassList = result
				else
					warn("Failed to load the API Dump")
					warn(result)
					Cleanup()
					return
				end
			end
		end

		elapse_t = os.clock()

		local ok, err = xpcall(save_game, function(err)
			return debug.traceback(err)
		end)

		if OPTIONS.BoostFPS then
			pcall(function()
				local max = 5
				task.delay(
					math.clamp(max - (os.clock() - elapse_t), 0, max),
					service.GuiService.ClearError,
					service.GuiService
				)
				service.RunService:Set3dRenderingEnabled(true)
			end)
		end

		if old_gethiddenproperty then
			gethiddenproperty = old_gethiddenproperty
		end

		Cleanup()

		elapse_t = os.clock() - elapse_t
		local Log10 = math.log10(elapse_t)
		local ExtraTime = 10

		if StatusText then
			task.spawn(function()
				if ok then
					if ScriptsToFolder then
						StatusText.Text = string.format("Saved scripts to folder! Time %.3f seconds", elapse_t)
					else
						StatusText.Text = string.format("Saved! Time %.3f seconds; Size %s", elapse_t, get_size_format())
					end
					StatusText.TextColor3 = Color3.new(0, 1)
					task.wait(Log10 * 2 + ExtraTime)
				else
					if Loading then
						task.cancel(Loading)
						Loading = nil
					end
					StatusText.Text = "Failed! Check F9 console for more info"
					StatusText.TextColor3 = Color3.new(1)
					warn("Error found while saving:")
					warn(err)
					task.wait(Log10 + ExtraTime)
				end
				StatusText:Destroy()
			end)
		end

		if OPTIONS.ShutdownWhenDone and ok then
			task.wait(Log10 * 2 + ExtraTime)
			game:Shutdown()
		end
	end
end

return synsaveinstance