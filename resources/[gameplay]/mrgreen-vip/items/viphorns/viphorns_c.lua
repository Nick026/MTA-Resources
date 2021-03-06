local vipHornPath = 'clientHornFiles/'
local vipHornURL = 'https://mrgreengaming.com/api/viphorn/?id='
local hornChecksums = false
local hornTable = {}
local hornIcons = {}
local hornSounds = {}
local hornSoundTimer = {}
local selectedHornForBind
local bindHornGui
local screenSizex, screenSizey = guiGetScreenSize()
local globalHornScale = 0.8
local globalHornAlpha = 0.6

function receiveVipHornTable(table)
    selectedHornForBind = false
    if guiGetVisible( bindHornGui.window[1] ) then
        guiSetVisible(bindHornGui.window[1], false)
    end

    hornTable = table
    guiGridListClear( gui['vipHornGridList'] )
    if not table then return false end
    for _,row in ipairs(table) do
        local name = row.name or 'no name'
        name = row.hornid .. ') ' .. name
        local gridRow = guiGridListAddRow( gui['vipHornGridList'], name, row.boundkey or '')
        guiGridListSetItemData(gui['vipHornGridList'], gridRow, 1, row.forumid..'-'..row.hornid)
    end
end
addEvent('onServerSendVipHornTable', true)
addEventHandler( 'onServerSendVipHornTable', localPlayer, receiveVipHornTable )

