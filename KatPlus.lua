-- KAT Ultra
-- Rebuilt UI + audio pipeline
-- Original legacy routines are retained below without modification.

repeat task.wait() until game:IsLoaded()
task.wait(1)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

if CoreGui:FindFirstChild("KATUltra") then
	return warn("KAT Ultra is already running")
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",20))
if not LocalPlayer or not PlayerGui then
	return warn("KAT Ultra: PlayerGui was not ready")
end

-- =========================================================
-- Adaptive game detection
-- =========================================================

local function findDescendant(root, name, className)
	if not root then return nil end
	local preferred = root:FindFirstChild(name)
	if preferred and (not className or preferred:IsA(className)) then
		return preferred
	end
	for _, object in ipairs(root:GetDescendants()) do
		if object.Name == name and (not className or object:IsA(className)) then
			return object
		end
	end
	return nil
end

local GameUI = PlayerGui:FindFirstChild("GameUI")
local HUD = GameUI and GameUI:FindFirstChild("HUD")
local Interface = GameUI and GameUI:FindFirstChild("Interface")
local BottomBar = Interface and Interface:FindFirstChild("BottomBar")
local SideButtons = Interface and Interface:FindFirstChild("SideButtons")
local SettingsPane = Interface and Interface:FindFirstChild("SettingsPane")
local Round = HUD and HUD:FindFirstChild("Round")

local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
local Misk = GameEvents and GameEvents:FindFirstChild("Misk")
local ReplicateSound = Misk and Misk:FindFirstChild("ReplicateSound")
if not ReplicateSound then
	ReplicateSound = findDescendant(ReplicatedStorage,"ReplicateSound","RemoteEvent")
end

local structureScore = 0
if GameUI then structureScore += 1 end
if HUD then structureScore += 1 end
if Interface then structureScore += 1 end
if BottomBar then structureScore += 1 end
if SideButtons then structureScore += 1 end
if SettingsPane then structureScore += 1 end
if Round then structureScore += 1 end
if ReplicateSound and ReplicateSound:IsA("RemoteEvent") then structureScore += 2 end

if structureScore < 4 then
	return warn("KAT Ultra: compatible game structure was not detected")
end

local Marker = Instance.new("BoolValue")
Marker.Name = "KATUltra"
Marker.Value = true
Marker.Parent = CoreGui

-- =========================================================
-- Runtime state
-- =========================================================

local VERSION = "3.0"
local Accent = Color3.fromRGB(88, 255, 184)
local Accent2 = Color3.fromRGB(105, 140, 255)
local Background = Color3.fromRGB(10, 12, 15)
local Surface = Color3.fromRGB(17, 20, 25)
local Surface2 = Color3.fromRGB(23, 27, 33)
local Surface3 = Color3.fromRGB(29, 34, 41)
local Text = Color3.fromRGB(241, 245, 247)
local Muted = Color3.fromRGB(145, 155, 166)
local Danger = Color3.fromRGB(255, 91, 105)
local Warning = Color3.fromRGB(255, 194, 96)

local ActiveSounds = {}
local SoundCards = {}
local SavedSounds = {}
local CurrentVolume = 1
local BroadcastRemote = false
local InsanityMode = false
local CurrentTab = "Sounds"
local SearchText = ""
local WindowOpen = true
local WindowMinimized = false
local UIConnections = {}

local hasFileAPI =
	type(isfile) == "function" and
	type(writefile) == "function" and
	type(isfolder) == "function" and
	type(makefolder) == "function"

-- =========================================================
-- Small helpers
-- =========================================================

local function track(connection)
	table.insert(UIConnections,connection)
	return connection
end

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key,value in pairs(properties or {}) do
		object[key] = value
	end
	if parent then object.Parent = parent end
	return object
end

local function corner(object, radius)
	local c = object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0,radius)
	c.Parent = object
	return c
end

local function stroke(object, color, transparency, thickness)
	local s = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local function tween(object, info, properties)
	local animation = TweenService:Create(object,info,properties)
	animation:Play()
	return animation
end

local function setClipboard(value)
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard,tostring(value))
		return ok
	end
	if type(toclipboard) == "function" then
		local ok = pcall(toclipboard,tostring(value))
		return ok
	end
	return false
end

local function normalizeId(value)
	local textValue = tostring(value or "")
	local id = textValue:match("%d+")
	return id
end

local function notify(message, kind)
	if not ToastHolder or not ToastTemplate then
		warn("[KAT Ultra] "..tostring(message))
		return
	end

	local toast = ToastTemplate:Clone()
	toast.Visible = true
	toast.Name = "Toast"
	toast.Parent = ToastHolder
	toast.Position = UDim2.new(1,20,0,0)
	toast.BackgroundTransparency = 0.04

	local tint = Accent
	if kind == "error" then
		tint = Danger
	elseif kind == "warn" then
		tint = Warning
	end

	local stripe = toast:FindFirstChild("Stripe")
	if stripe then stripe.BackgroundColor3 = tint end

	local label = toast:FindFirstChild("Message")
	if label then label.Text = tostring(message) end

	tween(toast,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
		Position = UDim2.new(0,0,0,0)
	})

	task.delay(2.8,function()
		if toast and toast.Parent then
			tween(toast,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
				Position = UDim2.new(1,20,0,0),
				BackgroundTransparency = 1
			})
			task.wait(0.25)
			if toast.Parent then toast:Destroy() end
		end
	end)
end

-- =========================================================
-- UI
-- =========================================================

local UIParent = CoreGui
if type(gethui) == "function" then
	local ok, result = pcall(gethui)
	if ok and result then
		UIParent = result
	end
end

local Screen = new("ScreenGui",{
	Name = "KATUltraUI",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 2147483647,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling
},UIParent)

local Root = new("Frame",{
	Name = "Root",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1,1)
},Screen)

