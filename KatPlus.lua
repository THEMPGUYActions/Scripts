-- KAT Ultra
-- Full UI rebuild for desktop + mobile.
-- Existing disruption routines are retained at the bottom.
-- The intensity control only affects the local diagnostic stress test.

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
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",20))

if not LocalPlayer or not PlayerGui then
	return warn("KAT Ultra: PlayerGui was not ready")
end

if CoreGui:FindFirstChild("KATUltra") then
	return warn("KAT Ultra is already running")
end

-- =========================================================
-- Live game detection
-- =========================================================

local function findDescendant(root, name, className)
	if not root then return nil end
	local direct = root:FindFirstChild(name)
	if direct and (not className or direct:IsA(className)) then
		return direct
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
local Round = HUD and HUD:FindFirstChild("Round")
local SettingsPane = Interface and Interface:FindFirstChild("SettingsPane")

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

if structureScore < 4 then
	return warn("KAT Ultra: compatible game structure was not detected")
end

local Marker = Instance.new("BoolValue")
Marker.Name = "KATUltra"
Marker.Value = true
Marker.Parent = CoreGui

-- =========================================================
-- Theme / state
-- =========================================================

local VERSION = "4.0"

local Colors = {
	Background = Color3.fromRGB(9,11,14),
	Surface = Color3.fromRGB(15,18,23),
	Surface2 = Color3.fromRGB(21,25,31),
	Surface3 = Color3.fromRGB(28,33,41),
	Border = Color3.fromRGB(49,58,69),
	Text = Color3.fromRGB(242,246,249),
	Muted = Color3.fromRGB(143,153,165),
	Accent = Color3.fromRGB(87,255,184),
	Accent2 = Color3.fromRGB(112,145,255),
	Warn = Color3.fromRGB(255,194,90),
	Danger = Color3.fromRGB(255,86,105),
	Black = Color3.fromRGB(0,0,0)
}

local State = {
	open = true,
	minimized = false,
	tab = "Sounds",
	volume = 1,
	search = "",
	localStress = 0,
	lastSound = nil,
	keybinds = {
		Toggle = Enum.KeyCode.RightControl,
		Stop = Enum.KeyCode.RightShift,
		FocusSearch = Enum.KeyCode.F,
		Mute = Enum.KeyCode.M
	}
}

local TrackedSounds = {}
local CatalogCards = {}
local Connections = {}
local Rebinding = nil

local function connect(signal, callback)
	local c = signal:Connect(callback)
	table.insert(Connections,c)
	return c
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

local function outline(object, color, transparency, thickness)
	local s = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local function animate(object, duration, properties, style, direction)
	local info = TweenInfo.new(
		duration or 0.18,
		style or Enum.EasingStyle.Quart,
		direction or Enum.EasingDirection.Out
	)
	local t = TweenService:Create(object,info,properties)
	t:Play()
	return t
end

local function safeClipboard(value)
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
	return tostring(value or ""):match("%d+")
end

local function destroyTracked(sound)
	for i,v in ipairs(TrackedSounds) do
		if v == sound then
			table.remove(TrackedSounds,i)
			break
		end
	end
end

local function updateSoundCount()
	local count = 0
	for _,sound in ipairs(TrackedSounds) do
		if sound and sound.Parent then
			count += 1
		end
	end
	return count
end

-- =========================================================
-- Root UI
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
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 999999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling
},UIParent)

pcall(function()
	Screen.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
end)

local Root = new("Frame",{
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1,1)
},Screen)

local Backdrop = new("Frame",{
	BackgroundColor3 = Colors.Black,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1,1),
	Visible = false,
	ZIndex = 1
},Root)

local MobileTopBar = new("Frame",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	Position = UDim2.new(0,7,0,7),
	Size = UDim2.new(1,-14,0,48),
	Visible = UserInputService.TouchEnabled,
	ZIndex = 20
},Root)
corner(MobileTopBar,14)
outline(MobileTopBar,Colors.Border,0,1)

local MobileTitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,0,0),
	Size = UDim2.new(1,-120,1,0),
	Font = Enum.Font.GothamBold,
	Text = "KAT ULTRA",
	TextColor3 = Colors.Text,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left
},MobileTopBar)

local MobileMinus = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-96,0,7),
	Size = UDim2.fromOffset(38,34),
	Text = "-",
	TextColor3 = Colors.Text,
	TextSize = 18,
	Font = Enum.Font.GothamBold
},MobileTopBar)
corner(MobileMinus,10)

local MobileClose = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-50,0,7),
	Size = UDim2.fromOffset(38,34),
	Text = "X",
	TextColor3 = Colors.Danger,
	TextSize = 13,
	Font = Enum.Font.GothamBold
},MobileTopBar)
corner(MobileClose,10)

local Shadow = new("Frame",{
	AnchorPoint = Vector2.new(0.5,0.5),
	BackgroundColor3 = Colors.Black,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5,0.51),
	Size = UDim2.new(0.78,0,0.8,0),
	ZIndex = 2
},Root)
corner(Shadow,20)

local Main = new("Frame",{
	Active = true,
	AnchorPoint = Vector2.new(0.5,0.5),
	BackgroundColor3 = Colors.Background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Position = UDim2.fromScale(0.5,0.5),
	Size = UDim2.new(0.78,0,0.8,0),
	ZIndex = 3
},Root)
corner(Main,20)
outline(Main,Colors.Accent,0.5,1.5)

new("UISizeConstraint",{
	MinSize = Vector2.new(300,280),
	MaxSize = Vector2.new(820,760)
},Main)

local WindowScale = new("UIScale",{Scale = 0.92},Main)
animate(WindowScale,0.5,{Scale = 1},Enum.EasingStyle.Back)

local Header = new("Frame",{
	Active = true,
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	Size = UDim2.new(1,0,0,64),
	ZIndex = 10
},Main)

