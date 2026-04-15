local Triggrd = ...;

-- the shittiest enum in existence
local appEvents = {
    [hs.application.watcher.activated] = "activated",
    [hs.application.watcher.deactivated] = "deactivated",
    [hs.application.watcher.hidden] = "hidden",
    [hs.application.watcher.launched] = "launched",
    [hs.application.watcher.launching] = "launching",
    [hs.application.watcher.terminated] = "terminated",
    [hs.application.watcher.unhidden] = "unhidden"
}

Triggrd.appWatcher = hs.application.watcher.new(function(name, type, app)
    Triggrd:handleEvent({
        tags = {"app", appEvents[type], name},
        data = {
            app = app,
            textArgs = {name, appEvents[type]}
        }
    })
    updateAppList(type, app)
end)
Triggrd.appWatcher:start()

local caffEvents = {
    [hs.caffeinate.watcher.screensaverDidStart] = "screensaverDidStart",
    [hs.caffeinate.watcher.screensaverDidStop] = "screensaverDidStop",
    [hs.caffeinate.watcher.screensaverWillStop] = "screensaverWillStop",
    [hs.caffeinate.watcher.screensDidLock] = "screensDidLock",
    [hs.caffeinate.watcher.screensDidSleep] = "screensDidSleep",
    [hs.caffeinate.watcher.screensDidUnlock] = "screensDidUnlock",
    [hs.caffeinate.watcher.screensDidWake] = "screensDidWake",
    [hs.caffeinate.watcher.sessionDidBecomeActive] = "sessionDidBecomeActive",
    [hs.caffeinate.watcher.sessionDidResignActive] = "sessionDidResignActive",
    [hs.caffeinate.watcher.systemDidWake] = "systemDidWake",
    [hs.caffeinate.watcher.systemWillPowerOff] = "systemWillPowerOff",
    [hs.caffeinate.watcher.systemWillSleep] = "systemWillSleep"
}

Triggrd.caffWatcher = hs.caffeinate.watcher.new(function(type)
    Triggrd:handleEvent({
        tags = {"caff", caffEvents[type]},
        data = {
            textArgs = {caffEvents[type]}
        }
    })
end)
Triggrd.caffWatcher:start()

Triggrd.usbWatcher = hs.usb.watcher.new(function(usbInfo)
    Triggrd:handleEvent({
        tags = {"usb", usbInfo.eventType, usbInfo.productName},
        data = {
            eventInfo = usbInfo,
            textArgs = {usbInfo.productName, ((usbInfo.eventType == "added") and "connected" or "disconnected")}
        }
    })
end)
Triggrd.usbWatcher:start()

Triggrd.spacesWatcher = hs.spaces.watcher.new(function(spaceNumber)
    Triggrd:handleEvent({
        tags = {"spacechanged", "space" .. spaceNumber},
        data = {
            spaceNumber = spaceNumber,
            textArgs = {spaceNumber}
        }
    })
end)
Triggrd.spacesWatcher:start()

Triggrd.pasteboardWatcher = hs.pasteboard.watcher.new(function(pasteboard)
    Triggrd:handleEvent({
        tags = {"pasteboard", pasteboard},
        data = {
            contents = pasteboard,
            textArgs = {pasteboard}
        }
    })
end)
Triggrd.pasteboardWatcher:start()

if hs.battery.batteryType==nil then
-- for some amount of filename convention
local powerSourceFilenames = {
    ["AC Power"] = "onAC",
    ["Battery Power"] = "onBattery",
    ["Off Line"] = "offline"
}

Triggrd.lastBatteryState = hs.battery.getAll()