local Launcher = new("TextButton",{
	Name = "Launcher",
	AutoButtonColor = false,
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-76,1,-76),
	Size = UDim2.fromOffset(56,56),
	Text = "K",
	TextColor3 = Text,
	TextSize = 24,
	Font = Enum.Font.GothamBold
},Root)
corner(Launcher,16)
stroke(Launcher,Accent,0.25,2)

local LauncherScale = new("UIScale",{Scale = 0.85},Launcher)
tween(LauncherScale,TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale = 1})

local Shadow = new("Frame",{
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5,0.5),
	BackgroundColor3 = Color3.new(0,0,0),
	BackgroundTransparency = 0.48,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5,0.52),
	Size = UDim2.new(0.78,0,0.82,0),
	ZIndex = 0
},Root)
corner(Shadow,22)

local Main = new("Frame",{
	Name = "Main",
	AnchorPoint = Vector2.new(0.5,0.5),
	BackgroundColor3 = Background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromScale(0.5,0.5),
	Size = UDim2.new(0.78,0,0.82,0),
	ZIndex = 2
},Root)
corner(Main,20)
stroke(Main,Accent,0.48,1.5)

local MainSizeConstraint = new("UISizeConstraint",{
	MinSize = Vector2.new(320,300),
	MaxSize = Vector2.new(760,760)
},Main)

-- The window is sized responsively below; no fixed aspect ratio is used so portrait phones do not clip the panel.

local MainScale = new("UIScale",{Scale = 0},Main)
tween(MainScale,TweenInfo.new(0.52,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale = 1})

local Header = new("Frame",{
	Name = "Header",
	Active = true,
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	Size = UDim2.new(1,0,0,74),
	ZIndex = 5
},Main)

local HeaderTitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,18,0,9),
	Size = UDim2.new(1,-150,0,29),
	Font = Enum.Font.GothamBold,
	Text = "KAT ULTRA",
	TextColor3 = Text,
	TextSize = 23,
	TextXAlignment = Enum.TextXAlignment.Left
},Header)

local HeaderSub = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,19,0,39),
	Size = UDim2.new(1,-180,0,20),
	Font = Enum.Font.Gotham,
	Text = "Soundboard  •  Music  •  Tools  •  Diagnostics",
	TextColor3 = Muted,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left
},Header)

local HeaderStatus = new("TextLabel",{
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1,0),
	Position = UDim2.new(1,-112,0,27),
	Size = UDim2.fromOffset(110,22),
	Font = Enum.Font.GothamMedium,
	Text = "LOCAL AUDIO",
	TextColor3 = Accent,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right
},Header)

local CloseButton = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-52,0,18),
	Size = UDim2.fromOffset(34,34),
	Text = "×",
	TextColor3 = Text,
	TextSize = 22,
	Font = Enum.Font.GothamBold
},Header)
corner(CloseButton,10)
stroke(CloseButton,Surface3,0,1)

local Content = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,0,0,74),
	Size = UDim2.new(1,0,1,-74)
},Main)

local Nav = new("Frame",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	Position = UDim2.new(0,10,0,10),
	Size = UDim2.new(0,142,1,-20)
},Content)
corner(Nav,15)

local NavTitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,13),
	Size = UDim2.new(1,-30,0,20),
	Font = Enum.Font.GothamBold,
	Text = "KAT  /  ULTRA",
	TextColor3 = Accent,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left
},Nav)

local NavList = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,8,0,45),
	Size = UDim2.new(1,-16,0,240)
},Nav)

new("UIListLayout",{
	Padding = UDim.new(0,7),
	SortOrder = Enum.SortOrder.LayoutOrder
},NavList)

local TabButtons = {}

local function createTab(name, icon, order)
	local button = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1,0,0,39),
		Text = "",
		ZIndex = 3
	},NavList)
	corner(button,11)

	local indicator = new("Frame",{
		BackgroundColor3 = Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0,0,0.5,-8),
		Size = UDim2.fromOffset(3,16),
		Visible = false
	},button)
	corner(indicator,3)

	local iconLabel = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,13,0,0),
		Size = UDim2.fromOffset(23,39),
		Font = Enum.Font.GothamBold,
		Text = icon,
		TextColor3 = Muted,
		TextSize = 14
	},button)

	local label = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,42,0,0),
		Size = UDim2.new(1,-48,1,0),
		Font = Enum.Font.GothamMedium,
		Text = name,
		TextColor3 = Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	},button)

	TabButtons[name] = {
		button = button,
		indicator = indicator,
		label = label,
		icon = iconLabel
	}

	track(button.Activated:Connect(function()
		CurrentTab = name
		for tab,data in pairs(TabButtons) do
			local active = tab == CurrentTab
			data.indicator.Visible = active
			data.button.BackgroundColor3 = active and Surface3 or Surface
			data.label.TextColor3 = active and Text or Muted
			data.icon.TextColor3 = active and Accent or Muted
		end
		for _,page in ipairs(PageHolder:GetChildren()) do
			if page:IsA("ScrollingFrame") or page:IsA("Frame") then
				page.Visible = page.Name == name.."Page"
			end
		end
	end))

	return button
end

createTab("Sounds","♪",1)
createTab("Music","♫",2)
createTab("Tools","◆",3)
createTab("Settings","⚙",4)
createTab("Diagnostics","?",5)


local NavFooter = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,1,-62),
	Size = UDim2.new(1,-30,0,44),
	Font = Enum.Font.Gotham,
	Text = "v"..VERSION.."\nAdaptive build",
	TextColor3 = Muted,
	TextSize = 10,
	TextTransparency = 0.2,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom
},Nav)

local PageHolder = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,164,0,10),
	Size = UDim2.new(1,-174,1,-20)
},Content)

-- =========================================================
-- Responsive layout
-- =========================================================

