-- Jar's Mouse Castbar
-- Castbar attached to mouse cursor with multiple animation styles

-- Bar texture options
local BAR_TEXTURES = {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Smooth"] = "Interface\\Buttons\\WHITE8X8",
    ["Aluminium"] = "Interface\\PetitionFrame\\PetitionFrameTile",
    ["Minimalist"] = "Interface\\BUTTONS\\WHITE8X8",
}

local DEFAULTS = {
    barLength = 200,
    barWidth = 24,
    cursorOffsetX = 20,
    cursorOffsetY = 20,
    barStyle = "horizontal", -- "horizontal", "vertical", or "circular"
    barTexture = "Blizzard",
    showText = true,
    circularRadius = 40,
}

-- Initialize saved variables, fill in any missing keys
local function InitDB()
    JarsMouseCastbarDB = JarsMouseCastbarDB or {}
    for k, v in pairs(DEFAULTS) do
        if JarsMouseCastbarDB[k] == nil then
            JarsMouseCastbarDB[k] = v
        end
    end
end

-- Forward declarations
local castFrame
local configFrame
local isCasting = false
local isChanneling = false
local isEmpowering = false
local isTesting = false
local currentCastBarID  -- castBarID of what the bar is showing

-- where castBarID sits in each payload (unit is 1), from UnitDocumentation
local CASTBAR_ID_ARG = {
    UNIT_SPELLCAST_STOP = 4,
    UNIT_SPELLCAST_SUCCEEDED = 4,
    UNIT_SPELLCAST_FAILED = 4,
    UNIT_SPELLCAST_INTERRUPTED = 5,
    UNIT_SPELLCAST_CHANNEL_STOP = 5,
    UNIT_SPELLCAST_EMPOWER_STOP = 6,
}

local function GetEventCastBarID(event, ...)
    local idx = CASTBAR_ID_ARG[event]
    if idx then
        return (select(idx, ...))
    end
end

-- nil on either side = cant tell, so accept like before
local function IsOurCast(castBarID)
    return castBarID == nil or currentCastBarID == nil or castBarID == currentCastBarID
end

-- players own cast info isnt secret, so plain math is fine here
local function ReadPlayerCast()
    if isChanneling or isEmpowering then
        local name, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if name and isEmpowering then
            -- include the hold at max like blizz does
            endTimeMS = endTimeMS + GetUnitEmpowerHoldAtMaxTime("player")
        end
        return name, startTimeMS, endTimeMS
    end
    local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
    return name, startTimeMS, endTimeMS
end