Triggrd.batteryWatcher = hs.battery.watcher.new(function()
    local batteryState = hs.battery.getAll()
    if batteryState.isCharging ~= Triggrd.lastBatteryState.isCharging then
        Triggrd:handleEvent({
            tags = {"battery", batteryState.isCharging and "charging" or "notCharging"},
            data = {
                batteryState = batteryState
            }
        })
    end
    if batteryState.percentage ~= Triggrd.lastBatteryState.percentage then
        Triggrd:handleEvent({
            tags = {"battery", "level", tostring(batteryState.percentage) .. "percent",
                    (batteryState.percentage > Triggrd.lastBatteryState.percentage) and "up" or "down"},
            data = {
                batteryState = batteryState,
                textArgs = {tostring(batteryState.percentage)}
            }
        })
    end
    if batteryState.powerSource ~= Triggrd.lastBatteryState.powerSource then
        Triggrd:handleEvent({
            tags = {"power", powerSourceFilenames[batteryState.powerSource]},
            data = {
                batteryState = batteryState,
                textArgs = {tostring(batteryState.powerSource)}
            }
        })
    end
    Triggrd.lastBatteryState = batteryState
end)
Triggrd.batteryWatcher:start()
end

Triggrd.screenWatcher = hs.screen.watcher.newWithActiveScreen(function()
    Triggrd:handleEvent({
        tags = {"screenchanged"}
    })
end)
Triggrd.screenWatcher:start()

-- I'm tired of these shitty enums, is there a better way to do this?
local volumeEvents = {
    [hs.fs.volume.didMount] = "didMount",
    [hs.fs.volume.didRename] = "didRename",
    [hs.fs.volume.didUnmount] = "didUnmount",
    [hs.fs.volume.willUnmount] = "willUnmount"
}

Triggrd.volumeWatcher = hs.fs.volume.new(function(eventType, volumeInfo)
if not volumeInfo.path:lower():find("timemachine") then
    Triggrd:handleEvent({
        tags = {"volume", volumeEvents[eventType]},
        data = {
            volumeInfo = volumeInfo,
            textArgs = {volumeInfo.NSURLVolumeNameKey}
        }
    })
end
end)
Triggrd.volumeWatcher:start()

function updateAppList(eventType, app)
    if eventType == hs.application.watcher.launched then
        for _, i in ipairs(Triggrd.runningApps) do
            if i[1] == app then
                return
            end
        end
        table.insert(Triggrd.runningApps, Triggrd.generateAppListItem(Triggrd, app))
    elseif eventType == hs.application.watcher.terminated then
        Triggrd.runningApps = hs.fnutils.ifilter(Triggrd.runningApps, function(i)
            -- Quick attempted fix, there is probably a cleaner way
            if i[1] == app and i[3] ~= nil then
                i[3]:stop()
            end
            return i[1] ~= app
        end)
    end
end

Triggrd.lastWifiRSSI = nil
Triggrd.lastWifiNetwork = hs.wifi.currentNetwork()