local HeaderAccent = new("Frame",{
	BackgroundColor3 = Colors.Accent,
	BorderSizePixel = 0,
	Position = UDim2.new(0,15,1,-3),
	Size = UDim2.fromOffset(48,3),
	ZIndex = 12
},Header)
corner(HeaderAccent,3)

local HeaderTitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,15,0,7),
	Size = UDim2.new(1,-170,0,28),
	Font = Enum.Font.GothamBold,
	Text = "KAT ULTRA",
	TextColor3 = Colors.Text,
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Left
},Header)

local HeaderSubtitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,16,0,34),
	Size = UDim2.new(1,-250,0,20),
	Font = Enum.Font.Gotham,
	Text = "Audio toolkit  •  touch ready  •  "..VERSION,
	TextColor3 = Colors.Muted,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left
},Header)

local HeaderMode = new("TextLabel",{
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1,0),
	Position = UDim2.new(1,-95,0,21),
	Size = UDim2.fromOffset(100,20),
	Font = Enum.Font.GothamMedium,
	Text = UserInputService.TouchEnabled and "MOBILE" or "DESKTOP",
	TextColor3 = Colors.Accent,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Right
},Header)

local MinusButton = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-85,0,15),
	Size = UDim2.fromOffset(32,32),
	Text = "-",
	TextColor3 = Colors.Text,
	TextSize = 17,
	Font = Enum.Font.GothamBold
},Header)
corner(MinusButton,9)

local CloseButton = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(1,-47,0,15),
	Size = UDim2.fromOffset(32,32),
	Text = "X",
	TextColor3 = Colors.Danger,
	TextSize = 11,
	Font = Enum.Font.GothamBold
},Header)
corner(CloseButton,9)

local Content = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,0,0,64),
	Size = UDim2.new(1,0,1,-64),
	ZIndex = 4
},Main)

local Sidebar = new("Frame",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	Position = UDim2.new(0,9,0,9),
	Size = UDim2.new(0,142,1,-18)
},Content)
corner(Sidebar,15)
outline(Sidebar,Colors.Border,0.25,1)

local SideTitle = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,0,12),
	Size = UDim2.new(1,-28,0,18),
	Font = Enum.Font.GothamBold,
	Text = "ULTRA",
	TextColor3 = Colors.Accent,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left
},Sidebar)

local TabList = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,7,0,40),
	Size = UDim2.new(1,-14,0,230)
},Sidebar)

new("UIListLayout",{
	Padding = UDim.new(0,6),
	SortOrder = Enum.SortOrder.LayoutOrder
},TabList)

local SideFooter = new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,1,-58),
	Size = UDim2.new(1,-28,0,42),
	Font = Enum.Font.Gotham,
	Text = "KAT Ultra "..VERSION.."
Adaptive UI",
	TextColor3 = Colors.Muted,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Bottom
},Sidebar)

local PageHolder = new("Frame",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,160,0,9),
	Size = UDim2.new(1,-169,1,-18)
},Content)

local Tabs = {}
local Pages = {}

local function makeTab(name, icon, order)
	local button = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1,0,0,39),
		Text = "",
		ZIndex = 6
	},TabList)
	corner(button,10)

	local indicator = new("Frame",{
		BackgroundColor3 = Colors.Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0,0,0.5,-8),
		Size = UDim2.fromOffset(3,16)
	},button)
	corner(indicator,3)

	local iconLabel = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,13,0,0),
		Size = UDim2.fromOffset(22,39),
		Font = Enum.Font.GothamBold,
		Text = icon,
		TextColor3 = Colors.Muted,
		TextSize = 13
	},button)

	local textLabel = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,41,0,0),
		Size = UDim2.new(1,-46,1,0),
		Font = Enum.Font.GothamMedium,
		Text = name,
		TextColor3 = Colors.Muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left
	},button)

	Tabs[name] = {button=button, indicator=indicator, icon=iconLabel, label=textLabel}

	connect(button.Activated,function()
		State.tab = name
		for tab,data in pairs(Tabs) do
			local active = tab == State.tab
			data.indicator.Visible = active
			data.button.BackgroundColor3 = active and Colors.Surface3 or Colors.Surface
			data.icon.TextColor3 = active and Colors.Accent or Colors.Muted
			data.label.TextColor3 = active and Colors.Text or Colors.Muted
		end
		for pageName,page in pairs(Pages) do
			page.Visible = pageName == State.tab
		end
	end)
end

makeTab("Sounds","S",1)
makeTab("Music","M",2)
makeTab("Tools","T",3)
makeTab("Settings","G",4)
makeTab("Diagnostics","D",5)

local function makePage(name)
	local page = new("ScrollingFrame",{
		Name = name,
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Colors.Accent,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1,1),
		Visible = false,
		ZIndex = 5
	},PageHolder)
	new("UIListLayout",{
		Padding = UDim.new(0,8),
		SortOrder = Enum.SortOrder.LayoutOrder
	},page)
	new("UIPadding",{
		PaddingBottom = UDim.new(0,10),
		PaddingLeft = UDim.new(0,2),
		PaddingRight = UDim.new(0,5)
	},page)
	Pages[name] = page
	return page
end

local SoundsPage = makePage("Sounds")
local MusicPage = makePage("Music")
local ToolsPage = makePage("Tools")
local SettingsPage = makePage("Settings")
local DiagnosticsPage = makePage("Diagnostics")

Tabs.Sounds.indicator.Visible = true
Tabs.Sounds.button.BackgroundColor3 = Colors.Surface3
Tabs.Sounds.icon.TextColor3 = Colors.Accent
Tabs.Sounds.label.TextColor3 = Colors.Text
SoundsPage.Visible = true

-- =========================================================
-- Toasts
-- =========================================================

