local TAG = "[NeverNight]"
local UEHelpers = require("UEHelpers")

local TARGET_TIME = 0.50
local time_enabled = true
local time_attempts = 0
local time_successes = 0
local last_time_success = "not applied yet"
local last_logged_time_success = ""
local begin_play_scheduled = false
local survival_guard_active = false

local function log(message)
    print(string.format("%s %s\n", TAG, message))
end

local function notify(message)
    log(message)

    local controller = UEHelpers.GetPlayerController()
    if is_valid(controller) then
        pcall(function()
            controller:ClientMessage("SN2: " .. message, FName("Event"), 4.0)
        end)
    end

    local kismet = UEHelpers.GetKismetSystemLibrary()
    if is_valid(kismet) then
        pcall(function()
            kismet:PrintString(UEHelpers.GetWorldContextObject(), "SN2: " .. message, true, true, { R = 0.2, G = 0.9, B = 1.0, A = 1.0 }, 4.0)
        end)
    end
end

local function is_valid(object)
    if object == nil then
        return false
    end

    local ok, valid = pcall(function()
        return object:IsValid()
    end)

    return ok and valid == true
end

local function object_name(object)
    local ok, value = pcall(function()
        return object:GetFullName()
    end)

    if ok and value ~= nil then
        return tostring(value)
    end

    return "<unknown object>"
end

local function object_short_name(object)
    local ok, fname = pcall(function()
        return object:GetFName()
    end)

    if ok and fname ~= nil then
        local ok_string, value = pcall(function()
            return fname:ToString()
        end)
        if ok_string and value ~= nil then
            return tostring(value)
        end
    end

    return ""
end

