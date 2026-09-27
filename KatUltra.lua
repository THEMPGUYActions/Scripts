-- KAT Ultra 5.0
-- Small, standalone Roblox UI for sounds and client tools.
-- The stress control stays client-side.

repeat task.wait() until game:IsLoaded()
task.wait(1)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui",20)
if not PlayerGui then return end

local function findDescendant(root,name,className)
	if not root then return nil end
	local direct = root:FindFirstChild(name)
	if direct and (not className or direct:IsA(className)) then return direct end
	for _,obj in ipairs(root:GetDescendants()) do
		if obj.Name == name and (not className or obj:IsA(className)) then
			return obj
		end
	end
	return nil
end

local GameUI = PlayerGui:FindFirstChild("GameUI")
local HUD = GameUI and GameUI:FindFirstChild("HUD")
local Interface = GameUI and GameUI:FindFirstChild("Interface")
local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
local Misk = GameEvents and GameEvents:FindFirstChild("Misk")
local ReplicateSound = Misk and Misk:FindFirstChild("ReplicateSound")
if not ReplicateSound then
	ReplicateSound = findDescendant(ReplicatedStorage,"ReplicateSound","RemoteEvent")
end

if CoreGui:FindFirstChild("KATUltra") or CoreGui:FindFirstChild("KATUltraUI") then
	return warn("KAT Ultra is already running")
end

local marker = Instance.new("BoolValue")
marker.Name = "KATUltra"
marker.Value = true
marker.Parent = CoreGui

local VERSION = "5.0"

local C = {
	bg = Color3.fromRGB(8,10,13),
	surface = Color3.fromRGB(14,17,22),
	surface2 = Color3.fromRGB(20,24,30),
	surface3 = Color3.fromRGB(28,33,40),
	border = Color3.fromRGB(46,55,66),
	text = Color3.fromRGB(242,246,249),
	muted = Color3.fromRGB(142,153,165),
	accent = Color3.fromRGB(89,255,184),
	accent2 = Color3.fromRGB(111,145,255),
	warn = Color3.fromRGB(255,194,90),
	danger = Color3.fromRGB(255,87,105),
	black = Color3.fromRGB(0,0,0)
}

local state = {
	open = true,
	minimized = false,
	tab = "Sounds",
	volume = 1,
	search = "",
	stress = 0,
	lastSound = nil,
	rebind = nil,
	keybinds = {
		Toggle = Enum.KeyCode.RightControl,
		Stop = Enum.KeyCode.RightShift,
		Search = Enum.KeyCode.F,
		Mute = Enum.KeyCode.M
	}
}

local connections = {}
local tracked = {}
local cards = {}
local keyButtons = {}

local function connect(signal,fn)
	local c = signal:Connect(fn)
	table.insert(connections,c)
	return c
end

local function new(className,props,parent)
	local obj = Instance.new(className)
	for k,v in pairs(props or {}) do obj[k]=v end
	if parent then obj.Parent=parent end
	return obj
end

local function round(obj,r)
	local c=obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius=UDim.new(0,r)
	c.Parent=obj
end

local function border(obj,color,transparency,thickness)
	local s=obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color=color
	s.Transparency=transparency or 0
	s.Thickness=thickness or 1
	s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	s.Parent=obj
end

local function tw(obj,time,props,ease)
	local t=TweenService:Create(obj,TweenInfo.new(time or .18,ease or Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props)
	t:Play()
	return t
end

local function clipboard(value)
	if type(setclipboard)=="function" then
		local ok=pcall(setclipboard,tostring(value))
		return ok
	end
	if type(toclipboard)=="function" then
		local ok=pcall(toclipboard,tostring(value))
		return ok
	end
	return false
end

local function idOf(value)
	return tostring(value or ""):match("%d+")
end

--
-- Root
--

local uiParent=CoreGui
if type(gethui)=="function" then
	local ok,obj=pcall(gethui)
	if ok and obj then uiParent=obj end
end

local screen=new("ScreenGui",{
	Name="KATUltraUI",
	ResetOnSpawn=false,
	IgnoreGuiInset=false,
	DisplayOrder=999999,
	ZIndexBehavior=Enum.ZIndexBehavior.Sibling
},uiParent)

pcall(function()
	screen.ScreenInsets=Enum.ScreenInsets.TopbarSafeInsets
end)

local root=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},screen)

local launcher=new("TextButton",{
	AutoButtonColor=false,
	AnchorPoint=Vector2.new(1,1),
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	Position=UDim2.new(1,-12,1,-12),
	Size=UDim2.fromOffset(52,52),
	Text="K",
	TextColor3=C.accent,
	TextSize=20,
	Font=Enum.Font.GothamBold,
	ZIndex=100
},root)
round(launcher,15)
border(launcher,C.accent,.25,2)

local shade=new("Frame",{
	BackgroundColor3=C.black,
	BackgroundTransparency=.58,
	BorderSizePixel=0,
	Size=UDim2.fromScale(1,1),
	Visible=false,
	ZIndex=1
},root)

local shadow=new("Frame",{
	AnchorPoint=Vector2.new(.5,.5),
	BackgroundColor3=C.black,
	BackgroundTransparency=.44,
	BorderSizePixel=0,
	Position=UDim2.fromScale(.5,.51),
	Size=UDim2.new(.78,0,.8,0),
	ZIndex=2
},root)
round(shadow,20)

local main=new("Frame",{
	Active=true,
	AnchorPoint=Vector2.new(.5,.5),
	BackgroundColor3=C.bg,
	BorderSizePixel=0,
	ClipsDescendants=true,
	Position=UDim2.fromScale(.5,.5),
	Size=UDim2.new(.78,0,.8,0),
	ZIndex=3
},root)
round(main,20)
border(main,C.accent,.5,1.5)
local scale=new("UIScale",{Scale=.94},main)
tw(scale,.45,{Scale=1},Enum.EasingStyle.Back)

local mobileBar=new("Frame",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	Position=UDim2.new(0,7,0,7),
	Size=UDim2.new(1,-14,0,46),
	Visible=UserInputService.TouchEnabled,
	ZIndex=90
},root)
round(mobileBar,13)
border(mobileBar,C.border,0,1)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,13,0,0),
	Size=UDim2.new(1,-115,1,0),
	Font=Enum.Font.GothamBold,
	Text="KAT ULTRA",
	TextColor3=C.text,
	TextSize=15,
	TextXAlignment=Enum.TextXAlignment.Left
},mobileBar)