local ToastHolder = new("Frame",{
	AnchorPoint = Vector2.new(1,0),
	BackgroundTransparency = 1,
	Position = UDim2.new(1,-10,0,10),
	Size = UDim2.fromOffset(300,260),
	ZIndex = 200
},Root)

new("UIListLayout",{
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0,7),
	SortOrder = Enum.SortOrder.LayoutOrder
},ToastHolder)

local function toast(message, kind)
	local tint = Colors.Accent
	if kind == "warn" then tint = Colors.Warn end
	if kind == "error" then tint = Colors.Danger end

	local card = new("Frame",{
		BackgroundColor3 = Colors.Surface2,
		BorderSizePixel = 0,
		Position = UDim2.new(1,20,0,0),
		Size = UDim2.fromOffset(286,48),
		ZIndex = 201
	},ToastHolder)
	corner(card,12)
	outline(card,Colors.Border,0,1)

	local stripe = new("Frame",{
		BackgroundColor3 = tint,
		BorderSizePixel = 0,
		Position = UDim2.new(0,0,0,8),
		Size = UDim2.fromOffset(3,32)
	},card)
	corner(stripe,3)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,13,0,0),
		Size = UDim2.new(1,-18,1,0),
		Font = Enum.Font.GothamMedium,
		Text = tostring(message),
		TextColor3 = Colors.Text,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	animate(card,0.23,{Position=UDim2.new(0,0,0,0)})
	task.delay(2.8,function()
		if card.Parent then
			animate(card,0.2,{Position=UDim2.new(1,20,0,0)})
			task.wait(0.23)
			if card.Parent then card:Destroy() end
		end
	end)
end

-- =========================================================
-- Common UI helpers
-- =========================================================

local function section(parent, title, subtitle, order)
	local box = new("Frame",{
		BackgroundTransparency = 1,
		LayoutOrder = order or 1,
		Size = UDim2.new(1,0,0,55)
	},parent)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,2,0,0),
		Size = UDim2.new(1,-4,0,24),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = Colors.Text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left
	},box)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,2,0,25),
		Size = UDim2.new(1,-4,0,29),
		Font = Enum.Font.Gotham,
		Text = subtitle,
		TextColor3 = Colors.Muted,
		TextSize = 9,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top
	},box)

	return box
end

local function action(parent, label, callback, color, order)
	local button = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = color or Colors.Surface2,
		BorderSizePixel = 0,
		LayoutOrder = order or 1,
		Size = UDim2.new(1,0,0,43),
		Text = label,
		TextColor3 = (color == Colors.Accent) and Colors.Background or Colors.Text,
		TextSize = 11,
		Font = Enum.Font.GothamBold
	},parent)
	corner(button,12)
	outline(button,Colors.Border,0.05,1)

	connect(button.Activated,callback)
	connect(button.MouseEnter,function()
		animate(button,0.12,{BackgroundColor3=(color or Colors.Surface2):Lerp(Color3.new(1,1,1),0.07)})
	end)
	connect(button.MouseLeave,function()
		animate(button,0.12,{BackgroundColor3=color or Colors.Surface2})
	end)
	return button
end

local function infoCard(parent, title, body, height, order)
	local card = new("Frame",{
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = order or 1,
		Size = UDim2.new(1,0,0,height or 76)
	},parent)
	corner(card,14)
	outline(card,Colors.Border,0.08,1)

	local titleLabel = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,14,0,9),
		Size = UDim2.new(1,-28,0,19),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = Colors.Text,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	local bodyLabel = new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,14,0,29),
		Size = UDim2.new(1,-28,1,-36),
		Font = Enum.Font.Gotham,
		Text = body,
		TextColor3 = Colors.Muted,
		TextSize = 9,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top
	},card)

	return card,titleLabel,bodyLabel
end

-- =========================================================
-- Verified sound catalog
-- =========================================================
-- These are IDs appearing on September 2026 working-code lists.
-- The script still verifies every item locally before calling it playable.

local SoundCatalog = {
	{group="Meme",name="Brainrot Skibidi Sigma 67",id="133664122932845"},
	{group="Meme",name="67 MEME SONG",id="127798544476125"},
	{group="Meme",name="OIIA OIIA CAT METAL",id="115565653791292"},
	{group="Meme",name="Bouncy Trap House",id="140158652733698"},
	{group="Meme",name="Silly Cat Vibes",id="137296865428573"},
	{group="Meme",name="Funny Dance",id="138915681911522"},
	{group="Meme",name="Rabbit Clock Breakcore",id="140574140684022"},
	{group="Meme",name="Six Seven Tribute",id="131231990268449"},
	{group="Meme",name="Silly Dance Meme XXI",id="139413640343848"},
	{group="Meme",name="Moye Moye",id="18315746510"},
	{group="Meme",name="Old Town Road OOFED",id="18315940082"},
	{group="Meme",name="Never Gonna Give You Up",id="507443984"},
	{group="Meme",name="Raining Tacos",id="142376088"},
	{group="Meme",name="Baby Shark",id="614018503"},
	{group="Meme",name="Banana Song",id="169360242"},
	{group="Meme",name="Michael Jackson Hee Hee",id="3048623108"},
	{group="Meme",name="OOF",id="3060494212"},
	{group="Meme",name="Fart",id="3068648094"},
	{group="Meme",name="THIS IS SPARTA",id="130781067"},
	{group="Meme",name="Godzilla Roar",id="130783046"},
	{group="Meme",name="LEEDLE LEE",id="130842019"},
	{group="Meme",name="Bonk",id="130944130"},
	{group="Meme",name="I'm Batman",id="130769318"},
	{group="Meme",name="Pokérap",id="152381839"},
	{group="Meme",name="Rush B",id="474303247"},
	{group="SFX",name="Mine Turtle",id="138112414"},
	{group="SFX",name="FBI Open Up",id="2276169441"},
	{group="SFX",name="Elevator Music",id="9119119619"},
	{group="SFX",name="Better Call Saul Theme",id="9106904975"},
	{group="SFX",name="I'm in My Mom's Car",id="170041353"},
	{group="SFX",name="Windows XP Theme",id="1626996526"},
	{group="SFX",name="Nightmare Music",id="6991661856"},
	{group="Music",name="Morning Mood",id="1846088038"},
	{group="Music",name="The Four Seasons - Spring",id="9045766074"},
	{group="Music",name="Lean On",id="606299326"},
	{group="Music",name="Thunderstruck",id="146961487"},
	{group="Music",name="Royals",id="412314152"},
	{group="Music",name="Sunflower",id="2698664996"},
	{group="Music",name="Gangnam Style",id="1293544985"},
	{group="Music",name="Natural",id="2173344520"}
}

