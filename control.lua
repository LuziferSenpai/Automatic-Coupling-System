local coupleSignalId = { type = "virtual", name = "signal-couple" }
local decoupleSignalId = { type = "virtual", name = "signal-decouple" }
local wireTypeDefine = defines.wire_type
local railDirectionDefine = defines.rail_direction

local function checkCircuitNetworkHasSignal(entity, signalId)
    local redCircuitNetwork = entity.get_circuit_network(wireTypeDefine.red)
    local greenCircuitNetwork = entity.get_circuit_network(wireTypeDefine.green)

    if redCircuitNetwork then
        if redCircuitNetwork.get_signal(signalId) ~= 0 then
            return true
        end
    end

    if greenCircuitNetwork then
        if greenCircuitNetwork.get_signal(signalId) ~= 0 then
            return true
        end
    end

    return false
end

local function checkCircuitNetworkHasSignals(train)
    local stationEntity = train.station

    if stationEntity ~= nil then
        if checkCircuitNetworkHasSignal(stationEntity, coupleSignalId) or checkCircuitNetworkHasSignal(stationEntity, decoupleSignalId) then
            return true
        end
    end

    return false
end

local function getCircuitNetworkSingalValue(entity, signalId)
    local redCircuitNetwork = entity.get_circuit_network(wireTypeDefine.red)
    local greenCircuitNetwork = entity.get_circuit_network(wireTypeDefine.green)
    local signalValue = 0

    if redCircuitNetwork then
        signalValue = signalValue + redCircuitNetwork.get_signal(signalId)
    end

    if greenCircuitNetwork then
        signalValue = signalValue + greenCircuitNetwork.get_signal(signalId)
    end

    return signalValue
end

local function matchEntityOrientation(entityAOrientation, entityBOrientation)
    return math.abs(entityAOrientation - entityBOrientation) < 0.25 or
        math.abs(entityAOrientation - entityBOrientation) > 0.75
end

local function getOrienationBetweenTwoPositions(entityAPosition, entityBPosition)
    return (math.atan2(entityBPosition.y - entityAPosition.y, entityBPosition.x - entityAPosition.x) / 2 / math.pi + 0.25) %
        1
end

local function getTileDistanceBetweenTwoPositions(positionA, positionB)
    return math.abs(positionA.x - positionB.x) + math.abs(positionA.y - positionB.y)
end

local function getFrontBackTrainEntity(train, stationEntity)
    local trainFrontEntity = train.front_stock
    local trainBackEntity = train.back_stock

    if getTileDistanceBetweenTwoPositions(trainFrontEntity.position, stationEntity.position) < getTileDistanceBetweenTwoPositions(trainBackEntity.position, stationEntity.position) then
        return trainFrontEntity, trainBackEntity
    else
        return trainBackEntity, trainFrontEntity
    end
end

local function swapRailDirection(railDirection)
    return railDirection == railDirectionDefine.front and railDirectionDefine.back or railDirectionDefine.front
end

local function attemptUncoupleTrain(train, stationEntity, trainFrontEntity)
    local decoupleCount = getCircuitNetworkSingalValue(stationEntity, decoupleSignalId)
    local carriages = train.carriages

    if decoupleCount ~= 0 then
        if math.abs(decoupleCount) < #carriages then
            local decoupleDirection = railDirectionDefine.front
            local targetCount = decoupleCount
            local targetWagon

            if trainFrontEntity ~= train.front_stock then
                decoupleCount = decoupleCount * -1
                targetCount = decoupleCount
            end

            if decoupleCount < 0 then
                decoupleCount = decoupleCount + #carriages
                targetCount = decoupleCount + 1
            else
                decoupleCount = decoupleCount + 1
            end

            targetWagon = carriages[decoupleCount]

            if not matchEntityOrientation(getOrienationBetweenTwoPositions(targetWagon.position, carriages[targetCount].position), targetWagon.orientation) then
                decoupleDirection = swapRailDirection(decoupleDirection)
            end

            if targetWagon.disconnect_rolling_stock(decoupleDirection) then
                if carriages[targetCount].type == "locomotive" then
                    carriages[targetCount].train.manual_mode = false
                end

                if targetWagon.type == "locomotive" then
                    targetWagon.train.manual_mode = false
                end

                return targetWagon
            end
        end
    end
end