local mobileMin=new("TextButton",{
	AutoButtonColor=false,
	BackgroundColor3=C.surface2,
	BorderSizePixel=0,
	Position=UDim2.new(1,-92,0,6),
	Size=UDim2.fromOffset(36,34),
	Text="-",
	TextColor3=C.text,
	TextSize=18,
	Font=Enum.Font.GothamBold
},mobileBar)
round(mobileMin,9)

local mobileClose=new("TextButton",{
	AutoButtonColor=false,
	BackgroundColor3=C.surface2,
	BorderSizePixel=0,
	Position=UDim2.new(1,-49,0,6),
	Size=UDim2.fromOffset(36,34),
	Text="X",
	TextColor3=C.danger,
	TextSize=11,
	Font=Enum.Font.GothamBold
},mobileBar)
round(mobileClose,9)

local mobileDragHandle=new("Frame",{
	Active=true,
	BackgroundTransparency=1,
	BorderSizePixel=0,
	Position=UDim2.new(0,0,0,0),
	Size=UDim2.new(1,-98,1,0),
	ZIndex=91
},mobileBar)

local header=new("Frame",{
	Active=true,
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	Size=UDim2.new(1,0,0,63),
	ZIndex=10
},main)

new("Frame",{
	BackgroundColor3=C.accent,
	BorderSizePixel=0,
	Position=UDim2.new(0,14,1,-3),
	Size=UDim2.fromOffset(46,3),
	ZIndex=12
},header)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,15,0,7),
	Size=UDim2.new(1,-170,0,27),
	Font=Enum.Font.GothamBold,
	Text="KAT ULTRA",
	TextColor3=C.text,
	TextSize=21,
	TextXAlignment=Enum.TextXAlignment.Left
},header)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,16,0,34),
	Size=UDim2.new(1,-240,0,19),
	Font=Enum.Font.Gotham,
	Text="Sounds + tools  •  "..VERSION,
	TextColor3=C.muted,
	TextSize=10,
	TextXAlignment=Enum.TextXAlignment.Left
},header)

local device=new("TextLabel",{
	BackgroundTransparency=1,
	AnchorPoint=Vector2.new(1,0),
	Position=UDim2.new(1,-95,0,21),
	Size=UDim2.fromOffset(90,19),
	Font=Enum.Font.GothamBold,
	Text=UserInputService.TouchEnabled and "TOUCH" or "DESKTOP",
	TextColor3=C.accent,
	TextSize=9,
	TextXAlignment=Enum.TextXAlignment.Right
},header)

local minus=new("TextButton",{
	AutoButtonColor=false,
	BackgroundColor3=C.surface2,
	BorderSizePixel=0,
	Position=UDim2.new(1,-84,0,15),
	Size=UDim2.fromOffset(31,31),
	Text="-",
	TextColor3=C.text,
	TextSize=16,
	Font=Enum.Font.GothamBold
},header)
round(minus,9)

local close=new("TextButton",{
	AutoButtonColor=false,
	BackgroundColor3=C.surface2,
	BorderSizePixel=0,
	Position=UDim2.new(1,-47,0,15),
	Size=UDim2.fromOffset(31,31),
	Text="X",
	TextColor3=C.danger,
	TextSize=10,
	Font=Enum.Font.GothamBold
},header)
round(close,9)

local dragHandle=new("Frame",{
	Active=true,
	BackgroundTransparency=1,
	BorderSizePixel=0,
	Position=UDim2.new(0,0,0,0),
	Size=UDim2.new(1,-88,1,0),
	ZIndex=11
},header)

local body=new("Frame",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,0,0,63),
	Size=UDim2.new(1,0,1,-63)
},main)

local sidebar=new("Frame",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	Position=UDim2.new(0,9,0,9),
	Size=UDim2.new(0,142,1,-18)
},body)
round(sidebar,15)
border(sidebar,C.border,.08,1)

local sideTitle=new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,14,0,11),
	Size=UDim2.new(1,-28,0,18),
	Font=Enum.Font.GothamBold,
	Text="ULTRA",
	TextColor3=C.accent,
	TextSize=11,
	TextXAlignment=Enum.TextXAlignment.Left
},sidebar)

local tabList=new("Frame",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,7,0,38),
	Size=UDim2.new(1,-14,0,236)
},sidebar)

new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},tabList)

local sideFooter=new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,14,1,-55),
	Size=UDim2.new(1,-28,0,38),
	Font=Enum.Font.Gotham,
	Text="KAT Ultra "..VERSION.."\nTouch + desktop",
	TextColor3=C.muted,
	TextSize=9,
	TextXAlignment=Enum.TextXAlignment.Left,
	TextYAlignment=Enum.TextYAlignment.Bottom
},sidebar)

local pageHolder=new("Frame",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,160,0,9),
	Size=UDim2.new(1,-169,1,-18)
},body)

local tabs={}
local pages={}

local function makePage(name)
	local page=new("ScrollingFrame",{
		Name=name,
		Active=true,
		AutomaticCanvasSize=Enum.AutomaticSize.Y,
		BackgroundTransparency=1,
		BorderSizePixel=0,
		CanvasSize=UDim2.new(),
		ScrollBarImageColor3=C.accent,
		ScrollBarThickness=4,
		ScrollingDirection=Enum.ScrollingDirection.Y,
		Size=UDim2.fromScale(1,1),
		Visible=false
	},pageHolder)
	new("UIPadding",{PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,5)},page)
	new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page)
	pages[name]=page
	return page
end

