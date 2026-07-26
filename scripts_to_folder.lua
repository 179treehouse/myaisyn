--!native
--!optimize 2
--!divine-intellect
-- ScriptsToFolder: Extract decompiled scripts from a Roblox place into a folder structure
-- Fork of https://github.com/luau/UniversalSynSaveInstance
-- Usage:
--   local scriptsToFolder = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/scripts_to_folder.lua", true))()
--   scriptsToFolder({ DecompileTimeout = 15, mode = "optimized" })
-- Or with custom instances:
--   scriptsToFolder({ Object = game.Workspace })

-- This script reuses the decompilation engine from UniversalSynSaveInstance
-- but outputs scripts to a folder structure instead of an XML place file.

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
				tmp[any1] = ArrayToDict(any2, hydridMode)
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
local getscriptbytecode = global_container.getscriptbytecode
local base64encode = global_container.base64encode

-- File system functions (must be provided by executor)
local writefile = writefile
local isfile = isfile
local makefolder = makefolder
local delfolder = delfolder

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
if not pcall(function() FULL_VERSION = version() end) then
	if not pcall(function() FULL_VERSION = settings():GetService("DebugSettings").RobloxVersion end) then
		if not pcall(function() FULL_VERSION = service.RunService:GetRobloxVersion() end) then
			FULL_VERSION = "UNKNOWN"
		end
	end
end

local CLIENT_VERSION = tonumber(string.match(FULL_VERSION, "%d+%.(%d+)")) or 9e9

