-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local screenDimensions = camera.ViewportSize

-- ESP Variables
local espConnection = nil
local currentPlayers = {}
local fovCircle
local fov = 100

-- Aimbot Variables
local aimbotConnection = nil
local isAimbotActive = false
local aimbotactive = false
local smoothness = 1

-- HBE Variables
local hbeActive = false

-- Paths
--local tanks = workspace:WaitForChild("Vehicles").Tanks

-- Optimization Variables
local lastUpdate = 0
local lastUpdateInterval = 0.1
local cachedTarget = nil

fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Filled = false
fovCircle.NumSides = 100
fovCircle.Transparency = 1
fovCircle.Radius = fov
fovCircle.Position = Vector2.new(screenDimensions.X / 2, screenDimensions.Y / 2)
fovCircle.Visible = true

local function findFirstChildRecursively(parent,name)
	local child = parent:FindFirstChild(name) 
	if child then
		return child		
	end

	for _,v in parent:GetChildren() do
		local found = findFirstChildRecursively(parent, name)
		if found then
			return found
		end
	end

	return nil
end

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
	text.Position = Vector2.new(0, 0)
	return text
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
	if not currentPlayers[player] and player.Team ~= localPlayer.Team then
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

	-- Connect to the "Team" property change signal
	v:GetPropertyChangedSignal("Team"):Connect(function()
		if v.Team ~= localPlayer.Team then
			addPlayer(v)
		elseif currentPlayers[v] then
			currentPlayers[v].box:Destroy()
			currentPlayers[v].label:Destroy()
			currentPlayers[v] = nil
		end
	end)

	if v.Team ~= localPlayer.Team then
		addPlayer(v)
	end
end

-- If player has joined, add them to the table
Players.PlayerAdded:Connect(function(player)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		if player.Team ~= localPlayer.Team then
			addPlayer(player)
		elseif currentPlayers[player] then
			currentPlayers[player].box:Destroy()
			currentPlayers[player].label:Destroy()
			currentPlayers[player] = nil
		end
	end)

	if player.Team ~= localPlayer.Team then
		addPlayer(player)
	end
end)

-- Remove the box and set the player to nil if the player has left the game
Players.PlayerRemoving:Connect(function(player)
	if currentPlayers[player] then
		currentPlayers[player].box:Remove()
		currentPlayers[player].label:Destroy()
		currentPlayers[player] = nil
	end
end)

-- Handle team changes for the local player
localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	-- Clear ESP for players now on the same team
	for player, _ in currentPlayers do
		if player.Team == localPlayer.Team then
			currentPlayers[player].box:Destroy()
			currentPlayers[player].label:Destroy()
			currentPlayers[player] = nil
		end
	end

	-- Add ESP for players on opposing teams
	for _, v in Players:GetPlayers() do
		if v == localPlayer or v.Team == localPlayer.Team then
			continue
		end
		addPlayer(v)
	end
end)

local lastTargetPos
local function aimAt(target)
	if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
	if target then
		aimbotConnection = RunService.RenderStepped:Connect(function(deltaTime)
            if isAimbotActive and target.Position ~= lastTargetPos then
			    camera = workspace.CurrentCamera
			    local lookAtCFrame = CFrame.new(camera.CFrame.Position,target.Position)
				camera.CFrame = lookAtCFrame
				lastTargetPos = target.Position
            else
				aimbotConnection:Disconnect()
                aimbotConnection = nil
                target = nil
            end
		end)
    end
end

-- Aimbot Functions
local function getTarget()
	if cachedTarget and cachedTarget.Parent and cachedTarget:IsDescendantOf(workspace) then
        local humanoid = cachedTarget.Parent:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            return cachedTarget
        end
    end

	if os.clock() - lastUpdate < lastUpdateInterval then
		return cachedTarget
	end

	lastUpdate = os.clock()

	local distance = math.huge
	local target = nil
	for _, v in Players:GetPlayers() do
		if v.Character and v ~= localPlayer and v.Team ~= localPlayer.Team then
			local character = v.Character
			local head = character:FindFirstChild("Head")
			local humanoid = character:FindFirstChild("Humanoid")
			if head and humanoid and humanoid.Health > 0 then
				local head2d, onscreen = camera:WorldToViewportPoint(head.Position)
				if onscreen then
					local enemydistance = (Vector2.new(screenDimensions.X / 2, screenDimensions.Y / 2) - Vector2.new(
						head2d.X,
						head2d.Y
					)).Magnitude
					if enemydistance < distance and enemydistance <= fov then
						target = head
						distance = enemydistance
					end
				end
			end
		end
	end
	cachedTarget = target
	return cachedTarget
end

RunService.RenderStepped:Connect(function()
    if isAimbotActive then
        local target = getTarget()
        if target then
            aimAt(target)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and aimbotactive and not gameProcessed then
		isAimbotActive = not isAimbotActive
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and aimbotactive and not gameProcessed then
		isAimbotActive = false
		cachedTarget = nil
	end
end)

-- GUI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
	Name = "NTSH Client",
	Icon = 0,
	LoadingTitle = "NTSH Client",
	LoadingSubtitle = "Nova's Finest",
	Theme = "Default",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
})

RunService.Heartbeat:Connect(function()
	if hbeActive then
		for i,v in currentPlayers do
			if i.Character then
				local character = i.Character
				local head = character:FindFirstChild("Head")
				if head then
					head.Transparency = 0.8
					head.Size = Vector3.new(3,3,3)
				end
			end
		end
	else
		for i,v in currentPlayers do
			if i.Character then
				local character = i.Character
				local head = character:FindFirstChild("Head")
				if head then
					head.Transparency = 1
					head.Size = Vector3.new(0,0,0)
				end
			end
		end
	end
end)

-- Tabs
local Tab1 = Window:CreateTab("Aimbot", "rewind")
local Tab2 = Window:CreateTab("ESP", "rewind")

-- Aimbot Toggle
local Toggle = Tab1:CreateToggle({
	Name = "Enable Aimbot",
	CurrentValue = false,
	Flag = "Aimbot1",
	Callback = function(Value)
		aimbotactive = Value
	end,
})

-- Smoothness
local Slider = Tab1:CreateSlider({
	Name = "Smoothness",
	Range = {0, 1},
	Increment = 0.01,
	Suffix = "",
	CurrentValue = 1,
	Flag = "Slider1",
	Callback = function(Value)
		smoothness = Value
	end,
 })

local Toggle = Tab1:CreateToggle({
	Name = "Enable HBE",
	CurrentValue = false,
	Flag = "HBE1",
	Callback = function(Value)
		hbeActive = Value
	end,
})

-- ESP Toggle
local Toggle = Tab2:CreateToggle({
	Name = "Enable ESP",
	CurrentValue = false,
	Flag = "ESP1",
	Callback = function(Value)
		if Value then
			-- ESP Loop
			espConnection = RunService.RenderStepped:Connect(function()
				fovCircle.Position = Vector2.new(screenDimensions.X / 2, screenDimensions.Y / 2)
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
			end)
		else
			if espConnection then
				espConnection:Disconnect()
				espConnection = nil
			end

			for i, v in currentPlayers do
				if currentPlayers[i] then
					currentPlayers[i].box.Visible = false
				end
			end
		end
	end,
})
