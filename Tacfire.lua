tacfire = {}

do
    
    local configDefaults = {
        ["MARKER_PREFIX"] = "[TACFIRE]",
        ["ARTILLERY_UNIT_TYPES"] = {
            ["M-109"] = true,
        },
    }
    local config = {}
    local artilleryGroups = {}
    local artilleryMenu = nil
    local fireMissionsMenuDB = {}

    local function log(tmpl, ...)
        local txt = string.format("[TACFIRE] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30) 
        end

        env.info(txt)
    end

    local function getArtilleryGroups(allGroups, whitelist)
        for i,group in ipairs(allGroups) do

            for i,u in ipairs(group.units) do
                if whitelist[u.type] then
                    table.insert(artilleryGroups, env.getValueDictByKey(group.name))
                    break
                end
            end
        end
    end

    local function buildConfig()
        local cfg = mist.utils.deepCopy(configDefaults)
        
        if tacfire.config then
            for k,v in pairs(tacfire.config) do
                cfg[k] = v
            end
        end

        return cfg
    end

    local function messageToAll(txt)
        trigger.action.outTextForCoalition(coalition.side.BLUE, txt, 10)
    end

    local function displayInstructions()
        local txt = "To create a fire mission, place a markpoint on the map with the following label:\n\n"
        txt = txt .. string.format("%s: <somename>\n\n", config.MARKER_PREFIX)
        txt = txt .. "Once this markpoint has been created, you can call in the fire mission from F10\n\n"
        txt = txt .. "If you call in an invalid fire mission (target is out of range), the artillery unit will not respond"
        messageToAll(txt)
    end

    function executeFireMission(params)
        local tacfire = Group.getByName(params.group)
        if not tacfire then
            log("Warning, no artillery group found")
            return
        end

        tacfire:getController():pushTask({
            id = "FireAtPoint",
            params = {
                point = params.point,
                radius = 100, 
                expendQty = 40,
                expendQtyEnabled = true,
            }
        })

        messageToAll(string.format("%s commencing fire mission", params.group))
    end

    local function ctldCallback(args)
        if args.action ~= "unpack" or not args.spawnedGroup then
            return
        end

        local group = args.spawnedGroup
        local  groupName = group:getName()

        for i,unit in ipairs(group:getUnits()) do
            if config.ARTILLERY_UNIT_TYPES[unit:getTypeName()] then
                table.insert(artilleryGroups, groupName)
                break
            end
        end
    end

    local function initCTLDTracking()
        if ctld == nil or ctld.addCallback == nil then
            log("CTLD not present, skipping CTLD tracking")
            return
        end
    
        ctld.addCallback(ctldCallback)
    end

    function eventHandler(event)
        if event.id == world.event.S_EVENT_MARK_ADDED or event.id == world.event.S_EVENT_MARK_CHANGE then
            if string.match(event.text, config.MARKER_PREFIX) then
                local subMenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, event.text, artilleryMenu)

                for i,groupName in ipairs(artilleryGroups) do
                    missionCommands.addCommandForCoalition(coalition.side.BLUE, groupName, subMenu, executeFireMission, {
                        group = groupName,
                        point = { 
                            x = event.pos.x, 
                            y = event.pos.z 
                        }
                    })
                end

                fireMissionsMenuDB[event.text] = subMenu

                messageToAll("Artillery fire mission added")
            end
        end

        if event.id == world.event.S_EVENT_MARK_REMOVE then
            missionCommands.removeItemForCoalition(coalition.side.BLUE, fireMissionsMenuDB[event.text])
        end
    end

    config = buildConfig()

    for i,c in ipairs(env.mission.coalition.blue.country) do
        if (c.vehicle) then
            getArtilleryGroups(c.vehicle.group, config.ARTILLERY_UNIT_TYPES)
        end
    end
    

    artilleryMenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "Artillery Fire Missions")
    missionCommands.addCommandForCoalition(coalition.side.BLUE, "Instructions", artilleryMenu, displayInstructions)

    mist.addEventHandler(eventHandler)
    initCTLDTracking()

    -- Use to test doing a CTLD unpack
    -- ctldCallback({ action="unpack", spawnedGroup=Group.getByName("Ground-1") })
end