local function makeTab(name,short,order)
	local b=new("TextButton",{
		AutoButtonColor=false,
		BackgroundColor3=C.surface,
		BorderSizePixel=0,
		LayoutOrder=order,
		Size=UDim2.new(1,0,0,39),
		Text=""
	},tabList)
	round(b,10)

	local mark=new("Frame",{
		BackgroundColor3=C.accent,
		BorderSizePixel=0,
		Position=UDim2.new(0,0,.5,-8),
		Size=UDim2.fromOffset(3,16)
	},b)
	round(mark,3)

	local icon=new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,13,0,0),
		Size=UDim2.fromOffset(22,39),
		Font=Enum.Font.GothamBold,
		Text=short,
		TextColor3=C.muted,
		TextSize=12
	},b)

	local label=new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,40,0,0),
		Size=UDim2.new(1,-45,1,0),
		Font=Enum.Font.GothamMedium,
		Text=name,
		TextColor3=C.muted,
		TextSize=11,
		TextXAlignment=Enum.TextXAlignment.Left
	},b)

	tabs[name]={button=b,mark=mark,icon=icon,label=label}

	connect(b.Activated,function()
		state.tab=name
		for tab,data in pairs(tabs) do
			local active=tab==state.tab
			data.mark.Visible=active
			data.button.BackgroundColor3=active and C.surface3 or C.surface
			data.icon.TextColor3=active and C.accent or C.muted
			data.label.TextColor3=active and C.text or C.muted
		end
		for pageName,page in pairs(pages) do
			page.Visible=pageName==state.tab
		end
	end)
end

makeTab("Sounds","S",1)
makeTab("Music","M",2)
makeTab("Tools","T",3)
makeTab("Settings","G",4)
makeTab("Diagnostics","D",5)

local Sounds=makePage("Sounds")
local Music=makePage("Music")
local Tools=makePage("Tools")
local Settings=makePage("Settings")
local Diagnostics=makePage("Diagnostics")

tabs.Sounds.mark.Visible=true
tabs.Sounds.button.BackgroundColor3=C.surface3
tabs.Sounds.icon.TextColor3=C.accent
tabs.Sounds.label.TextColor3=C.text
Sounds.Visible=true

--
-- Toasts
--

local toastHolder=new("Frame",{
	AnchorPoint=Vector2.new(1,0),
	BackgroundTransparency=1,
	Position=UDim2.new(1,-10,0,10),
	Size=UDim2.fromOffset(300,260),
	ZIndex=200
},root)
new("UIListLayout",{HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,7)},toastHolder)

local function toast(message,kind)
	local color=C.accent
	if kind=="warn" then color=C.warn end
	if kind=="error" then color=C.danger end

	local card=new("Frame",{
		BackgroundColor3=C.surface2,
		BorderSizePixel=0,
		Position=UDim2.new(1,20,0,0),
		Size=UDim2.fromOffset(288,48),
		ZIndex=201
	},toastHolder)
	round(card,12)
	border(card,C.border,0,1)

	local stripe=new("Frame",{
		BackgroundColor3=color,
		BorderSizePixel=0,
		Position=UDim2.new(0,0,0,8),
		Size=UDim2.fromOffset(3,32)
	},card)
	round(stripe,3)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,13,0,0),
		Size=UDim2.new(1,-18,1,0),
		Font=Enum.Font.GothamMedium,
		Text=tostring(message),
		TextColor3=C.text,
		TextSize=11,
		TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left
	},card)

	tw(card,.22,{Position=UDim2.new(0,0,0,0)})
	task.delay(2.6,function()
		if card.Parent then
			tw(card,.2,{Position=UDim2.new(1,20,0,0)})
			task.wait(.22)
			if card.Parent then card:Destroy() end
		end
	end)
end

--
-- Common controls
--

local function section(parent,title,subtitle,order)
	local box=new("Frame",{
		BackgroundTransparency=1,
		LayoutOrder=order or 1,
		Size=UDim2.new(1,0,0,54)
	},parent)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,2,0,0),
		Size=UDim2.new(1,-4,0,23),
		Font=Enum.Font.GothamBold,
		Text=title,
		TextColor3=C.text,
		TextSize=17,
		TextXAlignment=Enum.TextXAlignment.Left
	},box)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,2,0,24),
		Size=UDim2.new(1,-4,0,30),
		Font=Enum.Font.Gotham,
		Text=subtitle,
		TextColor3=C.muted,
		TextSize=9,
		TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top
	},box)
	return box
end

local function button(parent,text,callback,color,order)
	local b=new("TextButton",{
		AutoButtonColor=false,
		BackgroundColor3=color or C.surface2,
		BorderSizePixel=0,
		LayoutOrder=order or 1,
		Size=UDim2.new(1,0,0,43),
		Text=text,
		TextColor3=(color==C.accent) and C.bg or C.text,
		TextSize=10,
		Font=Enum.Font.GothamBold
	},parent)
	round(b,12)
	border(b,C.border,.05,1)
	connect(b.Activated,callback)
	connect(b.MouseEnter,function() tw(b,.1,{BackgroundColor3=(color or C.surface2):Lerp(Color3.new(1,1,1),.06)}) end)
	connect(b.MouseLeave,function() tw(b,.1,{BackgroundColor3=color or C.surface2}) end)
	return b
end

local function card(parent,title,body,height,order)
	local f=new("Frame",{
		BackgroundColor3=C.surface,
		BorderSizePixel=0,
		LayoutOrder=order or 1,
		Size=UDim2.new(1,0,0,height or 76)
	},parent)
	round(f,14)
	border(f,C.border,.08,1)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,14,0,9),
		Size=UDim2.new(1,-28,0,18),
		Font=Enum.Font.GothamBold,
		Text=title,
		TextColor3=C.text,
		TextSize=11,
		TextXAlignment=Enum.TextXAlignment.Left
	},f)

	local bodyLabel=new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,14,0,29),
		Size=UDim2.new(1,-28,1,-35),
		Font=Enum.Font.Gotham,
		Text=body,
		TextColor3=C.muted,
		TextSize=9,
		TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top
	},f)
	return f,bodyLabel
end

--
-- Sound catalog
--

