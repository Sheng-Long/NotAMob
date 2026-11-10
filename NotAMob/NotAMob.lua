local ADDON_NAME = ...
local NotAMob = CreateFrame("Frame")

local FONTS = {
    FRIZQT   = "Fonts\\FRIZQT__.TTF",
    ARIALN   = "Fonts\\ARIALN.TTF",
    MORPHEUS = "Fonts\\MORPHEUS.TTF",
    SKURRI   = "Fonts\\SKURRI.TTF",
}
local FONT_ORDER = { "FRIZQT", "SKURRI", "ARIALN", "MORPHEUS" }

local OUTLINES = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE" }

local DEFAULTS = {
    enabled      = true,
    font         = "FRIZQT",
    outline      = "outline",
    scale        = 1.5,
    size         = 0,
    shrinkToFit  = false,
    farOnly      = { font = false, size = false, outline = false },
    button       = { shown = true, point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
    icon         = "HUNTERSMARK",
    nineCam      = { shown = false, point = "CENTER", relPoint = "CENTER", x = 50, y = -180 },
}

local db

local issecretvalue = issecretvalue or function() return false end

local GetCVar        = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVar        = (C_CVar and C_CVar.SetCVar) or SetCVar
local GetCVarBool    = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
local GetCVarDefault = (C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault

local function Print(msg)
    print("|cffff5555NotAMob|r: " .. tostring(msg))
end

local NPC_NAME_CVARS = {
    "UnitNameNPC",
    "UnitNameHostleNPC",
    "UnitNameInteractiveNPC",
    "UnitNameFriendlySpecialNPCName",
}
local FALLBACK_NPC_NAMES = {
    UnitNameNPC = "0", UnitNameHostleNPC = "1",
    UnitNameInteractiveNPC = "1", UnitNameFriendlySpecialNPCName = "1",
}

local UpdateButton
local pendingNpcNames

local function ReadNpcNames()
    local t = {}
    for _, c in ipairs(NPC_NAME_CVARS) do t[c] = tostring(GetCVar(c) or "0") end
    return t
end

local function AllZero(t)
    for _, c in ipairs(NPC_NAME_CVARS) do
        if t[c] ~= "0" then return false end
    end
    return true
end

local function NpcNamesHidden()
    return AllZero(ReadNpcNames())
end

local function WriteNpcNames(values)
    for _, c in ipairs(NPC_NAME_CVARS) do
        pcall(SetCVar, c, values[c])
    end
    local now = ReadNpcNames()
    for _, c in ipairs(NPC_NAME_CVARS) do
        if now[c] ~= values[c] then return false end
    end
    return true
end

local function ApplyNpcNames(values, label)
    if WriteNpcNames(values) then
        pendingNpcNames = nil
        Print(label)
    elseif InCombatLockdown() then
        pendingNpcNames = { values = values, label = label }
        NotAMob:RegisterEvent("PLAYER_REGEN_ENABLED")
        Print("Can't change name settings in combat, will switch after.")
    else
        Print("Couldn't change name settings.")
    end
    if UpdateButton then UpdateButton() end
end

local function ToggleNpcNames()
    if NpcNamesHidden() then
        local saved = db.savedNpcNames
        if not saved or AllZero(saved) then saved = FALLBACK_NPC_NAMES end
        ApplyNpcNames(saved, "NPC names on.")
    else
        db.savedNpcNames = ReadNpcNames()
        local none = {}
        for _, c in ipairs(NPC_NAME_CVARS) do none[c] = "0" end
        ApplyNpcNames(none, "NPC names off.")
    end
end

local BINDING_ACTION = "NOTAMOB_TOGGLE_NPC_NAMES"
BINDING_HEADER_NOTAMOB = "NotAMob"
_G["BINDING_NAME_" .. BINDING_ACTION] = "Toggle NPC names"

function NotAMob_ToggleNpcNames()
    ToggleNpcNames()
end

local NINE_ACTION = "NOTAMOB_NINE_SNAP"
_G["BINDING_NAME_" .. NINE_ACTION] = "Nam Nine screenshot"

local function KeyTextFor(action)
    local key = GetBindingKey(action)
    return key and GetBindingText(key) or "Not bound"
end

local function SetKeyFor(action, key)
    if InCombatLockdown() then
        Print("Can't change key bindings in combat.")
        return false
    end
    local k1, k2 = GetBindingKey(action)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    if key then
        local old = GetBindingAction(key)
        SetBinding(key, action)
        if old and old ~= "" and old ~= action then
            Print(("%s no longer does \"%s\"."):format(
                GetBindingText(key), _G["BINDING_NAME_" .. old] or old))
        end
    end
    SaveBindings(GetCurrentBindingSet())
    return true
end

local function ToggleKeyText() return KeyTextFor(BINDING_ACTION) end
local function SetToggleKey(key) return SetKeyFor(BINDING_ACTION, key) end

local capture
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}

local function OpenKeyCapture(onDone, action)
    action = action or BINDING_ACTION
    if not capture then
        capture = CreateFrame("Frame", "NotAMobKeyCapture", UIParent, "BackdropTemplate")
        capture:SetSize(330, 130)
        capture:SetPoint("CENTER")
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        capture:SetToplevel(true)
        capture:EnableMouse(true)
        capture:EnableKeyboard(true)
        capture:SetBackdrop(BACKDROP_DIALOG_32_32 or {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        capture.text = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        capture.text:SetPoint("TOP", 0, -24)
        capture.text:SetWidth(290)

        local clear = CreateFrame("Button", nil, capture, "UIPanelButtonTemplate")
        clear:SetSize(110, 22)
        clear:SetPoint("BOTTOMLEFT", 28, 18)
        clear:SetText("Clear key")
        clear:SetScript("OnClick", function()
            if SetKeyFor(capture.action, nil) then Print("Key cleared.") end
            capture:Hide()
            if capture.onDone then capture.onDone() end
        end)

        local cancel = CreateFrame("Button", nil, capture, "UIPanelButtonTemplate")
        cancel:SetSize(110, 22)
        cancel:SetPoint("BOTTOMRIGHT", -28, 18)
        cancel:SetText(CANCEL or "Cancel")
        cancel:SetScript("OnClick", function() capture:Hide() end)

        capture:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then self:Hide() return end
            if MODIFIER_KEYS[key] then return end
            local combo = (IsAltKeyDown() and "ALT-" or "")
                .. (IsControlKeyDown() and "CTRL-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "")
                .. key
            local existing = GetBindingAction(combo)
            if existing and existing ~= "" and existing ~= self.action and self.pendingKey ~= combo then
                self.pendingKey = combo
                self.text:SetText(("|cffff4444%s is already bound to:|r\n%s\n\nPress it again to replace it, or pick another key."):format(
                    GetBindingText(combo), _G["BINDING_NAME_" .. existing] or existing))
                return
            end
            self.pendingKey = nil
            if SetKeyFor(self.action, combo) then
                Print(_G["BINDING_NAME_" .. self.action] .. " key: " .. GetBindingText(combo))
            end
            self:Hide()
            if self.onDone then self.onDone() end
        end)
    end
    capture.onDone = onDone
    capture.action = action
    capture.pendingKey = nil
    capture.text:SetText(("Press a key for: %s\n\nCurrent: %s\n(Esc to cancel)"):format(
        _G["BINDING_NAME_" .. action], KeyTextFor(action)))
    capture:Show()
end

local HUNTERS_MARK_SPELL = 1130
local HUNTERS_MARK_FALLBACK = "Interface\\Icons\\Ability_Hunter_SniperShot"

local function HuntersMarkIcon()
    local tex
    if C_Spell and C_Spell.GetSpellTexture then
        tex = C_Spell.GetSpellTexture(HUNTERS_MARK_SPELL)
    elseif GetSpellTexture then
        tex = GetSpellTexture(HUNTERS_MARK_SPELL)
    end
    return tex or HUNTERS_MARK_FALLBACK
end

local ICON_CHOICES = {
    { key = "HUNTERSMARK", label = "Hunter's Mark" },
    { key = "TRACKING",    label = "Track Humanoids", path = "Interface\\Icons\\Ability_Tracking" },
    { key = "EYE",         label = "Mind Vision",     path = "Interface\\Icons\\Spell_Holy_MindVision" },
    { key = "SPYGLASS",    label = "Spyglass",        path = "Interface\\Icons\\INV_Misc_Spyglass_03" },
    { key = "STEALTH",     label = "Stealth",         path = "Interface\\Icons\\Ability_Stealth" },
    { key = "SKULL",       label = "Skull",           path = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
    { key = "SWORDS",      label = "Crossed Swords",  path = "Interface\\Icons\\Ability_DualWield" },
}

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    if GetSpellTexture then return GetSpellTexture(spellID) end
end

local function ResolveCustomIcon(value)
    if value == nil or value == "" then return nil end
    local id = tonumber(value)
    if id then return SpellIcon(id) end
    local path = value
    if not path:find("[\\/]") then path = "Interface\\Icons\\" .. path end
    if GetFileIDFromPath and not GetFileIDFromPath(path) then return nil end
    return path
end

local function IconForKey(key)
    if key == "CUSTOM" then
        return ResolveCustomIcon(db.customIcon) or HuntersMarkIcon()
    end
    for _, c in ipairs(ICON_CHOICES) do
        if c.key == key and c.path then return c.path end
    end
    return HuntersMarkIcon()
end

local button

local function ApplyIcon()
    if button then button.icon:SetTexture(IconForKey(db.icon)) end
end

local function SaveButtonPosition()
    local point, _, relPoint, x, y = button:GetPoint(1)
    db.button.point, db.button.relPoint = point, relPoint
    db.button.x, db.button.y = x, y
end

local function PlaceButton()
    button:ClearAllPoints()
    button:SetPoint(db.button.point or "CENTER", UIParent, db.button.relPoint or "CENTER",
        db.button.x or 0, db.button.y or -180)
end

UpdateButton = function()
    if not button then return end
    local hidden = NpcNamesHidden()
    button.icon:SetDesaturated(not hidden)
    button.icon:SetVertexColor(hidden and 1 or 0.75, hidden and 1 or 0.75, hidden and 1 or 0.75)
    button.glow:SetShown(hidden)
    button:SetShown(db.button.shown)
    if GameTooltip:IsOwned(button) and button:GetScript("OnEnter") then
        button:GetScript("OnEnter")(button)
    end
end

local function CreateButton()
    button = CreateFrame("Button", "NotAMobToggleButton", UIParent)
    button:SetSize(36, 36)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon:SetTexture(IconForKey(db.icon))

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border:SetPoint("CENTER")
    button.border:SetSize(62, 62)

    button.glow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.glow:SetBlendMode("ADD")
    button.glow:SetAllPoints()

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    button:SetScript("OnClick", ToggleNpcNames)
    button:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveButtonPosition()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("NotAMob")
        if NpcNamesHidden() then
            GameTooltip:AddLine("NPC names: OFF", 1, 0.3, 0.3, true)
        else
            GameTooltip:AddLine("NPC names: ON", 0.3, 1, 0.3, true)
        end
        GameTooltip:AddLine("Click: toggle NPC names", 1, 1, 1)
        GameTooltip:AddLine("Shift-drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    PlaceButton()
    UpdateButton()
end

local function IsEnemyPlayer(unit)
    if not unit or not UnitExists(unit) then return false end
    local isPlayer = UnitIsPlayer(unit)
    local canAttack = UnitCanAttack("player", unit)
    if issecretvalue(isPlayer) or issecretvalue(canAttack) then return false end
    return isPlayer and canAttack and true or false
end

local function IsFar(unit)
    if not CheckInteractDistance then return true end
    local ok, near = pcall(CheckInteractDistance, unit, 4)
    if not ok or near == nil or issecretvalue(near) then return true end
    return not near
end

local testMode = false

local function IsTestTarget(unit)
    if not testMode then return false end
    local same = UnitIsUnit(unit, "target")
    if issecretvalue(same) then return false end
    return same and true or false
end

local function DesiredParts(unit)
    if not db.enabled then return nil end
    if not IsEnemyPlayer(unit) and not IsTestTarget(unit) then return nil end
    local far
    local function use(part)
        if not db.farOnly[part] then return true end
        if far == nil then far = IsFar(unit) end
        return far
    end
    local parts = { font = use("font"), size = use("size"), outline = use("outline") }
    if not (parts.font or parts.size or parts.outline) then return nil end
    return parts
end

local function ShouldStyle(unit)
    return DesiredParts(unit) ~= nil
end

local function AnyFarOnly()
    return db.farOnly.font or db.farOnly.size or db.farOnly.outline
end

local function BlizzardNameFontObject()
    local o = NamePlateSetupOptions
    local styles = NamePlateConstants and NamePlateConstants.NAME_ANCHOR_STYLES
    local outlined = _G.SystemFont_NamePlate_Outlined
    if o and styles and outlined then
        local s = o.unitNameAnchorStyle
        if s == styles.InsideHealthBar or s == styles.CenteredAboveHealthBar
            or (s == styles.AboveHealthBar and o.useOutlinedFontWhenAboveHealthBar) then
            return outlined
        end
    end
    return _G.SystemFont_NamePlate
end

local function BlizzardNameHeight()
    return NamePlateSetupOptions and NamePlateSetupOptions.healthBarFontHeight
end

local touched = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })
local fittedSize = setmetatable({}, { __mode = "k" })
local styledByToken = {}

local function Restore(unitFrame)
    applied[unitFrame] = nil
    if not touched[unitFrame] then return end
    local fs = unitFrame.name
    if not fs then return end
    local obj = BlizzardNameFontObject()
    if obj then
        fs:SetFontObject(obj)
        local file, size, flags = obj:GetFont()
        if file then fs:SetFont(file, size, flags) end
    end
    local h = BlizzardNameHeight()
    if h then fs:SetTextHeight(h) end
end

local function Apply(unitFrame, parts)
    local fs = unitFrame.name
    local obj = BlizzardNameFontObject()
    local bfile, bsize, bflags
    if obj then bfile, bsize, bflags = obj:GetFont() end
    local base = BlizzardNameHeight() or bsize or 12

    local file  = parts.font and (FONTS[db.font] or FONTS.FRIZQT) or bfile or FONTS.FRIZQT
    local size  = parts.size and ((db.size > 0) and db.size or math.floor(base * db.scale + 0.5)) or base
    local flags = parts.outline and (OUTLINES[db.outline] or "OUTLINE") or (bflags or "")
    local text = fs:GetText()
    if issecretvalue(text) or type(text) ~= "string" then text = "" end
    local key = file .. "|" .. size .. "|" .. flags .. "|" .. text .. "|" .. tostring(db.shrinkToFit)
    if applied[unitFrame] == key then
        local cur, curSize, curFlags = fs:GetFont()
        if type(cur) == "string" and cur:lower():gsub("/", "\\") == file:lower()
            and (curFlags or "") == flags
            and math.abs((curSize or 0) - (fittedSize[unitFrame] or size)) < 0.5 then
            return
        end
    end

    touched[unitFrame] = true
    local ok = fs:SetFont(file, size, flags)
    if ok == false or not fs:GetFont() then
        file = FONTS.FRIZQT
        fs:SetFont(file, size, flags)
    end
    fs:SetTextHeight(size)

    local fitted = size
    if db.shrinkToFit and parts.size and fs.IsTruncated then
        local function Truncated()
            local okT, t = pcall(fs.IsTruncated, fs)
            return okT and t == true
        end
        while fitted - 1 >= base and Truncated() do
            fitted = fitted - 1
            fs:SetFont(file, fitted, flags)
            fs:SetTextHeight(fitted)
        end
    end
    fittedSize[unitFrame] = fitted
    applied[unitFrame] = key
end

local function IsNamePlateUnitFrame(frame)
    if not frame or frame:IsForbidden() then return false end
    if not frame.name or not frame.unit then return false end
    local unit = frame.unit
    if issecretvalue(unit) or type(unit) ~= "string" then return false end
    return unit:sub(1, 9) == "nameplate"
end

local function Evaluate(unitFrame)
    if not IsNamePlateUnitFrame(unitFrame) then return end
    local unit = unitFrame.unit
    local parts = DesiredParts(unit)
    if parts then
        Apply(unitFrame, parts)
        styledByToken[unit] = unitFrame
    else
        Restore(unitFrame)
        if styledByToken[unit] == unitFrame then styledByToken[unit] = nil end
    end
end

local function EvaluateAll()
    for _, plate in ipairs(C_NamePlate.GetNamePlates(issecure()) or {}) do
        if plate.UnitFrame then Evaluate(plate.UnitFrame) end
    end
end

local function OnNamePlateOptionsChanged()
    wipe(applied)
    EvaluateAll()
end

local ticker
local function UpdateTicker()
    local want = db and db.enabled and AnyFarOnly()
    if want and not ticker then
        ticker = C_Timer.NewTicker(0.5, EvaluateAll)
    elseif not want and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local hooked = {}
local function InstallHooks()
    if not hooked.updateName and type(CompactUnitFrame_UpdateName) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateName", Evaluate)
        hooked.updateName = true
    end
    if NamePlateDriverFrame then
        if not hooked.added and NamePlateDriverFrame.OnNamePlateAdded then
            hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
                local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure())
                if plate and plate.UnitFrame then Evaluate(plate.UnitFrame) end
            end)
            hooked.added = true
        end
        if not hooked.options and NamePlateDriverFrame.UpdateNamePlateOptions then
            hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", OnNamePlateOptionsChanged)
            hooked.options = true
        end
    end
end

local RANGE_CVARS = { "nameplateMaxDistance", "nameplatePlayerMaxDistance" }
local RANGE_MAX_GUESS = 60

local function SetCVarSafe(name, value)
    if InCombatLockdown() then
        Print("Can't change nameplate settings in combat.")
        return false
    end
    SetCVar(name, tostring(value))
    return true
end

local function RangeReport()
    for _, c in ipairs(RANGE_CVARS) do
        local v = GetCVar(c)
        if v ~= nil then
            Print(("%s = %s (default %s)"):format(c, tostring(v), tostring(GetCVarDefault(c))))
        end
    end
end

local function CmdRange(arg)
    if arg == "" then RangeReport() return end
    if InCombatLockdown() then
        Print("Can't change nameplate settings in combat.")
        return
    end
    local reset = (arg == "default" or arg == "reset")
    if reset and not db.prevRange then
        Print("Nothing to undo.")
        return
    end
    local value = (arg == "max") and RANGE_MAX_GUESS or tonumber(arg)
    if not reset and not value then
        Print("Usage: /nam range [max | default | <yards>]")
        return
    end
    for _, c in ipairs(RANGE_CVARS) do
        local cur = GetCVar(c)
        if cur ~= nil then
            db.prevRange = db.prevRange or {}
            local target
            if reset then
                target = db.prevRange[c] or GetCVarDefault(c)
            else
                if db.prevRange[c] == nil then db.prevRange[c] = cur end
                target = value
            end
            SetCVarSafe(c, target)
            Print(("%s: %s"):format(c, tostring(GetCVar(c))))
        end
    end
    if reset then db.prevRange = nil end
end

local function ShowSettings()
    local farList = {}
    for _, part in ipairs({ "font", "size", "outline" }) do
        if db.farOnly[part] then farList[#farList + 1] = part end
    end
    Print(("Player names on plates: %s  font=%s  size=%s  outline=%s  only when far: %s"):format(
        db.enabled and "on" or "off", db.font,
        (db.size > 0) and tostring(db.size) or ("auto x" .. db.scale),
        db.outline, (#farList > 0) and table.concat(farList, ", ") or "none"))
    Print(("NPC names: %s   button: %s   enemy nameplates: %s"):format(
        NpcNamesHidden() and "OFF" or "ON", db.button.shown and "shown" or "hidden",
        tostring(GetCVarBool("nameplateShowEnemies"))))
end

local function Help()
    Print("commands")
    print("  /nam - options")
    print("  /nam names - toggle NPC names")
    print("  /nam key - set the toggle key (/nam key clear)")
    print("  /nam button show | hide | reset")
    print("  /nam on | off - bigger player names")
end

local function FontDesc(file, size, flags)
    return ("%s %.1f %s"):format(tostring(file):match("[^\\/]+$") or tostring(file),
        size or 0, (flags and flags ~= "") and flags or "none")
end

local function Debug()
    local unit = "target"
    if not UnitExists(unit) then Print("No target.") return end
    local isPlayer, canAttack = UnitIsPlayer(unit), UnitCanAttack("player", unit)
    Print(("Target %s: UnitIsPlayer=%s UnitCanAttack=%s -> enemy player=%s, would style=%s"):format(
        tostring(UnitName(unit)),
        issecretvalue(isPlayer) and "secret" or tostring(isPlayer),
        issecretvalue(canAttack) and "secret" or tostring(canAttack),
        tostring(IsEnemyPlayer(unit)), tostring(ShouldStyle(unit))))
    if AnyFarOnly() then
        local parts = DesiredParts(unit)
        Print(("  far (over 28 yd)=%s  using NotAMob's: font=%s size=%s outline=%s"):format(
            tostring(IsFar(unit)),
            tostring(parts and parts.font or false), tostring(parts and parts.size or false),
            tostring(parts and parts.outline or false)))
    end

    local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure())
    if not plate or not plate.UnitFrame then
        Print("  No addon-visible nameplate (plates off, out of range, or a protected instance plate).")
        return
    end
    local uf = plate.UnitFrame
    local file, size, flags = uf.name:GetFont()
    local obj = BlizzardNameFontObject()
    local bfile, _, bflags
    if obj then bfile, _, bflags = obj:GetFont() end
    local bh = BlizzardNameHeight()
    Print("  now:      " .. FontDesc(file, size, flags))
    Print("  Blizzard: " .. FontDesc(bfile, bh, bflags) .. "  (" .. (obj and obj:GetName() or "?") .. ")")
    Print(("  styled by NotAMob: %s   ever touched: %s"):format(
        tostring(applied[uf] ~= nil), tostring(touched[uf] == true)))
    for _, other in ipairs({ "Platynator", "BetterBlizzPlates", "Plater" }) do
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(other)
        if loaded then Print("  NOTE: " .. other .. " is loaded and may change nameplate fonts too.") end
    end
end

local function Refresh()
    UpdateTicker()
    EvaluateAll()
end

local function ToggleTestMode()
    testMode = not testMode
    if testMode then
        NotAMob:RegisterEvent("PLAYER_TARGET_CHANGED")
        Print("Test mode on: your target counts as an enemy player.")
    else
        NotAMob:UnregisterEvent("PLAYER_TARGET_CHANGED")
        Print("Test mode off.")
    end
    EvaluateAll()
end

local nineCam
local nineHidUI = false

local function NineCamRestoreUI()
    if nineHidUI then
        nineHidUI = false
        NotAMob:UnregisterEvent("SCREENSHOT_SUCCEEDED")
        NotAMob:UnregisterEvent("SCREENSHOT_FAILED")
        SetUIVisibility(true)
    end
end

local function NineCamSnap()
    if not UIParent:IsShown() then
        Screenshot()
        return
    end
    nineHidUI = true
    NotAMob:RegisterEvent("SCREENSHOT_SUCCEEDED")
    NotAMob:RegisterEvent("SCREENSHOT_FAILED")
    SetUIVisibility(false)
    C_Timer.After(0.1, function()
        local ok, err = pcall(Screenshot)
        if not ok then
            NineCamRestoreUI()
            Print("Screenshot failed: " .. tostring(err))
        end
    end)
    C_Timer.After(3, NineCamRestoreUI)
end

local function CreateNineCam()
    nineCam = CreateFrame("Button", "NotAMobNineCam", UIParent)
    nineCam:SetSize(36, 36)
    nineCam:SetClampedToScreen(true)
    nineCam:SetMovable(true)
    nineCam:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nineCam:RegisterForDrag("LeftButton")

    nineCam.icon = nineCam:CreateTexture(nil, "ARTWORK")
    nineCam.icon:SetAllPoints()
    nineCam.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    nineCam.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")

    local border = nineCam:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("CENTER")
    border:SetSize(62, 62)

    local label = nineCam:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    label:SetPoint("BOTTOMRIGHT", -2, 2)
    label:SetText("9")

    nineCam:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    nineCam:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    nineCam:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            db.nineCam.shown = false
            self:Hide()
            Print("Nam Nine cam hidden (/nam nine).")
        else
            GameTooltip:Hide()
            NineCamSnap()
        end
    end)
    nineCam:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then self:StartMoving() end
    end)
    nineCam:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        db.nineCam.point, db.nineCam.relPoint, db.nineCam.x, db.nineCam.y = point, relPoint, x, y
    end)
    nineCam:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nam Nine Cam")
        GameTooltip:AddLine("Click: screenshot without the UI", 1, 1, 1)
        GameTooltip:AddLine("Shift-drag: move", 1, 1, 1)
        GameTooltip:AddLine("Right-click: hide", 1, 1, 1)
        GameTooltip:Show()
    end)
    nineCam:SetScript("OnLeave", GameTooltip_Hide)

    nineCam:SetPoint(db.nineCam.point, UIParent, db.nineCam.relPoint, db.nineCam.x, db.nineCam.y)
    nineCam:SetShown(db.nineCam.shown)