Triggrd.wifiWatcher = hs.wifi.watcher.new(function(watcher, message, interface, rssi, transmitRate)
    -- check for connect/disconnect/SSIDChange on every event
    local network = hs.wifi.currentNetwork(interface)
    if network ~= Triggrd.lastWifiNetwork then
        local wasConnected = Triggrd.lastWifiNetwork ~= nil
        Triggrd.lastWifiNetwork = network
        if network and not wasConnected then
            Triggrd:handleEvent({
                tags = {"wifi", "connect", network},
                data = {
                    interface = interface,
                    network = network,
                    textArgs = {network}
                }
            })
        elseif network and wasConnected then
            Triggrd:handleEvent({
                tags = {"wifi", "SSIDChange", network},
                data = {
                    interface = interface,
                    network = network,
                    textArgs = {network}
                }
            })
        elseif not network and wasConnected then
            Triggrd:handleEvent({
                tags = {"wifi", "disconnect"},
                data = {
                    interface = interface,
                    textArgs = {interface or "unknown"}
                }
            })
        end
    end

    if message == "BSSIDChange" then
        local details = hs.wifi.interfaceDetails(interface)
        local bssid = details and details.bssid or "unknown"
        Triggrd:handleEvent({
            tags = {"wifi", "BSSIDChange"},
            data = {
                interface = interface,
                bssid = bssid,
                textArgs = {bssid}
            }
        })
    elseif message == "countryCodeChange" then
        local details = hs.wifi.interfaceDetails(interface)
        local countryCode = details and details.countryCode or "unknown"
        Triggrd:handleEvent({
            tags = {"wifi", "countryCodeChange", countryCode},
            data = {
                interface = interface,
                countryCode = countryCode,
                textArgs = {countryCode}
            }
        })
    elseif message == "linkQualityChange" then
        local absRSSI = math.abs(rssi)
        local tags = {"wifi", "linkQualityChange", "rssi" .. tostring(absRSSI)}
        if Triggrd.lastWifiRSSI then
            if rssi > Triggrd.lastWifiRSSI then
                table.insert(tags, "up")
            elseif rssi < Triggrd.lastWifiRSSI then
                table.insert(tags, "down")
            end
        end
        Triggrd.lastWifiRSSI = rssi
        Triggrd:handleEvent({
            tags = tags,
            data = {
                interface = interface,
                rssi = rssi,
                transmitRate = transmitRate,
                textArgs = {tostring(rssi), tostring(transmitRate)}
            }
        })
    elseif message == "modeChange" then
        Triggrd:handleEvent({
            tags = {"wifi", "modeChange"},
            data = {
                interface = interface,
                textArgs = {interface or "unknown"}
            }
        })
    elseif message == "powerChange" then
        local details = hs.wifi.interfaceDetails(interface)
        local power = details and details.power
        local powerTag = power and "powerOn" or "powerOff"
        Triggrd:handleEvent({
            tags = {"wifi", "powerChange", powerTag},
            data = {
                interface = interface,
                power = power,
                textArgs = {powerTag}
            }
        })
    elseif message == "scanCacheUpdated" then
        Triggrd:handleEvent({
            tags = {"wifi", "scanCacheUpdated"},
            data = {
                interface = interface,
                textArgs = {interface or "unknown"}
            }
        })
    end
end)
Triggrd.wifiWatcher:watchingFor("all")
Triggrd.wifiWatcher:start()

-- Internet reachability: passive route detection + active ping verification
Triggrd.lastInternetReachable = nil
Triggrd.ipv4Reachable = false
Triggrd.ipv6Reachable = false
Triggrd.pingInterval = 60
Triggrd.pingConsecutiveFailures = 0
Triggrd.pingConsecutiveSuccesses = 0
Triggrd.lastPingReachable = nil

-- Flap detection state
Triggrd.flapTransitions = {}
Triggrd.flapActive = false
Triggrd.flapReminderInterval = nil
Triggrd.flapReminderTimer = nil

local function pruneTransitions()
    local now = hs.timer.secondsSinceEpoch()
    local cutoff = now - Triggrd.flapWindow
    while #Triggrd.flapTransitions > 0 and Triggrd.flapTransitions[1] < cutoff do
        table.remove(Triggrd.flapTransitions, 1)
    end
end

local function stopFlapReminder()
    if Triggrd.flapReminderTimer then
        Triggrd.flapReminderTimer:stop()
        Triggrd.flapReminderTimer = nil
    end
    Triggrd.flapReminderInterval = nil
end