-- Create horizontal cast bar
local function CreateHorizontalBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(JarsMouseCastbarDB.barLength, JarsMouseCastbarDB.barWidth)
    bar:SetPoint("CENTER")
    local texturePath = BAR_TEXTURES[JarsMouseCastbarDB.barTexture] or BAR_TEXTURES["Blizzard"]
    bar:SetStatusBarTexture(texturePath)
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:GetStatusBarTexture():SetVertTile(false)
    bar:SetStatusBarColor(1, 0.7, 0, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Spell name text
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.text:SetPoint("CENTER")
    bar.text:SetText("")
    
    -- Time text
    bar.timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.timeText:SetPoint("RIGHT", -5, 0)
    bar.timeText:SetText("")
    
    return bar
end

-- Create vertical cast bar
local function CreateVerticalBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(JarsMouseCastbarDB.barWidth, JarsMouseCastbarDB.barLength)
    bar:SetPoint("CENTER")
    local texturePath = BAR_TEXTURES[JarsMouseCastbarDB.barTexture] or BAR_TEXTURES["Blizzard"]
    bar:SetStatusBarTexture(texturePath)
    bar:GetStatusBarTexture():SetHorizTile(false)
    bar:GetStatusBarTexture():SetVertTile(false)
    bar:SetStatusBarColor(1, 0.7, 0, 1)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Spell name text (rotated appearance)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.text:SetPoint("TOP", 0, 15)
    bar.text:SetText("")
    
    -- Time text
    bar.timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.timeText:SetPoint("BOTTOM", 0, -15)
    bar.timeText:SetText("")
    
    return bar
end

-- Create circular cast bar
local function CreateCircularBar(parent)
    local radius = JarsMouseCastbarDB.circularRadius
    local thickness = 8
    local segments = 40
    
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(radius * 2 + thickness * 2, radius * 2 + thickness * 2)
    bar:SetPoint("CENTER")
    
    -- Store textures for the circular segments
    bar.segments = {}
    bar.bgSegments = {}
    
    for i = 1, segments do
        -- Background segment
        local bgSeg = bar:CreateTexture(nil, "BACKGROUND")
        bgSeg:SetSize(thickness, radius * 0.15)
        bgSeg:SetColorTexture(0.2, 0.2, 0.2, 0.7)
        bar.bgSegments[i] = bgSeg
        
        -- Foreground segment
        local seg = bar:CreateTexture(nil, "ARTWORK")
        seg:SetSize(thickness, radius * 0.15)
        seg:SetColorTexture(1, 0.7, 0, 1)
        seg:Hide()
        bar.segments[i] = seg
    end
    
    -- Position segments in a circle
    bar.UpdateSegmentPositions = function(self)
        for i = 1, segments do
            local angle = (i / segments) * math.pi * 2 - math.pi / 2
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            
            self.bgSegments[i]:SetPoint("CENTER", x, y)
            self.segments[i]:SetPoint("CENTER", x, y)
            
            -- Rotate texture to point outward
            local texAngle = angle + math.pi / 2
            self.bgSegments[i]:SetRotation(texAngle)
            self.segments[i]:SetRotation(texAngle)
        end
    end
    bar:UpdateSegmentPositions()
    
    -- Update progress
    bar.SetValue = function(self, progress)
        local activeSegments = math.floor(progress * segments)
        for i = 1, segments do
            if i <= activeSegments then
                self.segments[i]:Show()
            else
                self.segments[i]:Hide()
            end
        end
    end
    
    bar.SetMinMaxValues = function(self, min, max) end -- Dummy function for compatibility
    bar.SetStatusBarColor = function(self, r, g, b, a)
        for i = 1, segments do
            self.segments[i]:SetColorTexture(r, g, b, a or 1)
        end
    end
    
    -- Spell name text (center)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.text:SetPoint("CENTER")
    bar.text:SetText("")
    
    -- Time text (below center)
    bar.timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.timeText:SetPoint("TOP", bar.text, "BOTTOM", 0, -5)
    bar.timeText:SetText("")
    
    return bar
end

-- Size the frame and swap to the bar for the current style.
-- each style's bar is made once and reused
local function ApplyLayout(frame)
    local db = JarsMouseCastbarDB
    -- Frame size will contain the bar plus some padding for text
    local size = math.max(db.barLength, db.barWidth)
    frame:SetSize(size + 20, size + 40)

    local style = db.barStyle
    if style ~= "vertical" and style ~= "circular" then
        style = "horizontal"
    end
    if not frame.bars[style] then
        if style == "vertical" then
            frame.bars[style] = CreateVerticalBar(frame)
        elseif style == "circular" then
            frame.bars[style] = CreateCircularBar(frame)
        else
            frame.bars[style] = CreateHorizontalBar(frame)
        end
    end
    for s, b in pairs(frame.bars) do
        b:SetShown(s == style)
    end

    local bar = frame.bars[style]
    if style ~= "circular" then
        if style == "vertical" then
            bar:SetSize(db.barWidth, db.barLength)
        else
            bar:SetSize(db.barLength, db.barWidth)
        end
        bar:SetStatusBarTexture(BAR_TEXTURES[db.barTexture] or BAR_TEXTURES["Blizzard"])
        bar:GetStatusBarTexture():SetHorizTile(false)
        bar:GetStatusBarTexture():SetVertTile(false)
    end
    frame.bar = bar
end

-- Create main cast bar frame
local function CreateCastFrame()
    local frame = CreateFrame("Frame", "JMCB_CastFrame", UIParent)
    frame:SetFrameStrata("HIGH")
    frame.bars = {}
    ApplyLayout(frame)

    frame:Hide()

    -- Frame follows cursor
    frame._lastX = 0
    frame._lastY = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Update cast progress
        if isCasting or isChanneling or isEmpowering then
            local currentTime = GetTime()
            local startTime, endTime

            local spellName, startTimeMS, endTimeMS = ReadPlayerCast()
            if spellName then
                startTime = startTimeMS / 1000
                endTime = endTimeMS / 1000
            end

            if startTime and endTime and spellName then
                local duration = endTime - startTime
                local remaining = endTime - currentTime
                local progress = 0

                if isChanneling then
                    -- Channels count down
                    progress = remaining / duration
                else
                    -- Casts and empowered spells count up
                    progress = 1 - (remaining / duration)
                end

                -- Clamp progress
                if progress < 0 then progress = 0 end
                if progress > 1 then progress = 1 end

                self.bar:SetValue(progress)
                if JarsMouseCastbarDB.showText then
                    self.bar.text:SetText(spellName)
                    self.bar.timeText:SetText(string.format("%.1f", remaining))
                else
                    self.bar.text:SetText("")
                    self.bar.timeText:SetText("")
                end
            else
                -- Cast ended, hide frame
                self:Hide()
                isCasting = false
                isChanneling = false
                isEmpowering = false
                currentCastBarID = nil
            end
        end
        
        -- Follow cursor
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local offsetX = JarsMouseCastbarDB.cursorOffsetX
        local offsetY = JarsMouseCastbarDB.cursorOffsetY
        
        local newX = (x / scale) + offsetX
        local newY = (y / scale) + offsetY
        
        -- Only update position if cursor moved at least 1 pixel
        if math.abs(newX - self._lastX) > 1 or math.abs(newY - self._lastY) > 1 then
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)
            self._lastX = newX
            self._lastY = newY
        end
    end)
    
    return frame