local function updateResponsiveLayout()
	local narrow = Main.AbsoluteSize.X < 520

	if narrow then
		Main.Size = UDim2.new(1,-14,1,-14)
		Shadow.Size = Main.Size
		Nav.Size = UDim2.new(0,62,1,-20)
		NavTitle.Text = "K"
		NavTitle.TextXAlignment = Enum.TextXAlignment.Center
		NavTitle.Position = UDim2.new(0,0,0,13)
		NavTitle.Size = UDim2.new(1,0,0,20)
		NavFooter.Visible = false
		PageHolder.Position = UDim2.new(0,72,0,10)
		PageHolder.Size = UDim2.new(1,-82,1,-20)

		for _,data in pairs(TabButtons) do
			data.label.Visible = false
			data.icon.Position = UDim2.new(0.5,-12,0,0)
			data.icon.TextXAlignment = Enum.TextXAlignment.Center
			data.icon.Size = UDim2.fromOffset(24,39)
		end
	else
		Main.Size = UDim2.new(0.78,0,0.82,0)
		Shadow.Size = Main.Size
		Nav.Size = UDim2.new(0,142,1,-20)
		NavTitle.Text = "KAT  /  ULTRA"
		NavTitle.TextXAlignment = Enum.TextXAlignment.Left
		NavTitle.Position = UDim2.new(0,15,0,13)
		NavTitle.Size = UDim2.new(1,-30,0,20)
		NavFooter.Visible = true
		PageHolder.Position = UDim2.new(0,164,0,10)
		PageHolder.Size = UDim2.new(1,-174,1,-20)

		for _,data in pairs(TabButtons) do
			data.label.Visible = true
			data.icon.Position = UDim2.new(0,13,0,0)
			data.icon.Size = UDim2.fromOffset(23,39)
			data.icon.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

track(Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveLayout))
updateResponsiveLayout()

local function makePage(name)
	return new("ScrollingFrame",{
		Name = name.."Page",
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Accent,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1,1),
		Visible = false
	},PageHolder)
end

local SoundsPage = makePage("Sounds")
local MusicPage = makePage("Music")
local ToolsPage = makePage("Tools")
local SettingsPage = makePage("Settings")
local DiagnosticsPage = makePage("Diagnostics")

local SoundsLayout = new("UIListLayout",{
	Padding = UDim.new(0,9),
	SortOrder = Enum.SortOrder.LayoutOrder
},SoundsPage)

local MusicLayout = new("UIListLayout",{
	Padding = UDim.new(0,9),
	SortOrder = Enum.SortOrder.LayoutOrder
},MusicPage)

local ToolsLayout = new("UIListLayout",{
	Padding = UDim.new(0,9),
	SortOrder = Enum.SortOrder.LayoutOrder
},ToolsPage)

local SettingsLayout = new("UIListLayout",{
	Padding = UDim.new(0,9),
	SortOrder = Enum.SortOrder.LayoutOrder
},SettingsPage)

local DiagnosticsLayout = new("UIListLayout",{
	Padding = UDim.new(0,9),
	SortOrder = Enum.SortOrder.LayoutOrder
},DiagnosticsPage)

-- =========================================================
-- Toast system
-- =========================================================

ToastHolder = new("Frame",{
	Name = "ToastHolder",
	AnchorPoint = Vector2.new(1,0),
	BackgroundTransparency = 1,
	Position = UDim2.new(1,-14,0,14),
	Size = UDim2.fromOffset(300,250),
	ZIndex = 100
},Root)

new("UIListLayout",{
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0,8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top
},ToastHolder)

ToastTemplate = new("Frame",{
	BackgroundColor3 = Surface2,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(285,46),
	Visible = false,
	ZIndex = 101
},Root)
corner(ToastTemplate,12)
stroke(ToastTemplate,Surface3,0,1)

new("Frame",{
	Name = "Stripe",
	BackgroundColor3 = Accent,
	BorderSizePixel = 0,
	Position = UDim2.new(0,0,0,9),
	Size = UDim2.fromOffset(3,28),
	ZIndex = 102
},ToastTemplate)

new("TextLabel",{
	Name = "Message",
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,0),
	Size = UDim2.new(1,-22,1,0),
	Font = Enum.Font.GothamMedium,
	Text = "",
	TextColor3 = Text,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left
},ToastTemplate)

-- =========================================================
-- Header drag + window controls
-- =========================================================

local dragging = false
local dragStart = nil
local startPosition = nil

track(Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = Main.Position
		track(input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end))
	end
end))

track(UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		Main.Position = UDim2.new(
			startPosition.X.Scale,startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,startPosition.Y.Offset + delta.Y
		)
		Shadow.Position = Main.Position
	end
end))

track(Launcher.Activated:Connect(function()
	WindowOpen = not WindowOpen
	Main.Visible = WindowOpen
	Shadow.Visible = WindowOpen
end))

track(CloseButton.Activated:Connect(function()
	WindowOpen = false
	Main.Visible = false
	Shadow.Visible = false
end))

track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		WindowOpen = not WindowOpen
		Main.Visible = WindowOpen
		Shadow.Visible = WindowOpen
	end
end))

local function addSectionTitle(parent, title, subtitle)
	local box = new("Frame",{
		BackgroundTransparency = 1,
		LayoutOrder = #parent:GetChildren()+1,
		Size = UDim2.new(1,0,0,54)
	},parent)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,2,0,0),
		Size = UDim2.new(1,-4,0,25),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left
	},box)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,2,0,26),
		Size = UDim2.new(1,-4,0,23),
		Font = Enum.Font.Gotham,
		Text = subtitle,
		TextColor3 = Muted,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left
	},box)

	return box
end

local function actionButton(parent, label, callback, color)
	local button = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = color or Surface2,
		BorderSizePixel = 0,
		Size = UDim2.new(1,0,0,44),
		Text = label,
		TextColor3 = Text,
		TextSize = 12,
		Font = Enum.Font.GothamMedium
	},parent)
	corner(button,12)
	stroke(button,color or Surface3,0.25,1)

	track(button.Activated:Connect(callback))

	track(button.MouseEnter:Connect(function()
		tween(button,TweenInfo.new(0.12),{
			BackgroundColor3 = (color or Surface2):Lerp(Color3.new(1,1,1),0.07)
		})
	end))
	track(button.MouseLeave:Connect(function()
		tween(button,TweenInfo.new(0.12),{
			BackgroundColor3 = color or Surface2
		})
	end))

	return button
