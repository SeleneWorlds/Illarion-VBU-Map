local Registries = require("selene.registries")
local Resources = require("selene.resources")
local Maps = require("selene.map")
local Dimensions = require("selene.dimensions")
local Saves = require("selene.saves")

function convertMap(tilesFile)
    local basePath = tilesFile:gsub(".tiles.txt", "")
    local baseName = basePath:gsub("illarion%-vbu%-map/server/maps/", "")
    local outputPath = "maps/partial/" .. baseName .. ".selenemap"
    -- Skip if a converted version of this map is already present
    if Saves.Has(outputPath) then
        return outputPath
    end

    local unknownTiles = {}
    local unknownItems = {}

    local map = Maps.Create()
    local tilesInput = Resources.LoadAsString(tilesFile)
    local header = {}
    local startX, startY, z
    for line in tilesInput:gmatch("([^\n]*)\n?") do
        if stringx.trim(line) ~= "" and stringx.trim(line):sub(1, 1) ~= "#" then
            -- Headers are in the format Key: Value
            local key, value = line:match("([^:]+):([^;]+);?")
            if key then
                header[key] = stringx.trim(value)
                if key == "X" then
                    startX = tonumber(header["X"])
                elseif key == "Y" then
                    startY = tonumber(header["Y"])
                elseif key == "L" then
                    z = tonumber(header["L"])
                end
            else
                -- Tiles are in the format X;Y;Tile;Music
                local x, y, combinedTileId, music = line:match("(-?%d+);(-?%d+);(%d+);(%d+)")

                local BASE_MASK = 0x001F
                local OVERLAY_MASK = 0x03E0
                local SHAPE_MASK = 0xFC00
                local tileId = tonumber(combinedTileId)
                if (tileId & SHAPE_MASK) ~= 0 then
                    tileId = tileId & BASE_MASK
                end

                local tile = Registries.FindByMetadata("tiles", "tileId", tonumber(tileId))
                if tile ~= nil and tileId ~= 0 then
                    map:PlaceTile(startX + tonumber(x), startY + tonumber(y), z, tile.Name)
                elseif tileId ~= 0 then
                    unknownTiles[tileId] = unknownTiles[tileId] and unknownTiles[tileId] + 1 or 1
                end
            end
        end
    end
    local itemsInput = Resources.LoadAsString(basePath .. ".items.txt")
    for line in itemsInput:gmatch("([^\n]*)\n?") do
        if stringx.trim(line) ~= "" and stringx.trim(line):sub(1, 1) ~= "#" then
            -- Items are in the format X;Y;Item;Quality
            local x, y, itemId, quality = line:match("(-?%d+);(-?%d+);(-?%d+);(-?%d+)")
            local tile = Registries.FindByMetadata("tiles", "itemId", tonumber(itemId))
            if tile == nil then
                unknownItems[tonumber(itemId)] = quality
            else
                map:PlaceTile(tonumber(x) + startX, tonumber(y) + startY, z, tile.Name)
            end
        end
    end
    local warpsInput = Resources.LoadAsString(basePath .. ".warps.txt")
    for line in warpsInput:gmatch("([^\n]*)\n?") do
        if stringx.trim(line) ~= "" and stringx.trim(line):sub(1, 1) ~= "#" then
            -- Warps are in the format X;Y;ToX;ToY;ToLevel
            local x, y, toX, toY, toLevel = line:match("(-?%d+);(-?%d+);(-?%d+);(-?%d+);(-?%d+)")
            map:AnnotateTile(tonumber(x) + startX, tonumber(y) + startY, z, "illarion:warp", {
                x = tonumber(x) + startX,
                y = tonumber(y) + startY,
                z = tonumber(toLevel)
            })
        end
    end

    for k, v in pairs(unknownTiles) do
        print("Unknown tile id " .. k .. " in " .. baseName .. " (x " .. v .. ")")
    end
    for k, v in pairs(unknownItems) do
        print("Unknown item id " .. k .. " in " .. baseName)
    end

    print("Saving " .. outputPath)
    Saves.Save(map, outputPath)
    return outputPath
end

local mergedMapPath = "maps/illarion-vbu.selenemap"
if not Saves.Has(mergedMapPath) then
    local mergedMap = Maps.Create()
    local files = Resources.ListFiles("illarion-vbu-map", "server/maps/*.tiles.txt")
    for _, file in pairs(files) do
        local outputPath = convertMap(file)
        local mapTree = Saves.Load(outputPath)
        if mapTree then
            mergedMap:Merge(mapTree)
        else
            print("Failed to load " .. outputPath)
        end
    end
    Saves.Save(mergedMap, mergedMapPath)
end

print("Loading " .. mergedMapPath)
local vbuMap = Saves.Load(mergedMapPath)
Dimensions.GetDefault().Map = vbuMap