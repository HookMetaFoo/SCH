local actor = nil
for i, act in getactors() do
	if act:FindFirstChild("CoreClient") then
		actor = act
	end
end

run_on_actor(
	actor,
	[[
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local marmotsPath = workspace.Marmots
local DEBUG = false
math.randomseed(os.time())

-- ESP Variables
local espToggle = false
local currentPlayers = {}
local fovCircle
local fov = 100
local showMarmots = false
local showDealers = false
local showDealerships = false
local marmots = {}

-- Aimbot Variables
local isLocked = false
local isAimbotActive = false
local aimbotactive = false
local ptarget = nil
local wallcheck = false
local indicatorToggle = false

-- Silent Aim Type Variables
local keybindSilentAim = true
local autoSilentAim = false

-- Hitchances
local bodyShotChance = 100
local headShotChance = 100

-- RaycastParams
local filter = {}
table.insert(filter,localPlayer.Character)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = filter

-- Utility Functions
local function findFirstChildRecursively(parent, name)
    local child = parent:FindFirstChild(name)
    if child then
        return child
    end
    for _, v in parent:GetChildren() do
        local found = findFirstChildRecursively(v, name)
        if found then
            return found
        end
    end
    return nil
end

-- FOV Circle
fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Filled = false
fovCircle.NumSides = 100
fovCircle.Transparency = 1
fovCircle.Radius = fov
fovCircle.Position = Vector2.new(0,0)
fovCircle.Visible = false

-- ESP Functions
local function createBox(color)
    local box = Drawing.new("Quad")
    box.Visible = false
    box.PointA = Vector2.new(0, 0)
    box.PointB = Vector2.new(0, 0)
    box.PointC = Vector2.new(0, 0)
    box.PointD = Vector2.new(0, 0)
    box.Color = color
    box.Filled = false
    box.Thickness = 2
    box.Transparency = 1
    return box
end

local function createText(color, name)
    local text = Drawing.new("Text")
    text.Text = name
    text.Color = color
    text.Size = 15
    text.Font = Drawing.Fonts.UI
    text.Outlined = false
    text.Centered = true
    text.Visible = false
    text.Position = Vector2.new(0,0)
    return text
end

local dealers = {
    [Vector3.new(-116.526611328125, 190.7767791748047, -2117.9501953125)] = createText(Color3.new(1, 0.843, 0),"Denver (Illegal Guns)"),
    [Vector3.new(-110.91162109375, 202.0384521484375, -2155.40771484375)] = createText(Color3.new(1, 0.843, 0),"Mite (Thermite)"),
    [Vector3.new(816.475830078125, 197.17501831054688, 2814.609130859375)] = createText(Color3.new(1, 0.843, 0),"Kuz (Picklocks)"),
    [Vector3.new(-2031.06787109375, 190.55502319335938, 154.6298065185547)] = createText(Color3.new(1, 0.843, 0),"Yerida (Sell bars)")
}

local dealerships = {

}

local indicator = createText(Color3.new(1, 0.843, 0),"")

local function updateMarmots()
	for _,v in marmotsPath:GetChildren() do
		if marmots[v] then
			continue
		end
		marmots[v] = createText(Color3.new(0, 0, 1),"Marmot")
	end
end

local function updateBoxes(box, distanceY, root2d)
    box.PointA = Vector2.new(root2d.X + distanceY, root2d.Y - distanceY * 2)
    box.PointB = Vector2.new(root2d.X - distanceY, root2d.Y - distanceY * 2)
    box.PointC = Vector2.new(root2d.X - distanceY, root2d.Y + distanceY * 2)
    box.PointD = Vector2.new(root2d.X + distanceY, root2d.Y + distanceY * 2)
    box.Visible = true
end

local function updateLabel(label, distanceY, root2d)
    local scaledOffset = math.clamp(distanceY * 3, 30, 100)
    label.Position = Vector2.new(root2d.X, root2d.Y - scaledOffset)
    label.Visible = true
end

-- Create a table that contains the boxes for each player
local function addPlayer(player)
    if not currentPlayers[player] then
        currentPlayers[player] = {
            box = createBox(player.TeamColor.Color),
            label = createText(player.TeamColor.Color, player.Name),
        }
    else
        currentPlayers[player].box.Color = player.TeamColor.Color
        currentPlayers[player].label.Color = player.TeamColor.Color
    end
end

-- Add each player to the currentPlayers table
for _, v in Players:GetPlayers() do
    if v == localPlayer then
        continue
    end
    v:GetPropertyChangedSignal("Team"):Connect(function()
        addPlayer(v)
    end)
    addPlayer(v)
end

Players.PlayerAdded:Connect(function(player)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        addPlayer(player)
    end)
    addPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    if currentPlayers[player] then
        currentPlayers[player].box:Remove()
        currentPlayers[player].label:Destroy()
        currentPlayers[player] = nil
    end
end)

-- Aimbot Functions
local function getTarget()
    local distance = math.huge
    local target = nil
	local rootPart = nil
	local headPart = nil
    local rootVisible = false
    local headVisible = false
    local player = nil
    local visible = false
    local isGlass = false
    for _, v in Players:GetPlayers() do
        if v.Character and v ~= localPlayer then
            local character = v.Character
            local root = character:FindFirstChild("HumanoidRootPart")
			local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChild("Humanoid")
            if root and humanoid and head and humanoid.Health > 0 then
                local root2d, onscreen = camera:WorldToViewportPoint(root.Position)
                if onscreen then
                    local mouse = UserInputService:GetMouseLocation()
                    local enemydistance = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(root2d.X, root2d.Y)).Magnitude
                    if enemydistance < distance and enemydistance <= fov then
                        target = root2d
                        distance = enemydistance
						rootPart = root
						headPart = head
                        player = v
                    end
                end
            end
        end
    end

    if target and headPart and rootPart then
        table.insert(filter,headPart.Parent)
        raycastParams.FilterDescendantsInstances = filter
        local origin = localPlayer.Character:FindFirstChild("Torso").Position + Vector3.new(0,1.5,0,0)
        local rootRay = workspace:Raycast(origin,rootPart.Position - origin, raycastParams)
        if not rootRay then 
            rootVisible = true 
        elseif rootRay.Instance.Name == "Glass" then
            isGlass = true
        end
        local headRay = workspace:Raycast(origin,headPart.Position - origin,raycastParams)
        if DEBUG and headRay then
            print("RAY HIT WITH THE FOLLOWING PARAMETERS:")
            print("Hit Instance Name:", headRay.Instance.Name)
            print("Hit Position:", headRay.Position)
            print("Surface Normal:", headRay.Normal)
            print("Material:", headRay.Material)
            print()
        end
        if not headRay then 
            headVisible = true 
        elseif headRay.Instance.Name == "Glass" then
            isGlass = true
        end
    end
    if indicatorToggle and indicator and player then
        indicator.Text = "DETECTED: "..player.Name .. "\nHEAD VISIBLE: " .. tostring(headVisible) .. "\nROOT VISIBLE: " .. tostring(headVisible)
        indicator.Visible = true
    end
    return target, rootPart, headPart, rootVisible, headVisible, isGlass, rootRay, headRay
end

local raycastFunction = nil
for i, v in getgc(true) do
    if type(v) == "table" and rawget(v, "Raycast") then
        raycastFunction = rawget(v, "Raycast")
    end
end

local old
old = hookfunction(raycastFunction, newcclosure(function(inst, origin, dest, params, limit, ...)

    local function chance(percentage)
        return math.random(1, 100) <= percentage
    end

    if ptarget then
		local rootPart, headPart, bodyShotChance, headShotChance, wallcheck, rootVisible, headVisible,isGlass,rootRay,headRay = unpack(ptarget)
        if isGlass then
            if rootRay then
                return rootRay.Instance, rootRay.Position, rootRay.Normal, rootRay.Material
            end
            if headRay then
                return headRay.Instance, headRay.Position, headRay.Normal, headRay.Material
            end
        end
		local fakeInstance = nil
		local fakePosition = nil
		if chance(bodyShotChance) then
			fakeInstance = rootPart
        	fakePosition = rootPart.Position
		elseif chance(headShotChance) then
			fakeInstance = headPart
        	fakePosition = headPart.Position
		else
			return old(inst, origin, dest, params, limit, ...)
		end
        local fakeNormal = Vector3.new(0, 1, 0) 
        local fakeMaterial = nil
        if wallcheck then
            if fakeInstance == rootPart and not rootVisible then
                return old(inst, origin, dest, params, limit, ...)
            elseif fakeInstance == headPart and not headVisible then
                return old(inst, origin, dest, params, limit, ...)
            end
        end
        return fakeInstance, fakePosition, fakeNormal, fakeMaterial
    end
    return old(inst, origin, dest, params, limit, ...)
end))

RunService.RenderStepped:Connect(function()
    if indicatorToggle then
        local mousePos = UserInputService:GetMouseLocation()
        indicator.Position = Vector2.new(mousePos.X,mousePos.Y + 15)
    end
    if espToggle then
	    fovCircle.Position = UserInputService:GetMouseLocation()
        if not fovCircle.Visible then fovCircle.Visible = true end
	    if showMarmots then
		    updateMarmots()
		    for marmot,text in marmots do
			    local touchPart = marmot:FindFirstChild("TouchPart")
			    if touchPart then
				    local pos2d, onscreen = camera:WorldToViewportPoint(touchPart.CFrame.Position)
				    if pos2d and onscreen then
					    text.Position = Vector2.new(pos2d.X,pos2d.Y)
					    text.Visible = true
				    else
					    text.Visible = false
			        end
                else
                    text.Visible = false
			    end
		    end
	    end
        if showDealers then
            for pos,text in dealers do
                local pos2d, onscreen = camera:WorldToViewportPoint(pos)
                if pos2d and onscreen then
                    text.Position = Vector2.new(pos2d.X,pos2d.Y)
                    text.Visible = true
                else
                    text.Visible = false
                end
            end
        end
        if showDealerships then
            for pos,text in dealerships do
                local pos2d, onscreen = camera:WorldToViewportPoint(pos)
                if pos2d and onscreen then
                    text.Position = Vector2.new(pos2d.X,pos2d.Y)
                    text.Visible = true
                else
                    text.Visible = false
                end
            end
        end
        for player, data in currentPlayers do
            if player and player.Character then
                local character = player.Character
                local root = character:FindFirstChild("HumanoidRootPart")
                local head = character:FindFirstChild("Head")
                if root and head then
                    local root2d, onscreen = camera:WorldToViewportPoint(root.Position)
                    if onscreen and root2d.Z > 0 then
                        local head2d = camera:WorldToViewportPoint(head.Position)
                        local distanceY = math.clamp(
                            (Vector2.new(head2d.X, head2d.Y) - Vector2.new(root2d.X, root2d.Y)).Magnitude,
                            2,
                            math.huge
                            )
                            updateBoxes(data.box, distanceY, root2d)
                            updateLabel(data.label, distanceY, root2d)
                    else
                        data.box.Visible = false
                        data.label.Visible = false
                    end
                else
                    data.box.Visible = false
                    data.label.Visible = false
                end
            else
                data.box.Visible = false
                data.label.Visible = false
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if isAimbotActive or autoSilentAim then
        local target,rootPart,headPart,rootVisible,headVisible,isGlass,rootRay,headRay = getTarget()
        isLocked = true
        if target and rootPart and headPart then
	        ptarget = {rootPart,headPart,bodyShotChance,headShotChance, wallcheck,rootVisible,headVisible,isGlass,rootRay,headRay}
        else
            ptarget = nil
            indicator.Visible = false
        end
    end
end)

-- GUI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Clark County Client",
    Icon = 0,
    LoadingTitle = "Clark County Client",
    LoadingSubtitle = "Made by Lemont",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
})