-- =========================================================
-- Audio engine
-- =========================================================

local KATGroup = Instance.new("SoundGroup")
KATGroup.Name = "KATUltraGroup"
KATGroup.Volume = State.volume
KATGroup.Parent = SoundService

local function waitForLoad(sound, timeout)
	local deadline = os.clock() + (timeout or 7)
	if sound.IsLoaded then return true end

	pcall(function()
		ContentProvider:PreloadAsync({sound})
	end)

	while not sound.IsLoaded and os.clock() < deadline do
		task.wait(0.05)
	end

	return sound.IsLoaded
end

local function createLocalSound(id, looped)
	local normalized = normalizeId(id)
	if not normalized then return nil,"Invalid ID" end

	local sound = Instance.new("Sound")
	sound.Name = "KATUltraAudio_"..normalized
	sound.SoundId = "rbxassetid://"..normalized
	sound.Volume = 1
	sound.Looped = looped == true
	sound.SoundGroup = KATGroup
	sound.Parent = SoundService

	return sound
end

local function playLocal(id, displayName, looped)
	local normalized = normalizeId(id)
	if not normalized then
		toast("Enter a numeric Roblox audio ID.","error")
		return nil
	end

	local sound = createLocalSound(normalized,looped)
	if not sound then
		toast("Could not create the audio object.","error")
		return nil
	end

	local loaded = waitForLoad(sound,7)
	if not loaded then
		sound:Destroy()
		toast("Audio "..normalized.." did not load. Roblox may have restricted, removed, or blocked the asset.","error")
		return nil
	end

	sound.Volume = 1
	table.insert(TrackedSounds,sound)
	State.lastSound = normalized
	sound:Play()

	if looped ~= true then
		connect(sound.Ended,function()
			destroyTracked(sound)
			if sound.Parent then sound:Destroy() end
		end)
	end

	toast((displayName or "Sound").." loaded and played.")
	return sound
end

local function stopAllLocal()
	local stopped = 0
	local seen = {}

	for _,sound in ipairs(TrackedSounds) do
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

	table.clear(TrackedSounds)
	toast("Stopped "..tostring(stopped).." local sounds.")
end

local function verifySound(soundData, statusLabel)
	local temp = createLocalSound(soundData.id,false)
	if not temp then
		statusLabel.Text = "BAD"
		statusLabel.TextColor3 = Colors.Danger
		return false
	end

	local loaded = waitForLoad(temp,6)
	if temp.Parent then temp:Destroy() end

	if loaded then
		statusLabel.Text = "OK"
		statusLabel.TextColor3 = Colors.Accent
	else
		statusLabel.Text = "NO"
		statusLabel.TextColor3 = Colors.Danger
	end

	return loaded
end

-- =========================================================
-- Sound page
-- =========================================================

section(SoundsPage,"Soundboard","Search the maintained catalog or paste any audio ID. Each catalog card can self-check.",1)

local SearchBox = new("TextBox",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	PlaceholderText = "Search name, group or ID...",
	PlaceholderColor3 = Colors.Muted,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Colors.Text,
	TextSize = 11,
	Size = UDim2.new(1,0,0,42),
	LayoutOrder = 2
},SoundsPage)
corner(SearchBox,12)
outline(SearchBox,Colors.Border,0,1)

local CustomRow = new("Frame",{
	BackgroundTransparency = 1,
	LayoutOrder = 3,
	Size = UDim2.new(1,0,0,42)
},SoundsPage)

local CustomId = new("TextBox",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	PlaceholderText = "Custom audio ID...",
	PlaceholderColor3 = Colors.Muted,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Colors.Text,
	TextSize = 11,
	Size = UDim2.new(0.58,0,1,0)
},CustomRow)
corner(CustomId,12)
outline(CustomId,Colors.Border,0,1)

local CustomPlay = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Accent,
	BorderSizePixel = 0,
	Position = UDim2.new(0.6,0,0,0),
	Size = UDim2.new(0.19,0,1,0),
	Text = "PLAY",
	TextColor3 = Colors.Background,
	TextSize = 10,
	Font = Enum.Font.GothamBold
},CustomRow)
corner(CustomPlay,12)

local StopAll = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(0.81,0,0,0),
	Size = UDim2.new(0.19,0,1,0),
	Text = "STOP",
	TextColor3 = Colors.Text,
	TextSize = 10,
	Font = Enum.Font.GothamBold
},CustomRow)
corner(StopAll,12)
outline(StopAll,Colors.Danger,0.35,1)

local CatalogHeader = infoCard(SoundsPage,"Catalog","Public IDs from current 2026 code lists. Green OK means this client just loaded the asset; NO means it failed the live check.",62,4)

connect(SearchBox:GetPropertyChangedSignal("Text"),function()
	State.search = string.lower(SearchBox.Text)
	for _,entry in ipairs(CatalogCards) do
		local text = string.lower(entry.name.." "..entry.group.." "..entry.id)
		entry.card.Visible = State.search == "" or string.find(text,State.search,1,true) ~= nil
	end
end)