end

local function ToggleNineCam()
    db.nineUnlocked = true
    db.nineCam.shown = not db.nineCam.shown
    if not nineCam then CreateNineCam() end
    nineCam:SetShown(db.nineCam.shown)
    if db.nineCam.shown then
        Print("Hi Nam Nine. Say cheese.")
    end
end

function NotAMob_NineSnap()
    NineCamSnap()
end

local function RangeText()
    local npc = GetCVar("nameplateMaxDistance")
    local plr = GetCVar("nameplatePlayerMaxDistance")
    if plr ~= nil and plr ~= npc then
        return ("now %s yd / players %s yd"):format(tostring(npc), tostring(plr))
    end
    return ("now %s yd"):format(tostring(npc))
end

local optionsCategory

local FONT_LABELS = {
    SKURRI   = "Skurri (heavy, slanted)",
    FRIZQT   = "Friz Quadrata (Blizzard's normal font)",
    ARIALN   = "Arial Narrow",
    MORPHEUS = "Morpheus (quest-text serif)",
}
local OUTLINE_LABELS = { none = "None", outline = "Thin", thick = "Thick" }

local function BuildOptions()
    if optionsCategory or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

    local category, layout = Settings.RegisterVerticalLayoutCategory("NotAMob")
    optionsCategory = category
    if not layout and SettingsPanel and SettingsPanel.GetLayout then
        layout = SettingsPanel:GetLayout(category)
    end

    local function Header(text)
        if layout and CreateSettingsListSectionHeaderInitializer then
            local init = CreateSettingsListSectionHeaderInitializer(text)
            layout:AddInitializer(init)
            return init
        end
    end

    local function AddButton(name, textFunc, onClick, tooltip, refreshEvent)
        if layout and CreateSettingsButtonInitializer then
            local refresh = refreshEvent and function(btn) btn:SetText(textFunc()) end or nil
            local init = CreateSettingsButtonInitializer(name, textFunc, onClick, tooltip, true,
                nil, refresh, refreshEvent)
            layout:AddInitializer(init)
            return init
        end
    end

    Header("NPC names (works at any distance)")

    AddButton("NPC names",
        function() return NpcNamesHidden() and "Show NPC names" or "Hide NPC names" end,
        function(btn)
            ToggleNpcNames()
            btn:SetText(NpcNamesHidden() and "Show NPC names" or "Hide NPC names")
        end,
        "Hide every NPC floating name, so any name you can still see is a player. Click again to get your own NPC Names setting back.")

    AddButton("Toggle key",
        ToggleKeyText,
        function(btn)
            OpenKeyCapture(function() btn:SetText(ToggleKeyText()) end)
        end,
        "Click, then press the key you want for toggling NPC names. If the key is already used, you'll be warned first. It also appears under Options > Keybindings > AddOns > NotAMob.",
        "UPDATE_BINDINGS")

    AddButton("Clear toggle key",
        function() return "Clear key" end,
        function()
            if not GetBindingKey(BINDING_ACTION) then
                Print("No toggle key set.")
            elseif SetToggleKey(nil) then
                Print("Toggle key cleared.")
            end
        end,
        "Remove the key binding for toggling NPC names.")

    do
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_SHOW_BUTTON",
            Settings.VarType.Boolean, "Show toggle button", true,
            function() return db.button.shown end,
            function(v) db.button.shown = v; UpdateButton() end)
        Settings.CreateCheckbox(category, setting,
            "The floating button that toggles NPC names. Shift-drag it to move it.")
    end

    do
        local function GetOptions()
            local c = Settings.CreateControlTextContainer()
            for _, choice in ipairs(ICON_CHOICES) do
                local tex = IconForKey(choice.key)
                c:Add(choice.key, "|T" .. tostring(tex) .. ":16:16|t " .. choice.label)
            end
            if db.customIcon then
                c:Add("CUSTOM", "|T" .. tostring(IconForKey("CUSTOM")) .. ":16:16|t Custom (" .. db.customIcon .. ")")
            end
            return c:GetData()
        end
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_ICON",
            Settings.VarType.String, "Button icon", DEFAULTS.icon,
            function() return db.icon end,
            function(v) db.icon = v; ApplyIcon() end)
        Settings.CreateDropdown(category, setting, GetOptions,
            "The picture on the toggle button. For any other icon, type /nam icon followed by an icon name (like Ability_Stealth) or a spell ID.")
    end

    AddButton("Button position", function() return "Reset position" end,
        function()
            db.button.point, db.button.relPoint, db.button.x, db.button.y = "CENTER", "CENTER", 0, -180
            PlaceButton()
        end,
        "Move the Hunter's Mark button back to the middle of the screen.")

    Header("Enemy player names on nameplates")

    do
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_ENABLED",
            Settings.VarType.Boolean, "Bigger enemy-player names", true,
            function() return db.enabled end,
            function(v) db.enabled = v; Refresh() end)
        Settings.CreateCheckbox(category, setting,
            "Inside nameplate range, enemy players' names use the font and size below. Mobs keep Blizzard's normal font.")
    end

    do
        local function GetOptions()
            local c = Settings.CreateControlTextContainer()
            for _, key in ipairs(FONT_ORDER) do c:Add(key, FONT_LABELS[key] or key) end
            return c:GetData()
        end
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_FONT",
            Settings.VarType.String, "Font", DEFAULTS.font,
            function() return db.font end,
            function(v) if FONTS[v] then db.font = v; Refresh() end end)
        Settings.CreateDropdown(category, setting, GetOptions, "Typeface for enemy-player names.")
    end

    do
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_SCALE",
            Settings.VarType.Number, "Size", DEFAULTS.scale,
            function() return db.scale end,
            function(v)
                db.scale = math.floor(v * 10 + 0.5) / 10
                db.size = 0
                Refresh()
            end)
        local options = Settings.CreateSliderOptions(1, 3, 0.1)
        if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                function(v) return ("%.1fx"):format(v) end)
        end
        Settings.CreateSlider(category, setting, options,
            "How much bigger than Blizzard's normal name size. 1.5x is the default.")
    end

    do
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_SHRINK_TO_FIT",
            Settings.VarType.Boolean, "Shrink long names to fit", false,
            function() return db.shrinkToFit end,
            function(v) db.shrinkToFit = v; wipe(applied); Refresh() end)
        Settings.CreateCheckbox(category, setting,
            "Long names that don't fit at the bigger size get cut off with \"...\". Check this to shrink those names just enough to show in full (never smaller than Blizzard's normal size).")
    end

    do
        local function GetOptions()
            local c = Settings.CreateControlTextContainer()
            c:Add("none", OUTLINE_LABELS.none, "No border around the letters.")
            c:Add("outline", OUTLINE_LABELS.outline, "A thin dark border around each letter.")
            c:Add("thick", OUTLINE_LABELS.thick, "A heavy dark border around each letter.")
            return c:GetData()
        end
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_OUTLINE",
            Settings.VarType.String, "Outline", DEFAULTS.outline,
            function() return db.outline end,
            function(v) if OUTLINES[v] then db.outline = v; Refresh() end end)
        Settings.CreateDropdown(category, setting, GetOptions,
            "A dark border drawn around each letter, so names stay readable over bright or busy backgrounds.")
    end

    Header("Only when far away (beyond 28 yards)")

    local FAR_PARTS = {
        { key = "font",    name = "Font only when far",
          tip = "Checked: up close, enemy players keep Blizzard's normal font; your font is used only when they're far away. Unchecked: your font is always used." },
        { key = "size",    name = "Size only when far",
          tip = "Checked: up close, enemy players keep Blizzard's normal name size; the bigger size is used only when they're far away. Unchecked: always bigger." },
        { key = "outline", name = "Outline only when far",
          tip = "Checked: up close, enemy players keep Blizzard's normal outline; your outline is used only when they're far away. Unchecked: your outline is always used." },
    }
    for _, p in ipairs(FAR_PARTS) do
        local setting = Settings.RegisterProxySetting(category, "NOTAMOB_FARONLY_" .. p.key:upper(),
            Settings.VarType.Boolean, p.name, false,
            function() return db.farOnly[p.key] end,
            function(v) db.farOnly[p.key] = v; Refresh() end)
        Settings.CreateCheckbox(category, setting, p.tip)
    end

    Header("Testing")

    AddButton("Test on my target",
        function() return testMode and "Stop test" or "Start test" end,
        function(btn)
            ToggleTestMode()
            btn:SetText(testMode and "Stop test" or "Start test")
        end,
        "Treat whatever you target as an enemy player, so you can check the font with only mobs around. Tab between mobs: only your current target should look big. Turns off on /reload.")

    Header("Nameplate range")

    AddButton("Show plates farther away",
        function() return "Max range (" .. RangeText() .. ")" end,
        function(btn)
            CmdRange("max")
            btn:SetText("Max range (" .. RangeText() .. ")")
        end,
        "Raise how far away nameplates (and the bigger player names) appear, for NPCs and players, to the game's maximum. This changes nameplateMaxDistance and nameplatePlayerMaxDistance; the game may cap the value.",
        "CVAR_UPDATE")

    AddButton("Undo range change",
        function() return "Restore previous" end,
        function()
            CmdRange("default")
        end,
        "Put nameplate range back to what it was before NotAMob changed it. Does nothing if NotAMob hasn't changed it.")

    local function unlocked() return db.nineUnlocked == true end
    local nineRows = {
        Header("Nam Nine"),
        AddButton("Screenshot key",
            function() return KeyTextFor(NINE_ACTION) end,
            function(btn)
                OpenKeyCapture(function() btn:SetText(KeyTextFor(NINE_ACTION)) end, NINE_ACTION)
            end,
            "A key that hides the UI and takes a screenshot, like the Nam Nine Cam button.",
            "UPDATE_BINDINGS"),
        AddButton("Clear screenshot key",
            function() return "Clear key" end,
            function()
                if not GetBindingKey(NINE_ACTION) then
                    Print("No screenshot key set.")
                elseif SetKeyFor(NINE_ACTION, nil) then
                    Print("Screenshot key cleared.")
                end
            end,
            "Remove the screenshot key."),
    }
    for _, init in pairs(nineRows) do
        if init.AddShownPredicate then init:AddShownPredicate(unlocked) end
    end

    Settings.RegisterAddOnCategory(category)