end

-- Re-apply settings to the existing frame, no more rebuilding
local function RecreateCastFrame()
    -- -- Preserve state
    -- local wasShown = castFrame and castFrame:IsShown()
    -- local wasCasting = isCasting
    -- local wasChanneling = isChanneling
    -- if castFrame then
    --     castFrame:Hide()
    --     castFrame:SetScript("OnUpdate", nil)
    --     castFrame = nil
    -- end
    -- castFrame = CreateCastFrame()
    if castFrame then
        ApplyLayout(castFrame)
    end
end

-- Start casting
local function StartCasting()
    if not castFrame then return end

    local name, _, _, startTimeMS, endTimeMS, _, _, _, _, castBarID = UnitCastingInfo("player")
    if name then
        -- Check if spell actually has a cast time (not instant)
        local duration = (endTimeMS - startTimeMS) / 1000
        if duration > 0 then
            -- Only show cast bar for spells with cast time
            isCasting = true
            isChanneling = false
            isEmpowering = false
            isTesting = false
            currentCastBarID = castBarID
            castFrame.bar:SetStatusBarColor(1, 0.7, 0, 1) -- Yellow/gold for casts
            castFrame:Show()
        end
        -- If duration is 0 (instant cast), ignore it and let channel continue
    end
end

-- Start channeling, empowers are channels too so this handles both
local function StartChanneling()
    if not castFrame then return end

    -- C_Timer.After(0.05, function()
    -- channel info is there right at CHANNEL_START, no need to wait
    local name, _, _, _, _, _, _, _, isEmpowered, _, castBarID = UnitChannelInfo("player")
    if name then
        isCasting = false
        isTesting = false
        currentCastBarID = castBarID
        if isEmpowered then
            isEmpowering = true
            isChanneling = false
            castFrame.bar:SetStatusBarColor(0.3, 0.8, 1, 1) -- Light blue for empowered
        else
            isChanneling = true
            isEmpowering = false
            castFrame.bar:SetStatusBarColor(0.2, 0.6, 1, 1) -- Blue for channels
        end
        castFrame:Show()
    end
end

-- Start empowered cast
-- local function StartEmpowering()
--     local name, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
--     ... empowers come from UnitChannelInfo not UnitCastingInfo, so this never showed
-- end
local StartEmpowering = StartChanneling

-- Stop casting/channeling
local function StopCasting()
    -- Check if we're still channeling before hiding
    local channelName = UnitChannelInfo("player")
    if channelName and isChanneling then
        -- Still channeling, don't hide the bar
        -- Just clear the casting flag in case an instant cast triggered this
        isCasting = false
        return
    end

    -- Not channeling, safe to hide
    if castFrame then
        castFrame:Hide()
    end
    isCasting = false
    isChanneling = false
    isEmpowering = false
    currentCastBarID = nil
end

-- Failed/interrupted cast
local function FailedCast()
    -- Check if we're still channeling before showing failed state
    local channelName = UnitChannelInfo("player")
    if channelName and isChanneling then
        -- Still channeling, don't show failed state
        -- The instant cast just failed, but channel continues
        isCasting = false
        return
    end

    -- Not channeling, show the failed cast state
    isEmpowering = false
    if castFrame and castFrame:IsShown() then
        castFrame.bar:SetStatusBarColor(1, 0, 0, 1) -- Red for failed
        -- dont kill a new cast that started in the 0.3s
        local failedID = currentCastBarID
        C_Timer.After(0.3, function()
            if currentCastBarID == failedID then
                StopCasting()
            end
        end)
    end
end

-- Modern dark UI colour palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 1.0,  0.55, 0.0,  1 },
    accentDim = { 0.70, 0.35, 0.0,  1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 1.0,  0.55, 0.0,  0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 1.0,  0.55, 0.0,  1 },
    checkOff  = { 0.22, 0.22, 0.26, 1 },
}