local Catalog={
	{"Meme","Brainrot Skibidi Sigma 67","133664122932845"},
	{"Meme","67 MEME SONG","127798544476125"},
	{"Meme","OIIA OIIA CAT METAL","115565653791292"},
	{"Meme","Bouncy Trap House","140158652733698"},
	{"Meme","Silly Cat Vibes","137296865428573"},
	{"Meme","Funny Dance","138915681911522"},
	{"Meme","Rabbit Clock Breakcore","140574140684022"},
	{"Meme","Six Seven Tribute","131231990268449"},
	{"Meme","Silly Dance Meme XXI","139413640343848"},
	{"Meme","Moye Moye","18315746510"},
	{"Meme","Old Town Road OOFED","18315940082"},
	{"Meme","Never Gonna Give You Up","507443984"},
	{"Meme","Raining Tacos","142376088"},
	{"Meme","Baby Shark","614018503"},
	{"Meme","Banana Song","169360242"},
	{"Meme","Michael Jackson Hee Hee","3048623108"},
	{"Meme","OOF","3060494212"},
	{"Meme","Fart","3068648094"},
	{"Meme","THIS IS SPARTA","130781067"},
	{"Meme","Godzilla Roar","130783046"},
	{"Meme","LEEDLE LEE","130842019"},
	{"Meme","Bonk","130944130"},
	{"Meme","I'm Batman","130769318"},
	{"Meme","Pokérap","152381839"},
	{"Meme","Rush B","474303247"},
	{"SFX","Mine Turtle","138112414"},
	{"SFX","FBI Open Up","2276169441"},
	{"SFX","Elevator Music","9119119619"},
	{"SFX","Better Call Saul Theme","9106904975"},
	{"SFX","I'm in My Mom's Car","170041353"},
	{"SFX","Windows XP Theme","1626996526"},
	{"SFX","Nightmare Music","6991661856"},
	{"Music","Morning Mood","1846088038"},
	{"Music","The Four Seasons - Spring","9045766074"},
	{"Music","Lean On","606299326"},
	{"Music","Thunderstruck","146961487"},
	{"Music","Royals","412314152"},
	{"Music","Sunflower","2698664996"},
	{"Music","Gangnam Style","1293544985"},
	{"Music","Natural","2173344520"}
}

--
-- Audio engine
--

local group=Instance.new("SoundGroup")
group.Name="KATUltraLocal"
group.Volume=state.volume
group.Parent=SoundService

local function waitLoaded(sound,timeout)
	if sound.IsLoaded then return true end
	pcall(function() ContentProvider:PreloadAsync({sound}) end)
	local deadline=os.clock()+(timeout or 7)
	while not sound.IsLoaded and os.clock()<deadline do
		task.wait(.05)
	end
	return sound.IsLoaded
end

local function newSound(id,looped)
	local n=idOf(id)
	if not n then return nil end
	local sound=Instance.new("Sound")
	sound.Name="KATUltra_"..n
	sound.SoundId="rbxassetid://"..n
	sound.Volume=1
	sound.Looped=looped==true
	sound.SoundGroup=group
	sound.Parent=SoundService
	return sound
end

local function forget(sound)
	for i,v in ipairs(tracked) do
		if v==sound then
			table.remove(tracked,i)
			break
		end
	end
end

local function play(id,name,looped)
	local n=idOf(id)
	if not n then
		toast("Invalid audio ID.","error")
		return nil
	end

	local sound=newSound(n,looped)
	if not sound then
		toast("Could not create Sound.","error")
		return nil
	end

	if not waitLoaded(sound,7) then
		if sound.Parent then sound:Destroy() end
		toast("Audio "..n.." did not load. The asset may be restricted, removed or unavailable here.","error")
		return nil
	end

	table.insert(tracked,sound)
	state.lastSound=n
	sound:Play()

	if not sound.Looped then
		connect(sound.Ended,function()
			forget(sound)
			if sound.Parent then sound:Destroy() end
		end)
	end

	toast((name or "Sound").." loaded and played.")
	return sound
end

local function stopAll()
	local seen={}
	local count=0

	for _,sound in ipairs(tracked) do
		if sound and sound.Parent and not seen[sound] then
			seen[sound]=true
			pcall(function() sound:Stop() end)
			pcall(function() sound:Destroy() end)
			count+=1
		end
	end

	for _,rootObj in ipairs({SoundService,workspace,PlayerGui}) do
		for _,sound in ipairs(rootObj:GetDescendants()) do
			if sound:IsA("Sound") and sound.Playing and not seen[sound] then
				seen[sound]=true
				pcall(function() sound:Stop() end)
				count+=1
			end
		end
	end

	table.clear(tracked)
	toast("Stopped "..tostring(count).." local sounds.")
end

local function verify(id)
	local sound=newSound(id,false)
	if not sound then return false end
	local ok=waitLoaded(sound,6)
	if sound.Parent then sound:Destroy() end
	return ok
end

--
-- Sounds page
--

section(Sounds,"Soundboard","Check an asset when it looks unavailable, then play it locally.",1)

local searchBox=new("TextBox",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	ClearTextOnFocus=false,
	PlaceholderText="Search by name, type or ID...",
	PlaceholderColor3=C.muted,
	Font=Enum.Font.Gotham,
	Text="",
	TextColor3=C.text,
	TextSize=11,
	LayoutOrder=2,
	Size=UDim2.new(1,0,0,42)
},Sounds)
round(searchBox,12)
border(searchBox,C.border,0,1)

local custom=new("Frame",{
	BackgroundTransparency=1,
	LayoutOrder=3,
	Size=UDim2.new(1,0,0,42)
},Sounds)

local customId=new("TextBox",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	ClearTextOnFocus=false,
	PlaceholderText="Custom audio ID",
	PlaceholderColor3=C.muted,
	Font=Enum.Font.Gotham,
	Text="",
	TextColor3=C.text,
	TextSize=10,
	Size=UDim2.new(.59,0,1,0)
},custom)
round(customId,12)
border(customId,C.border,0,1)

local customPlay=button(custom,"PLAY",function()
	play(customId.Text,"Custom Sound",false)
end,C.accent,2)
customPlay.Position=UDim2.new(.61,0,0,0)
customPlay.Size=UDim2.new(.18,0,1,0)

local customStop=button(custom,"STOP",stopAll,C.surface2,3)
customStop.Position=UDim2.new(.81,0,0,0)
customStop.Size=UDim2.new(.19,0,1,0)

card(Sounds,"Catalog","CHECK loads the asset on this client. PLAY starts it after a successful load.",62,4)

connect(searchBox:GetPropertyChangedSignal("Text"),function()
	state.search=string.lower(searchBox.Text)
	for _,entry in ipairs(cards) do
		local hay=string.lower(entry.name.." "..entry.kind.." "..entry.id)
		entry.frame.Visible=state.search=="" or string.find(hay,state.search,1,true)~=nil
	end
end)