end

local function OpenOptions()
    if not optionsCategory then BuildOptions() end
    if optionsCategory then
        Settings.OpenToCategory(optionsCategory:GetID())
    else
        Print("Couldn't open the options page. Type /nam help for commands.")
    end
end

SLASH_NOTAMOB1 = "/nam"
SLASH_NOTAMOB2 = "/notamob"
SlashCmdList.NOTAMOB = function(msg)
    local original = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local rawArg = original:match("^%S*%s*(.-)$") or ""
    msg = original:lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == "" or cmd == "options" or cmd == "menu" then
        OpenOptions()
    elseif cmd == "status" then
        ShowSettings()
    elseif cmd == "key" then
        if arg == "clear" then
            if not GetBindingKey(BINDING_ACTION) then
                Print("No toggle key is set.")
            elseif SetToggleKey(nil) then
                Print("NPC names toggle key cleared.")
            end
        else
            OpenKeyCapture()
        end
    elseif cmd == "help" then
        Help()
    elseif cmd == "names" or cmd == "npcnames" then
        ToggleNpcNames()
    elseif cmd == "button" then
        if arg == "show" then db.button.shown = true
        elseif arg == "hide" then db.button.shown = false
        elseif arg == "reset" then
            db.button = { shown = true, point = "CENTER", relPoint = "CENTER", x = 0, y = -180 }
            PlaceButton()
        else db.button.shown = not db.button.shown end
        UpdateButton()
        Print(db.button.shown and "Button shown." or "Button hidden (/nam button show).")
    elseif cmd == "icon" then
        local raw = rawArg
        local up = arg:upper()
        local found
        for _, c in ipairs(ICON_CHOICES) do
            if c.key == up then found = c.key end
        end
        if arg == "" then
            Print("/nam icon <name | icon file | spell ID | default>")
        elseif arg == "default" then
            db.icon = DEFAULTS.icon; ApplyIcon()
        elseif found then
            db.icon = found; ApplyIcon()
        elseif ResolveCustomIcon(raw) then
            db.customIcon = raw; db.icon = "CUSTOM"; ApplyIcon()
        else
            Print("No icon called \"" .. raw .. "\".")
        end
    elseif cmd == "on" or cmd == "enable" then
        db.enabled = true; Refresh(); Print("Bigger player names on.")
    elseif cmd == "off" or cmd == "disable" then
        db.enabled = false; Refresh(); Print("Bigger player names off.")
    elseif cmd == "font" then
        local key = arg:upper():gsub("%.TTF$", ""):gsub("_+$", "")
        if FONTS[key] then
            db.font = key; Refresh(); Print("Font: " .. key)
        else
            Print("Fonts: " .. table.concat(FONT_ORDER, ", "))
        end
    elseif cmd == "size" then
        if arg == "auto" then
            db.size = 0; Refresh(); Print("Size: " .. db.scale .. "x")
        else
            local n = tonumber(arg)
            if n and n >= 6 and n <= 64 then
                db.size = n; Refresh(); Print("Size: " .. n)
            else
                Print("/nam size <6-64 | auto>")
            end
        end
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 4 then
            db.scale = n; db.size = 0; Refresh(); Print("Size: " .. n .. "x")
        else
            Print("/nam scale <0.5-4>")
        end
    elseif cmd == "fit" then
        if arg == "on" then db.shrinkToFit = true
        elseif arg == "off" then db.shrinkToFit = false
        else db.shrinkToFit = not db.shrinkToFit end
        wipe(applied); Refresh()
        Print("Shrink to fit " .. (db.shrinkToFit and "on." or "off."))
    elseif cmd == "outline" then
        if OUTLINES[arg] then
            db.outline = arg; Refresh(); Print("Outline: " .. arg)
        else
            Print("/nam outline <none | outline | thick>")
        end
    elseif cmd == "distance" then
        local v = (arg == "on") or (arg ~= "off" and not AnyFarOnly())
        db.farOnly.font, db.farOnly.size, db.farOnly.outline = v, v, v
        Refresh(); Print("Only when far " .. (v and "on." or "off."))
    elseif cmd == "far" then
        local part, onoff = arg:match("^(%S+)%s*(%S*)$")
        if part and db.farOnly[part] ~= nil then
            if onoff == "on" then db.farOnly[part] = true
            elseif onoff == "off" then db.farOnly[part] = false
            else db.farOnly[part] = not db.farOnly[part] end
            Refresh()
            Print(("%s only when far %s."):format(part, db.farOnly[part] and "on" or "off"))
        else
            Print("/nam far <font | size | outline> [on | off]")
        end
    elseif cmd == "range" then
        CmdRange(arg)
    elseif cmd == "showplates" then
        if SetCVarSafe("nameplateShowEnemies", 1) then Print("Enemy nameplates turned on.") end
    elseif cmd == "debug" then
        Debug()
    elseif cmd == "test" then
        ToggleTestMode()
    elseif cmd == "nine" then
        ToggleNineCam()
    elseif cmd == "reset" then
        local keep = { savedNpcNames = db.savedNpcNames, prevRange = db.prevRange, welcomed = db.welcomed,
            nineUnlocked = db.nineUnlocked, nineCam = db.nineCam }
        wipe(db)
        for k, v in pairs(DEFAULTS) do db[k] = (type(v) == "table") and CopyTable(v) or v end
        for k, v in pairs(keep) do db[k] = v end
        PlaceButton(); Refresh(); UpdateButton()
        if nineCam then nineCam:SetShown(db.nineCam.shown) end
        Print("Settings reset.")
    else
        Help()
    end
