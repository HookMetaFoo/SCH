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
local espConnection = nil
-- Aimbot Functionality
local dealShot
local hitTarget
local createFirearmImpact

-- Circles
local circle = Drawing.new("Circle")
circle.Color = Color3.new(0, 0, 1)
circle.Transparency = 1
circle.Radius = fov
circle.Filled = false
circle.Thickness = 2
circle.Position = Vector2.new(0, 0)
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
			flagbearer = false,
		}
	end
end

-- Add each player to the currentPlayers table
for _, v in Players:GetPlayers() do
	if v == localPlayer or v.Team == localPlayer.Team then
		continue
	end
	addPlayer(v)
	v.Changed:Connect(function(property)
		if property == "Team" then
			if v.Team ~= localPlayer.Team then
				addPlayer(v)
			elseif currentPlayers[v] then
				currentPlayers[v].box:Destroy()
				currentPlayers[v] = nil
			end
		end
	end)
end

-- If player has joined, add them to the table
Players.PlayerAdded:Connect(function(player)
	player.Changed:Connect(function(property)
		if property == "Team" then
			if player.Team ~= localPlayer.Team then
				addPlayer(player)
			elseif currentPlayers[player] then
				currentPlayers[player].box:Destroy()
				currentPlayers[player] = nil
			end
		end
	end)
	addPlayer(player)
end)

-- Remove the box and set the player to nil if the player has left the game
Players.PlayerRemoving:Connect(function(player)
	if currentPlayers[player] then
		currentPlayers[player].box:Remove()
		currentPlayers[player] = nil
	end
end)