function playVipHorn(player, hornid)
    if isElement(player) and getElementType(player) == 'player' and getElementDimension( localPlayer ) == getElementDimension(player) and hornid then
        local vehicle = getPedOccupiedVehicle( player )
        if not vehicle then return end
        local x, y, z = getElementPosition( vehicle )
        local x2, y2, z2 = getElementPosition(getCameraTarget() or localPlayer)
        if getDistanceBetweenPoints3D(x2, y2, z2, x,y,z) > 260 then return end
        local showIcon = getResourceState(getResourceFromName( 'mrgreen-settings' )) == 'running' and exports['mrgreen-settings']:isCustomHornIconEnabled()
        if hornSounds[player] and isElement(hornSounds[player]) then
            destroyElement(hornSounds[player])
        end

        -- Check if file exists, if not stream and download, else play
        -- Stream and play should be merged in the future
        if fileExists('clientHornFiles/'..hornid .. '.mp3') then
            hornSounds[player] = playSound3D( 'clientHornFiles/'..hornid .. '.mp3', x, y, z )
            if not hornSounds[player] or not isElement(hornSounds[player]) or isSoundPaused(hornSounds[player]) then
                hornSounds[player] = nil
                return
            end 
            setSoundMaxDistance(hornSounds[player], 50)
            setSoundSpeed(hornSounds[player], getGameSpeed() or 1) -- change horn pitch as gamespeed changes
            local length = getSoundLength(hornSounds[player])

            if isElement(hornIcons[vehicle]) then 
                destroyElement(hornIcons[vehicle])
                hornIcons[vehicle] = nil
            end
            hornIcons[vehicle] = guiCreateStaticImage(0, 0, 1, 1, "img/vip_horn_icon.png", false)
            guiSetVisible(hornIcons[vehicle], false)

            -- update horn icon position/alpha
            hornSoundTimer[player] = setTimer(function(sound,car, player)
                if not isElement(sound) or not isElement(car) or isSoundPaused(sound) then
                    -- Kill this timer
                    if isTimer(hornSoundTimer[player]) then
                        killTimer(hornSoundTimer[player])
                        hornSoundTimer[player] = nil
                    end
                    if isElement(sound) then
                        destroyElement(sound)
                    end
                    if isElement(hornIcons[car]) then
                        destroyElement(hornIcons[car])
                        hornIcons[car] = nil
                    end
                    return 
                end
                local rx, ry, rz = getElementPosition(car)
                setElementPosition(sound, rx, ry, rz)
                setSoundSpeed(sound, getGameSpeed() or 1) -- change horn pitch
                if showIcon then
                    local target = getCameraTarget()
                    local playerx, playery, playerz = false, false, false
                    if target then
                        playerx, playery, playerz = getElementPosition(target)
                    elseif getPedOccupiedVehicle(localPlayer) then
                        playerx, playery, playerz = getElementPosition(getPedOccupiedVehicle(localPlayer))
                    elseif hornIcons[car] and isElement(hornIcons[car]) then
                        guiSetAlpha( hornIcons[car], 0 )
                        return
                    else
                        return
                    end
                    local cp_x, cp_y, cp_z = getElementPosition(car)
                    local dist = getDistanceBetweenPoints3D(cp_x, cp_y, cp_z, playerx, playery, playerz)
                    if dist and dist < 40 then
                        local screenX, screenY = getScreenFromWorldPosition(cp_x, cp_y, cp_z)
                        local scaled = screenSizex * (1 / (2 * (dist + 5))) * .85
                        local relx, rely = scaled * globalHornScale, scaled * globalHornScale

                        guiSetAlpha(hornIcons[car], globalHornAlpha)
                        guiSetSize(hornIcons[car], relx, rely, false)
                        if (screenX and screenY) then
                            guiSetPosition(hornIcons[car], screenX - relx / 2, screenY - rely / 1.3, false)
                            guiSetVisible(hornIcons[car], true)
                        else
                            guiSetVisible(hornIcons[car], false)
                        end
                    else
                        guiSetVisible(hornIcons[car], false)
                    end
                end
            end,50,0,hornSounds[player],vehicle, player)
            -- Cleanup
            setTimer(function()
                if isTimer(hornSoundTimer[player]) then killTimer(hornSoundTimer[player]) end
                if isElement(hornSounds[player]) then destroyElement(hornSounds[player]) hornSounds[player] = nil end
                if isElement(hornIcons[vehicle]) then destroyElement(hornIcons[vehicle]) hornIcons[vehicle] = nil end
            end,length*1000,1)
        else
            -- Stream file, then request download from server
            triggerServerEvent('onClientRequestsVipHorn', resourceRoot, hornid)
            hornSounds[player] = playSound3D( vipHornURL..hornid, x, y, z )
            if not hornSounds[player] or not isElement(hornSounds[player]) or isSoundPaused(hornSounds[player]) then
                hornSounds[player] = nil
                return
            end 
            setSoundMaxDistance(hornSounds[player], 50)
            setSoundSpeed(hornSounds[player], getGameSpeed() or 1) -- change horn pitch as gamespeed changes

            local function handleVipHorn(suc, length, streamN, err)
                removeEventHandler('onClientSoundStream', hornSounds[player], handleVipHorn)
                if not suc or not length or length == 0 then outputDebugString('VIP horns: failed to stream '..tostring(streamN)..' - error:'..tostring(err)) return end
                if hornIcons[vehicle] and isElement(hornIcons[vehicle]) then
                    destroyElement(hornIcons[vehicle])
                end
                hornIcons[vehicle] = guiCreateStaticImage(0, 0, 1, 1, "img/vip_horn_icon.png", false)
                guiSetVisible(hornIcons[vehicle], false)

                -- update horn icon position/alpha
                hornSoundTimer[player] = setTimer(function(sound,car, player)
                    if not isElement(sound) or not isElement(car) or isSoundPaused(sound) then
                        -- Kill this timer
                        if isTimer(hornSoundTimer[player]) then
                            killTimer(hornSoundTimer[player])
                            hornSoundTimer[player] = nil
                        end
                        if isElement(sound) then
                            destroyElement(sound)
                        end
                        if isElement(hornIcons[car]) then
                            destroyElement(hornIcons[car])
                            hornIcons[car] = nil
                        end
                        return 
                    end
                    local rx, ry, rz = getElementPosition(car)
                    setElementPosition(sound, rx, ry, rz)
                    setSoundSpeed(sound, getGameSpeed() or 1) -- change horn pitch
                    if showIcon then
                        local target = getCameraTarget()
                        local playerx, playery, playerz = false, false, false
                        if target then
                            playerx, playery, playerz = getElementPosition(target)
                        elseif getPedOccupiedVehicle(localPlayer) then
                            playerx, playery, playerz = getElementPosition(getPedOccupiedVehicle(localPlayer))
                        elseif hornIcons[car] and isElement(hornIcons[car]) then
                            guiSetAlpha( hornIcons[car], 0 )
                            return
                        else
                            return
                        end
                        local cp_x, cp_y, cp_z = getElementPosition(car)
                        local dist = getDistanceBetweenPoints3D(cp_x, cp_y, cp_z, playerx, playery, playerz)
                        if dist and dist < 40 then
                            local screenX, screenY = getScreenFromWorldPosition(cp_x, cp_y, cp_z)
                            local scaled = screenSizex * (1 / (2 * (dist + 5))) * .85
                            local relx, rely = scaled * globalHornScale, scaled * globalHornScale

                            guiSetAlpha(hornIcons[car], globalHornAlpha)
                            guiSetSize(hornIcons[car], relx, rely, false)
                            if (screenX and screenY) then
                                guiSetPosition(hornIcons[car], screenX - relx / 2, screenY - rely / 1.3, false)
                                guiSetVisible(hornIcons[car], true)
                            else
                                guiSetVisible(hornIcons[car], false)
                            end
                        else
                            guiSetVisible(hornIcons[car], false)
                        end
                    end
                end,50,0,hornSounds[player],vehicle, player)
                -- Cleanup
                setTimer(function()
                    if isTimer(hornSoundTimer[player]) then killTimer(hornSoundTimer[player]) end
                    if isElement(hornSounds[player]) then destroyElement(hornSounds[player]) hornSounds[player] = nil end
                    if isElement(hornIcons[vehicle]) then destroyElement(hornIcons[vehicle]) hornIcons[vehicle] = nil end
                end,length*1000,1)
            end
            addEventHandler('onClientSoundStream',hornSounds[player],handleVipHorn)
        end
    end
