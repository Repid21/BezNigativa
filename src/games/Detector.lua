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
        Name = "VIOLENCE DISTRICT",
        Module = "games/ViolenceDistrict",
        UniverseId = 6739698191,
        MainPlaceId = 93978595733734,
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
