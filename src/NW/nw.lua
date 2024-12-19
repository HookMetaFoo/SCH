-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local vim = game:GetService("VirtualInputManager")

-- Variables
local ptarget = nil
local isLocked = false
local camera = game.Workspace.CurrentCamera
local localPlayer = Players.LocalPlayer
local currentPlayers = {}
local fov = 100
local mouse = localPlayer:GetMouse()

-- Circles
local circle = Drawing.new("Circle")
circle.Color = Color3.new(0, 0, 1)
circle.Transparency = 1
circle.Radius = fov
circle.Filled = false
circle.Thickness = 2
circle.Visible = true

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
	end
end

-- Remove the box and set the player to nil if the player has left the game
Players.PlayerRemoving:Connect(function(player)
	if currentPlayers[player] then
		currentPlayers[player].box:Remove()
		currentPlayers[player] = nil
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
						ptarget = humanoidRootPart
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
	Name = "Old Guard Client",
	Icon = 0,
	LoadingTitle = "Old Guard Client",
	LoadingSubtitle = "",
	Theme = "DarkBlue",
	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false,
})

-- Tabs
local Tab1 = Window:CreateTab("Aimbot", "rewind")
local Tab2 = Window:CreateTab("ESP", "rewind")

local isAimbotActive = false -- Track if the aimbot is active

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
					while isAimbotActive do -- Continue while the aimbot is active
						task.wait()
						if UserInputService:IsKeyDown(Enum.KeyCode.J) then
							local target = getTarget()
							isLocked = true
							if target then
								vim:SendMouseMoveEvent(target.x, target.y, game)
							end
						end
						isLocked = false
					end
				end)
			end
		elseif not Value then
			isAimbotActive = false
		end
	end,
})

-- Aimbot Indicator Toggle
local Toggle = Tab1:CreateToggle({
	Name = "Enable Aimbot Indicator",
	CurrentValue = false,
	Flag = "Aimbot2",
	Callback = function(Value) end,
})

-- Prioritize Flagbearer Toggle
local Toggle = Tab1:CreateToggle({
	Name = "Prioritize Flagbearer",
	CurrentValue = false,
	Flag = "Flagbearer1",
	Callback = function(Value) end,
})

-- ESP Toggle
local Toggle = Tab2:CreateToggle({
	Name = "Enable ESP",
	CurrentValue = false,
	Flag = "ESP1",
	Callback = function(Value)
		if Value then
			-- Add each player to the currentPlayers table
			for _, v in Players:GetPlayers() do
				if v == localPlayer or v.Team == localPlayer.Team then
					continue
				end
				addPlayer(v)
			end

			-- If player has joined, add them to the table
			Players.PlayerAdded:Connect(function(player)
				addPlayer(player)
			end)

			-- ESP Loop
			RunService.RenderStepped:Connect(function()
				circle.Position = UserInputService:GetMouseLocation()

				for player, table in currentPlayers do
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
				end
			end)
		else
			for _, v in Players:GetPlayers() do
				if currentPlayers[v] then
					currentPlayers[v].box:Remove()
					currentPlayers[v] = nil
				end
			end
		end
	end,
})

-- Highlight Flagbearer Toggle
local Toggle = Tab2:CreateToggle({
	Name = "Highlight Flagbearer",
	CurrentValue = false,
	Flag = "ESP2",
	Callback = function(Value)
		
	end,
})

-- Aimbot Functionality
local dealShot
local hitTarget
local createFirearmImpact
for i, v in getgc(true) do
	if typeof(v) == "function" then
		if debug.getinfo(v).name == "dealShot" then
			dealShot = v
		end
		if debug.getinfo(v).name == "hitTarget" then
			hitTarget = v
		end
		if debug.getinfo(v).name == "createFirearmImpact" then
			createFirearmImpact = v
		end
		if debug.getinfo(v).name == "projectileLanded" then
			projectileLanded = v
		end
	end
end

for i, v in getgc(true) do
	if typeof(v) == "function" then
		if debug.getinfo(v).name == "simulateFirearmProjectile" then
			local old
			old = hookfunction(
				v,
				newcclosure(function(bullet, deltaTime, gravity)
					local originPosition = bullet.position
					local direction = (mouse.Hit.Position - originPosition).Unit
					local destinationVector = direction
					local raycastParams = RaycastParams.new()
					if bullet.isLocal then
						local localPlayerHit = 4
						local localIgnoredCharacters = {}
						table.clear(localIgnoredCharacters)
						table.insert(localIgnoredCharacters, localPlayer.Character)

						while true do
							raycastParams.FilterDescendantsInstances = localIgnoredCharacters
							localPlayerHit = localPlayerHit - 1
							local raycastResult
							if ptarget and isLocked then
								raycastResult = workspace:Raycast(
									originPosition,
									(ptarget.Position - originPosition).Unit * 10000,
									raycastParams
								)
							else
								raycastResult =
									workspace:Raycast(originPosition, destinationVector * 10000, raycastParams)
							end
							if raycastResult then
								local hitInstance = raycastResult.Instance
								local character = hitInstance.Parent
								local humanoid = character:FindFirstChild("Humanoid")

								if humanoid then
									local playerHit = Players:GetPlayerFromCharacter(character)

									if not playerHit then
										return true
									elseif playerHit.Team == localPlayer.Team then
										table.insert(localIgnoredCharacters, character)
									else
										local hitPlayerObj = playerHit
										local hitHumanoidObj = humanoid
										local hitInstanceObj = hitInstance
										local hitPosition = raycastResult.Position
										local isNonFatal = bullet.lifetime <= 4
											and (not hitInstanceObj or hitInstanceObj.Name ~= "Head")

										dealShot(hitPlayerObj, hitHumanoidObj, hitInstanceObj, hitPosition, isNonFatal)
										return true
									end
								elseif character.Name == "TargetModel" then
									hitTarget(character, 100)
									return true
								else
									createFirearmImpact(raycastResult.Position, raycastResult.Normal)
									projectileLanded(raycastResult.Position)
									return true
								end
							end

							if localPlayerHit <= 0 then
								break
							end
						end
					else
						return old(bullet, deltaTime, gravity)
					end
				end)
			)
		end
	end
end
