-- Final Fixed Clock Engine
local hue = 0
local isFlooding = false
local floodFrame = 0
local blinkTimer = 0
local lastMin = -1
local oldTimeLines = {"", "", "", "", ""}
math.randomseed(os.time())

function Initialize()
    -- Each entry is exactly 5 lines tall to ensure perfect alignment
    asciiDictionary = {
        ["0"] = {" ### ", "#   #", "#   #", "#   #", " ### "},
        ["1"] = {"  #  ", " ##  ", "  #  ", "  #  ", " ### "},
        ["2"] = {" ### ", "#   #", "   # ", "  #  ", "#####"},
        ["3"] = {" ### ", "    #", "  ## ", "    #", " ### "},
        ["4"] = {"#   #", "#   #", "#####", "    #", "    #"},
        ["5"] = {"#####", "#    ", "#### ", "    #", "#### "},
        ["6"] = {"  ## ", " #   ", "#### ", "#   #", " ### "},
        ["7"] = {"#####", "    #", "   # ", "  #  ", " #   "},
        ["8"] = {" ### ", "#   #", " ### ", "#   #", " ### "},
        ["9"] = {" ### ", "#   #", " ####", "    #", " ### "},
        -- Colons are 5 lines tall and centered
        [":"] = {"     ", "  #  ", "     ", "  #  ", "     "},
        ["bold:"] = {"     ", " # # ", "     ", " # # ", "     "},
        ["blank:"] = {"     ", "     ", "     ", "     ", "     "}
    }
end

function Update()
    -- 1. RAINBOW COLORING
    local enableRainbow = SKIN:GetVariable('EnableRainbow') == '1'
    if enableRainbow then
        hue = (hue + (tonumber(SKIN:GetVariable('RainbowSpeed')) or 0.004)) % 1
        local r, g, b = HSLtoRGB(hue, 0.8, 0.6)
        SKIN:Bang('!SetOption', 'MeterASCIIClock', 'FontColor', string.format("%d,%d,%d", r, g, b))
    else
        SKIN:Bang('!SetOption', 'MeterASCIIClock', 'FontColor', SKIN:GetVariable('FontColor'))
    end

    -- 2. BLINK TIMER (Frame-based for high speed)
    local blinkEnabled = SKIN:GetVariable('BlinkColon') == '1'
    local blinkSpeed = tonumber(SKIN:GetVariable('BlinkSpeed')) or 15
    blinkTimer = (blinkTimer + 1) % (blinkSpeed * 2)
    local showColon = (not blinkEnabled) or (blinkTimer < blinkSpeed)

    -- 3. GET TIME
    local timeTable = os.date("*t")
    local hour, min = timeTable.hour, timeTable.min
    local is12Hour = SKIN:GetVariable('Use12Hour') == '1'
    if is12Hour then
        if hour == 0 then hour = 12 elseif hour > 12 then hour = hour - 12 end
    end
    local timeStr = string.format("%02d:%02d", hour, min)

    -- 4. BUILD THE DISPLAY STRINGS
    local useCustom = SKIN:GetVariable('UseCustomChar') == '1'
    local customChar = SKIN:GetVariable('CustomChar') or "*"
    local customColon = SKIN:GetVariable('CustomColonChar') or ":"
    local useDoubleColon = SKIN:GetVariable('UseDoubleColon') == '1'
    
    local numSpacing = string.rep(" ", tonumber(SKIN:GetVariable('CharSpacing')) or 2)
    local colonSpacing = string.rep(" ", tonumber(SKIN:GetVariable('ColonSpacing')) or 1)
    
    local newTimeLines = {"", "", "", "", ""}
    
    for i = 1, #timeStr do
        local char = timeStr:sub(i, i)
        local lookup = char
        
        if char == ":" then
            -- Pause blinking during a flood transition
            if not showColon and not isFlooding then
                lookup = "blank:"
            else
                lookup = useDoubleColon and "bold:" or ":"
            end
        end
        
        local art = asciiDictionary[lookup]
        -- Determine what character to actually draw
        local drawWith
        if lookup == "blank:" then
            drawWith = " "
        elseif char == ":" then
            drawWith = customColon
        else
            drawWith = useCustom and customChar or char
        end

        -- Spacing logic
        local currentSpacing = (char == ":" or (i < #timeStr and timeStr:sub(i+1, i+1) == ":")) and colonSpacing or numSpacing

        for lineIndex = 1, 5 do
            newTimeLines[lineIndex] = newTimeLines[lineIndex] .. string.gsub(art[lineIndex], "#", drawWith) .. currentSpacing
        end
    end

    -- 5. FLOOD ANIMATION STATE MACHINE
    if lastMin ~= -1 and min ~= lastMin and not isFlooding and SKIN:GetVariable('EnableFlood') == '1' then
        isFlooding = true
        floodFrame = 0
    end

    if isFlooding then
        floodFrame = floodFrame + 1
        local framesPerLine = tonumber(SKIN:GetVariable('FloodSpeed')) or 4
        local totalLines = 5
        local phase1End = framesPerLine * totalLines
        local width = #newTimeLines[1]
        local displayLines = {}

        if floodFrame <= phase1End then
            -- Phase 1: Rising Binary
            local activeLine = totalLines - math.floor(floodFrame / framesPerLine)
            for i = 1, totalLines do
                displayLines[i] = (i >= activeLine) and GenerateBinary(width) or (oldTimeLines[i] ~= "" and oldTimeLines[i] or newTimeLines[i])
            end
        elseif floodFrame <= (phase1End * 2) then
            -- Phase 2: Falling Binary revealing new time
            local relativeFrame = floodFrame - phase1End
            local activeLine = math.floor(relativeFrame / framesPerLine)
            for i = 1, totalLines do
                displayLines[i] = (i <= activeLine) and newTimeLines[i] or GenerateBinary(width)
            end
        else
            -- End Animation
            isFlooding = false
            lastMin = min
            oldTimeLines = newTimeLines
            return table.concat(newTimeLines, "\n")
        end
        return table.concat(displayLines, "\n")
    end

    -- 6. NORMAL IDLE STATE
    lastMin = min
    oldTimeLines = newTimeLines
    return table.concat(newTimeLines, "\n")
end

function GenerateBinary(len)
    local s = ""
    for i = 1, len do s = s .. (math.random(0, 9) > 4 and "1" or "0") end
    return s
end

function HSLtoRGB(h, s, l)
    local function h2r(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return h2r(p, q, h + 1/3) * 255, h2r(p, q, h) * 255, h2r(p, q, h - 1/3) * 255
end