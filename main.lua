-- File: main.lua | Repository: ssevruk074-hash/gamesense.pub
if _G.GS and _G.GS.FullUnhook then
    pcall(_G.GS.FullUnhook)
end

local RepoBase = "https://raw.githubusercontent.com/ssevruk074-hash/gamesense.pub/main/"
local Modules = {
    "core.lua",
    "combat.lua",
    "movement_skins.lua",
    "visuals_ui.lua"
}

for _, fileName in ipairs(Modules) do
    local url = RepoBase .. fileName .. "?t=" .. tostring(math.floor(tick()))
    local ok, src = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and src and #src > 10 then
        local fn, err = loadstring(src)
        if fn then
            fn()
        else
            warn("[gamesense.pub] Compile error in " .. fileName .. ": " .. tostring(err))
        end
    else
        warn("[gamesense.pub] Failed to fetch " .. fileName .. " from GitHub! Check if repo is Public.")
    end
end