end
addEvent('onClientVipUseHorn', true)
addEventHandler( 'onClientVipUseHorn', resourceRoot, playVipHorn)

-- Receive/checksums
function clientReceiveVipHorn(data, id)
    if data and type(id) == 'string' then
        id = id:gsub('.mp3', '')
        local file = fileCreate( vipHornPath .. id .. '.mp3' )
        fileWrite(file, data)
        fileClose(file)
        -- Set checksum, then save
        local checksum = getMD5(vipHornPath .. id .. '.mp3')
        if checksum then
            hornChecksums[id] = checksum
            saveChecksumTable()
        end
    end
end
addEvent('onServerSendsClientVipHorn', true)
addEventHandler('onServerSendsClientVipHorn', resourceRoot, clientReceiveVipHorn)

function checkVipHornsChecksum(receivedChecksums)
    if type(receivedChecksums) ~= 'table' then return end
    -- Check what horns need to be downloaded from the server
    for id, checksum in pairs(receivedChecksums) do
        if not hornChecksums[id] or hornChecksums[id] ~= checksum then
            -- file either does not exist, or changed. Download from server
            triggerServerEvent('onClientRequestsVipHorn', resourceRoot, id)
        end
    end
end
addEvent('onServerSendVipHornChecksum', true)
addEventHandler('onServerSendVipHornChecksum', resourceRoot, checkVipHornsChecksum)

--

function previewVipHorn()
    local selected = guiGridListGetSelectedItem(gui['vipHornGridList'])
    if not selected or selected == -1 then return end
    local hornid = guiGridListGetItemData( gui['vipHornGridList'], selected, 1 )
    if hornid then
        playSound(vipHornURL..hornid)
    end
end

function cancelVipHornOnGcHornUsage(_, car)
    if isElement(source) and getElementType(source) == 'player' and hornSounds[source] then
        -- Stop VIP horn when player triggered GC horn
        if isTimer(hornSoundTimer[source]) then
            killTimer(hornSoundTimer[source])
            hornSoundTimer[source] = nil
        end
        if isElement(hornSounds[source]) then
            destroyElement(hornSounds[source])
        end
        if isElement(hornIcons[car]) then
            destroyElement(hornIcons[car])
            hornIcons[car] = nil
        end

    end
end
addEvent('onPlayerUsingHorn', true)
addEventHandler('onPlayerUsingHorn', root, cancelVipHornOnGcHornUsage)

-- KeyBinding horns
bindHornGui = {
    button = {},
    window = {},
    label = {}
}
addEventHandler("onClientResourceStart", resourceRoot,
    function()
        local screenW, screenH = guiGetScreenSize()
        bindHornGui.window[1] = guiCreateWindow((screenW - 353) / 2, (screenH - 137) / 2, 353, 137, "VIP Horn Keybind", false)
        guiSetProperty( bindHornGui.window[1], 'AlwaysOnTop', 'True' )
        guiSetVisible( bindHornGui.window[1], false )
        guiWindowSetMovable(bindHornGui.window[1], false)
        guiWindowSetSizable(bindHornGui.window[1], false)
        bindHornGui.button[1] = guiCreateButton(129, 97, 96, 30, "Cancel", false, bindHornGui.window[1])
        addEventHandler( 'onClientGUIClick', bindHornGui.button[1], cancelHornBind, false)
        bindHornGui.label[1] = guiCreateLabel(38, 33, 272, 24, "Press a key to bind the selected horn to", false, bindHornGui.window[1])
        guiLabelSetHorizontalAlign(bindHornGui.label[1], "center", true)
        bindHornGui.label[2] = guiCreateLabel(38, 65, 274, 22, "Press escape to clear the current bind", false, bindHornGui.window[1])
        guiSetFont(bindHornGui.label[2], "default-bold-small")
        guiLabelSetHorizontalAlign(bindHornGui.label[2], "center", false)    
    end
)