for index,row in ipairs(Catalog) do
	local kind,name,id=row[1],row[2],row[3]

	local f=new("Frame",{
		BackgroundColor3=C.surface,
		BorderSizePixel=0,
		LayoutOrder=5+index,
		Size=UDim2.new(1,0,0,64)
	},Sounds)
	round(f,13)
	border(f,C.border,.08,1)

	local strip=new("Frame",{
		BackgroundColor3=kind=="SFX" and C.warn or kind=="Music" and C.accent2 or C.accent,
		BorderSizePixel=0,
		Position=UDim2.new(0,10,0,12),
		Size=UDim2.fromOffset(4,40)
	},f)
	round(strip,3)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,23,0,8),
		Size=UDim2.new(1,-220,0,20),
		Font=Enum.Font.GothamBold,
		Text=name,
		TextColor3=C.text,
		TextSize=10,
		TextXAlignment=Enum.TextXAlignment.Left
	},f)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,23,0,31),
		Size=UDim2.new(1,-220,0,18),
		Font=Enum.Font.Gotham,
		Text=kind.."  •  "..id,
		TextColor3=C.muted,
		TextSize=8,
		TextXAlignment=Enum.TextXAlignment.Left
	},f)

	local status=new("TextLabel",{
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(1,.5),
		Position=UDim2.new(1,-175,.5,0),
		Size=UDim2.fromOffset(33,18),
		Font=Enum.Font.GothamBold,
		Text="--",
		TextColor3=C.muted,
		TextSize=8,
		TextXAlignment=Enum.TextXAlignment.Right
	},f)

	local check=button(f,"CHECK",function()
		status.Text="..."
		status.TextColor3=C.warn
		task.spawn(function()
			local ok=verify(id)
			status.Text=ok and "OK" or "NO"
			status.TextColor3=ok and C.accent or C.danger
			toast(name..(ok and " loaded successfully." or " failed the live check."),ok and nil or "warn")
		end)
	end,C.surface2,10+index)
	check.AnchorPoint=Vector2.new(1,0)
	check.Position=UDim2.new(1,-127,0,12)
	check.Size=UDim2.fromOffset(52,40)

	local playButton=button(f,"PLAY",function()
		play(id,name,false)
	end,C.accent,11+index)
	playButton.AnchorPoint=Vector2.new(1,0)
	playButton.Position=UDim2.new(1,-66,0,12)
	playButton.Size=UDim2.fromOffset(58,40)

	connect(f.InputBegan,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			customId.Text=id
		end
	end)

	table.insert(cards,{frame=f,name=name,kind=kind,id=id})
end

--
-- Music page
--

section(Music,"Music","Loop tracks here. Playback uses the same load check as the soundboard.",1)

local musicId=new("TextBox",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	ClearTextOnFocus=false,
	PlaceholderText="Music ID",
	PlaceholderColor3=C.muted,
	Font=Enum.Font.Gotham,
	Text="",
	TextColor3=C.text,
	TextSize=10,
	LayoutOrder=2,
	Size=UDim2.new(1,0,0,42)
},Music)
round(musicId,12)
border(musicId,C.border,0,1)

button(Music,"PLAY LOOPING",function()
	play(musicId.Text,"Looping Music",true)
end,C.accent,3)

button(Music,"STOP ALL MUSIC",stopAll,C.surface2,4)

local _,musicBody=card(Music,"Playback","Volume: 1.00\nActive KAT sounds: 0",70,5)

--
-- Tools page
--

section(Tools,"Tools","Server hop, audio controls, and a small client stress test.",1)

local _,toolStatus=card(
	Tools,
	"Game hooks",
	"GameUI: "..tostring(GameUI~=nil).."\nInterface: "..tostring(Interface~=nil).."\nSound hook: "..tostring(ReplicateSound~=nil),
	86,
	2
)

button(Tools,"REFRESH DETECTION",function()
	GameUI=PlayerGui:FindFirstChild("GameUI")
	HUD=GameUI and GameUI:FindFirstChild("HUD")
	Interface=GameUI and GameUI:FindFirstChild("Interface")
	GameEvents=ReplicatedStorage:FindFirstChild("GameEvents")
	Misk=GameEvents and GameEvents:FindFirstChild("Misk")
	ReplicateSound=(Misk and Misk:FindFirstChild("ReplicateSound")) or findDescendant(ReplicatedStorage,"ReplicateSound","RemoteEvent")
	toolStatus.Text="GameUI: "..tostring(GameUI~=nil).."\nInterface: "..tostring(Interface~=nil).."\nAudio integration: "..tostring(ReplicateSound~=nil)
	toast("Detection refreshed.")
end,C.surface2,3)

button(Tools,"SERVER HOP",function()
	local ok,err=pcall(function()
		local order="Desc"
		local cursor=""
		local destination=nil

		for _=1,10 do
			local url="https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder="..order.."&limit=100"
			if cursor~="" then url=url.."&cursor="..HttpService:UrlEncode(cursor) end

			local good,result=pcall(function() return game:HttpGet(url) end)
			if not good then break end

			local decoded=HttpService:JSONDecode(result)
			for _,server in ipairs(decoded.data or {}) do
				if server.id~=game.JobId and server.playing and server.maxPlayers and server.playing<server.maxPlayers then
					destination=server.id
					break
				end
			end
			if destination then break end
			cursor=decoded.nextPageCursor or ""
			if cursor=="" then break end
			task.wait()
		end

		if destination then
			TeleportService:TeleportToPlaceInstance(game.PlaceId,destination)
		else
			toast("No open server was found.","warn")
		end
	end)
	if not ok then toast("Server hop failed: "..tostring(err),"error") end
end,C.surface2,4)

button(Tools,"COPY JOB ID",function()
	if clipboard(game.JobId) then toast("Job ID copied.") else toast("Clipboard API unavailable.","warn") end
end,C.surface2,5)

button(Tools,"STOP LOCAL AUDIO",stopAll,C.surface2,6)