local function add_object(object, output, seen)
    if not is_valid(object) then
        return
    end

    local ok, address = pcall(function()
        return object:GetAddress()
    end)
    local key = ok and tostring(address) or object_name(object)

    if seen[key] then
        return
    end

    seen[key] = true
    output[#output + 1] = object
end

local function collect_from_class(class_name, output, seen)
    local objects = FindAllOf(class_name)
    if objects == nil then
        return
    end

    for _, object in pairs(objects) do
        add_object(object, output, seen)
    end
end

local function call_noarg_any(object, method_name)
    local ok, value = pcall(function()
        return object[method_name](object)
    end)

    if ok then
        return value
    end

    return nil
end

local function call_noarg_object(object, method_name)
    local value = call_noarg_any(object, method_name)
    if is_valid(value) then
        return value
    end

    return nil
end

local function call_one_number(object, method_name, value)
    local ok = pcall(function()
        object[method_name](object, value)
    end)

    return ok
end

local function read_number_method(object, method_name)
    local value = call_noarg_any(object, method_name)
    if type(value) == "number" then
        return value
    end

    return nil
end

local function read_struct_number(value)
    if value == nil or type(value) ~= "userdata" then
        return nil
    end

    for _, field_name in ipairs({ "CurrentValue", "BaseValue" }) do
        local ok, field_value = pcall(function()
            return value[field_name]
        end)
        if ok and type(field_value) == "number" then
            return field_value
        end
    end

    return nil
end

local function read_number_property(object, property_name)
    local ok, value = pcall(function()
        return object:GetPropertyValue(property_name)
    end)

    if ok then
        if type(value) == "number" then
            return value
        end
        return read_struct_number(value)
    end

    return nil
end

local function find_property_in_hierarchy(object, property_name)
    if not is_valid(object) then
        return nil
    end

    local class = object:GetClass()
    while is_valid(class) do
        local found = nil
        pcall(function()
            class:ForEachProperty(function(property)
                if property:GetFName():ToString() == property_name then
                    found = property
                    return true
                end
                return false
            end)
        end)

        if found ~= nil and found:IsValid() then
            return found
        end

        local ok, super = pcall(function()
            return class:GetSuperStruct()
        end)
        if not ok then
            return nil
        end
        class = super
    end

    return nil
end

local function import_property(object, property_name, text_value)
    local ok, changed = pcall(function()
        local property = object:Reflection():GetProperty(property_name)
        if property ~= nil and property:IsValid() then
            property:ImportText(text_value, property:ContainerPtrToValuePtr(object), 0, object)
            return true
        end

        property = find_property_in_hierarchy(object, property_name)
        if property ~= nil and property:IsValid() then
            property:ImportText(text_value, property:ContainerPtrToValuePtr(object), 0, object)
            return true
        end

        return false
    end)

    return ok and changed == true
end

local function import_number_property(object, property_name, value)
    local variants = {
        tostring(value),
        string.format("%.6f", value),
        string.format("(BaseValue=%.6f,CurrentValue=%.6f)", value, value),
        string.format("(CurrentValue=%.6f,BaseValue=%.6f)", value, value)
    }

    for _, text_value in ipairs(variants) do
        if import_property(object, property_name, text_value) then
            return true
        end
    end

    return false
end

local function try_time_object(object, source)
    if not is_valid(object) then
        return false
    end

    local touched = false
    if call_one_number(object, "SetTimeOfDaySpeed", 0.0) then touched = true end
    if call_one_number(object, "SetTimeOfDay", TARGET_TIME) then touched = true end
    if call_one_number(object, "SetTimeOfDayPreview", TARGET_TIME) then touched = true end
    if import_property(object, "bRunDayCycle", "False") then touched = true end
    if import_property(object, "bSetTimeOfDay", "True") then touched = true end
    if import_property(object, "DayNightCycleTime", tostring(TARGET_TIME)) then touched = true end
    if import_property(object, "InitialTimeOfDay", tostring(TARGET_TIME)) then touched = true end
    if import_property(object, "TimeOfDay", tostring(TARGET_TIME)) then touched = true end
    if import_property(object, "DayNightCycleMode", "FixedTime") then touched = true end

    if touched then
        last_time_success = string.format("%s via %s", object_name(object), source)
    end

    return touched
end

local function collect_time_objects()
    local objects = {}
    local seen = {}
    collect_from_class("UWETimeOfDayComponent", objects, seen)
    collect_from_class("TimeOfDayComponent", objects, seen)
    collect_from_class("DaySequenceActor", objects, seen)
    collect_from_class("SunMoonDaySequenceActor", objects, seen)

    local sky_actors = {}
    collect_from_class("SkyActor", sky_actors, {})
    collect_from_class("BP_UWESky_C", sky_actors, {})

    for _, sky_actor in pairs(sky_actors) do
        add_object(sky_actor, objects, seen)
        local component = call_noarg_object(sky_actor, "GetTimeOfDayComponent")
        if is_valid(component) then add_object(component, objects, seen) end

        local ok, property_component = pcall(function()
            return sky_actor:GetPropertyValue("TimeOfDayComponent")
        end)
        if ok and is_valid(property_component) then add_object(property_component, objects, seen) end
    end

    return objects
end

local function apply_never_night(reason)
    if not time_enabled then
        return false
    end

    time_attempts = time_attempts + 1
    local touched = 0
    for _, object in pairs(collect_time_objects()) do
        if try_time_object(object, reason) then touched = touched + 1 end
    end

    if touched > 0 then
        time_successes = time_successes + 1
        if time_successes == 1 or time_successes % 12 == 0 or last_time_success ~= last_logged_time_success then
            last_logged_time_success = last_time_success
            log(string.format("held time %.2f on %d object(s); last=%s", TARGET_TIME, touched, last_time_success))
        end
    elseif time_attempts == 1 or time_attempts % 10 == 0 then
        log(string.format("no time object found yet after %d attempt(s)", time_attempts))
    end

    return touched > 0
end

local function remember_key(object, keys)
    if is_valid(object) then
        local short_name = object_short_name(object)
        if short_name ~= "" then keys[#keys + 1] = short_name end
    end
end

local function get_player_refs()
    local refs = {}
    local seen = {}
    local keys = {}

    local controller = UEHelpers.GetPlayerController()
    add_object(controller, refs, seen)
    remember_key(controller, keys)

    if is_valid(controller) then
        local ok_state, player_state = pcall(function() return controller.PlayerState end)
        if ok_state then
            add_object(player_state, refs, seen)
            remember_key(player_state, keys)
        end

        local ok_pawn, pawn = pcall(function() return controller.Pawn end)
        if ok_pawn then
            add_object(pawn, refs, seen)
            remember_key(pawn, keys)
        end
    end

    local player = UEHelpers.GetPlayer()
    add_object(player, refs, seen)
    remember_key(player, keys)

    return refs, keys, seen
end

local function name_matches_any_key(object, keys)
    local name = object_name(object)
    for _, key in ipairs(keys) do
        if key ~= "" and name:find(key, 1, true) ~= nil then return true end
    end
    return false
end

local function collect_vital_objects()
    local objects, keys, seen = get_player_refs()

    local function collect_player_components(class_name)
        local components = FindAllOf(class_name)
        if components == nil then return end

        for _, component in pairs(components) do
            if name_matches_any_key(component, keys) then add_object(component, objects, seen) end
        end
    end

    collect_player_components("UWESurvivalSetComponent")
    collect_player_components("SurvivalSetComponent")
    collect_player_components("UWEHealthSetComponent")
    collect_player_components("HealthSetComponent")
    collect_player_components("AbilitySystemComponent")

    return objects
end

local function max_for(object, method_name, property_name, fallback)
    return read_number_method(object, method_name) or read_number_property(object, property_name) or fallback
end

local function mark(touched, name)
    touched[name] = true
end

local function try_fill_vitals_object(object)
    if not is_valid(object) then return {} end

    local touched = {}
    local max_health = max_for(object, "GetMaxHealth", "MaxHealth", 100.0)
    local max_food = max_for(object, "GetMaxFood", "MaxFood", 100.0)
    local max_water = max_for(object, "GetMaxWater", "MaxWater", 100.0)
    local max_oxygen = max_for(object, "GetMaxOxygen", "MaxOxygen", 100.0) or read_number_property(object, "MaxOxygenLevel") or 100.0

    if call_one_number(object, "SetHealth", max_health) then mark(touched, "health") end
    if call_noarg_any(object, "RestoreHealth") ~= nil then mark(touched, "health") end
    if import_number_property(object, "Health", max_health) then mark(touched, "health") end
    if import_number_property(object, "Food", max_food) then mark(touched, "food") end
    if import_number_property(object, "Water", max_water) then mark(touched, "water") end
    if call_one_number(object, "SetOxygenLevel", max_oxygen) then mark(touched, "oxygen") end
    if import_number_property(object, "Oxygen", max_oxygen) then mark(touched, "oxygen") end
    if import_number_property(object, "OxygenLevel", max_oxygen) then mark(touched, "oxygen") end

    return touched
end

local function fill_vitals_once(reason)
    local touched = {}
    local object_count = 0

    for _, object in pairs(collect_vital_objects()) do
        local object_touched = try_fill_vitals_object(object)
        local did_touch_object = false
        for name, value in pairs(object_touched) do
            if value then
                touched[name] = true
                did_touch_object = true
            end
        end
        if did_touch_object then object_count = object_count + 1 end
    end

    local names = {}
    for _, name in ipairs({ "health", "food", "water", "oxygen" }) do
        if touched[name] then names[#names + 1] = name end
    end

    if #names == 0 then
        notify(string.format("%s: no player vitals object accepted refill yet", reason))
    else
        notify(string.format("%s: refilled %s on %d player object(s)", reason, table.concat(names, ", "), object_count))
    end
end

local function run_console_command(command)
    local controller = UEHelpers.GetPlayerController()
    if not is_valid(controller) then
        return false
    end

    local ok = pcall(function()
        controller:ConsoleCommand(command, true)
    end)
    if ok then
        return true
    end

    ok = pcall(function()
        controller:ProcessConsoleExec(command, nil, controller)
    end)

    return ok
end

local function toggle_survival_guard(reason)
    local commands = {
        "Cheat.NoDehydrate",
        "Cheat.NoStarve",
        "Cheat.NoSuffocate",
        "Cheat.UnlimitedHealth"
    }

    local ok_count = 0
    for _, command in ipairs(commands) do
        if run_console_command(command) then
            ok_count = ok_count + 1
        end
    end

    notify(string.format("%s: toggled survival guard commands (%d/%d)", reason, ok_count, #commands))
end

local function pulse_survival_guard(reason)
    if survival_guard_active then
        notify(reason .. ": survival guard already active")
        return
    end

    survival_guard_active = true
    toggle_survival_guard(reason .. " on")

    ExecuteWithDelay(10000, function()
        ExecuteInGameThread(function()
            toggle_survival_guard(reason .. " off")
            survival_guard_active = false
        end)
    end)
end

local function contains_vital_token(value)
    if value == nil then return false end
    local lower = string.lower(tostring(value))
    return lower:find("health", 1, true) ~= nil
        or lower:find("food", 1, true) ~= nil
        or lower:find("water", 1, true) ~= nil
        or lower:find("oxygen", 1, true) ~= nil
        or lower:find("survival", 1, true) ~= nil
        or lower:find("thirst", 1, true) ~= nil
        or lower:find("hunger", 1, true) ~= nil
end

local function log_vital_object(label, object)
    if not is_valid(object) then
        log(label .. ": <invalid>")
        return
    end

    log(label .. ": " .. object_name(object))
    local class = object:GetClass()
    while is_valid(class) do
        log(label .. " class: " .. object_name(class))
        pcall(function()
            class:ForEachProperty(function(property)
                local property_name = property:GetFName():ToString()
                if contains_vital_token(property_name) then log(label .. " property " .. property_name) end
                return false
            end)
        end)
        pcall(function()
            class:ForEachFunction(function(func)
                local function_name = func:GetFName():ToString()
                if contains_vital_token(function_name) then log(label .. " function " .. function_name) end
                return false
            end)
        end)
        local ok, super = pcall(function() return class:GetSuperStruct() end)
        if not ok then break end
        class = super
    end
end

local function diagnose_vitals(reason)
    log("vitals probe started: " .. reason)
    for index, object in ipairs(collect_vital_objects()) do
        if index > 12 then break end
        log_vital_object("vital[" .. tostring(index) .. "]", object)
    end
    log("vitals probe complete")
end

local function print_help()
    log("commands: nevernight_on, nevernight_off, nevernight_status, nevernight_noon")
    log("commands: survival_100 / vitals_100 / hydrate / water_100 = one-shot refill")
    log("commands: survival_guard_10s = temporary no thirst/starve/suffocate/health damage")
    log("commands: vitals_probe = log player vitals objects")
    log("hotkey: F5 (or fn+F5) = survival_100 + survival_guard_10s")
end

local function schedule_time_apply(reason, delay_ms)
    ExecuteWithDelay(delay_ms, function()
        ExecuteInGameThread(function() apply_never_night(reason) end)
    end)
end

RegisterConsoleCommandGlobalHandler("nevernight_on", function()
    time_enabled = true
    notify("day mode on")
    ExecuteInGameThread(function() apply_never_night("console on") end)
    return true
end)

RegisterConsoleCommandGlobalHandler("nevernight_off", function()
    time_enabled = false
    notify("day mode off")
    return true
end)

RegisterConsoleCommandGlobalHandler("nevernight_status", function()
    log(string.format("enabled=%s attempts=%d last_success=%s", tostring(time_enabled), time_attempts, last_time_success))
    return true
end)

RegisterConsoleCommandGlobalHandler("nevernight_noon", function()
    TARGET_TIME = 0.50
    time_enabled = true
    notify("day mode on")
    ExecuteInGameThread(function() apply_never_night("console noon") end)
    return true
end)

RegisterConsoleCommandGlobalHandler("day", function()
    TARGET_TIME = 0.50
    time_enabled = true
    notify("day mode on")
    ExecuteInGameThread(function() apply_never_night("day") end)
    return true
end)

RegisterConsoleCommandGlobalHandler("nevernight_help", function() print_help(); return true end)
RegisterConsoleCommandGlobalHandler("sn2_help", function() print_help(); return true end)

RegisterConsoleCommandGlobalHandler("vitals_probe", function()
    ExecuteInGameThread(function() diagnose_vitals("console") end)
    return true
end)

local function register_vitals_command(command_name)
    RegisterConsoleCommandGlobalHandler(command_name, function()
        ExecuteInGameThread(function() fill_vitals_once(command_name) end)
        return true
    end)
end

local function register_stats_command(command_name)
    RegisterConsoleCommandGlobalHandler(command_name, function()
        ExecuteInGameThread(function()
            fill_vitals_once(command_name)
            pulse_survival_guard(command_name)
        end)
        return true
    end)
end

register_vitals_command("survival_100")
register_vitals_command("vitals_100")
register_vitals_command("hydrate")
register_vitals_command("water_100")
register_stats_command("stats_100")
register_stats_command("stats")
register_stats_command("sn2_stats")

RegisterConsoleCommandGlobalHandler("survival_guard_10s", function()
    ExecuteInGameThread(function() pulse_survival_guard("survival_guard_10s") end)
    return true
end)

pcall(function()
    RegisterKeyBind(Key.F5, function()
        ExecuteInGameThread(function()
            fill_vitals_once("F5")
            pulse_survival_guard("F5")
        end)
    end)
end)

RegisterBeginPlayPostHook(function()
    if begin_play_scheduled then return end
    begin_play_scheduled = true
    schedule_time_apply("begin play", 3000)
    schedule_time_apply("begin play settle", 10000)
end)

RegisterLoadMapPostHook(function()
    begin_play_scheduled = false
    schedule_time_apply("load map", 5000)
end)

pcall(function()
    NotifyOnNewObject("/Script/UWETimeOfDay.UWETimeOfDayComponent", function(object)
        ExecuteInGameThread(function() try_time_object(object, "new UWETimeOfDayComponent") end)
    end)
end)

schedule_time_apply("startup", 10000)
schedule_time_apply("startup settle", 25000)

LoopAsync(15000, function()
    ExecuteInGameThread(function() apply_never_night("periodic") end)
    return false
end)

log("loaded; target time is noon")