localPlayer.Changed:Connect(function(property)
	if property == "Team" then
		for player,_ in currentPlayers do
			if player.Team == localPlayer.Team then
				currentPlayers[player].box:Destroy()
                currentPlayers[player] = nil
            end
		end
        for _, v in Players:GetPlayers() do
	        if v == localPlayer or v.Team == localPlayer.Team then
		        continue
	        end
	        addPlayer(v)
        end
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
	Name = "VG Client 2.0",
	Icon = 0,
	LoadingTitle = "VG Client",
	LoadingSubtitle = "Unequaled, Unrivaled",
	Theme = "DarkBlue",
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
								vim:SendMouseMoveEvent(target.x, target.y, game)
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

-- STILL WIP
-- Silent Aim
local Toggle = Tab1:CreateToggle({
	Name = "Enable Silent Aim",
	CurrentValue = false,
	Flag = "Aimbot3",
	Callback = function(Value)
		if Value then
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

										local raycastResult =
											workspace:Raycast(originPosition, destinationVector * 10000, raycastParams)
										if raycastResult then
											local hitInstance = ptarget
											local character = ptarget.Parent
											local humanoid = character:FindFirstChild("Humanoid")

											if humanoid and isLocked then
												local playerHit = Players:GetPlayerFromCharacter(character)

												if not playerHit then
													return true
												elseif playerHit.Team == localPlayer.Team then
													table.insert(localIgnoredCharacters, character)
												else
													local hitPlayerObj = playerHit
													local hitHumanoidObj = humanoid
													local hitInstanceObj = hitInstance
													local hitPosition = ptarget.Position
													local isNonFatal = false

													dealShot(
														hitPlayerObj,
														hitHumanoidObj,
														hitInstanceObj,
														hitPosition,
														isNonFatal
													)
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
			-- ESP Loop
			espConnection = RunService.RenderStepped:Connect(function()
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

local flags = {}
local connections = {}
local Toggle = Tab2:CreateToggle({
	Name = "Highlight Flagbearer",
	CurrentValue = false,
	Flag = "ESP2",
	Callback = function(Value)
		if Value then
			-- Find the flags and highlight the players holding them
			for player, data in currentPlayers do
				local character = player.Character
				if character then
					local torso = character:FindFirstChild("Torso")
					if torso then
						local flagJoint = torso:FindFirstChild("FlagJoint")
						if flagJoint then
							flags[player] = flagJoint
							data.flagbearer = true
							data.box.Color = Color3.new(1, 0, 0.784)
						end
					end
				end
			end

			for player, data in currentPlayers do
				local character = player.Character
				local torso
				if character then
					torso = character:FindFirstChild("Torso")
					if torso then
						connections[player] = {
							ChildAdded = torso.ChildAdded:Connect(function(instance)
								if instance.Name == "FlagJoint" then
									local torso = instance.Parent
									local character = torso.Parent
									local player = Players:GetPlayerFromCharacter(character)
									if player then
										flags[player] = instance
										currentPlayers[player].flagbearer = true
										if currentPlayers[player].box then
											currentPlayers[player].box.Color = Color3.new(1, 0, 0.784)
										end
									end
								end
							end),
							ChildRemoved = torso.ChildRemoved:Connect(function(instance)
								if instance.Name == "FlagJoint" then
									for player, flag in flags do
										if instance == flag then
											flags[player] = nil
											if currentPlayers[player] then
												currentPlayers[player].flagbearer = false
												currentPlayers[player].box.Color = player.TeamColor.Color
											end
										end
									end
								end
							end),
						}
					end
				end
			end

			Players.PlayerAdded:Connect(function(player)
				if connections[player] then
					return
				end
				player.CharacterAdded:Wait()
				local character = player.Character
				local torso = character.Torso
				if torso then
					connections[player] = {
						ChildAdded = torso.ChildAdded:Connect(function(instance)
							if instance.Name == "FlagJoint" then
								local torso = instance.Parent
								local character = torso.Parent
								local player = Players:GetPlayerFromCharacter(character)
								if player then
									flags[player] = instance
									currentPlayers[player].flagbearer = true
									if currentPlayers[player].box then
										currentPlayers[player].box.Color = Color3.new(1, 0, 0.784)
									end
								end
							end
						end),
						ChildRemoved = torso.ChildRemoved:Connect(function(instance)
							if instance.Name == "FlagJoint" then
								for player, flag in flags do
									if instance == flag then
										flags[player] = nil
										if currentPlayers[player] then
											currentPlayers[player].flagbearer = false
											currentPlayers[player].box.Color = player.TeamColor.Color
										end
									end
								end
							end
						end),
					}
				end
			end)

			Players.PlayerRemoving:Connect(function(player)
				if connections[player] then
					if connections[player].ChildAdded then
						connections[player].ChildAdded:Disconnect()
					end
					if connections[player].ChildRemoved then
						connections[player].ChildRemoved:Disconnect()
					end
				end
			end)
		else
			for player, flag in flags do
				if currentPlayers[player] then
					currentPlayers[player].flagbearer = false
					currentPlayers[player].box.Color = player.TeamColor.Color
				end

				if connections[player] then
					if connections[player].ChildAdded then
						connections[player].ChildAdded:Disconnect()
					end
					if connections[player].ChildRemoved then
						connections[player].ChildRemoved:Disconnect()
					end
				end
			end
			flags = {}
			connections = {}
		end
	end,
})

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

-- STILL WIP
-- Silent Aim
local Toggle = Tab1:CreateToggle({
	Name = "Enable Silent Aim",
	CurrentValue = false,
	Flag = "Aimbot3",
	Callback = function(Value)
		if Value then
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

										local raycastResult =
											workspace:Raycast(originPosition, destinationVector * 10000, raycastParams)
										if raycastResult then
											local hitInstance = ptarget
											local character = ptarget.Parent
											local humanoid = character:FindFirstChild("Humanoid")

											if humanoid and isLocked then
												local playerHit = Players:GetPlayerFromCharacter(character)

												if not playerHit then
													return true
												elseif playerHit.Team == localPlayer.Team then
													table.insert(localIgnoredCharacters, character)
												else
													local hitPlayerObj = playerHit
													local hitHumanoidObj = humanoid
													local hitInstanceObj = hitInstance
													local hitPosition = ptarget.Position
													local isNonFatal = false

													dealShot(
														hitPlayerObj,
														hitHumanoidObj,
														hitInstanceObj,
														hitPosition,
														isNonFatal
													)
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
		end
	end,
})