end

local function addInfoCard(parent, title, body, order)
	local card = new("Frame",{
		BackgroundColor3 = Surface,
		BorderSizePixel = 0,
		LayoutOrder = order or 1,
		Size = UDim2.new(1,0,0,76)
	},parent)
	corner(card,14)
	stroke(card,Surface3,0,1)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,15,0,10),
		Size = UDim2.new(1,-30,0,20),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,15,0,31),
		Size = UDim2.new(1,-30,0,34),
		Font = Enum.Font.Gotham,
		Text = body,
		TextColor3 = Muted,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top
	},card)

	return card
end

-- =========================================================
-- Sound catalog
-- =========================================================

-- IDs below are sourced from current 2026 Roblox ID lists/pages.
-- Availability can still vary by experience/audio permissions.
local SoundCatalog = {
	{group="Current",name="Brainrot Skibidi Sigma 67",id="133664122932845",kind="meme"},
	{group="Current",name="Memento Mori",id="138649427280723",kind="music"},
	{group="Current",name="67 MEME SONG",id="127798544476125",kind="meme"},
	{group="Current",name="OIIA OIIA CAT - Metal",id="115565653791292",kind="meme"},
	{group="Current",name="Silly Cat Vibes",id="137296865428573",kind="music"},
	{group="Current",name="Funny Dance",id="138915681911522",kind="music"},
	{group="Current",name="Rabbit Clock Meme Breakcore",id="140574140684022",kind="music"},
	{group="Meme",name="Mii Channel Music",id="143666548",kind="music"},
	{group="Meme",name="Kitty Cat Dance",id="224845627",kind="music"},
	{group="Meme",name="Ain't Nobody Got Time For Dat",id="130776739",kind="meme"},
	{group="Meme",name="Baka Meme",id="1136862424",kind="meme"},
	{group="Meme",name="Cringey Recorder Song",id="454451340",kind="meme"},
	{group="Meme",name="Deja Oof",id="1444622447",kind="meme"},
	{group="Meme",name="A Barrel Roll",id="130791919",kind="meme"},
	{group="Meme",name="FitnessGram Pacer Test",id="413089817",kind="meme"},
	{group="SFX",name="Vine Boom",id="6308606116",kind="sfx"},
	{group="SFX",name="Vine Boom Alternative",id="5153845714",kind="sfx"},
	{group="SFX",name="Metal Pipe Falling",id="7149255556",kind="sfx"},
	{group="SFX",name="Loud Metal Pipe Drop",id="9106044186",kind="sfx"},
	{group="SFX",name="Short Metal Pipe Impact",id="198221872",kind="sfx"},
	{group="SFX",name="Distant Metal Pipe",id="9121773901",kind="sfx"},
	{group="SFX",name="Reverb Pipe Crash",id="8482784709",kind="sfx"},
	{group="SFX",name="Mine Turtle",id="138112414",kind="sfx"},
	{group="SFX",name="Mayonnaise",id="340688214",kind="sfx"},
	{group="SFX",name="Oof Classic",id="131961136",kind="sfx"},
	{group="SFX",name="Bruh Sound Effect",id="5153845942",kind="sfx"},
	{group="SFX",name="Windows XP Error",id="138167455",kind="sfx"},
	{group="SFX",name="Airhorn",id="131072554",kind="sfx"},
	{group="SFX",name="Sad Trombone",id="141679876",kind="sfx"},
	{group="SFX",name="MLG Airhorn",id="4565899976",kind="sfx"},
	{group="UI",name="Default Click",id="72046313",kind="ui"},
	{group="UI",name="Level Up",id="1837694600",kind="ui"}
}

local function catalogMatches(soundData)
	if SearchText == "" then
		return true
	end
	local q = string.lower(SearchText)
	return string.find(string.lower(soundData.name),q,1,true) ~= nil
		or string.find(soundData.id,q,1,true) ~= nil
		or string.find(string.lower(soundData.group),q,1,true) ~= nil
end

-- =========================================================
-- Audio pipeline
-- =========================================================

local function removeTrackedSound(sound)
	for index, trackedSound in ipairs(ActiveSounds) do
		if trackedSound == sound then
			table.remove(ActiveSounds,index)
			break
		end
	end
end

local function preloadSound(sound)
	if not sound or not sound.Parent then
		return false
	end

	local fetchStatus = nil
	local ok = pcall(function()
		ContentProvider:PreloadAsync({sound},function(_, status)
			fetchStatus = status
		end)
	end)

	if not ok then
		return false
	end

	if sound.IsLoaded then
		return true
	end

	if fetchStatus then
		return tostring(fetchStatus):lower():find("success",1,true) ~= nil
	end

	return false
end

local function PlaySound(id, name, volume, looped)
	local normalized = normalizeId(id)
	if not normalized then
		notify("That is not a valid audio ID.","error")
		return nil
	end

	local numericVolume = tonumber(volume) or CurrentVolume or 1
	numericVolume = math.clamp(numericVolume,0,10)

	local sound = Instance.new("Sound")
	sound.Name = "KATUltraSound_"..normalized
	sound.SoundId = "rbxassetid://"..normalized
	sound.Volume = numericVolume
	sound.Looped = looped == true
	sound.Parent = SoundService

	local loaded = preloadSound(sound)
	if not loaded and not sound.IsLoaded then
		if sound.Parent then sound:Destroy() end
		notify("Audio "..normalized.." failed to load. It may be private, moderated, or unavailable to this experience.","error")
		return nil
	end

	table.insert(ActiveSounds,sound)
	sound:Play()

	if BroadcastRemote and ReplicateSound and ReplicateSound:IsA("RemoteEvent") then
		pcall(function()
			ReplicateSound:FireServer({
				"PlaySound",
				LocalPlayer.Name,
				"rbxassetid://"..normalized,
				{SoundService},
				numericVolume,
				looped == true
			})
		end)
	end

	if not sound.Looped then
		track(sound.Ended:Connect(function()
			removeTrackedSound(sound)
			if sound.Parent then sound:Destroy() end
		end))
	end

	notify((name or "Sound").."  •  "..normalized)
	return sound