local FONT_NORMAL = "Fonts\\FRIZQT__.TTF"

-- Helper: section header ---------------------------------------------------
local function CreateSectionHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(22)
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", 0, 0)
    line:SetPoint("RIGHT", 0, 0)
    line:SetColorTexture(UI.accent[1], UI.accent[2], UI.accent[3], 0.35)
    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_NORMAL, 13, "")
    label:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3], UI.accent[4])
    label:SetPoint("LEFT", 0, 0)
    label:SetText(text)
    line:SetPoint("LEFT", label, "RIGHT", 6, 0)
    header.label = label
    return header
end

-- Helper: modern slider ----------------------------------------------------
local function CreateModernSlider(parent, name, labelText, minVal, maxVal, curVal, step, width, formatFunc, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 40)

    -- Label (left)
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_NORMAL, 11, "")
    label:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)

    -- Value readout (right)
    local valText = container:CreateFontString(nil, "OVERLAY")
    valText:SetFont(FONT_NORMAL, 11, "")
    valText:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3], UI.accent[4])
    valText:SetPoint("TOPRIGHT", 0, 0)
    valText:SetText(formatFunc and formatFunc(curVal) or tostring(math.floor(curVal)))

    -- Track background
    local trackBg = container:CreateTexture(nil, "BACKGROUND")
    trackBg:SetHeight(4)
    trackBg:SetPoint("TOPLEFT", 0, -18)
    trackBg:SetPoint("TOPRIGHT", 0, -18)
    trackBg:SetColorTexture(UI.sliderBg[1], UI.sliderBg[2], UI.sliderBg[3], UI.sliderBg[4])

    -- Fill texture
    local fill = container:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    fill:SetColorTexture(UI.sliderFill[1], UI.sliderFill[2], UI.sliderFill[3], UI.sliderFill[4])

    -- The actual slider (thin, rides on the track)
    local slider = CreateFrame("Slider", name, container, "MinimalSliderTemplate")
    slider:SetSize(width, 16)
    slider:SetPoint("TOPLEFT", 0, -12)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(curVal)

    -- Thumb styling
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(14, 14)
        thumb:SetColorTexture(UI.accent[1], UI.accent[2], UI.accent[3], UI.accent[4])
    end

    local function UpdateFill(val)
        local frac = (val - minVal) / (maxVal - minVal)
        fill:SetWidth(math.max(1, frac * width))
    end
    UpdateFill(curVal)

    slider:SetScript("OnValueChanged", function(self, value)
        valText:SetText(formatFunc and formatFunc(value) or tostring(math.floor(value)))
        UpdateFill(value)
        if onChange then onChange(value) end
    end)

    container.slider = slider
    container.valText = valText
    return container
end