-- Tabs
local Tab1 = Window:CreateTab("Aim", "rewind")
local Tab2 = Window:CreateTab("ESP", "rewind")
local Tab3 = Window:CreateTab("Aim Custom Rules", "rewind")
local Tab4 = Window:CreateTab("Keybinds", "rewind")

-- Aimbot Toggle
local Toggle = Tab1:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = false,
    Flag = "Aimbot1",
    Callback = function(Value)
        aimbotactive = Value
    end,
})

-- Bodyshot Chance
local Slider = Tab1:CreateSlider({
	Name = "Bodyshot Chance",
	Range = {0, 100},
	Increment = 1,
	Suffix = "%",
	CurrentValue = 100,
	Flag = "Slider1",
	Callback = function(Value)
		bodyShotChance = Value
	end,
})

-- Headshot Chance
local Slider = Tab1:CreateSlider({
	Name = "Headshot Chance",
	Range = {0, 100},
	Increment = 1,
	Suffix = "%",
	CurrentValue = 100,
	Flag = "Slider2",
	Callback = function(Value)
		headShotChance = Value
	end,
})

-- Wallcheck Toggle
local Toggle = Tab1:CreateToggle({
    Name = "Wallcheck",
    CurrentValue = false,
    Flag = "Wallcheck1",
    Callback = function(Value)
        wallcheck = Value
    end,
})

