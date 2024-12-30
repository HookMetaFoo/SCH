local func = nil
local func2 = nil
local func3 = nil
local table = nil
local ore = nil
local Players = game:GetService("Players")
local localPlayer = Players.localPlayer
local humanoidrootpart = localPlayer.Character:FindFirstChild("HumanoidRootPart")
for i,v in getgc(true) do
    if type(v) == "table" and rawget(v,"DamageOre") then
        table = v
        func = rawget(v,"DamageOre")
        func2 = rawget(v,"BeginMinigame")
        func3 = rawget(v, "SelectOre")
    end
end

local old; old = hookfunction(func, function(...)  
    local _,ore,damage,bool = ...
    damage = 10000
    return old(_,ore,damage,bool)
end)

local old2; old2 = hookfunction(func3, function(...)
    local _, s = ...
    ore = s
    return old2(_,s)
end)

local old3; old3 = hookfunction(func2, function(...)
    if ore then
        table:DamageOre(ore,10000,true)
    end
end)

while true do
    task.wait()
    humanoidrootpart.Anchored = false
end


