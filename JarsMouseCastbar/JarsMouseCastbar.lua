-- Jar's Mouse Castbar
-- Castbar attached to mouse cursor with multiple animation styles

-- Bar texture options
local BAR_TEXTURES = {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Smooth"] = "Interface\\Buttons\\WHITE8X8",
    ["Aluminium"] = "Interface\\PetitionFrame\\PetitionFrameTile",
    ["Minimalist"] = "Interface\\BUTTONS\\WHITE8X8",
}

-- Initialize saved variables
local function InitDB()
    if not JarsMouseCastbarDB then
        JarsMouseCastbarDB = {
            barLength = 200,
            barWidth = 24,
            cursorOffsetX = 20,
            cursorOffsetY = 20,
            barStyle = "horizontal", -- "horizontal", "vertical", or "circular"
            barTexture = "Blizzard",
            showText = true,
            circularRadius = 40,
        }
    end
    -- Set defaults if missing
    if not JarsMouseCastbarDB.barTexture then
        JarsMouseCastbarDB.barTexture = "Blizzard"
    end
    if JarsMouseCastbarDB.showText == nil then
        JarsMouseCastbarDB.showText = true
    end
    if not JarsMouseCastbarDB.barLength then
        JarsMouseCastbarDB.barLength = 200
    end
    if not JarsMouseCastbarDB.barWidth then
        JarsMouseCastbarDB.barWidth = 24
    end
end

-- Forward declarations
local castFrame
local configFrame
local isCasting = false
local isChanneling = false

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

-- Create main cast bar frame
local function CreateCastFrame()
    local frame = CreateFrame("Frame", "JMCB_CastFrame", UIParent)
    -- Frame size will contain the bar plus some padding for text
    local frameWidth = math.max(JarsMouseCastbarDB.barLength, JarsMouseCastbarDB.barWidth) + 20
    local frameHeight = math.max(JarsMouseCastbarDB.barLength, JarsMouseCastbarDB.barWidth) + 40
    frame:SetSize(frameWidth, frameHeight)
    frame:SetFrameStrata("HIGH")
    
    -- Create bar based on style
    local barStyle = JarsMouseCastbarDB.barStyle or "horizontal"
    if barStyle == "vertical" then
        frame.bar = CreateVerticalBar(frame)
    elseif barStyle == "circular" then
        frame.bar = CreateCircularBar(frame)
    else
        frame.bar = CreateHorizontalBar(frame)
    end
    
    frame:Hide()
    
    -- Frame follows cursor
    frame._lastX = 0
    frame._lastY = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Update cast progress
        if isCasting or isChanneling then
            local currentTime = GetTime()
            local startTime, endTime, spellName
            
            if isCasting then
                local name, text, texture, startTimeMS, endTimeMS = UnitCastingInfo("player")
                if name then
                    spellName = name
                    startTime = startTimeMS / 1000
                    endTime = endTimeMS / 1000
                end
            elseif isChanneling then
                local name, text, texture, startTimeMS, endTimeMS = UnitChannelInfo("player")
                if name then
                    spellName = name
                    startTime = startTimeMS / 1000
                    endTime = endTimeMS / 1000
                end
            end
            
            if startTime and endTime and spellName then
                local duration = endTime - startTime
                local remaining = endTime - currentTime
                local progress = 0
                
                if isChanneling then
                    -- Channels count down
                    progress = remaining / duration
                else
                    -- Casts count up
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

-- Recreate cast frame with new settings
local function RecreateCastFrame()
    -- Preserve state
    local wasShown = castFrame and castFrame:IsShown()
    local wasCasting = isCasting
    local wasChanneling = isChanneling
    
    -- Destroy old frame
    if castFrame then
        castFrame:Hide()
        castFrame:SetScript("OnUpdate", nil)
        castFrame = nil
    end
    
    -- Create new frame
    castFrame = CreateCastFrame()
    
    -- Restore state if needed
    if wasShown and (wasCasting or wasChanneling) then
        castFrame:Show()
    end
end

-- Start casting
local function StartCasting()
    if not castFrame then return end
    
    local name, text, texture, startTimeMS, endTimeMS = UnitCastingInfo("player")
    if name then
        -- Check if spell actually has a cast time (not instant)
        local duration = (endTimeMS - startTimeMS) / 1000
        if duration > 0 then
            -- Only show cast bar for spells with cast time
            isCasting = true
            isChanneling = false
            castFrame.bar:SetStatusBarColor(1, 0.7, 0, 1) -- Yellow/gold for casts
            castFrame:Show()
        end
        -- If duration is 0 (instant cast), ignore it and let channel continue
    end