end

local function StopAllSounds()
	local stopped = 0
	local seen = {}

	for _,sound in ipairs(ActiveSounds) do
		if sound and sound.Parent and not seen[sound] then
			seen[sound] = true
			pcall(function() sound:Stop() end)
			pcall(function() sound:Destroy() end)
			stopped += 1
		end
	end

	for _,root in ipairs({SoundService,workspace,PlayerGui}) do
		for _,sound in ipairs(root:GetDescendants()) do
			if sound:IsA("Sound") and sound.Playing and not seen[sound] then
				seen[sound] = true
				pcall(function() sound:Stop() end)
				stopped += 1
			end
		end
	end

	table.clear(ActiveSounds)
	notify("Stopped "..tostring(stopped).." active sounds.")
end

local function RefreshSoundHeader()
	local remoteText = (ReplicateSound and ReplicateSound:IsA("RemoteEvent")) and "REMOTE READY" or "LOCAL ONLY"
	HeaderStatus.Text = remoteText
	HeaderStatus.TextColor3 = (remoteText == "REMOTE READY") and Accent or Warning
end

-- =========================================================
-- Sound controls
-- =========================================================

addSectionTitle(SoundsPage,"Soundboard","Search, preview and play audio with a reliable local Sound pipeline.")

local SearchBox = new("TextBox",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	PlaceholderText = "Search sounds or IDs...",
	PlaceholderColor3 = Muted,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Text,
	TextSize = 12,
	Size = UDim2.new(1,0,0,43)
},SoundsPage)
corner(SearchBox,12)
stroke(SearchBox,Surface3,0,1)

local SoundActionRow = new("Frame",{
	BackgroundTransparency = 1,
	Size = UDim2.new(1,0,0,43)
},SoundsPage)

local SoundActionLayout = new("UIListLayout",{
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0,8),
	SortOrder = Enum.SortOrder.LayoutOrder
},SoundActionRow)

local CustomIdBox = new("TextBox",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	PlaceholderText = "Custom ID",
	PlaceholderColor3 = Muted,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Text,
	TextSize = 12,
	Size = UDim2.new(0.46,0,1,0)
},SoundActionRow)
corner(CustomIdBox,12)
stroke(CustomIdBox,Surface3,0,1)

local CustomPlay = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Accent,
	BorderSizePixel = 0,
	Size = UDim2.new(0.25,0,1,0),
	Text = "PLAY",
	TextColor3 = Color3.fromRGB(6,15,12),
	TextSize = 11,
	Font = Enum.Font.GothamBold
},SoundActionRow)
corner(CustomPlay,12)

local StopButton = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Surface2,
	BorderSizePixel = 0,
	Size = UDim2.new(0.25,0,1,0),
	Text = "STOP ALL",
	TextColor3 = Text,
	TextSize = 11,
	Font = Enum.Font.GothamBold
},SoundActionRow)
corner(StopButton,12)
stroke(StopButton,Danger,0.35,1)

track(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	SearchText = SearchBox.Text
	for _,entry in ipairs(SoundCards) do
		if entry.data then
			entry.card.Visible = catalogMatches(entry.data)
		end
	end
end))

track(CustomPlay.Activated:Connect(function()
	local id = normalizeId(CustomIdBox.Text)
	if not id then
		notify("Enter a numeric Roblox audio ID.","warn")
		return
	end
	PlaySound(id,"Custom Sound",CurrentVolume,false)
end))

track(StopButton.Activated:Connect(StopAllSounds))

local CategoryTitle = addSectionTitle(SoundsPage,"Library","Current entries are kept as a small maintained set instead of mystery IDs.")

local function createSoundCard(parent, soundData, order)
	local card = new("Frame",{
		Name = "Sound_"..soundData.id,
		BackgroundColor3 = Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1,0,0,66)
	},parent)
	corner(card,14)
	stroke(card,Surface3,0,1)

	local dotColor = soundData.kind == "sfx" and Warning or soundData.kind == "meme" and Accent2 or Accent
	new("Frame",{
		BackgroundColor3 = dotColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0,12,0,17),
		Size = UDim2.fromOffset(7,32)
	},card)
	corner(card:FindFirstChildOfClass("Frame"),4)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,29,0,9),
		Size = UDim2.new(1,-194,0,22),
		Font = Enum.Font.GothamBold,
		Text = soundData.name,
		TextColor3 = Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,29,0,33),
		Size = UDim2.new(1,-194,0,18),
		Font = Enum.Font.Gotham,
		Text = soundData.group.."  •  "..soundData.id,
		TextColor3 = Muted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	local copy = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Surface2,
		BorderSizePixel = 0,
		Position = UDim2.new(1,-168,0,12),
		Size = UDim2.fromOffset(52,40),
		Text = "COPY",
		TextColor3 = Muted,
		TextSize = 9,
		Font = Enum.Font.GothamBold
	},card)
	corner(copy,10)

	local play = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(1,-108,0,12),
		Size = UDim2.fromOffset(96,40),
		Text = "PLAY",
		TextColor3 = Color3.fromRGB(6,15,12),
		TextSize = 10,
		Font = Enum.Font.GothamBold
	},card)
	corner(play,10)

	track(copy.Activated:Connect(function()
		if setClipboard(soundData.id) then
			notify("Copied "..soundData.id)
		else
			notify("Clipboard API is unavailable in this executor.","warn")
		end
	end))

	track(play.Activated:Connect(function()
		PlaySound(soundData.id,soundData.name,CurrentVolume,false)
	end))

	track(card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			CustomIdBox.Text = soundData.id
		end
	end))

	table.insert(SoundCards,{card=card,data=soundData})
	return card