-- Silent Aim Type
local Dropdown = Tab1:CreateDropdown({
   Name = "Silent Aim Type",
   Options = {"Keybind","Auto"},
   CurrentOption = {"Keybind"},
   MultipleOptions = false,
   Flag = "Dropdown1", 
   Callback = function(Options)
        if Options[1] == "Keybind" then
            keybindSilentAim = true
            autoSilentAim = false
        else
            autoSilentAim = true
            keybindSilentAim = false
        end
   end,
})

local Toggle = Tab1:CreateToggle({
    Name = "Enable Silent Aim Indicator",
    CurrentValue = false,
    Flag = "Indicator1",
    Callback = function(Value)
        indicatorToggle = Value
    end,
})

-- FOV Size Adjuster
local Slider = Tab1:CreateSlider({
	Name = "FOV",
	Range = {0, 1000},
	Increment = 10,
	Suffix = "",
	CurrentValue = 100,
	Flag = "Slider2",
	Callback = function(Value)
		fovCircle.Radius = Value
		fov = Value
	end,
})

-- ESP Toggle
local Toggle = Tab2:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESP1",
    Callback = function(Value)
        espToggle = Value
        if not Value then
            for i, v in currentPlayers do
                if currentPlayers[i] then
                    currentPlayers[i].box.Visible = false
                    currentPlayers[i].label.Visible = false
                end
            end
            fovCircle.Visible = false
        end
    end,
})