end

-- Start channeling
local function StartChanneling()
    if not castFrame then return end
    
    -- Use C_Timer to delay the check slightly, channels may not have data immediately
    C_Timer.After(0.05, function()
        local name = UnitChannelInfo("player")
        if name then
            isChanneling = true
            isCasting = false
            castFrame.bar:SetStatusBarColor(0.2, 0.6, 1, 1) -- Blue for channels
            castFrame:Show()
        end
    end)
end

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
    if castFrame and castFrame:IsShown() then
        castFrame.bar:SetStatusBarColor(1, 0, 0, 1) -- Red for failed
        C_Timer.After(0.3, StopCasting)
    end
end

-- Create configuration window
local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "JMCB_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 700)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Jar's Mouse Castbar Configuration")
    
    -- Bar Length slider
    local lengthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lengthLabel:SetPoint("TOPLEFT", 20, -35)
    lengthLabel:SetText("Bar Length: " .. JarsMouseCastbarDB.barLength)
    
    local lengthSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    lengthSlider:SetPoint("TOPLEFT", 20, -55)
    lengthSlider:SetMinMaxValues(50, 300)
    lengthSlider:SetValue(JarsMouseCastbarDB.barLength)
    lengthSlider:SetValueStep(5)
    lengthSlider:SetObeyStepOnDrag(true)
    lengthSlider:SetWidth(300)
    lengthSlider.Low:SetText("50")
    lengthSlider.High:SetText("300")
    lengthSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseCastbarDB.barLength = value
        lengthLabel:SetText("Bar Length: " .. math.floor(value))
        RecreateCastFrame()
    end)
    
    -- Bar Width slider
    local widthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", 20, -100)
    widthLabel:SetText("Bar Width: " .. JarsMouseCastbarDB.barWidth)
    
    local widthSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", 20, -120)
    widthSlider:SetMinMaxValues(5, 80)
    widthSlider:SetValue(JarsMouseCastbarDB.barWidth)
    widthSlider:SetValueStep(2)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(300)
    widthSlider.Low:SetText("5")
    widthSlider.High:SetText("80")
    widthSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseCastbarDB.barWidth = value
        widthLabel:SetText("Bar Width: " .. math.floor(value))
        RecreateCastFrame()
    end)
    
    -- Cursor Offset X slider
    local offsetXLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetXLabel:SetPoint("TOPLEFT", 20, -165)
    offsetXLabel:SetText("Cursor Offset X: " .. JarsMouseCastbarDB.cursorOffsetX)
    
    local offsetXSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", 20, -185)
    offsetXSlider:SetMinMaxValues(-200, 200)
    offsetXSlider:SetValue(JarsMouseCastbarDB.cursorOffsetX)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    offsetXSlider:SetWidth(300)
    offsetXSlider.Low:SetText("-200")
    offsetXSlider.High:SetText("200")
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseCastbarDB.cursorOffsetX = value
        offsetXLabel:SetText("Cursor Offset X: " .. math.floor(value))
    end)
    
    -- Cursor Offset Y slider
    local offsetYLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetYLabel:SetPoint("TOPLEFT", 20, -230)
    offsetYLabel:SetText("Cursor Offset Y: " .. JarsMouseCastbarDB.cursorOffsetY)
    
    local offsetYSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("TOPLEFT", 20, -250)
    offsetYSlider:SetMinMaxValues(-200, 200)
    offsetYSlider:SetValue(JarsMouseCastbarDB.cursorOffsetY)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    offsetYSlider:SetWidth(300)
    offsetYSlider.Low:SetText("-200")
    offsetYSlider.High:SetText("200")
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseCastbarDB.cursorOffsetY = value
        offsetYLabel:SetText("Cursor Offset Y: " .. math.floor(value))
    end)
    
    -- Bar Style dropdown
    local styleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 20, -295)
    styleLabel:SetText("Bar Style:")
    
    local styleDropdown = CreateFrame("Frame", "JMCB_StyleDropdown", frame, "UIDropDownMenuTemplate")
    styleDropdown:SetPoint("TOPLEFT", 10, -310)
    
    local function StyleDropdown_OnClick(self)
        JarsMouseCastbarDB.barStyle = self.value
        UIDropDownMenu_SetText(styleDropdown, self:GetText())
        RecreateCastFrame()
    end
    
    local function StyleDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        info.text = "Horizontal"
        info.value = "horizontal"
        info.func = StyleDropdown_OnClick
        info.checked = (JarsMouseCastbarDB.barStyle == "horizontal")
        UIDropDownMenu_AddButton(info)
        
        info.text = "Vertical"
        info.value = "vertical"
        info.func = StyleDropdown_OnClick
        info.checked = (JarsMouseCastbarDB.barStyle == "vertical")
        UIDropDownMenu_AddButton(info)
        
        info.text = "Circular"
        info.value = "circular"
        info.func = StyleDropdown_OnClick
        info.checked = (JarsMouseCastbarDB.barStyle == "circular")
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_Initialize(styleDropdown, StyleDropdown_Initialize)
    UIDropDownMenu_SetWidth(styleDropdown, 150)
    
    local styleText = "Horizontal"
    if JarsMouseCastbarDB.barStyle == "vertical" then
        styleText = "Vertical"
    elseif JarsMouseCastbarDB.barStyle == "circular" then
        styleText = "Circular"
    end
    UIDropDownMenu_SetText(styleDropdown, styleText)
    
    -- Bar Texture dropdown
    local textureLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textureLabel:SetPoint("TOPLEFT", 20, -355)
    textureLabel:SetText("Bar Texture:")
    
    local textureDropdown = CreateFrame("Frame", "JMCB_TextureDropdown", frame, "UIDropDownMenuTemplate")
    textureDropdown:SetPoint("TOPLEFT", 10, -370)
    
    local function TextureDropdown_OnClick(self)
        JarsMouseCastbarDB.barTexture = self.value
        UIDropDownMenu_SetText(textureDropdown, self:GetText())
        RecreateCastFrame()
    end
    
    local function TextureDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        for textureName, _ in pairs(BAR_TEXTURES) do
            info.text = textureName
            info.value = textureName
            info.func = TextureDropdown_OnClick
            info.checked = (JarsMouseCastbarDB.barTexture == textureName)
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(textureDropdown, TextureDropdown_Initialize)
    UIDropDownMenu_SetWidth(textureDropdown, 150)
    UIDropDownMenu_SetText(textureDropdown, JarsMouseCastbarDB.barTexture or "Blizzard")
    
    -- Show Text checkbox
    local showTextCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    showTextCheck:SetPoint("TOPLEFT", 20, -410)
    showTextCheck.text = showTextCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    showTextCheck.text:SetPoint("LEFT", showTextCheck, "RIGHT", 5, 0)
    showTextCheck.text:SetText("Show Spell Name and Time")
    showTextCheck:SetChecked(JarsMouseCastbarDB.showText)
    showTextCheck:SetScript("OnClick", function(self)
        JarsMouseCastbarDB.showText = self:GetChecked()
    end)
    
    -- Test button
    local testBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    testBtn:SetSize(150, 25)
    testBtn:SetPoint("BOTTOM", 0, 20)
    testBtn:SetText("Test Castbar")
    testBtn:SetScript("OnClick", function()
        if castFrame then
            isCasting = true
            isChanneling = false
            castFrame.bar:SetStatusBarColor(1, 0.7, 0, 1)
            if JarsMouseCastbarDB.showText then
                castFrame.bar.text:SetText("Test Cast")
                castFrame.bar.timeText:SetText("3.0")
            end
            castFrame.bar:SetValue(0)
            castFrame:Show()
            
            -- Animate test cast over 3 seconds
            local startTime = GetTime()
            local duration = 3.0
            local testFrame = CreateFrame("Frame")
            testFrame:SetScript("OnUpdate", function(self)
                local elapsed = GetTime() - startTime
                local progress = elapsed / duration
                if progress >= 1 then
                    progress = 1
                    self:SetScript("OnUpdate", nil)
                    C_Timer.After(0.5, function()
                        isCasting = false
                        castFrame:Hide()
                    end)
                end
                castFrame.bar:SetValue(progress)
                if JarsMouseCastbarDB.showText then
                    castFrame.bar.timeText:SetText(string.format("%.1f", duration - elapsed))
                end
            end)
        end
    end)
    
    return frame
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")

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
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if unit == "player" then
            StopCasting()
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit == "player" then
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