local stressFrame=new("Frame",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	LayoutOrder=7,
	Size=UDim2.new(1,0,0,112)
},Tools)
round(stressFrame,14)
border(stressFrame,C.border,.08,1)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,14,0,10),
	Size=UDim2.new(1,-90,0,18),
	Font=Enum.Font.GothamBold,
	Text="Client stress intensity",
	TextColor3=C.text,
	TextSize=11,
	TextXAlignment=Enum.TextXAlignment.Left
},stressFrame)

local stressValue=new("TextLabel",{
	BackgroundTransparency=1,
	AnchorPoint=Vector2.new(1,0),
	Position=UDim2.new(1,-14,0,10),
	Size=UDim2.fromOffset(65,18),
	Font=Enum.Font.GothamBold,
	Text="0%",
	TextColor3=C.accent,
	TextSize=9,
	TextXAlignment=Enum.TextXAlignment.Right
},stressFrame)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,14,0,30),
	Size=UDim2.new(1,-28,0,25),
	Font=Enum.Font.Gotham,
	Text="This only increases local diagnostic workload. It does not modify server disruption behavior.",
	TextColor3=C.muted,
	TextSize=8,
	TextWrapped=true,
	TextXAlignment=Enum.TextXAlignment.Left
},stressFrame)

local stressBar=new("Frame",{
	BackgroundColor3=C.surface3,
	BorderSizePixel=0,
	Position=UDim2.new(0,14,0,66),
	Size=UDim2.new(1,-28,0,10)
},stressFrame)
round(stressBar,5)

local stressFill=new("Frame",{
	BackgroundColor3=C.accent,
	BorderSizePixel=0,
	Size=UDim2.new(0,0,1,0)
},stressBar)
round(stressFill,5)

local sliding=false
local function setStress(x)
	local width=stressBar.AbsoluteSize.X
	if width<=0 then return end
	local v=math.clamp((x-stressBar.AbsolutePosition.X)/width,0,1)
	state.stress=v
	stressFill.Size=UDim2.new(v,0,1,0)
	stressValue.Text=tostring(math.floor(v*100+.5)).."%"
end

connect(stressBar.InputBegan,function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		sliding=true
		setStress(input.Position.X)
	end
end)

connect(UserInputService.InputChanged,function(input)
	if not sliding then return end
	if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
		setStress(input.Position.X)
	end
end)

connect(UserInputService.InputEnded,function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
		sliding=false
	end
end)

--
-- Settings
--

section(Settings,"Settings","Touch-friendly controls plus editable keyboard shortcuts.",1)

local volumeFrame=new("Frame",{
	BackgroundColor3=C.surface,
	BorderSizePixel=0,
	LayoutOrder=2,
	Size=UDim2.new(1,0,0,104)
},Settings)
round(volumeFrame,14)
border(volumeFrame,C.border,.08,1)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,14,0,10),
	Size=UDim2.new(1,-28,0,18),
	Font=Enum.Font.GothamBold,
	Text="Master volume",
	TextColor3=C.text,
	TextSize=11
},volumeFrame)

local volumeBox=new("TextBox",{
	BackgroundColor3=C.surface2,
	BorderSizePixel=0,
	ClearTextOnFocus=false,
	Position=UDim2.new(0,14,0,36),
	Size=UDim2.fromOffset(92,38),
	Font=Enum.Font.GothamBold,
	Text="1.00",
	TextColor3=C.text,
	TextSize=11
},volumeFrame)
round(volumeBox,10)
border(volumeBox,C.border,0,1)

new("TextLabel",{
	BackgroundTransparency=1,
	Position=UDim2.new(0,118,0,39),
	Size=UDim2.new(1,-132,0,30),
	Font=Enum.Font.Gotham,
	Text="0 mute  •  1 normal  •  10 max",
	TextColor3=C.muted,
	TextSize=9
},volumeFrame)

connect(volumeBox.FocusLost,function()
	local v=tonumber(volumeBox.Text)
	state.volume=math.clamp(v or state.volume,0,10)
	group.Volume=state.volume
	volumeBox.Text=string.format("%.2f",state.volume)
	toast("Volume "..string.format("%.2f",state.volume))
end)

section(Settings,"Keybinds","Tap a key button, then press the new keyboard key.",3)

local bindList={
	{"Toggle","Toggle UI"},
	{"Stop","Stop audio"},
	{"Search","Focus search"},
	{"Mute","Mute / unmute"}
}

for i,item in ipairs(bindList) do
	local key,itemLabel=item[1],item[2]
	local row=new("Frame",{
		BackgroundColor3=C.surface,
		BorderSizePixel=0,
		LayoutOrder=3+i,
		Size=UDim2.new(1,0,0,45)
	},Settings)
	round(row,12)
	border(row,C.border,.08,1)

	new("TextLabel",{
		BackgroundTransparency=1,
		Position=UDim2.new(0,13,0,0),
		Size=UDim2.new(1,-100,1,0),
		Font=Enum.Font.GothamMedium,
		Text=itemLabel,
		TextColor3=C.text,
		TextSize=10,
		TextXAlignment=Enum.TextXAlignment.Left
	},row)

	local keyButton=new("TextButton",{
		AutoButtonColor=false,
		BackgroundColor3=C.surface2,
		BorderSizePixel=0,
		Position=UDim2.new(1,-82,0,7),
		Size=UDim2.fromOffset(69,31),
		Text=state.keybinds[key].Name,
		TextColor3=C.accent,
		TextSize=8,
		Font=Enum.Font.GothamBold
	},row)
	round(keyButton,9)
	border(keyButton,C.border,0,1)
	keyButtons[key]=keyButton

	connect(keyButton.Activated,function()
		state.rebind=key
		keyButton.Text="PRESS KEY"
		keyButton.TextColor3=C.warn
	end)
end

button(Settings,"CENTER WINDOW",function()
	main.Position=UDim2.fromScale(.5,.5)
	shadow.Position=main.Position
	toast("Window centered.")
end,C.surface2,8)

--
-- Diagnostics
--

section(Diagnostics,"Diagnostics","Live values, audio checks and device details.",1)

local _,runtimeBody=card(
	Diagnostics,
	"Runtime",
	"Version: "..VERSION.."\nPlaceId: "..tostring(game.PlaceId).."\nInput: "..(UserInputService.TouchEnabled and "Touch" or "Keyboard / Mouse"),
	80,
	2
)