-- Helper: modern checkbox --------------------------------------------------
local function CreateModernCheck(parent, labelText, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 20)

    local box = CreateFrame("Button", nil, container)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)

    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(UI.checkOff[1], UI.checkOff[2], UI.checkOff[3], UI.checkOff[4])
    box.bg = boxBg

    local checkMark = box:CreateFontString(nil, "OVERLAY")
    checkMark:SetFont(FONT_NORMAL, 13, "")
    checkMark:SetPoint("CENTER", 0, 1)
    checkMark:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    box.checkMark = checkMark

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_NORMAL, 11, "")
    label:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(labelText)

    local isChecked = checked
    local function Refresh()
        if isChecked then
            boxBg:SetColorTexture(UI.checkOn[1], UI.checkOn[2], UI.checkOn[3], UI.checkOn[4])
            checkMark:SetText("\226\156\147")  -- checkmark
        else
            boxBg:SetColorTexture(UI.checkOff[1], UI.checkOff[2], UI.checkOff[3], UI.checkOff[4])
            checkMark:SetText("")
        end
    end
    Refresh()

    box:SetScript("OnClick", function()
        isChecked = not isChecked
        Refresh()
        if onClick then onClick(isChecked) end
    end)

    container.GetChecked = function() return isChecked end
    container.SetChecked = function(_, v) isChecked = v; Refresh() end
    return container
end