-- Show Marmots Toggle
local Toggle = Tab2:CreateToggle({
    Name = "Show Marmots",
    CurrentValue = false,
    Flag = "ESP2",
    Callback = function(Value)
        showMarmots = Value
        if not Value then
            for marmot,text in marmots do
			    text.Visible = false
		    end
        end
    end,
})

-- Show Dealers Toggle
local Toggle = Tab2:CreateToggle({
    Name = "Show Dealers",
    CurrentValue = false,
    Flag = "ESP3",
    Callback = function(Value)
        showDealerships = Value
        if not Value then
            for _,text in dealerships do
			    text.Visible = false
		    end
        end
    end,
})

-- Show Dealerships Toggle
local Toggle = Tab2:CreateToggle({
    Name = "Show Car Dealerships",
    CurrentValue = false,
    Flag = "ESP3",
    Callback = function(Value)
        showdealerships = Value
        if not Value then
            for _,text in dealers do
			    text.Visible = false
		    end
        end
    end,
})

local Keybind = Tab4:CreateKeybind({
   Name = "Silent Aim Keybind",
   CurrentKeybind = "F",
   HoldToInteract = true,
   Flag = "Keybind1", 
   Callback = function(Keybind)
        if Keybind and aimbotactive then
            isAimbotActive = true
        elseif aimbotactive then
            isAimbotActive = false
            isLocked = false
            ptarget = nil
            if indicatorToggle then indicator.Visible = false end 
        end
   end,
})

]]
)