connect(CustomPlay.Activated,function()
	playLocal(CustomId.Text,"Custom Sound",false)
end)

connect(StopAll.Activated,stopAllLocal)

local function addCatalogCard(soundData, order)
	local card = new("Frame",{
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1,0,0,64)
	},SoundsPage)
	corner(card,13)
	outline(card,Colors.Border,0.08,1)

	local strip = new("Frame",{
		BackgroundColor3 = soundData.group == "SFX" and Colors.Warn or soundData.group == "Music" and Colors.Accent2 or Colors.Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0,10,0,12),
		Size = UDim2.fromOffset(4,40)
	},card)
	corner(strip,3)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,23,0,8),
		Size = UDim2.new(1,-225,0,20),
		Font = Enum.Font.GothamBold,
		Text = soundData.name,
		TextColor3 = Colors.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,23,0,31),
		Size = UDim2.new(1,-225,0,18),
		Font = Enum.Font.Gotham,
		Text = soundData.group.."  •  "..soundData.id,
		TextColor3 = Colors.Muted,
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left
	},card)

	local status = new("TextLabel",{
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1,-176,0.5,0),
		Size = UDim2.fromOffset(34,20),
		Font = Enum.Font.GothamBold,
		Text = "--",
		TextColor3 = Colors.Muted,
		TextSize = 8
	},card)

	local verify = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Surface2,
		BorderSizePixel = 0,
		Position = UDim2.new(1,-135,0,12),
		Size = UDim2.fromOffset(52,40),
		Text = "CHECK",
		TextColor3 = Colors.Muted,
		TextSize = 8,
		Font = Enum.Font.GothamBold
	},card)
	corner(verify,10)

	local play = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Accent,
		BorderSizePixel = 0,
		Position = UDim2.new(1,-76,0,12),
		Size = UDim2.fromOffset(66,40),
		Text = "PLAY",
		TextColor3 = Colors.Background,
		TextSize = 8,
		Font = Enum.Font.GothamBold
	},card)
	corner(play,10)

	connect(verify.Activated,function()
		status.Text = "..."
		status.TextColor3 = Colors.Warn
		task.spawn(function()
			local ok = verifySound(soundData,status)
			toast(soundData.name..(ok and " is available now." or " failed the live audio check."),ok and nil or "warn")
		end)
	end)

	connect(play.Activated,function()
		playLocal(soundData.id,soundData.name,false)
	end)

	connect(card.InputBegan,function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			CustomId.Text = soundData.id
		end
	end)

	table.insert(CatalogCards,{card=card,name=soundData.name,group=soundData.group,id=soundData.id})
end

for index,soundData in ipairs(SoundCatalog) do
	addCatalogCard(soundData,5+index)
end

-- =========================================================
-- Music
-- =========================================================

section(MusicPage,"Music","Loop a track, stop it, or load an ID with the same live validation path.",1)

local MusicInput = new("TextBox",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	PlaceholderText = "Music ID...",
	PlaceholderColor3 = Colors.Muted,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = Colors.Text,
	TextSize = 11,
	Size = UDim2.new(1,0,0,42),
	LayoutOrder = 2
},MusicPage)
corner(MusicInput,12)
outline(MusicInput,Colors.Border,0,1)

action(MusicPage,"PLAY LOOPING MUSIC",function()
	playLocal(MusicInput.Text,"Looping Music",true)
end,Colors.Accent,3)

action(MusicPage,"STOP ALL MUSIC",stopAllLocal,Colors.Surface2,4)

local _,_,musicStatus = infoCard(
	MusicPage,
	"Playback",
	"Volume: "..string.format("%.2f",State.volume).."\nActive KAT sounds: "..tostring(updateSoundCount()),
	70,
	5
)

-- =========================================================
-- Tools
-- =========================================================

section(ToolsPage,"Tools","General utilities kept separate from the audio library.",1)

local _,_,detectStatus = infoCard(
	ToolsPage,
	"Game structure",
	"UI: "..tostring(GameUI ~= nil).."  •  HUD: "..tostring(HUD ~= nil).."\nInterface: "..tostring(Interface ~= nil).."  •  Sound hook: "..tostring(ReplicateSound ~= nil),
	76,
	2
)

action(ToolsPage,"REFRESH GAME DETECTION",function()
	GameUI = PlayerGui:FindFirstChild("GameUI")
	HUD = GameUI and GameUI:FindFirstChild("HUD")
	Interface = GameUI and GameUI:FindFirstChild("Interface")
	BottomBar = Interface and Interface:FindFirstChild("BottomBar")
	SideButtons = Interface and Interface:FindFirstChild("SideButtons")
	GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
	Misk = GameEvents and GameEvents:FindFirstChild("Misk")
	ReplicateSound = (Misk and Misk:FindFirstChild("ReplicateSound")) or findDescendant(ReplicatedStorage,"ReplicateSound","RemoteEvent")
	detectStatus.Text = "UI: "..tostring(GameUI ~= nil).."  •  HUD: "..tostring(HUD ~= nil).."\nInterface: "..tostring(Interface ~= nil).."  •  Sound hook: "..tostring(ReplicateSound ~= nil)
	toast("Game detection refreshed.")
end,Colors.Surface2,3)

action(ToolsPage,"SERVER HOP",function()
	local ok,err = pcall(function()
		ServerHop()
	end)
	if not ok then toast("Server hop failed: "..tostring(err),"error") end
end,Colors.Surface2,4)

action(ToolsPage,"COPY JOB ID",function()
	if safeClipboard(game.JobId) then
		toast("Job ID copied.")
	else
		toast("Clipboard API unavailable.","warn")
	end
end,Colors.Surface2,5)

action(ToolsPage,"STOP ALL LOCAL AUDIO",stopAllLocal,Colors.Surface2,6)