-- Load base64 implementation
do
	local rbxcrypt_base64encode
	pcall(function()
		local b64_enc_buf = loadstring(
			game:HttpGet("https://raw.githubusercontent.com/daily3014/rbx-cryptography/refs/heads/main/src/Utilities/Base64.luau", true),
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
			-- Use fastest available
			local function benchmark(funcs, test_str)
				local ranking = {}
				for i, f in next, funcs do
					local start = os.clock()
					for _ = 1, 50 do f(test_str) end
					ranking[i] = { t = os.clock() - start, f = f }
				end
				table.sort(ranking, function(a, b) return a.t < b.t end)
				return ranking[1].f
			end
			local test_str = string.rep("\1\0\0\0\1\2\3\4\5\6\7", 50)
			base64encode = benchmark({ base64encode, rbxcrypt_base64encode, EncodingService_base64encode }, test_str)
		end
	else
		base64encode = rbxcrypt_base64encode
	end

	if not base64encode then
		warn("base64encode not found")
		return function() end
	end
end

-- ============================================================
-- ScriptsToFolder implementation
-- ============================================================

local function sanitizePathComponent(name)
	-- string.gsub returns 2 values (result + count), so we wrap it
	local result = string.gsub(name, '[<>:"/\\|?*]', "_")
	return result
end

local function ensureDir(dirPath)
	if not isfile(dirPath) then
		local success = pcall(makefolder, dirPath)
		if not success then
			warn("Failed to create directory:", dirPath)
		end
	end
end

local function getScriptExtension(instance)
	if instance:IsA("ModuleScript") then
		return ".module.lua"
	elseif instance:IsA("LocalScript") then
		return ".client.lua"
	else
		return ".server.lua"
	end
end

-- Known Roblox services that should use their class name instead of instance name
local KNOWN_SERVICES = {
	Workspace = true, Players = true, Lighting = true, MaterialService = true,
	ReplicatedFirst = true, ReplicatedStorage = true,
	ServerScriptService = true, ServerStorage = true,
	StarterGui = true, StarterPack = true, StarterPlayer = true,
	Teams = true, SoundService = true, Chat = true, TextChatService = true,
	LocalizationService = true, JointsService = true,
	InsertService = true, TestService = true, VoiceChatService = true,
	CoreGui = true, CorePackages = true,
}

local function getScriptFilePath(instance, baseDir)
	local pathParts = {}
	local current = instance
	while current and current ~= game do
		local name
		-- If this is a direct child of game and is a known service,
		-- use the class name instead of the (potentially renamed) instance name
		if current.Parent == game and KNOWN_SERVICES[current.ClassName] then
			name = current.ClassName
		else
			name = sanitizePathComponent(current.Name)
		end
		table.insert(pathParts, 1, name)
		current = current.Parent
	end

	if #pathParts == 0 then
		return baseDir, "unknown" .. getScriptExtension(instance)
	end

	local dirPath = baseDir
	for i = 1, #pathParts - 1 do
		dirPath = dirPath .. "/" .. pathParts[i]
	end

	local fileName = pathParts[#pathParts] .. getScriptExtension(instance)
	return dirPath, fileName
end

local decompile
local decompileTimeout = 10
local scriptCache = {}
local scriptCacheEnabled = true

-- Decompilation with timeout
local function decompileWithTimeout(script)
	if not decompile then
		return "-- Your Executor does NOT have a Decompiler"
	end

	local thread = coroutine.running()
	local isCancelled
	local timeoutThread

	timeoutThread = task.delay(decompileTimeout, function()
		isCancelled = true
		coroutine.resume(thread, nil, "Decompiler timed out")
	end)

	local function doDecompile()
		local ok, result = pcall(decompile, script)

		if isCancelled then return end
		task.cancel(timeoutThread)

		while coroutine.status(thread) ~= "suspended" do
			task.wait()
		end

		coroutine.resume(thread, ok, result)
	end

	task.spawn(doDecompile)

	return coroutine.yield()
end

-- Get decompiled source for a script
local function getScriptSource(instance)
	local useCache = scriptCacheEnabled and getscriptbytecode

	if useCache then
		local s, bc = pcall(getscriptbytecode, instance)
		if s and bc and bc ~= "" then
			local cached = scriptCache[bc]
			if cached then
				return cached
			end

			local ok, source = decompileWithTimeout(instance)
			if ok and source then
				source = string.gsub(source, "\0", "\\0")
				scriptCache[bc] = source
				return source
			end

			local err = source or "Empty Output"
			local output = "--[[ Failed to decompile. Reason:\n" .. err .. "\n]]"
			scriptCache[bc] = output
			return output
		elseif not s then
			-- getscriptbytecode failed, try decompile directly
			local ok, source = decompileWithTimeout(instance)
			if ok and source then
				return string.gsub(source, "\0", "\\0")
			end
			return "--[[ Failed to decompile. Reason:\n" .. (source or "Unknown") .. "\n]]"
		else
			return "-- The Script is Empty"
		end
	else
		local ok, source = decompileWithTimeout(instance)
		if ok and source then
			return string.gsub(source, "\0", "\\0")
		end
		return "--[[ Failed to decompile. Reason:\n" .. (source or "Empty Output") .. "\n]]"
	end
end

-- Recursively collect script instances to save
local function collectScripts(instance, results, processed)
	processed = processed or {}

	if processed[instance] then
		return
	end
	processed[instance] = true

	if instance:IsA("LuaSourceContainer") then
		table.insert(results, instance)
	end

	for _, child in next, instance:GetChildren() do
		collectScripts(child, results, processed)
	end
end

-- Main function
local function scriptsToFolder(options)
	if not writefile then
		warn("Your executor does not support writefile")
		return
	end

	if not makefolder then
		warn("Your executor does not support makefolder")
		return
	end

	-- Default options
	local opts = {
		mode = "optimized",
		Decompile = EXECUTOR_NAME ~= "Velocity",
		DecompileTimeout = 10,
		FilePath = false,
		Object = false,
		SaveBytecode = false,
		IgnoreList = { "CoreGui", "CorePackages" },
		ShowStatus = true,
		KillAllScripts = true,
		SafeMode = true,
		BoostFPS = false,
		AntiIdle = true,
	}

	-- Merge user options
	if options then
		for k, v in next, options do
			opts[k] = v
		end
	end

	-- Handle special parameter formats
	if typeof(options) == "Instance" then
		opts.Object = options
		opts.mode = "full"
	end

	decompileTimeout = opts.DecompileTimeout

	if not opts.Decompile then
		warn("Decompilation is disabled, no scripts will be saved")
		return
	end

	-- Check if decompile function exists
	local decompileExists, decompileFunc = pcall(getfenv, 0)
	decompile = decompileFunc and decompileFunc.decompile or decompile

	if not decompile then
		warn("No decompiler available on this executor")
		return
	end

	-- Setup status display
	local StatusText
	if opts.ShowStatus then
		pcall(function()
			local StatusGui = Instance.new("ScreenGui")
			StatusGui.DisplayOrder = 2e9
			pcall(function() StatusGui.OnTopOfCoreBlur = true end)
			StatusGui.Name = string.rep(string.char(math.random(32, 126)), math.random(10, 20))

			StatusText = Instance.new("TextLabel")
			StatusText.Text = "ScriptsToFolder: Scanning..."
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

			if global_container.gethui then
				StatusGui.Parent = global_container.gethui()
			elseif global_container.protectgui then
				global_container.protectgui(StatusGui)
				StatusGui.Parent = game:GetService("CoreGui")
			else
				local RobloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
				StatusGui.Parent = RobloxGui or game:GetService("CoreGui")
			end
		end)
	end

	-- SafeMode
	if opts.SafeMode then
		task.spawn(function()
			local LocalPlayer = service.Players.LocalPlayer
			if LocalPlayer then
				LocalPlayer:Kick("[SCRIPTS TO FOLDER]\nSaving scripts...\nDo NOT leave")
			end
		end)
	end

	-- Anti-Idle
	if opts.AntiIdle then
		task.spawn(function()
			local lp = service.Players.LocalPlayer
			if lp then
				lp.Idled:Connect(function()
					service.VirtualInputManager:SendMouseWheelEvent(
						service.UserInputService:GetMouseLocation().X,
						service.UserInputService:GetMouseLocation().Y,
						true,
						game
					)
				end)
			end
		end)
	end

	-- Build the list of instances to scan
	local rootInstance = opts.Object or game
	local scanList = {}

	if opts.mode == "optimized" or opts.mode == "full" then
		if opts.mode == "optimized" then
			-- Standard services
			local servicesToScan = {
				"Workspace", "Players", "Lighting", "ReplicatedFirst",
				"ReplicatedStorage", "ServerScriptService", "ServerStorage",
				"StarterGui", "StarterPack", "StarterPlayer", "Teams",
				"SoundService", "Chat", "TextChatService",
			}
			for _, serviceName in next, servicesToScan do
				local svc = game:FindService(serviceName)
				if svc then
					table.insert(scanList, svc)
				end
			end
		else
			-- Full: scan all children of game
			for _, child in next, game:GetChildren() do
				table.insert(scanList, child)
			end
		end
	elseif opts.mode == "scripts" then
		-- scripts mode: collect parent instances that contain scripts
		local unique = {}
		for _, instance in next, rootInstance:GetDescendants() do
			if instance:IsA("LuaSourceContainer") then
				local Parent = instance.Parent
				while Parent and Parent ~= rootInstance do
					instance = instance.Parent
					Parent = instance.Parent
				end
				if Parent then
					unique[instance] = true
				end
			end
		end
		for instance in next, unique do
			table.insert(scanList, instance)
		end
	end

	-- Also handle Object parameter
	if opts.Object and opts.Object ~= game then
		table.insert(scanList, 1, opts.Object)
	end

	-- Handle ExtraInstances
	if opts.ExtraInstances then
		for _, inst in next, opts.ExtraInstances do
			table.insert(scanList, inst)
		end
	end

	-- Handle IgnoreList
	local IgnoreList = ArrayToDict(opts.IgnoreList or {}, true)

	-- Create output directory name
	local PlaceName = tostring(game.PlaceId)
	pcall(function()
		PlaceName = game.PlaceId .. " " .. service.MarketplaceService:GetProductInfoAsync(game.PlaceId).Name
	end)

	local function sanitizeFileName(str)
		return string.sub(string.gsub(string.gsub(string.gsub(str, "[^%w _]", ""), " +", " "), " +$", ""), 1, 240)
	end

	local outputDir = opts.FilePath or ("scripts_" .. sanitizeFileName(PlaceName))

	-- Delete existing directory if present
	pcall(delfolder, outputDir)
	ensureDir(outputDir)

	if StatusText then
		StatusText.Text = "ScriptsToFolder: Collecting scripts..."
	end

	-- Collect all scripts
	local allScripts = {}
	local processed = {}

	for _, rootInst in next, scanList do
		if not IgnoreList[rootInst] then
			collectScripts(rootInst, allScripts, processed)
		end
	end

	if #allScripts == 0 then
		if StatusText then
			StatusText.Text = "No scripts found!"
			task.delay(5, function() StatusText:Destroy() end)
		end
		warn("No scripts found to save")
		return
	end

	if StatusText then
		StatusText.Text = "ScriptsToFolder: Found " .. #allScripts .. " scripts. Decompiling..."
	end

	-- Decompile and save each script
	local savedCount = 0
	local failedCount = 0
	local totalScripts = #allScripts

	for i, script in next, allScripts do
		local scriptName = script:GetFullName()

		-- Update status
		if StatusText then
			if i % 5 == 0 or i == totalScripts then
				StatusText.Text = string.format("ScriptsToFolder: [%d/%d] %s", i, totalScripts, script.Name)
			end
		end

		local source = getScriptSource(script)

		-- Prepend header
		local header = "-- Saved by ScriptsToFolder (based on UniversalSynSaveInstance)\n"
			.. "-- Original Path: " .. scriptName .. "\n"
			.. "-- Class: " .. script.ClassName .. "\n"
			.. "\n"

		local content = header .. source

		-- Optionally prepend bytecode
		if opts.SaveBytecode and getscriptbytecode then
			local s, bc = pcall(getscriptbytecode, script)
			if s and bc and bc ~= "" then
				content = "-- Bytecode (Base64):\n-- " .. base64encode(bc) .. "\n\n" .. content
			end
		end

		-- Write to file
		local dirPath, fileName = getScriptFilePath(script, outputDir)
		ensureDir(dirPath)

		local fullPath = dirPath .. "/" .. fileName

		-- Handle duplicate names
		if isfile(fullPath) then
			local counter = 1
			local ext = getScriptExtension(script)
			local nameWithoutExt = string.sub(fileName, 1, #fileName - #ext)
			while isfile(fullPath) do
				fullPath = dirPath .. "/" .. nameWithoutExt .. "(" .. counter .. ")" .. ext
				counter = counter + 1
			end
		end

		local success = pcall(writefile, fullPath, content)
		if success then
			savedCount = savedCount + 1
		else
			failedCount = failedCount + 1
			warn("Failed to write:", fullPath)
		end

		-- Yield occasionally
		if i % 20 == 0 then
			task.wait()
		end
	end

	-- Write README
	local readmeContent = "Scripts extracted by ScriptsToFolder\n"
		.. "Based on UniversalSynSaveInstance - https://github.com/luau/UniversalSynSaveInstance\n\n"
		.. "Original Place: " .. tostring(game.PlaceId) .. "\n"
		.. "Client Version: " .. FULL_VERSION .. "\n"
		.. "Date (UTC): " .. DateTime.now():FormatUniversalTime("LL LTS", "en-gb") .. "\n"
		.. "Total Scripts Saved: " .. savedCount .. "\n"
		.. "Failed: " .. failedCount .. "\n\n"
		.. "Notes:\n"
		.. "- Server Scripts are IMPOSSIBLE to save because of FilteringEnabled.\n"
		.. "- Script extensions: .server.lua (Script), .client.lua (LocalScript), .module.lua (ModuleScript)\n"
		.. "- Folder structure mirrors the Roblox instance hierarchy.\n"

	pcall(writefile, outputDir .. "/README.txt", readmeContent)

	if StatusText then
		StatusText.Text = string.format("Done! Saved %d scripts to '%s'", savedCount, outputDir)
		StatusText.TextColor3 = Color3.new(0, 1)
		task.delay(8, function()
			pcall(function() StatusText:Destroy() end)
		end)
	end

	warn(string.format("ScriptsToFolder: Saved %d scripts (failed: %d) to '%s'", savedCount, failedCount, outputDir))
end

return scriptsToFolder