end

for index,soundData in ipairs(SoundCatalog) do
	createSoundCard(SoundsPage,soundData,index+3)
end

-- =========================================================
-- Music page
-- =========================================================

addSectionTitle(MusicPage,"Music controls","Longer tracks stay separate from the rapid-fire meme/SFX board.")

local MusicInfo = addInfoCard(MusicPage,"Playback","Volume: "..string.format("%.2f",CurrentVolume).."\nActive local sounds: 0",1)

local MusicId = new("TextBox",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	PlaceholderText = "Enter music ID...",
	PlaceholderColor3 = Muted,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Text,
	TextSize = 12,
	Size = UDim2.new(1,0,0,43),
	LayoutOrder = 2
},MusicPage)
corner(MusicId,12)
stroke(MusicId,Surface3,0,1)

local MusicButtons = new("Frame",{
	BackgroundTransparency = 1,
	LayoutOrder = 3,
	Size = UDim2.new(1,0,0,43)
},MusicPage)

new("UIListLayout",{
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0,8),
	SortOrder = Enum.SortOrder.LayoutOrder
},MusicButtons)

local PlayMusic = actionButton(MusicButtons,"PLAY MUSIC",function()
	local id = normalizeId(MusicId.Text)
	if id then
		PlaySound(id,"Custom Music",CurrentVolume,true)
	else
		notify("Enter a numeric music ID.","warn")
	end
end,Accent)

PlayMusic.Size = UDim2.new(0.48,0,1,0)

local StopMusicButton = actionButton(MusicButtons,"STOP ALL MUSIC",StopAllSounds,Surface2)
StopMusicButton.Size = UDim2.new(0.48,0,1,0)

-- =========================================================
-- Tools page
-- =========================================================

addSectionTitle(ToolsPage,"Tools","Utility controls that do not depend on KAT's internal modal UI.")

local DetectCard = addInfoCard(
	ToolsPage,
	"Game detection",
	"GameUI: "..tostring(GameUI ~= nil).."  •  Interface: "..tostring(Interface ~= nil).."\nRemote sound: "..tostring(ReplicateSound ~= nil).."  •  Structure score: "..tostring(structureScore),
	1
)

actionButton(ToolsPage,"REFRESH DETECTION",function()
	GameUI = PlayerGui:FindFirstChild("GameUI")
	HUD = GameUI and GameUI:FindFirstChild("HUD")
	Interface = GameUI and GameUI:FindFirstChild("Interface")
	BottomBar = Interface and Interface:FindFirstChild("BottomBar")
	SideButtons = Interface and Interface:FindFirstChild("SideButtons")
	GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	Misk = GameEvents and GameEvents:FindFirstChild("Misk")
	ReplicateSound = (Misk and Misk:FindFirstChild("ReplicateSound")) or findDescendant(ReplicatedStorage,"ReplicateSound","RemoteEvent")
	DetectCard:FindFirstChildOfClass("TextLabel").Text = "Game detection refreshed"
	local second = DetectCard:GetChildren()[#DetectCard:GetChildren()]
	for _,child in ipairs(DetectCard:GetChildren()) do
		if child:IsA("TextLabel") and child ~= DetectCard:FindFirstChildOfClass("TextLabel") then
			child.Text = "GameUI: "..tostring(GameUI ~= nil).."  •  Interface: "..tostring(Interface ~= nil).."\nRemote sound: "..tostring(ReplicateSound ~= nil).."  •  PlaceId: "..tostring(game.PlaceId)
		end
	end
	RefreshSoundHeader()
	notify("Detection refreshed.")
end,Surface2)

actionButton(ToolsPage,"SERVER HOP",function()
	local ok, err = pcall(function()
		ServerHop()
	end)
	if not ok then
		notify("Server hop failed: "..tostring(err),"error")
	end
end,Surface2)

actionButton(ToolsPage,"COPY JOB ID",function()
	if setClipboard(game.JobId) then
		notify("JobId copied.")
	else
		notify("Clipboard API is unavailable.","warn")
	end
end,Surface2)

actionButton(ToolsPage,"STOP EVERY SOUND",StopAllSounds,Surface2)

-- =========================================================
-- Settings page
-- =========================================================

addSectionTitle(SettingsPage,"Settings","Audio and interface preferences.")

local VolumeCard = new("Frame",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	Size = UDim2.new(1,0,0,94),
	LayoutOrder = 1
},SettingsPage)
corner(VolumeCard,14)
stroke(VolumeCard,Surface3,0,1)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,10),
	Size = UDim2.new(1,-30,0,20),
	Font = Enum.Font.GothamBold,
	Text = "Master volume",
	TextColor3 = Text,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left
},VolumeCard)

local VolumeBox = new("TextBox",{
	BackgroundColor3 = Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(0,15,0,40),
	Size = UDim2.fromOffset(92,38),
	Font = Enum.Font.GothamBold,
	Text = "1.00",
	TextColor3 = Text,
	TextSize = 12
},VolumeCard)
corner(VolumeBox,10)
stroke(VolumeBox,Surface3,0,1)

local VolumeHint = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,118,0,42),
	Size = UDim2.new(1,-133,0,33),
	Font = Enum.Font.Gotham,
	Text = "0 = mute  •  1 = normal  •  10 = loud",
	TextColor3 = Muted,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left
},VolumeCard)

track(VolumeBox.FocusLost:Connect(function()
	local value = tonumber(VolumeBox.Text)
	if value then
		CurrentVolume = math.clamp(value,0,10)
	end
	VolumeBox.Text = string.format("%.2f",CurrentVolume)
	notify("Volume set to "..string.format("%.2f",CurrentVolume))
end))