local function attemptCoupleTrain(stationEntity, trainFrontEntity)
    local coupleCount = getCircuitNetworkSingalValue(stationEntity, coupleSignalId)

    if coupleCount ~= 0 then
        local coupleRailDirection = coupleCount < 0 and railDirectionDefine.back or railDirectionDefine.front

        if not matchEntityOrientation(trainFrontEntity.orientation, stationEntity.orientation) then
            coupleRailDirection = swapRailDirection(coupleRailDirection)
        end

        if trainFrontEntity.connect_rolling_stock(coupleRailDirection) then
            return true
        end
    end

    return false
end

local function doTrainCoupleLogic(train)
    local trainIdString = tostring(train.id)
    local globalTainData = global.trainIds[trainIdString]
    local stationEntity = globalTainData.station

    global.trainIds[trainIdString] = nil

    if stationEntity and stationEntity.valid then
        local trainFrontEntity, trainBackEntity = getFrontBackTrainEntity(train, stationEntity)
        local trainSchedule = train.schedule
        local didCouple = false
        local didChange = false

        if attemptCoupleTrain(stationEntity, trainFrontEntity) then
            didCouple = true
            didChange = true

            train = trainFrontEntity.train

            if trainFrontEntity == train.front_stock or trainBackEntity == train.back_stock then
                trainFrontEntity = train.front_stock
                trainBackEntity = train.back_stock
            else
                trainFrontEntity = train.back_stock
                trainBackEntity = train.front_stock
            end
        end

        trainFrontEntity = attemptUncoupleTrain(train, stationEntity, trainFrontEntity)

        if trainFrontEntity then
            didChange = true
        else
            trainFrontEntity = trainBackEntity
        end

        if didChange then
            frontTrain = trainFrontEntity.train
            backTrain = trainBackEntity.train

            frontTrain.schedule = trainSchedule
            backTrain.schedule = trainSchedule

            if #frontTrain.locomotives > 0 or didCouple then frontTrain.manual_mode = false end
            if #backTrain.locomotives > 0 or didCouple then backTrain.manual_mode = false end
        end
    end
end

script.on_init(function()
    global.trainIds = global.trainIds or {}
end)

script.on_configuration_changed(function(eventData)
    local modChanges = eventData.mod_changes

    global.trainIds = global.trainIds or {}

    if modChanges then
        local atcChanges = modChanges["Automatic_Coupling_System"]

        if atcChanges then
            local oldAtcVersion = atcChanges.old_version

            if oldAtcVersion and atcChanges.new_version then
                if oldAtcVersion <= "0.2.3" then
                    local trainIds = global.TrainsID

                    global.TrainsID = nil

                    if next(trainIds) then
                        for trainId, tableData in pairs(trainIds) do
                            global.trainIds[tostring(trainId)] = tableData.s
                        end
                    end
                end

                if oldAtcVersion > "0.2.3" and oldAtcVersion <= "2.0.0" then
                    local trainIds = global.TrainsID

                    global.TrainsID = nil

                    if next(trainIds) then
                        for trainId, tableData in pairs(trainIds) do
                            global.trainIds[tostring(trainId)] = tableData.station
                        end
                    end
                end
            end
        end
    end
end)

script.on_event(defines.events.on_train_created, function(eventData)
    local newTrainId = tostring(eventData.train.id)
    local oldTrainId1 = tostring(eventData.old_train_id_1)
    local oldTrainId2 = tostring(eventData.old_train_id_2)

    if global.trainIds[oldTrainId1] then
        global.trainIds[newTrainId] = global.trainIds[oldTrainId1]
    elseif global.trainIds[oldTrainId2] then
        global.trainIds[newTrainId] = global.trainIds[oldTrainId2]
    end

    if global.trainIds[oldTrainId1] then
        global.trainIds[oldTrainId1] = nil
    end

    if global.trainIds[oldTrainId2] then
        global.trainIds[oldTrainId2] = nil
    end
end)

script.on_event(defines.events.on_train_changed_state, function(eventData)
    local train = eventData.train
    local waitStationDefine = defines.train_state.wait_station

    if train.state == waitStationDefine then
        if checkCircuitNetworkHasSignals(train) then
            global.trainIds[tostring(train.id)] = { station = train.station }
        end

        return
    end

    if eventData.old_state == waitStationDefine then
        local globalTainData = global.trainIds[tostring(train.id)]

        if globalTainData and not globalTainData.modded then
            doTrainCoupleLogic(train)
        end
    end
end)

remote.add_interface("automaticCoupling", {
    checkCoupleSignals = function(train)
        if checkCircuitNetworkHasSignals(train) then
            global.trainIds[tostring(train.id)] = { station = train.station, modded = true }

            return true
        end

        return false
    end,
    doTrainCoupleLogic = doTrainCoupleLogic
})