-- This intensity control is intentionally local-only.
local StressCard = new("Frame",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	LayoutOrder = 7,
	Size = UDim2.new(1,0,0,112)
},ToolsPage)
corner(StressCard,14)
outline(StressCard,Colors.Border,0.08,1)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,0,9),
	Size = UDim2.new(1,-28,0,19),
	Font = Enum.Font.GothamBold,
	Text = "Client stress test",
	TextColor3 = Colors.Text,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left
},StressCard)

local StressValue = new("TextLabel",{
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1,0),
	Position = UDim2.new(1,-14,0,9),
	Size = UDim2.fromOffset(62,19),
	Font = Enum.Font.GothamBold,
	Text = "0%",
	TextColor3 = Colors.Accent,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Right
},StressCard)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,0,29),
	Size = UDim2.new(1,-28,0,22),
	Font = Enum.Font.Gotham,
	Text = "Adjusts only the local diagnostic workload. It does not change the existing server-disruption routine.",
	TextColor3 = Colors.Muted,
	TextSize = 8,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left
},StressCard)

local StressBar = new("Frame",{
	BackgroundColor3 = Colors.Surface3,
	BorderSizePixel = 0,
	Position = UDim2.new(0,14,0,64),
	Size = UDim2.new(1,-28,0,10)
},StressCard)
corner(StressBar,5)

local StressFill = new("Frame",{
	BackgroundColor3 = Colors.Accent,
	BorderSizePixel = 0,
	Size = UDim2.new(0,0,1,0)
},StressBar)
corner(StressFill,5)

local StressButton = new("TextButton",{
	Active = true,
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.new(0,-8,0,-9),
	Size = UDim2.new(1,16,1,28),
	Text = ""
},StressBar)

local function updateStressFromX(x)
	local localX = math.clamp(x-StressBar.AbsolutePosition.X,0,StressBar.AbsoluteSize.X)
	local value = StressBar.AbsoluteSize.X > 0 and localX / StressBar.AbsoluteSize.X or 0
	State.localStress = value
	StressFill.Size = UDim2.new(value,0,1,0)
	StressValue.Text = tostring(math.floor(value*100+0.5)).."%"
end

connect(StressButton.Activated,function() end)
connect(StressButton.InputBegan,function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		updateStressFromX(input.Position.X)
	end
end)
connect(UserInputService.InputChanged,function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if StressButton:IsDescendantOf(game) and input.UserInputState == Enum.UserInputState.Change then
			local p = UserInputService:GetMouseLocation()
			if UserInputService:IsMouseButtonPressed and p then
				-- Mouse slider movement is handled by the frame only after press.
			end
		end
	end
end)

-- =========================================================
-- Settings / keybinds
-- =========================================================

section(SettingsPage,"Settings","UI controls, audio volume and editable desktop keybinds.",1)

local VolumeCard = new("Frame",{
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	LayoutOrder = 2,
	Size = UDim2.new(1,0,0,106)
},SettingsPage)
corner(VolumeCard,14)
outline(VolumeCard,Colors.Border,0.08,1)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,14,0,10),
	Size = UDim2.new(1,-28,0,18),
	Font = Enum.Font.GothamBold,
	Text = "Master volume",
	TextColor3 = Colors.Text,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left
},VolumeCard)

local VolumeBox = new("TextBox",{
	BackgroundColor3 = Colors.Surface2,
	BorderSizePixel = 0,
	Position = UDim2.new(0,14,0,37),
	Size = UDim2.fromOffset(90,38),
	ClearTextOnFocus = false,
	Font = Enum.Font.GothamBold,
	Text = "1.00",
	TextColor3 = Colors.Text,
	TextSize = 11
},VolumeCard)
corner(VolumeBox,10)
outline(VolumeBox,Colors.Border,0,1)

new("TextLabel",{
	BackgroundTransparency = 1,
	Position = UDim2.new(0,114,0,39),
	Size = UDim2.new(1,-128,0,34),
	Font = Enum.Font.Gotham,
	Text = "0 = mute   1 = normal   10 = max",
	TextColor3 = Colors.Muted,
	TextSize = 9,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left
},VolumeCard)

connect(VolumeBox.FocusLost,function()
	local v = tonumber(VolumeBox.Text)
	if v then
		State.volume = math.clamp(v,0,10)
	end
	VolumeBox.Text = string.format("%.2f",State.volume)
	KATGroup.Volume = State.volume
	toast("Volume "..string.format("%.2f",State.volume))
end)

local KeybindsHeader = section(SettingsPage,"Keybinds","Click a key to rebind it, then press the new keyboard key.",3)

local KeybindNames = {
	{"Toggle","Toggle UI"},
	{"Stop","Stop all audio"},
	{"FocusSearch","Focus sound search"},
	{"Mute","Mute / unmute"}
}

local KeybindButtons = {}

for index,pair in ipairs(KeybindNames) do
	local keyName = pair[1]
	local label = pair[2]
	local row = new("Frame",{
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		LayoutOrder = 3+index,
		Size = UDim2.new(1,0,0,46)
	},SettingsPage)
	corner(row,12)
	outline(row,Colors.Border,0.08,1)

	new("TextLabel",{
		BackgroundTransparency = 1,
		Position = UDim2.new(0,13,0,0),
		Size = UDim2.new(1,-100,1,0),
		Font = Enum.Font.GothamMedium,
		Text = label,
		TextColor3 = Colors.Text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left
	},row)

	local keyButton = new("TextButton",{
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Surface2,
		BorderSizePixel = 0,
		Position = UDim2.new(1,-82,0,7),
		Size = UDim2.fromOffset(68,32),
		Text = State.keybinds[keyName].Name,
		TextColor3 = Colors.Accent,
		TextSize = 9,
		Font = Enum.Font.GothamBold
	},row)
	corner(keyButton,9)
	outline(keyButton,Colors.Border,0,1)
	KeybindButtons[keyName] = keyButton

	connect(keyButton.Activated,function()
		Rebinding = keyName
		keyButton.Text = "PRESS KEY"
		keyButton.TextColor3 = Colors.Warn
	end)