local function flapReminder()
    pruneTransitions()
    if #Triggrd.flapTransitions >= Triggrd.flapThreshold then
        -- still flapping, fire reminder and escalate interval
        print("internet: still flapping (" .. #Triggrd.flapTransitions
            .. " transitions in window, next reminder in "
            .. Triggrd.flapReminderInterval .. "s)")
        Triggrd:handleEvent({
            tags = {"internet", "flapping"},
            data = { textArgs = {tostring(#Triggrd.flapTransitions)} }
        })
        Triggrd.flapReminderInterval = math.min(
            Triggrd.flapReminderInterval * 2, Triggrd.flapReminderMax)
        Triggrd.flapReminderTimer = hs.timer.doAfter(
            Triggrd.flapReminderInterval, flapReminder)
    else
        -- no longer flapping
        Triggrd.flapActive = false
        stopFlapReminder()
        local routeExists = Triggrd.ipv4Reachable or Triggrd.ipv6Reachable
        if routeExists and Triggrd.lastPingReachable then
            print("internet: stable (flapping ended)")
            Triggrd:handleEvent({
                tags = {"internet", "stable"},
                data = { textArgs = {"stable"} }
            })
        else
            print("internet: flapping ended but still offline, suppressing stable event")
        end
    end
end

local function checkFlapping()
    pruneTransitions()
    local count = #Triggrd.flapTransitions
    if count >= Triggrd.flapThreshold and not Triggrd.flapActive then
        -- new flap episode
        Triggrd.flapActive = true
        Triggrd.flapReminderInterval = math.min(Triggrd.flapWindow, Triggrd.flapReminderMax)
        print("internet: flapping detected (" .. count .. " transitions in window)")
        Triggrd:handleEvent({
            tags = {"internet", "flapping"},
            data = { textArgs = {tostring(count)} }
        })
        -- schedule escalating reminders
        Triggrd.flapReminderTimer = hs.timer.doAfter(
            Triggrd.flapReminderInterval, flapReminder)
    end
end

local function updateInternetState()
    local routeExists = Triggrd.ipv4Reachable or Triggrd.ipv6Reachable
    -- active ping is authoritative once it has data; passive is the fast initial check
    local reachable
    if Triggrd.lastPingReachable ~= nil then
        reachable = Triggrd.lastPingReachable
    else
        reachable = routeExists
    end

    if reachable ~= Triggrd.lastInternetReachable then
        Triggrd.lastInternetReachable = reachable
        local tag = reachable and "reachable" or "unreachable"
        print("internet: " .. tag .. " (route=" .. tostring(routeExists)
            .. " ping=" .. tostring(Triggrd.lastPingReachable)
            .. " v4=" .. tostring(Triggrd.ipv4Reachable)
            .. " v6=" .. tostring(Triggrd.ipv6Reachable) .. ")")
        Triggrd:handleEvent({
            tags = {"internet", tag},
            data = { textArgs = {tag} }
        })
        -- record transition for flap detection
        table.insert(Triggrd.flapTransitions, hs.timer.secondsSinceEpoch())
        checkFlapping()
    end
end

-- Passive route watchers

Triggrd.reachabilityV4 = hs.network.reachability.forAddress("0.0.0.0")
Triggrd.reachabilityV4:setCallback(function(obj, flags)
    Triggrd.ipv4Reachable = obj:statusString():find("R") ~= nil
    updateInternetState()
end)
Triggrd.reachabilityV4:start()

Triggrd.reachabilityV6 = hs.network.reachability.forAddress("::")
Triggrd.reachabilityV6:setCallback(function(obj, flags)
    Triggrd.ipv6Reachable = obj:statusString():find("R") ~= nil
    updateInternetState()
end)
Triggrd.reachabilityV6:start()

-- Active ping checker

local function getPingTargets()
    local targets = {}
    for _, t in ipairs(Triggrd.pingTargetsV4) do
        table.insert(targets, t)
    end
    if Triggrd.ipv6Reachable then
        for _, t in ipairs(Triggrd.pingTargetsV6) do
            table.insert(targets, t)
        end
    end
    return targets
end

local function doPingCheck()
    local targets = getPingTargets()
    if #targets == 0 then
        -- no route at all, passive watcher handles this
        Triggrd.pingTimer = hs.timer.doAfter(Triggrd.pingInterval, doPingCheck)
        return
    end

    local function tryTarget(index)
        if index > #targets then
            -- all targets failed — drop to min interval immediately
            Triggrd.pingConsecutiveFailures = Triggrd.pingConsecutiveFailures + 1
            Triggrd.pingConsecutiveSuccesses = 0
            Triggrd.pingInterval = Triggrd.pingMinInterval
            print("ping: all targets failed (" .. Triggrd.pingConsecutiveFailures
                .. " consecutive, next check in " .. Triggrd.pingInterval .. "s)")
            local failTags = {"ping", "fail"}
            for _, t in ipairs(targets) do
                table.insert(failTags, t)
            end
            Triggrd:handleEvent({
                tags = failTags,
                data = { textArgs = {tostring(Triggrd.pingConsecutiveFailures)} }
            })
            if Triggrd.pingConsecutiveFailures >= Triggrd.pingConfirmThreshold then
                Triggrd.lastPingReachable = false
                updateInternetState()
            end
            Triggrd.pingTimer = hs.timer.doAfter(Triggrd.pingInterval, doPingCheck)
            return
        end

        local target = targets[index]
        local gotReply = false
        hs.network.ping.ping(target, 1, 1, 2, "any", function(self, message)
            if message == "receivedPacket" then
                gotReply = true
                self:cancel()
                Triggrd.pingConsecutiveSuccesses = Triggrd.pingConsecutiveSuccesses + 1
                Triggrd.pingConsecutiveFailures = 0
                Triggrd.pingInterval = math.min(Triggrd.pingInterval * 2, Triggrd.pingMaxInterval)
                print("ping: " .. target .. " ok (" .. Triggrd.pingConsecutiveSuccesses
                    .. " consecutive, next check in " .. Triggrd.pingInterval .. "s)")
                Triggrd:handleEvent({
                    tags = {"ping", "success", target},
                    data = { textArgs = {target} }
                })
                if Triggrd.pingConsecutiveSuccesses >= Triggrd.pingConfirmThreshold then
                    Triggrd.lastPingReachable = true
                    updateInternetState()
                end
                Triggrd.pingTimer = hs.timer.doAfter(Triggrd.pingInterval, doPingCheck)
            elseif message == "didFail" then
                tryTarget(index + 1)
            elseif message == "didFinish" and not gotReply then
                tryTarget(index + 1)
            end
        end)
    end

    tryTarget(1)
end

Triggrd.pingTimer = hs.timer.doAfter(Triggrd.pingInterval, doPingCheck)

-- Audio device events

local function getAudioDeviceNames()
    local names = {}
    for _, dev in ipairs(hs.audiodevice.allDevices()) do
        names[dev:name()] = true
    end
    return names
end

Triggrd.lastAudioDevices = getAudioDeviceNames()

hs.audiodevice.watcher.setCallback(function(event)
    if event == "dOut" then
        local dev = hs.audiodevice.defaultOutputDevice()
        local name = dev and dev:name() or "unknown"
        Triggrd:handleEvent({
            tags = {"audiodevice", "defaultOutputChanged", name},
            data = { textArgs = {name} }
        })
    elseif event == "dIn " then
        local dev = hs.audiodevice.defaultInputDevice()
        local name = dev and dev:name() or "unknown"
        Triggrd:handleEvent({
            tags = {"audiodevice", "defaultInputChanged", name},
            data = { textArgs = {name} }
        })
    elseif event == "dev#" then
        local current = getAudioDeviceNames()
        -- detect added devices
        for name, _ in pairs(current) do
            if not Triggrd.lastAudioDevices[name] then
                Triggrd:handleEvent({
                    tags = {"audiodevice", "added", name},
                    data = { textArgs = {name} }
                })
            end
        end
        -- detect removed devices
        for name, _ in pairs(Triggrd.lastAudioDevices) do
            if not current[name] then
                Triggrd:handleEvent({
                    tags = {"audiodevice", "removed", name},
                    data = { textArgs = {name} }
                })
            end
        end
        Triggrd.lastAudioDevices = current
    end
end)
hs.audiodevice.watcher.start()