local RemoteCard = new("Frame",{
	BackgroundColor3 = Surface,
	BorderSizePixel = 0,
	Size = UDim2.new(1,0,0,72),
	LayoutOrder = 2
},SettingsPage)
corner(RemoteCard,14)
stroke(RemoteCard,Surface3,0,1)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,9),
	Size = UDim2.new(1,-100,0,20),
	Font = Enum.Font.GothamBold,
	Text = "Broadcast via detected remote",
	TextColor3 = Text,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left
},RemoteCard)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,31),
	Size = UDim2.new(1,-95,0,28),
	Font = Enum.Font.Gotham,
	Text = "Local playback is always attempted first. Broadcast is optional.",
	TextColor3 = Muted,
	TextSize = 9,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left
},RemoteCard)

local RemoteToggle
RemoteToggle = actionButton(RemoteCard,"OFF",function()
	if not ReplicateSound or not ReplicateSound:IsA("RemoteEvent") then
		BroadcastRemote = false
		RemoteToggle.Text = "OFF"
		notify("No compatible ReplicateSound RemoteEvent was detected.","warn")
		return
	end
	BroadcastRemote = not BroadcastRemote
	RemoteToggle.Text = BroadcastRemote and "ON" or "OFF"
	RemoteToggle.BackgroundColor3 = BroadcastRemote and Accent or Surface2
	RemoteToggle.TextColor3 = BroadcastRemote and Color3.fromRGB(6,15,12) or Text
	notify(BroadcastRemote and "Remote broadcast enabled." or "Remote broadcast disabled.")
end,Surface2)
RemoteToggle.AnchorPoint = Vector2.new(1,0.5)
RemoteToggle.Position = UDim2.new(1,-13,0.5,0)
RemoteToggle.Size = UDim2.fromOffset(64,34)

local UIScaleCard = addInfoCard(SettingsPage,"Window scale","Use the launcher or Right Control to hide/show KAT Ultra. The interface is built around touch-friendly Activated events.",3)

actionButton(SettingsPage,"CENTER WINDOW",function()
	Main.Position = UDim2.fromScale(0.5,0.5)
	Shadow.Position = Main.Position
	notify("Window centered.")
end,Surface2)

-- =========================================================
-- Diagnostics page
-- =========================================================

addSectionTitle(DiagnosticsPage,"Diagnostics","See exactly what KAT Ultra can detect and what Roblox lets the client load.")

local DiagnosticText = addInfoCard(
	DiagnosticsPage,
	"Runtime status",
	"Version: "..VERSION.."\nPlaceId: "..tostring(game.PlaceId).."\nJobId: "..tostring(game.JobId),
	1
)

local AudioStatusCard = addInfoCard(
	DiagnosticsPage,
	"Audio status",
	"ReplicateSound: "..tostring(ReplicateSound ~= nil).."\nLocal sounds tracked: 0",
	2
)

actionButton(DiagnosticsPage,"TEST MII CHANNEL",function()
	PlaySound("143666548","Mii Channel Music",CurrentVolume,false)
end,Accent)

actionButton(DiagnosticsPage,"TEST VINE BOOM",function()
	PlaySound("6308606116","Vine Boom",CurrentVolume,false)
end,Accent2)

actionButton(DiagnosticsPage,"TEST METAL PIPE",function()
	PlaySound("7149255556","Metal Pipe Falling",CurrentVolume,false)
end,Surface2)