function bindVipHorn(selected)
    local hornid = guiGridListGetItemData( gui['vipHornGridList'], selected, 1 )
    if not hornid then return false end
    selectedHornForBind = hornid
    -- Show gui
    guiSetEnabled( gui["vip_horn_bind"], false )
    guiSetVisible( bindHornGui.window[1], true )
    -- Add eventhandler
    removeEventHandler("onClientKey", root, getKeyForHorn)
    addEventHandler("onClientKey", root, getKeyForHorn)
end

function getKeyForHorn(keyNew)
    if keyNew == 'mouse1' then return end
    guiGridListSetSelectedItem( gui['vipHornGridList'], -1, -1)
    cancelEvent()
    removeEventHandler("onClientKey", root, getKeyForHorn)
    guiSetVisible( bindHornGui.window[1], false )
    if keyNew == "escape" then
        -- Clear bind
        bindKeyToHorn(false, selectedHornForBind)
    else
        bindKeyToHorn(keyNew, selectedHornForBind)
    end
    guiSetEnabled( gui["vip_horn_bind"], true )
end

function cancelHornBind()
    guiSetEnabled( gui["vip_horn_bind"], true )
    selectedHornForBind = false
    guiSetVisible( bindHornGui.window[1], false )
end

function bindKeyToHorn(key, hornid)
    for _, row in ipairs(hornTable) do
        if hornid == row.forumid..'-'..row.hornid then
            if row.boundkey and row.boundkey == key then return false end
            triggerServerEvent('onClientVipHornBindsChanged', resourceRoot, key or false, hornid)
        end
    end
end

-- VIP Checksum load/save
function saveChecksumTable()
    if type(hornChecksums) ~= 'table' then
        loadChecksumTable() 
        return
    end
    local xmlFile = xmlLoadFile( vipHornPath .. 'checksums.xml' )
    local child = xmlFindChild( xmlFile, 'checksumObject', 0 )
    local jsonTable = toJSON(hornChecksums)
    if not xmlFile or not child or not jsonTable then
        if xmlFile then xmlUnloadFile( xmlFile ) end
        loadChecksumTable() 
        return 
    end
    xmlNodeSetAttribute( child, 'json', jsonTable)
    xmlSaveFile( xmlFile )
    xmlUnloadFile( xmlFile )
end

function loadChecksumTable()
    local exists = fileExists( vipHornPath .. 'checksums.xml' )
    local xmlFile = false
    if not exists then
        -- Create file
        xmlFile = xmlCreateFile( vipHornPath .. 'checksums.xml', 'checksums' )
        local child = xmlCreateChild( xmlFile, 'checksumObject' )
        xmlNodeSetAttribute( child, 'json', '' )
        xmlSaveFile( xmlFile )
        xmlUnloadFile( xmlFile )
        hornChecksums = {}
        return
    else
        xmlFile = xmlLoadFile( vipHornPath .. 'checksums.xml' )
        local child = xmlFindChild( xmlFile, 'checksumObject', 0 )
        local value = xmlNodeGetAttribute( child, 'json' )
        local valueTable = false
        if value == '' or type(value) ~= 'string' then
            valueTable = {}
        else
            valueTable = fromJSON(value)
        end
        if not xmlFile or not child or not value or type(valueTable) ~= 'table' then
            -- If we couldnt parse, remove and create new
            if xmlFile then xmlUnloadFile( xmlFile ) end
            fileDelete( vipHornPath .. 'checksums.xml' )
            loadChecksumTable()
            return
        else
            hornChecksums = valueTable
            xmlUnloadFile( xmlFile )
        end
    end
end
addEventHandler('onClientResourceStart', resourceRoot, loadChecksumTable)
