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