end

action(SettingsPage,"CENTER WINDOW",function()
	Main.Position = UDim2.fromScale(0.5,0.5)
	Shadow.Position = Main.Position
	toast("Window centered.")
end,Colors.Surface2,9)

-- =========================================================
-- Diagnostics
-- =========================================================

section(DiagnosticsPage,"Diagnostics","Nothing is labelled as ready until the script actually sees it or loads it.",1)

local RuntimeCard,_,RuntimeBody = infoCard(
	DiagnosticsPage,
	"Runtime",
	"Version: "..VERSION.."\nPlaceId: "..tostring(game.PlaceId).."\nDevice: "..(UserInputService.TouchEnabled and "Touch" or "Keyboard / Mouse"),
	78,
	2
)

local AudioCard,_,AudioBody = infoCard(
	DiagnosticsPage,
	"Audio engine",
	"Local Sound pipeline active\nTracked sounds: 0\nDetected game hook: "..tostring(ReplicateSound ~= nil),
	78,
	3
)

action(DiagnosticsPage,"VERIFY FIRST 10 CATALOG SOUNDS",function()
	task.spawn(function()
		local good, bad = 0,0
		for i=1,math.min(10,#SoundCatalog) do
			local temp = createLocalSound(SoundCatalog[i].id,false)
			if temp then
				local ok = waitForLoad(temp,6)
				if ok then good += 1 else bad += 1 end
				temp:Destroy()
			else
				bad += 1
			end
		end
		toast("Live audio check: "..good.." OK, "..bad.." unavailable.")
	end)
end,Colors.Accent,4)

action(DiagnosticsPage,"TEST RICKROLL",function()
	playLocal("507443984","Never Gonna Give You Up",false)
end,Colors.Surface2,5)

action(DiagnosticsPage,"TEST MORNING MOOD",function()
	playLocal("1846088038","Morning Mood",false)
end,Colors.Surface2,6)

action(DiagnosticsPage,"TEST MINE TURTLE",function()
	playLocal("138112414","Mine Turtle",false)
end,Colors.Surface2,7)

action(DiagnosticsPage,"STOP TEST AUDIO",stopAllLocal,Colors.Surface2,8)

-- =========================================================
-- Window controls + drag
-- =========================================================

local function setOpen(open)
	State.open = open
	Backdrop.Visible = open
	Main.Visible = open
	Shadow.Visible = open
	if open then
		animate(WindowScale,0.22,{Scale=1},Enum.EasingStyle.Back)
	end
end

local function setMinimized(minimized)
	State.minimized = minimized
	Content.Visible = not minimized
	Main.ClipsDescendants = true

	if minimized then
		animate(Main,0.22,{Size=UserInputService.TouchEnabled and UDim2.new(1,-14,0,64) or UDim2.new(0.55,0,0,64)})
		animate(Shadow,0.22,{Size=UserInputService.TouchEnabled and UDim2.new(1,-14,0,64) or UDim2.new(0.55,0,0,64)})
	else
		animate(Main,0.22,{Size=UserInputService.TouchEnabled and UDim2.new(1,-14,1,-92) or UDim2.new(0.78,0,0.8,0)})
		animate(Shadow,0.22,{Size=UserInputService.TouchEnabled and UDim2.new(1,-14,1,-92) or UDim2.new(0.78,0,0.8,0)})
	end
end

connect(MinusButton.Activated,function()
	setMinimized(not State.minimized)
end)

connect(MobileMinus.Activated,function()
	setMinimized(not State.minimized)
end)

connect(CloseButton.Activated,function()
	setOpen(false)
end)

connect(MobileClose.Activated,function()
	setOpen(false)
end)

local Launcher = new("TextButton",{
	AutoButtonColor = false,
	BackgroundColor3 = Colors.Surface,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1,1),
	Position = UDim2.new(1,-12,1,-12),
	Size = UDim2.fromOffset(52,52),
	Text = "K",
	TextColor3 = Colors.Accent,
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	ZIndex = 50
},Root)
corner(Launcher,15)
outline(Launcher,Colors.Accent,0.25,1.5)

connect(Launcher.Activated,function()
	setOpen(not State.open)
end)

local dragging = false
local dragStart = nil
local dragOrigin = nil