local _,audioBody=card(
	Diagnostics,
	"Audio",
	"Audio active\nTracked: 0\nGame hook found: "..tostring(ReplicateSound~=nil),
	80,
	3
)

button(Diagnostics,"VERIFY 10 CATALOG ITEMS",function()
	task.spawn(function()
		local okCount,badCount=0,0
		for i=1,math.min(10,#Catalog) do
			if verify(Catalog[i][3]) then okCount+=1 else badCount+=1 end
			task.wait()
		end
		toast("Live check: "..okCount.." OK, "..badCount.." unavailable.",badCount>0 and "warn" or nil)
	end)
end,C.accent,4)

button(Diagnostics,"TEST RICKROLL",function() play("507443984","Never Gonna Give You Up",false) end,C.surface2,5)
button(Diagnostics,"TEST MORNING MOOD",function() play("1846088038","Morning Mood",false) end,C.surface2,6)
button(Diagnostics,"TEST MINE TURTLE",function() play("138112414","Mine Turtle",false) end,C.surface2,7)
button(Diagnostics,"STOP TEST AUDIO",stopAll,C.surface2,8)

-- Window controls

local statePosition=main.Position
local dragging=false
local dragInput=nil
local dragStart=nil
local mainStart=nil
local barStart=nil

local function setOpen(open)
	state.open=open
	if open then
		main.Visible=not state.minimized
		shadow.Visible=not state.minimized
		shade.Visible=true
		mobileBar.Visible=UserInputService.TouchEnabled
		launcher.Visible=false
	else
		main.Visible=false
		shadow.Visible=false
		shade.Visible=false
		mobileBar.Visible=UserInputService.TouchEnabled
		mobileMin.Text="+"
		launcher.Visible=true
	end
end

local function normalWindowSize()
	local viewport=root.AbsoluteSize
	local width
	local height

	if viewport.X < 650 or GuiService.ViewportDisplaySize==Enum.DisplaySize.Small then
		width=math.max(300,math.min(620,viewport.X-30))
		height=math.max(220,math.min(680,viewport.Y-82))
	else
		width=math.min(820,math.max(520,viewport.X*.78))
		height=math.min(720,math.max(360,viewport.Y*.80))
	end

	return UDim2.fromOffset(width,height)
end

local function centerWindow()
	local size=main.AbsoluteSize
	local viewport=root.AbsoluteSize
	if size.X<=0 or size.Y<=0 or viewport.X<=0 or viewport.Y<=0 then return end

	if UserInputService.TouchEnabled then
		local barHeight=mobileBar.AbsoluteSize.Y
		local x=viewport.X*.5
		local y=barHeight+8+size.Y*.5
		main.Position=UDim2.fromOffset(x,y)
	else
		main.Position=UDim2.fromOffset(viewport.X*.5,viewport.Y*.5)
	end
	shadow.Position=main.Position
	statePosition=main.Position
end

local function setMinimized(minimized)
	state.minimized=minimized
	if minimized then
		statePosition=main.Position
		body.Visible=false
		if UserInputService.TouchEnabled then
			main.Visible=false
			shadow.Visible=false
			mobileMin.Text="+"
		else
			main.Visible=true
			shadow.Visible=true
			mobileMin.Text="+"
			tw(main,.18,{Size=UDim2.fromOffset(420,63)})
			tw(shadow,.18,{Size=UDim2.fromOffset(420,63)})
		end
	else
		body.Visible=true
		main.Visible=true
		shadow.Visible=true
		mobileMin.Text="-"
		main.Size=normalWindowSize()
		shadow.Size=main.Size
		main.Position=statePosition
		shadow.Position=statePosition
	end
	layout()
end

local function clampTopLeft(x,y,width,height,extraTop)
	local viewport=root.AbsoluteSize
	local topMin=extraTop or 6
	local left=math.clamp(x,6,math.max(6,viewport.X-width-6))
	local top=math.clamp(y,topMin,math.max(topMin,viewport.Y-height-6))
	return left,top
end

local function beginDrag(input)
	if not state.open or state.minimized then return end
	if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end

	dragging=true
	dragInput=input
	dragStart=input.Position
	mainStart=main.AbsolutePosition
	barStart=mobileBar.AbsolutePosition
end

local function updateDrag(input)
	if not dragging or not dragInput then return end
	if input~=dragInput and input.UserInputType~=Enum.UserInputType.MouseMovement then return end

	local delta=input.Position-dragStart
	if UserInputService.TouchEnabled then
		local barSize=mobileBar.AbsoluteSize
		local barX,barY=clampTopLeft(barStart.X+delta.X,barStart.Y+delta.Y,barSize.X,barSize.Y,2)
		mobileBar.Position=UDim2.fromOffset(barX,barY)

		local mainSize=main.AbsoluteSize
		local mainTop=barY+barSize.Y+7
		local mainX=barX+(barSize.X-mainSize.X)*.5
		local maxX=math.max(6,root.AbsoluteSize.X-mainSize.X-6)
		local maxY=math.max(mainTop,root.AbsoluteSize.Y-mainSize.Y-6)
		mainX=math.clamp(mainX,6,maxX)
		mainTop=math.clamp(mainTop,mainTop,maxY)
		main.Position=UDim2.fromOffset(mainX+mainSize.X*.5,mainTop+mainSize.Y*.5)
		shadow.Position=main.Position
	else
		local mainSize=main.AbsoluteSize
		local x,y=clampTopLeft(mainStart.X+delta.X,mainStart.Y+delta.Y,mainSize.X,mainSize.Y,6)
		main.Position=UDim2.fromOffset(x+mainSize.X*.5,y+mainSize.Y*.5)
		shadow.Position=main.Position
	end
end

local function endDrag(input)
	if dragging and input==dragInput then
		dragging=false
		dragInput=nil
		statePosition=main.Position
	end
end

connect(dragHandle.InputBegan,beginDrag)
connect(mobileDragHandle.InputBegan,beginDrag)
connect(UserInputService.InputChanged,updateDrag)
connect(UserInputService.InputEnded,endDrag)

connect(minus.Activated,function() setMinimized(not state.minimized) end)
connect(mobileMin.Activated,function() setMinimized(not state.minimized) end)
connect(close.Activated,function() setOpen(false) end)
connect(mobileClose.Activated,function() setOpen(false) end)
connect(launcher.Activated,function()
	state.minimized=false
	main.Size=normalWindowSize()
	shadow.Size=main.Size
	mobileBar.Position=UDim2.new(.5,-150,0,7)
	centerWindow()
	setOpen(true)
end)

-- Responsive layout

function layout()
	local viewport=root.AbsoluteSize
	local touch=UserInputService.TouchEnabled
	mobileBar.Visible=touch and state.open

	if touch then
		mobileBar.Size=UDim2.new(1,-14,0,46)
		header.Visible=false
		body.Position=UDim2.new(0,0,0,0)
		body.Size=UDim2.fromScale(1,1)

		if state.open and not state.minimized then
			main.Size=normalWindowSize()
			shadow.Size=main.Size
			local size=main.AbsoluteSize
			local barSize=mobileBar.AbsoluteSize
			if mobileBar.AbsolutePosition.X==0 and mobileBar.AbsolutePosition.Y==0 then
				mobileBar.Position=UDim2.new(.5,-math.min(150,viewport.X*.5-7),0,7)
			end
			local left=math.max(6,mobileBar.AbsolutePosition.X+(barSize.X-size.X)*.5)
			local top=math.max(barSize.Y+7,6)
			main.Position=UDim2.fromOffset(left+size.X*.5,top+size.Y*.5)
			shadow.Position=main.Position
		end

		sidebar.Size=UDim2.new(0,57,1,-18)
		sideTitle.Text="K"
		sideTitle.TextXAlignment=Enum.TextXAlignment.Center
		sideTitle.Position=UDim2.new(0,0,0,11)
		sideTitle.Size=UDim2.new(1,0,0,18)
		sideFooter.Visible=false
		pageHolder.Position=UDim2.new(0,66,0,9)
		pageHolder.Size=UDim2.new(1,-75,1,-18)
		for _,data in pairs(tabs) do
			data.label.Visible=false
			data.icon.Position=UDim2.new(.5,-11,0,0)
			data.icon.Size=UDim2.fromOffset(22,39)
			data.icon.TextXAlignment=Enum.TextXAlignment.Center
		end
	else
		header.Visible=true
		body.Position=UDim2.new(0,0,0,63)
		body.Size=UDim2.new(1,0,1,-63)
		mobileBar.Visible=false
		if state.open and not state.minimized then
			main.Size=normalWindowSize()
			shadow.Size=main.Size
		end
		sidebar.Size=UDim2.new(0,142,1,-18)
		sideTitle.Text="ULTRA"
		sideTitle.TextXAlignment=Enum.TextXAlignment.Left
		sideTitle.Position=UDim2.new(0,14,0,11)
		sideTitle.Size=UDim2.new(1,-28,0,18)
		sideFooter.Visible=true
		pageHolder.Position=UDim2.new(0,160,0,9)
		pageHolder.Size=UDim2.new(1,-169,1,-18)
		for _,data in pairs(tabs) do
			data.label.Visible=true
			data.icon.Position=UDim2.new(0,13,0,0)
			data.icon.Size=UDim2.fromOffset(22,39)
			data.icon.TextXAlignment=Enum.TextXAlignment.Left
		end
	end

	mobileMin.Text=state.minimized and "+" or "-"
end

connect(root:GetPropertyChangedSignal("AbsoluteSize"),function()
	if state.open and not state.minimized then layout() end
end)
connect(GuiService:GetPropertyChangedSignal("ViewportDisplaySize"),function()
	if state.open and not state.minimized then layout() end
end)
connect(UserInputService:GetPropertyChangedSignal("PreferredInput"),function()
	if state.open and not state.minimized then layout() end
end)
layout()
main.Size=normalWindowSize()
shadow.Size=main.Size
centerWindow()
setOpen(true)

--
-- Keybind handling
--

connect(UserInputService.InputBegan,function(input,processed)
	if input.UserInputType~=Enum.UserInputType.Keyboard then return end

	if state.rebind then
		if input.KeyCode~=Enum.KeyCode.Unknown then
			local name=state.rebind
			state.keybinds[name]=input.KeyCode
			if keyButtons[name] then
				keyButtons[name].Text=input.KeyCode.Name
				keyButtons[name].TextColor3=C.accent
			end
			state.rebind=nil
			toast(name.." bound to "..input.KeyCode.Name)
		end
		return
	end

	if processed then return end

	if input.KeyCode==state.keybinds.Toggle then
		setOpen(not state.open)
	elseif input.KeyCode==state.keybinds.Stop then
		stopAll()
	elseif input.KeyCode==state.keybinds.Search then
		searchBox:CaptureFocus()
	elseif input.KeyCode==state.keybinds.Mute then
		state.volume=state.volume>0 and 0 or 1
		group.Volume=state.volume
		volumeBox.Text=string.format("%.2f",state.volume)
		toast(state.volume==0 and "Audio muted." or "Audio unmuted.")
	end
end)

--
-- Live stats / local stress
--

task.spawn(function()
	while screen.Parent do
		local active=0
		for _,sound in ipairs(tracked) do
			if sound and sound.Parent then active+=1 end
		end

		musicBody.Text="Volume: "..string.format("%.2f",state.volume).."\nActive KAT sounds: "..tostring(active)
		audioBody.Text="Audio active\nTracked: "..tostring(active).."\nGame hook found: "..tostring(ReplicateSound~=nil)
		runtimeBody.Text="Version: "..VERSION.."\nPlaceId: "..tostring(game.PlaceId).."\nInput: "..(UserInputService.TouchEnabled and "Touch" or "Keyboard / Mouse")
		task.wait(1)
	end
end)

task.spawn(function()
	while screen.Parent do
		task.wait(.1)
		if state.stress>0 then
			local iterations=math.floor(250+state.stress*2400)
			local total=0
			for i=1,iterations do
				total += math.sin(i*.01)
			end
			if total==math.huge then warn("KAT Ultra stress overflow") end
		end
	end
end)

task.delay(.35,function()
	toast("KAT Ultra "..VERSION.." loaded.")
end)

print("[KAT Ultra] Loaded.")