end

NotAMob:RegisterEvent("ADDON_LOADED")
NotAMob:RegisterEvent("PLAYER_LOGIN")
NotAMob:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
NotAMob:RegisterEvent("CVAR_UPDATE")

NotAMob:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            NotAMobDB = NotAMobDB or {}
            db = NotAMobDB
            for k, v in pairs(DEFAULTS) do
                if db[k] == nil then db[k] = (type(v) == "table") and CopyTable(v) or v end
            end
            if not FONTS[db.font] then db.font = DEFAULTS.font end
            if not OUTLINES[db.outline] then db.outline = DEFAULTS.outline end
            for part in pairs(DEFAULTS.farOnly) do
                if db.farOnly[part] == nil then db.farOnly[part] = false end
            end
            if db.distanceMode ~= nil then
                if db.distanceMode then
                    db.farOnly.font, db.farOnly.size, db.farOnly.outline = true, true, true
                end
                db.distanceMode = nil
            end
            if db.prevMaxDistance ~= nil then
                db.prevRange = db.prevRange or { nameplateMaxDistance = db.prevMaxDistance }
                db.prevMaxDistance = nil
            end
        end
        if db then InstallHooks() end

    elseif event == "PLAYER_LOGIN" then
        InstallHooks()
        CreateButton()
        if db.nineCam.shown then CreateNineCam() end
        BuildOptions()
        UpdateTicker()
        EvaluateAll()
        if not db.welcomed then
            C_Timer.After(4, function()
                Print("Click the button to hide NPC names. /nam for options.")
                if not GetCVarBool("nameplateShowEnemies") then
                    Print("Enemy nameplates are off (V) - turn them on for bigger player names.")
                end
                db.welcomed = true
            end)
        elseif not GetCVarBool("nameplateShowEnemies") then
            Print("Enemy nameplates are off (V).")
        end

    elseif event == "CVAR_UPDATE" then
        if UpdateButton then UpdateButton() end

    elseif event == "PLAYER_TARGET_CHANGED" then
        EvaluateAll()

    elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        NineCamRestoreUI()

    elseif event == "PLAYER_REGEN_ENABLED" then
        NotAMob:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if pendingNpcNames then
            local p = pendingNpcNames
            pendingNpcNames = nil
            ApplyNpcNames(p.values, p.label)
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local uf = styledByToken[arg1]
        styledByToken[arg1] = nil
        if uf then Restore(uf) end
    end
end)