-- Helper: modern flat button -----------------------------------------------
local function CreateModernButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
    btn.bg = bg

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(UI.border[1], UI.border[2], UI.border[3], UI.border[4])
    btn.border = border

    -- Re-layer so bg is above border (border acts as outline)
    bg:SetDrawLayer("ARTWORK")
    border:SetDrawLayer("BACKGROUND")

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT_NORMAL, 11, "")
    label:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    label:SetPoint("CENTER")
    label:SetText(text)
    btn.label = label

    btn:SetScript("OnEnter", function()
        bg:SetColorTexture(UI.btnHover[1], UI.btnHover[2], UI.btnHover[3], UI.btnHover[4])
    end)
    btn:SetScript("OnLeave", function()
        bg:SetColorTexture(UI.btnNormal[1], UI.btnNormal[2], UI.btnNormal[3], UI.btnNormal[4])
    end)
    btn:SetScript("OnMouseDown", function()
        bg:SetColorTexture(UI.btnPress[1], UI.btnPress[2], UI.btnPress[3], UI.btnPress[4])
    end)
    btn:SetScript("OnMouseUp", function()
        bg:SetColorTexture(UI.btnHover[1], UI.btnHover[2], UI.btnHover[3], UI.btnHover[4])
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Create configuration window
local function CreateConfigFrame()
    -- Main frame with dark backdrop
    local frame = CreateFrame("Frame", "JMCB_ConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(400, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(UI.bg[1], UI.bg[2], UI.bg[3], UI.bg[4])
    frame:SetBackdropBorderColor(UI.border[1], UI.border[2], UI.border[3], UI.border[4])
    frame:Hide()
    tinsert(UISpecialFrames, "JMCB_ConfigFrame")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(UI.header[1], UI.header[2], UI.header[3], UI.header[4])
    titleBar:SetBackdropBorderColor(UI.border[1], UI.border[2], UI.border[3], UI.border[4])

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_NORMAL, 13, "")
    titleText:SetTextColor(UI.accent[1], UI.accent[2], UI.accent[3], UI.accent[4])
    titleText:SetPoint("LEFT", 12, 0)
    titleText:SetText("Jar's Mouse Castbar")
    frame.title = titleText

    -- Close button (minimal "x")
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("RIGHT", -2, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont(FONT_NORMAL, 13, "")
    closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3], UI.textDim[4])
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4, 1) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(UI.textDim[1], UI.textDim[2], UI.textDim[3], UI.textDim[4]) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -34)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(356, 1)
    scrollFrame:SetScrollChild(content)

    local PAD_LEFT = 20
    local yOffset = -8

    local function NextY(h)
        local y = yOffset
        yOffset = yOffset - h
        return y
    end

    -------------------------------------------------------------------
    -- DIMENSIONS
    -------------------------------------------------------------------
    local dimHeader = CreateSectionHeader(content, "Dimensions")
    dimHeader:SetPoint("TOPLEFT", PAD_LEFT, NextY(26))
    dimHeader:SetPoint("RIGHT", -PAD_LEFT, 0)

    local lengthSlider = CreateModernSlider(content, nil, "Bar Length", 50, 300,
        JarsMouseCastbarDB.barLength, 5, 316, nil, function(value)
            JarsMouseCastbarDB.barLength = value
            RecreateCastFrame()
        end)
    lengthSlider:SetPoint("TOPLEFT", PAD_LEFT, NextY(48))

    local widthSlider = CreateModernSlider(content, nil, "Bar Width", 5, 80,
        JarsMouseCastbarDB.barWidth, 2, 316, nil, function(value)
            JarsMouseCastbarDB.barWidth = value
            RecreateCastFrame()
        end)
    widthSlider:SetPoint("TOPLEFT", PAD_LEFT, NextY(48))

    -------------------------------------------------------------------
    -- POSITION
    -------------------------------------------------------------------
    NextY(10)
    local posHeader = CreateSectionHeader(content, "Position")
    posHeader:SetPoint("TOPLEFT", PAD_LEFT, NextY(26))
    posHeader:SetPoint("RIGHT", -PAD_LEFT, 0)

    local offXSlider = CreateModernSlider(content, nil, "Cursor Offset X", -200, 200,
        JarsMouseCastbarDB.cursorOffsetX, 1, 316, nil, function(value)
            JarsMouseCastbarDB.cursorOffsetX = value
        end)
    offXSlider:SetPoint("TOPLEFT", PAD_LEFT, NextY(48))

    local offYSlider = CreateModernSlider(content, nil, "Cursor Offset Y", -200, 200,
        JarsMouseCastbarDB.cursorOffsetY, 1, 316, nil, function(value)
            JarsMouseCastbarDB.cursorOffsetY = value
        end)
    offYSlider:SetPoint("TOPLEFT", PAD_LEFT, NextY(48))

    -------------------------------------------------------------------
    -- STYLE
    -------------------------------------------------------------------
    NextY(10)
    local styleHeader = CreateSectionHeader(content, "Style")
    styleHeader:SetPoint("TOPLEFT", PAD_LEFT, NextY(26))
    styleHeader:SetPoint("RIGHT", -PAD_LEFT, 0)

    -- Bar Style dropdown
    local styleLbl = content:CreateFontString(nil, "OVERLAY")
    styleLbl:SetFont(FONT_NORMAL, 11, "")
    styleLbl:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    styleLbl:SetPoint("TOPLEFT", PAD_LEFT, NextY(20))
    styleLbl:SetText("Bar Style")

    local styleNames = { horizontal = "Horizontal", vertical = "Vertical", circular = "Circular" }
    local styleDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    styleDropdown:SetPoint("TOPLEFT", PAD_LEFT, NextY(30))
    styleDropdown:SetWidth(180)
    styleDropdown:SetDefaultText(styleNames[JarsMouseCastbarDB.barStyle] or "Horizontal")
    styleDropdown:SetupMenu(function(_, rootDescription)
        for value, label in pairs(styleNames) do
            rootDescription:CreateRadio(label,
                function() return JarsMouseCastbarDB.barStyle == value end,
                function()
                    JarsMouseCastbarDB.barStyle = value
                    RecreateCastFrame()
                end)
        end
    end)

    -- Bar Texture dropdown
    local texLbl = content:CreateFontString(nil, "OVERLAY")
    texLbl:SetFont(FONT_NORMAL, 11, "")
    texLbl:SetTextColor(UI.text[1], UI.text[2], UI.text[3], UI.text[4])
    texLbl:SetPoint("TOPLEFT", PAD_LEFT, NextY(20))
    texLbl:SetText("Bar Texture")

    local textureDropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    textureDropdown:SetPoint("TOPLEFT", PAD_LEFT, NextY(30))
    textureDropdown:SetWidth(180)
    textureDropdown:SetDefaultText(JarsMouseCastbarDB.barTexture or "Blizzard")
    textureDropdown:SetupMenu(function(_, rootDescription)
        for textureName, _ in pairs(BAR_TEXTURES) do
            rootDescription:CreateRadio(textureName,
                function() return JarsMouseCastbarDB.barTexture == textureName end,
                function()
                    JarsMouseCastbarDB.barTexture = textureName
                    RecreateCastFrame()
                end)
        end
    end)

    -- Show Text checkbox
    NextY(6)
    local showTextCheck = CreateModernCheck(content, "Show Spell Name and Time",
        JarsMouseCastbarDB.showText, function(checked)
            JarsMouseCastbarDB.showText = checked
        end)
    showTextCheck:SetPoint("TOPLEFT", PAD_LEFT, NextY(24))

    -------------------------------------------------------------------
    -- TEST
    -------------------------------------------------------------------
    NextY(10)
    local testHeader = CreateSectionHeader(content, "Test")
    testHeader:SetPoint("TOPLEFT", PAD_LEFT, NextY(26))
    testHeader:SetPoint("RIGHT", -PAD_LEFT, 0)

    -- one test driver, reused. the old one set isCasting so the real
    -- OnUpdate saw no cast and hid the bar right away
    local testFrame = CreateFrame("Frame")
    local testStart, testDuration = 0, 3.0
    testFrame:SetScript("OnUpdate", function(self)
        if not isTesting then
            self:Hide()
            return
        end
        local elapsed = GetTime() - testStart
        local progress = elapsed / testDuration
        if progress >= 1 then
            progress = 1
            self:Hide()
            C_Timer.After(0.5, function()
                if isTesting then
                    isTesting = false
                    castFrame:Hide()
                end
            end)
        end
        castFrame.bar:SetValue(progress)
        if JarsMouseCastbarDB.showText then
            castFrame.bar.timeText:SetText(string.format("%.1f", testDuration - elapsed))
        end
    end)
    testFrame:Hide()

    local testBtn = CreateModernButton(content, "Test Castbar", 160, 28, function()
        if castFrame and not (isCasting or isChanneling or isEmpowering) then
            isTesting = true
            castFrame.bar:SetStatusBarColor(1, 0.7, 0, 1)
            if JarsMouseCastbarDB.showText then
                castFrame.bar.text:SetText("Test Cast")
                castFrame.bar.timeText:SetText("3.0")
            end
            castFrame.bar:SetValue(0)
            castFrame:Show()

            -- Animate test cast over 3 seconds
            testStart = GetTime()
            testFrame:Show()
        end
    end)
    testBtn:SetPoint("TOPLEFT", PAD_LEFT, NextY(36))

    -- Set content height so scroll works
    content:SetHeight(math.abs(yOffset) + 10)

    return frame
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_EMPOWER_UPDATE",
}
-- player only, skip everyone elses casts
for _, event in ipairs(CAST_EVENTS) do
    eventFrame:RegisterUnitEvent(event, "player")
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsMouseCastbar" then
            InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        print("|cff00ff00Jar's Mouse Castbar|r loaded. Type /jmcb for options.")
        
        -- Create frames
        castFrame = CreateCastFrame()
        configFrame = CreateConfigFrame()
        
    elseif event == "UNIT_SPELLCAST_START" then
        local unit = ...
        if unit == "player" then
            StartCasting()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = ...
        if unit == "player" then
            StartChanneling()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local unit = ...
        if unit == "player" and isChanneling then
            -- Keep updating channel info
            local name = UnitChannelInfo("player")
            if not name then
                StopCasting()
            end
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        local unit = ...
        if unit == "player" then
            StartEmpowering()
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local unit = ...
        if unit == "player" and IsOurCast(GetEventCastBarID(event, ...)) then
            StopCasting()
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        local unit = ...
        if unit == "player" and isEmpowering then
            -- local name = UnitCastingInfo("player")
            local name = UnitChannelInfo("player")
            if not name then
                StopCasting()
            end
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        -- instants and spam presses have a diff castBarID, leave our bar alone
        if unit == "player" and IsOurCast(GetEventCastBarID(event, ...)) then
            -- off gcd instant during a hardcast, STOP will come for the real one
            if event == "UNIT_SPELLCAST_SUCCEEDED" and isCasting and UnitCastingInfo("player") then
                return
            end
            StopCasting()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" and IsOurCast(GetEventCastBarID(event, ...)) then
            FailedCast()
        end
    end
end)

-- Slash commands
SLASH_JARSMOUSECASTBAR1 = "/jmcb"
SLASH_JARSMOUSECASTBAR2 = "/jarsmousecastbar"
SlashCmdList["JARSMOUSECASTBAR"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "config" or msg == "" then
        if configFrame then
            configFrame:SetShown(not configFrame:IsShown())
        end
    else
        print("|cff00ff00Jar's Mouse Castbar|r Commands:")
        print("  /jmcb - Open configuration window")
        print("  /jmcb config - Open configuration window")
    end
end

-- for JarsAddonConfig
function JarsMouseCastbar_OpenConfig()
    if configFrame then
        configFrame:Show()
    end
end