actionButton(DiagnosticsPage,"RUN AUDIO SCAN",function()
	local success = 0
	local failed = 0
	local sampleCount = math.min(#SoundCatalog,10)

	for i = 1,sampleCount do
		local soundData = SoundCatalog[i]
		local id = normalizeId(soundData.id)
		local temp = Instance.new("Sound")
		temp.Name = "KATUltraScan"
		temp.SoundId = "rbxassetid://"..id
		temp.Parent = SoundService

		local loaded = preloadSound(temp)
		if loaded or temp.IsLoaded then
			success += 1
		else
			failed += 1
		end

		temp:Destroy()
		task.wait()
	end

	notify("Audio scan: "..success.." loaded, "..failed.." unavailable.")
end,Surface2)

-- =========================================================
-- Render defaults
-- =========================================================

for _,data in pairs(TabButtons) do
	data.indicator.Visible = false
	data.button.BackgroundColor3 = Surface
	data.label.TextColor3 = Muted
	data.icon.TextColor3 = Muted
end
TabButtons.Sounds.indicator.Visible = true
TabButtons.Sounds.button.BackgroundColor3 = Surface3
TabButtons.Sounds.label.TextColor3 = Text
TabButtons.Sounds.icon.TextColor3 = Accent
SoundsPage.Visible = true

local function updateCounters()
	if AudioStatusCard and AudioStatusCard.Parent then
		for _,child in ipairs(AudioStatusCard:GetChildren()) do
			if child:IsA("TextLabel") and child.Text ~= "" and child.Position.Y.Offset > 20 then
				child.Text = "ReplicateSound: "..tostring(ReplicateSound ~= nil).."\nLocal sounds tracked: "..tostring(#ActiveSounds)
			end
		end
	end
	if MusicInfo and MusicInfo.Parent then
		for _,child in ipairs(MusicInfo:GetChildren()) do
			if child:IsA("TextLabel") and child.Position.Y.Offset > 20 then
				child.Text = "Volume: "..string.format("%.2f",CurrentVolume).."\nActive local sounds: "..tostring(#ActiveSounds)
			end
		end
	end
end

task.spawn(function()
	while Screen.Parent do
		updateCounters()
		RefreshSoundHeader()
		task.wait(1)
	end
end)

-- =========================================================
-- Local bounded stress utility
-- =========================================================

task.spawn(function()
	while Screen.Parent do
		task.wait(0.1)
		if InsanityMode then
			local checksum = 0
			for i = 1,1500 do
				checksum += math.sin(i * 0.01)
			end
			if checksum == math.huge then
				warn("KAT Ultra stress test overflow")
			end
		end
	end
end)

-- =========================================================
-- Persistence helpers
-- =========================================================

local function ensureDataFolders()
	if not hasFileAPI then return false end
	pcall(function()
		if not isfolder("NaikoScript") then
			makefolder("NaikoScript")
		end
		if not isfolder("NaikoScript/KatPlus") then
			makefolder("NaikoScript/KatPlus")
		end
	end)
	return true
end

local function DefaultData(path, value)
	if not ensureDataFolders() then return end
	local full = "NaikoScript/KatPlus/"..path
	if not isfile(full) then
		pcall(writefile,full,tostring(value))
	end
end

local function ChangeData(path, value, withFolder)
	if not hasFileAPI then return end
	local full = withFolder == false and path or "NaikoScript/KatPlus/"..path
	pcall(writefile,full,tostring(value))
end

local function ReturnData(path, withFolder)
	if not hasFileAPI then return nil end
	local full = withFolder == false and path or "NaikoScript/KatPlus/"..path
	if isfile(full) then
		local ok, value = pcall(readfile,full)
		if ok then return value end
	end
	return nil
end

ensureDataFolders()
DefaultData("ToolDelete.txt","Disabled")
DefaultData("Headshot.txt","false")
DefaultData("ServerHop.txt","false")
DefaultData("TargetServer.JobId","None")

-- =========================================================
-- Legacy utility functions
-- =========================================================

function ServerHop()
	local Servers = {}
	local order = "Desc"
	local url = string.format(
		"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&limit=100",
		game.PlaceId,
		order
	)
	local starting = tick()
	local Server = nil

	repeat
		local good, result = pcall(function()
			return game:HttpGet(url)
		end)

		if not good then
			task.wait(2)
			continue
		end

		local decoded = HttpService:JSONDecode(result)
		if decoded and decoded.data and #decoded.data ~= 0 then
			Servers = decoded.data
			for _,v in pairs(Servers) do
				if v.maxPlayers and v.playing and v.maxPlayers - 1 > v.playing and v.id ~= game.JobId then
					Server = v
					break
				end
			end
			if Server then
				break
			end
		end

		if not decoded or not decoded.nextPageCursor then
			break
		end

		url = string.format(
			"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=%s&limit=100&cursor=%s",
			game.PlaceId,
			order,
			decoded.nextPageCursor
		)
	until tick() - starting >= 60

	if not Server or #Servers == 0 then
		return
	end

	local queueTeleport = nil
	pcall(function()
		queueTeleport = syn and syn.queue_on_teleport
	end)
	if not queueTeleport then
		queueTeleport = queue_on_teleport
	end

	if queueTeleport ~= nil then
		pcall(function()
			queueTeleport("loadstring(game:HttpGet(('https://raw.githubusercontent.com/NaikoScript/Kat-Plus/main/Script')))()")
		end)
	end

	ChangeData("TargetServer.JobId",tostring(Server.id),true)
	task.wait()
	TeleportService:TeleportToPlaceInstance(game.PlaceId,Server.id)
end

function RT(Tool)
	if Tool and Tool:FindFirstChild("ClientEvent") then
		Tool:FindFirstChild("ClientEvent"):FireServer("ConfirmDestruction",{})
	end
end

function RPT(Player,ToolType)
	ToolType = ToolType or "All"
	if not Player or not Player.Character then
		return
	end

	for _,v in pairs(Player.Character:GetChildren()) do
		if v:IsA("Tool") then
			if ToolType == "All" and (v.Name == "Knife" or v.Name == "Revolver") then
				RT(v)
			elseif (ToolType == "Gun" or ToolType == "Revolver") and v.Name == "Revolver" then
				RT(v)
			elseif ToolType == "Knife" and v.Name == "Knife" then
				RT(v)
			end
		end
	end

	if Player.Backpack then
		for _,v in pairs(Player.Backpack:GetChildren()) do
			if v:IsA("Tool") then
				if ToolType == "All" and (v.Name == "Knife" or v.Name == "Revolver") then
					RT(v)
				elseif (ToolType == "Gun" or ToolType == "Revolver") and v.Name == "Revolver" then
					RT(v)
				elseif ToolType == "Knife" and v.Name == "Knife" then
					RT(v)
				end
			end
		end
	end
end

function S(ID,instance,Volume,Looped,LocalVolume)
	return PlaySound(ID,"Quick Sound",LocalVolume or Volume or 1,Looped == true)
end

function QS(ID)
	return S(ID,workspace,1,false,1)
end

-- =========================================================
-- Legacy server-disruption routines retained as-is
-- =========================================================

function LR()
	task.spawn(function()
	for i = 1,10000 do
		local Data = {"PlaySound",game.Players.LocalPlayer.Name,"rbxassetid://1843497734",{workspace,workspace,workspace,workspace,workspace,workspace,workspace,workspace},0,true}
		game.ReplicatedStorage.GameEvents.Misk.ReplicateSound:FireServer(Data)
		end
	end)
end

function Raid()
task.spawn(function()
while task.wait(math.random(10,20)) do
notify("Attempting to change servers (from raid)")
ServerHop()
end
end)
task.spawn(function()
for i = 1,250 do
	task.wait(0.05)
	task.spawn(function()
	S(6600188325,workspace,10,true,0.02)
end)
	task.wait()
end
end)
task.spawn(function()
while task.wait(0.03) do
	for i,v in pairs(game.Players:GetPlayers()) do
				RPT(v)
			end
end
end)
end

-- =========================================================
-- Final status
-- =========================================================

RefreshSoundHeader()
task.delay(0.4,function()
	notify("KAT Ultra "..VERSION.." loaded.")
end)

print("[KAT Ultra] UI rebuilt. Local audio pipeline ready.")
print("[KAT Ultra] Structure score:",structureScore)
print("[KAT Ultra] ReplicateSound:",ReplicateSound and ReplicateSound:GetFullName() or "not detected")
