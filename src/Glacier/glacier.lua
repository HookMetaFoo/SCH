-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local vim = game:GetService("VirtualInputManager")

local camera = game.Workspace.CurrentCamera
local localPlayer = Players.LocalPlayer
local currentPlayers = {}
local fov = 100
local espConnection = nil
local showOnlyFlagbearers = false

for i, v in getgc(true) do
	if typeof(v) == "function" then
		if debug.getinfo(v).name == "dealShot" then
			dealShot = v
		elseif debug.getinfo(v).name == "hitTarget" then
			hitTarget = v
		elseif debug.getinfo(v).name == "createFirearmImpact" then
			createFirearmImpact = v
		elseif debug.getinfo(v).name == "projectileLanded" then
			projectileLanded = v
		end
	end
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

local function updateBoxes(box, distanceY, root2d)
	box.PointA = Vector2.new(root2d.X + distanceY, root2d.Y - distanceY * 2)
	box.PointB = Vector2.new(root2d.X - distanceY, root2d.Y - distanceY * 2)
	box.PointC = Vector2.new(root2d.X - distanceY, root2d.Y + distanceY * 2)
	box.PointD = Vector2.new(root2d.X + distanceY, root2d.Y + distanceY * 2)
	box.Visible = true
end

-- Create a table that contains the boxes for each player
local function addPlayer(player)
    if not currentPlayers[player] and player.Team ~= localPlayer.Team then
        currentPlayers[player] = {
            box = createBox(player.TeamColor.Color),
        }
    else
        currentPlayers[player].box.Color = player.TeamColor.Color
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
		currentPlayers[player] = nil
	end
end)

-- Handle team changes for the local player
localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    -- Clear ESP for players now on the same team
    for player, _ in pairs(currentPlayers) do
        if player.Team == localPlayer.Team then
            currentPlayers[player].box:Destroy()
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

-- Aimbot Functions
local function getTarget()
	local distance = math.huge
	local target = nil
	for _, v in Players:GetPlayers() do
		if v.Character and v ~= localPlayer and v.Team ~= localPlayer.Team then
			local character = v.Character
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoidRootPart and humanoid and humanoid.Health > 0 then
				local root2d, onscreen = camera:WorldToViewportPoint(humanoidRootPart.Position)
				if onscreen then
					local mouse = UserInputService:GetMouseLocation()
					local enemydistance = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(root2d.X, root2d.Y)).Magnitude
					if enemydistance < distance and enemydistance <= fov then
						target = root2d
						distance = enemydistance
					end
				end
			end
		end
	end
	return target
end

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

-- Tabs
local Tab1 = Window:CreateTab("Aimbot", "rewind")
local Tab2 = Window:CreateTab("ESP", "rewind")

local isAimbotActive = false

-- Aimbot Toggle
local Toggle = Tab1:CreateToggle({
	Name = "Enable Aimbot",
	CurrentValue = false,
	Flag = "Aimbot1",
	Callback = function(Value)
		if Value then
			if not isAimbotActive then
				isAimbotActive = true
				spawn(function()
					while isAimbotActive do
						task.wait()
						if UserInputService:IsKeyDown(Enum.KeyCode.J) then
							local target = getTarget()
							isLocked = true
							if target then
								vim:SendMouseMoveEvent(target.X, target.Y, game)
								
							end
						else
							isLocked = false
						end
					end
				end)
			end
		elseif not Value then
			isAimbotActive = false
		end
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
				for player, table in currentPlayers do
					if (currentPlayers[player].flagbearer == true and showOnlyFlagbearers) or not showOnlyFlagbearers then
						if player then
							if player.Character then
								local character = player.Character
								local root = character:FindFirstChild("HumanoidRootPart")
								local head = character:FindFirstChild("Head")
								if root and head then
									local root2d, onscreen = camera:WorldToViewportPoint(root.Position)
									local head2 = camera:WorldToViewportPoint(head.Position)
									if onscreen and root2d and head2 then
										local distanceY = math.clamp(
											(Vector2.new(head2.X, head2.Y) - Vector2.new(root2d.X, root2d.Y)).Magnitude,
											2,
											math.huge
										)
										updateBoxes(table.box, distanceY, root2d)
									else
										table.box.Visible = false
									end
								end
							end
						end
					else
						table.box.Visible = false
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