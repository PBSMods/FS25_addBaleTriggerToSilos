--
-- Mod: FS25_addBaleTriggerToSilos
--
-- File: scripts/addBaleTriggerToSilos.lua
--
-- Author: PBSMods
-- email: pbsmods (at) pbsmods (dot) ch
-- @Date: 02.03.2026
-- @Version: 1.0.0.0

-- #############################################################################

--[[
# Was dieses Script macht

| Schritt | Erklärung                                       |
| ------- | ----------------------------------------------- |
| 1       | Beim Map-Load werden alle Placeables geprüft    |
| 2       | Wenn Storage + LoadingStation vorhanden         |
| 3       | Falls kein BaleTrigger existiert                |
| 4       | Wird automatisch ein Import-BaleTrigger erzeugt |
| 5       | Ballen werden in FillLevel umgerechnet          |
| 6       | Ballen werden gelöscht                          |
| 7       | Silo gibt normal als Schüttgut aus              |


# What this script does

| Step    | Explanation                                       |
| ------- | ------------------------------------------------- |
| 1       | All placeables are checked when the map is loaded |
| 2       | If storage + loading station is available         |
| 3       | If no BaleTrigger exists                          |
| 4       | An import BaleTrigger is automatically created    |
| 5       | Bales are converted to FillLevel                  |
| 6       | Bales are deleted                                 |
| 7       | Silo outputs normally as bulk material            |

]]--

addBaleTriggerToSilos = {}
addBaleTriggerToSilos.modName = g_currentModName

function addBaleTriggerToSilos:loadMap(name)
    self:addTriggersToAllSilos()
end

function addBaleTriggerToSilos:addTriggersToAllSilos()
    for _, placeable in pairs(g_currentMission.placeables) do
        if placeable.storage ~= nil and placeable.spec_loadingStation ~= nil then
            -- Prüfen ob bereits BaleTrigger existiert
            if placeable.spec_baleTrigger == nil then
                self:addBaleTrigger(placeable)
                Logging.info("[addBaleTriggerToSilos] BaleTrigger hinzugefügt zu: %s", placeable.configFileName)
            end
        end
    end
end

function addBaleTriggerToSilos:addBaleTrigger(placeable)
    local triggerNode = createTransformGroup("autoBaleTrigger")

    link(placeable.rootNode, triggerNode)
    setTranslation(triggerNode, 0, 0, -5)

    local baleTrigger = BaleTrigger.new(placeable, triggerNode, true)

    baleTrigger:setAcceptedFillTypes(placeable.storage:getFillTypes())

    function baleTrigger:onBaleTriggerCallback(bale, fillType, fillLevel)
        if placeable.storage:getFreeCapacity(fillType) > fillLevel then
            placeable.storage:addFillLevel(
                g_currentMission:getFarmId(),
                fillLevel,
                fillType,
                ToolType.UNDEFINED,
                nil
            )
            bale:delete()
        end
    end
    placeable.spec_baleTrigger = baleTrigger
end

function addBaleTriggerToSilos:deleteMap()
end

addModEventListener(addBaleTriggerToSilos)


