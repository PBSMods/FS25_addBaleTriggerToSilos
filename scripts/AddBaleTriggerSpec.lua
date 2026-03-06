--
-- Mod: FS25_AddBaleTriggerSpecialization
--
-- File: scripts/AddBaleTriggerSpec.lua
--
-- Author: PBSMods
-- email: pbsmods (at) pbsmods (dot) ch
-- @Date: 02.03.2026
-- @Version: 1.0.0.0

-- #############################################################################
-- EVENT-KLASSE FÜR MULTIPLAYER-SYNCHRONISATION
-- #############################################################################

AddBaleFillEvent = {}
local AddBaleFillEvent_mt = Class(AddBaleFillEvent, Event)
InitEventClass(AddBaleFillEvent, "AddBaleFillEvent")

function AddBaleFillEvent.emptyNew()
    local self = Event.new(AddBaleFillEvent_mt)
    return self
end

function AddBaleFillEvent.new(placeable, fillType, fillLevel)
    local self = AddBaleFillEvent.emptyNew()
    self.placeable = placeable
    self.fillType = fillType
    self.fillLevel = fillLevel
    return self
end

function AddBaleFillEvent:readStream(streamId, connection)
    self.placeable = NetworkUtil.readNodeObject(streamId)
    self.fillType = streamReadInt32(streamId)
    self.fillLevel = streamReadFloat32(streamId)
    self:run(connection)
end

function AddBaleFillEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.placeable)
    streamWriteInt32(streamId, self.fillType)
    streamWriteFloat32(streamId, self.fillLevel)
end

function AddBaleFillEvent:run(connection)
    -- Wenn das Event auf dem Server ankommt, an alle anderen Clients weiterleiten
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.placeable)
    end
    
    -- Tatsächliches Hinzufügen der Füllmenge in das Lager
    if self.placeable ~= nil and self.placeable:getIsSynchronized() then
        if self.placeable.spec_storage ~= nil then
            local farmId = self.placeable:getOwnerFarmId()
            self.placeable.spec_storage:addFillLevel(self.fillLevel, self.fillType, farmId, nil)
        end
    end
end

function AddBaleFillEvent.sendEvent(placeable, fillType, fillLevel, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(AddBaleFillEvent.new(placeable, fillType, fillLevel), nil, nil, placeable)
        else
            g_client:getServerConnection():sendEvent(AddBaleFillEvent.new(placeable, fillType, fillLevel))
        end
    end
end


-- #############################################################################
-- SPECIALIZATION-KLASSE
-- #############################################################################

AddBaleTriggerSpec = {}

function AddBaleTriggerSpec.prerequisitesPresent(specializations)
    return true
end

function AddBaleTriggerSpec.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "addBaleImportTrigger", AddBaleTriggerSpec.addBaleImportTrigger)
    SpecializationUtil.registerFunction(placeableType, "onBaleTriggerCallback", AddBaleTriggerSpec.onBaleTriggerCallback)
end

function AddBaleTriggerSpec.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", AddBaleTriggerSpec)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", AddBaleTriggerSpec)
end

function AddBaleTriggerSpec:onLoad(savegame)
    if self.spec_storage ~= nil and
       self.spec_loadingStation ~= nil and
       self.spec_baleTrigger == nil then

        self:addBaleImportTrigger()
    end
end

function AddBaleTriggerSpec:onDelete()
    -- Wichtig: Den Trigger beim Löschen/Verkaufen des Gebäudes wieder entfernen
    if self.spec_addBaleImport ~= nil and self.spec_addBaleImport.triggerId ~= nil then
        removeTrigger(self.spec_addBaleImport.triggerId)
    end
end

function AddBaleTriggerSpec:addBaleImportTrigger()
    local triggerNode = createTransformGroup("baleImportTrigger")
    link(self.rootNode, triggerNode)
    setTranslation(triggerNode, 0, 0, -5)

    -- HINWEIS: createTransformGroup erstellt nur eine leere TransformGroup ohne Kollisions-Shape. 
    -- Damit 'addTrigger' feuert, benötigt die Engine normalerweise einen RigidBody mit Collision Mask.
    -- Sollte der Trigger im Spiel nicht auslösen, musst du entweder per Script eine Shape generieren 
    -- oder eine unsichtbare i3d mit einem vorbereiteten Trigger-Node laden und hier verlinken.

    self.spec_addBaleImport = {}
    self.spec_addBaleImport.triggerNode = triggerNode
    self.spec_addBaleImport.triggerId = triggerNode

    addTrigger(triggerNode, "onBaleTriggerCallback", self)
end

function AddBaleTriggerSpec:onBaleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    -- Ballen-Logik nur auf dem Server ausführen, um Desyncs zu vermeiden
    if onEnter and g_server ~= nil then
        local bale = g_currentMission.nodeToObject[otherId]

        -- Sicherstellen, dass es wirklich ein Ballen ist
        if bale ~= nil and bale:isa(Bale) and bale.getFillType ~= nil then

            local fillType = bale:getFillType()
            local fillLevel = bale:getFillLevel()

            if self.spec_storage:getFreeCapacity(fillType) >= fillLevel then
                -- Event abfeuern (synchronisiert die Füllstandsanpassung an alle)
                AddBaleFillEvent.sendEvent(self, fillType, fillLevel)
                
                -- Den Ballen direkt auf dem Server löschen
                bale:delete()
            end
        end
    end
end


-- #############################################################################
-- REGISTRIERUNG AN ALLE PLACEABLES
-- #############################################################################

TypeManager.validateTypes = Utils.appendedFunction(
    TypeManager.validateTypes,
    function(self)
        -- Nur ausführen, wenn der aktuelle Manager der PlaceableTypeManager ist
        if self == g_placeableTypeManager then
            for typeName, typeEntry in pairs(self.types) do
                -- Prüfe, ob die Spezialisierung "storage" in diesem Placeable-Typ existiert
                if typeEntry.specializationsByName ~= nil and typeEntry.specializationsByName["storage"] then
                    -- Hänge die neue Spezialisierung dynamisch an
                    self:addSpecializationToType("AddBaleTriggerSpec", typeName)
                end
            end
        end
    end
)