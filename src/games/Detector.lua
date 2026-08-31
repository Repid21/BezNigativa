local Detector = {}

local PROFILES = {
    {
        Name = "Forsaken",
        Module = "games/Forsaken",
        UniverseId = 6331902150,
        MainPlaceId = 18687417158,
    },
    {
        Name = "Murder Mystery 2",
        Module = "games/MurderMystery2",
        UniverseId = 66654135,
        MainPlaceId = 142823291,
    },
    {
        Name = "Untitled Boxing Game",
        Module = "games/UntitledBoxingGame",
        UniverseId = 4730278139,
        MainPlaceId = 13621938427,
    },
}

function Detector.Detect(dataModel)
    local universeId = tonumber(dataModel.GameId)
    local placeId = tonumber(dataModel.PlaceId)
    for _, profile in ipairs(PROFILES) do
        if universeId == profile.UniverseId or placeId == profile.MainPlaceId then
            return profile
        end
    end
    return nil
end

return Detector