connect(Header.InputBegan,function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		dragOrigin = Main.Position
		connect(input.Changed,function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

connect(UserInputService.InputChanged,function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = input.Position - dragStart
	Main.Position = UDim2.new(
		dragOrigin.X.Scale,dragOrigin.X.Offset + delta.X,
		dragOrigin.Y.Scale,dragOrigin.Y.Offset + delta.Y
	)
	Shadow.Position = Main.Position
end)

-- =========================================================
-- Mobile / resize handling
-- =========================================================

local function updateLayout()
	local viewport = GuiService.ViewportDisplaySize
	local touch = UserInputService.TouchEnabled
	local verySmall = Main.AbsoluteSize.X < 420

	MobileTopBar.Visible = touch
	Launcher.Size = touch and UDim2.fromOffset(48,48) or UDim2.fromOffset(52,52)

	if touch or viewport == Enum.DisplaySize.Small or verySmall then
		Main.Size = UDim2.new(1,-14,1,-92)
		Shadow.Size = Main.Size
		Sidebar.Size = UDim2.new(0,58,1,-18)
		SideTitle.Text = "K"
		SideTitle.TextXAlignment = Enum.TextXAlignment.Center
		SideTitle.Position = UDim2.new(0,0,0,12)
		SideTitle.Size = UDim2.new(1,0,0,18)
		SideFooter.Visible = false
		PageHolder.Position = UDim2.new(0,67,0,9)
		PageHolder.Size = UDim2.new(1,-76,1,-18)

		for _,data in pairs(Tabs) do
			data.label.Visible = false
			data.icon.Position = UDim2.new(0.5,-11,0,0)
			data.icon.Size = UDim2.fromOffset(22,39)
			data.icon.TextXAlignment = Enum.TextXAlignment.Center
		end
	else
		Main.Size = UDim2.new(0.78,0,0.8,0)
		Shadow.Size = Main.Size
		Sidebar.Size = UDim2.new(0,142,1,-18)
		SideTitle.Text = "ULTRA"
		SideTitle.TextXAlignment = Enum.TextXAlignment.Left
		SideTitle.Position = UDim2.new(0,14,0,12)
		SideTitle.Size = UDim2.new(1,-28,0,18)
		SideFooter.Visible = true
		PageHolder.Position = UDim2.new(0,160,0,9)
		PageHolder.Size = UDim2.new(1,-169,1,-18)

		for _,data in pairs(Tabs) do
			data.label.Visible = true
			data.icon.Position = UDim2.new(0,13,0,0)
			data.icon.Size = UDim2.fromOffset(22,39)
			data.icon.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
end

connect(Main:GetPropertyChangedSignal("AbsoluteSize"),updateLayout)
connect(GuiService:GetPropertyChangedSignal("ViewportDisplaySize"),updateLayout)
connect(UserInputService:GetPropertyChangedSignal("PreferredInput"),updateLayout)
updateLayout()
setOpen(true)

-- =========================================================
-- Keyboard handling
-- =========================================================

connect(UserInputService.InputBegan,function(input,processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	if Rebinding then
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			State.keybinds[Rebinding] = input.KeyCode
			if KeybindButtons[Rebinding] then
				KeybindButtons[Rebinding].Text = input.KeyCode.Name
				KeybindButtons[Rebinding].TextColor3 = Colors.Accent
			end
			toast(Rebinding.." bound to "..input.KeyCode.Name)
			Rebinding = nil
		end
		return
	end

	if processed then return end

	if input.KeyCode == State.keybinds.Toggle then
		setOpen(not State.open)
	elseif input.KeyCode == State.keybinds.Stop then
		stopAllLocal()
	elseif input.KeyCode == State.keybinds.FocusSearch then
		SearchBox:CaptureFocus()
	elseif input.KeyCode == State.keybinds.Mute then
		State.volume = State.volume > 0 and 0 or 1
		KATGroup.Volume = State.volume
		VolumeBox.Text = string.format("%.2f",State.volume)
		toast(State.volume == 0 and "Audio muted." or "Audio unmuted.")
	end
end)

-- =========================================================
-- Live UI stats
-- =========================================================

task.spawn(function()
	while Screen.Parent do
		AudioBody.Text = "Local Sound pipeline active\nTracked sounds: "..tostring(updateSoundCount()).."\nDetected game hook: "..tostring(ReplicateSound ~= nil)
		musicStatus.Text = "Volume: "..string.format("%.2f",State.volume).."\nActive KAT sounds: "..tostring(updateSoundCount())
		RuntimeBody.Text = "Version: "..VERSION.."\nPlaceId: "..tostring(game.PlaceId).."\nDevice: "..(UserInputService.TouchEnabled and "Touch" or "Keyboard / Mouse")
		task.wait(1)
	end
end)

-- =========================================================
-- Local diagnostic stress test
-- =========================================================

task.spawn(function()
	while Screen.Parent do
		task.wait(0.1)
		if State.localStress > 0 then
			local iterations = math.floor(300 + State.localStress * 2200)
			local checksum = 0
			for i=1,iterations do
				checksum += math.sin(i*0.01)
			end
			if checksum == math.huge then
				warn("KAT Ultra local stress overflow")
			end
		end
	end
end)

-- =========================================================
-- Safe persistence
-- =========================================================

local hasFileAPI =
	type(isfile) == "function" and
	type(writefile) == "function" and
	type(isfolder) == "function" and
	type(makefolder) == "function"

local function ensureDataFolders()
	if not hasFileAPI then return end
	pcall(function()
		if not isfolder("NaikoScript") then makefolder("NaikoScript") end
		if not isfolder("NaikoScript/KatPlus") then makefolder("NaikoScript/KatPlus") end
	end)
end

local function saveSetting(path,value)
	if not hasFileAPI then return end
	ensureDataFolders()
	pcall(writefile,"NaikoScript/KatPlus/"..path,tostring(value))
end

local function loadSetting(path)
	if not hasFileAPI then return nil end
	local full = "NaikoScript/KatPlus/"..path
	if not isfile(full) then return nil end
	local ok,value = pcall(readfile,full)
	return ok and value or nil
end

ensureDataFolders()
saveSetting("Version",VERSION)

-- =========================================================
-- Legacy functions retained
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
	if not tonumber(ID) then return end
	if ReplicateSound and ReplicateSound:IsA("RemoteEvent") then
		pcall(function()
			ReplicateSound:FireServer({
				"PlaySound",
				LocalPlayer.Name,
				"rbxassetid://"..tostring(ID),
				{instance},
				tonumber(Volume) or 1,
				Looped == true
			})
		end)
	end
	return PlaySound(ID,"Quick Sound",LocalVolume or Volume or 1,Looped == true)
end



function S(ID,instance,Volume,Looped,LocalVolume)
	if not tonumber(ID) then return end
	if ReplicateSound and ReplicateSound:IsA("RemoteEvent") then
		pcall(function()
			ReplicateSound:FireServer({
				"PlaySound",
				LocalPlayer.Name,
				"rbxassetid://"..tostring(ID),
				{instance},
				tonumber(Volume) or 1,
				Looped == true
			})
		end)
	end
	return PlaySound(ID,"Quick Sound",LocalVolume or Volume or 1,Looped == true)
end



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

