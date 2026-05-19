-- OCEGroupFinder_Settings.lua
-- Settings panel: a draggable frame listing all OCE realms with add / remove controls.
-- Opens via  /ocegf config  (or  /ocegf settings)
-- Compatible with World of Warcraft: Midnight (patch 12.0.5, interface 120005)

local ADDON_NAME   = "OCEGroupFinder"
local PANEL_WIDTH  = 340
local PANEL_HEIGHT = 480
local ROW_HEIGHT   = 26
local MAX_VISIBLE  = 13   -- rows shown without scrolling

-- ─── Shared realm table (global so both files can access it) ─────────────────
-- This file loads first (see .toc). OCEGroupFinder.lua reads/writes this table.
OCE_REALMS = {}   -- populated below and persisted via SavedVariables

local DEFAULT_REALMS = {
    "Barthilas", "Caelestrasz", "Dath'Remar", "Dreadmaul", "Frostmourne",
    "Gundrak",   "Jubei'Thos",  "Khaz'goroth", "Nagrand",  "Saurfang",
    "Thaurissan",
}

-- Seed OCE_REALMS with defaults immediately so it's ready before ADDON_LOADED.
for _, r in ipairs(DEFAULT_REALMS) do OCE_REALMS[r] = true end

-- Forward-declared so the panel builder can reference it
local panel

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function Trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

-- Capitalise first letter, lowercase the rest (basic normalisation)
local function NormaliseRealm(name)
    name = Trim(name)
    if name == "" then return "" end
    return name:sub(1,1):upper() .. name:sub(2)
end

-- ─── Shared styled texture helpers ────────────────────────────────────────────

local function AddBackground(frame, r, g, b, a)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(r, g, b, a or 1)
    return bg
end

local function AddBorder(frame, r, g, b, thickness)
    thickness = thickness or 1
    local function Edge(point, relPoint, xOff, yOff, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, 1)
        t:SetPoint(point, frame, relPoint, xOff, yOff)
        t:SetSize(w, h)
    end
    Edge("TOPLEFT",     "TOPLEFT",     0,          0,           PANEL_WIDTH, thickness)
    Edge("BOTTOMLEFT",  "BOTTOMLEFT",  0,          0,           PANEL_WIDTH, thickness)
    Edge("TOPLEFT",     "TOPLEFT",     0,          0,           thickness,   PANEL_HEIGHT)
    Edge("TOPRIGHT",    "TOPRIGHT",    0,          0,           thickness,   PANEL_HEIGHT)
end

-- ─── Row pool ─────────────────────────────────────────────────────────────────

local rowPool = {}  -- reusable row frames

local function GetRow(parent)
    local r = table.remove(rowPool)
    if r then
        r:SetParent(parent)
        r:Show()
        return r
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    -- Subtle alternating stripe (toggled when displayed)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetColorTexture(1, 1, 1, 0)

    -- Realm name label
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetTextColor(0.9, 0.9, 0.9)

    -- Remove button  [×]
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(22, 22)
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.removeBtn:SetNormalFontObject("GameFontNormalSmall")
    row.removeBtn:SetText("|cFFFF5555X|r")   -- × in UTF-8

    local btnBg = row.removeBtn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints(row.removeBtn)
    btnBg:SetColorTexture(0.25, 0.05, 0.05, 0.8)
    row.removeBtn.bg = btnBg

    row.removeBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.55, 0.1, 0.1, 1)
    end)
    row.removeBtn:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.25, 0.05, 0.05, 0.8)
    end)

    return row
end

local function ReleaseRow(row)
    row:Hide()
    row:SetParent(nil)
    row.removeBtn:SetScript("OnClick", nil)
    table.insert(rowPool, row)
end

-- ─── Panel state ──────────────────────────────────────────────────────────────

local activeRows   = {}
local scrollOffset = 0   -- index of first visible realm (0-based)

local function GetSortedRealms()
    local list = {}
    for realm in pairs(OCE_REALMS) do list[#list + 1] = realm end
    table.sort(list)
    return list
end

-- ─── Render the realm list ────────────────────────────────────────────────────

local function RenderList()
    -- Release old rows
    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}

    local realms  = GetSortedRealms()
    local total   = #realms
    local listFrame = panel.listFrame

    -- Update scrollbar
    local scrollbar = panel.scrollbar
    local maxScroll = math.max(0, total - MAX_VISIBLE)
    scrollOffset = math.min(scrollOffset, maxScroll)
    if maxScroll > 0 then
        scrollbar:Show()
        scrollbar:SetMinMaxValues(0, maxScroll)
        scrollbar:SetValue(scrollOffset)
    else
        scrollbar:Hide()
    end

    -- Draw visible rows
    local visibleCount = math.min(MAX_VISIBLE, total - scrollOffset)
    for i = 1, visibleCount do
        local realmIndex = scrollOffset + i
        local realm      = realms[realmIndex]
        local row        = GetRow(listFrame)

        row:SetPoint("TOPLEFT",  listFrame, "TOPLEFT",  0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)

        -- Alternating stripe
        if i % 2 == 0 then
            row.stripe:SetColorTexture(1, 1, 1, 0.04)
        else
            row.stripe:SetColorTexture(0, 0, 0, 0)
        end

        row.label:SetText(realm)

        local capturedRealm = realm
        row.removeBtn:SetScript("OnClick", function()
            OCE_REALMS[capturedRealm] = nil
            -- Persist to SavedVariables
            OCEGroupFinderDB.customRealms = OCEGroupFinderDB.customRealms or {}
            OCEGroupFinderDB.removedRealms = OCEGroupFinderDB.removedRealms or {}
            OCEGroupFinderDB.removedRealms[capturedRealm] = true
            OCEGroupFinderDB.customRealms[capturedRealm]  = nil
            scrollOffset = math.max(0, math.min(scrollOffset, #GetSortedRealms() - MAX_VISIBLE))
            RenderList()
            panel.countLabel:SetText(#GetSortedRealms() .. " realms")
        end)

        activeRows[#activeRows + 1] = row
    end

    -- Empty-state message
    if total == 0 then
        panel.emptyLabel:Show()
    else
        panel.emptyLabel:Hide()
    end

    panel.countLabel:SetText(total .. " realm" .. (total == 1 and "" or "s"))
end

-- ─── Build the panel ──────────────────────────────────────────────────────────

local function BuildPanel()
    if panel then return end

    panel = CreateFrame("Frame", ADDON_NAME .. "SettingsPanel", UIParent,
                        "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
    panel:Hide()

    -- Background
    AddBackground(panel, 0.08, 0.08, 0.10, 0.96)

    -- Cyan top accent bar
    local accent = panel:CreateTexture(nil, "BORDER")
    accent:SetHeight(3)
    accent:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, 0)
    accent:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    accent:SetColorTexture(0.0, 0.78, 1.0, 1)

    -- Thin outer border
    local bdr = panel:CreateTexture(nil, "ARTWORK")
    bdr:SetAllPoints(panel)
    bdr:SetColorTexture(0.0, 0.78, 1.0, 0.18)

    -- ── Title bar ────────────────────────────────────────────────────────────

    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetHeight(36)
    titleBar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -3)
    titleBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -3)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints(titleBar)
    titleBg:SetColorTexture(0.0, 0.78, 1.0, 0.10)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    titleText:SetText("|cFF00C8FFOCEGroupFinder|r    Realm Editor")
    titleText:SetTextColor(0.9, 0.9, 0.9)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -7)
    closeBtn:SetNormalFontObject("GameFontNormalLarge")
    closeBtn:SetText("|cFFAAAAAAX|r")
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeBtn)
    closeBg:SetColorTexture(1, 1, 1, 0)
    closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(1, 0.2, 0.2, 0.25) end)
    closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(1, 1,   1,   0)    end)

    -- ── "Add realm" input row ─────────────────────────────────────────────────

    local inputRow = CreateFrame("Frame", nil, panel)
    inputRow:SetHeight(38)
    inputRow:SetPoint("TOPLEFT",  panel, "TOPLEFT",  10, -46)
    inputRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -46)

    local inputBg = inputRow:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints(inputRow)
    inputBg:SetColorTexture(0, 0, 0, 0.4)

    local inputBox = CreateFrame("EditBox", ADDON_NAME .. "RealmInput", inputRow,
                                 "InputBoxTemplate")
    inputBox:SetHeight(24)
    inputBox:SetPoint("LEFT",  inputRow, "LEFT",  8,   0)
    inputBox:SetPoint("RIGHT", inputRow, "RIGHT", -90, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(64)
    inputBox:SetFontObject("GameFontHighlight")

    -- Placeholder ghost text
    local placeholder = inputRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", inputBox, "LEFT", 4, 0)
    placeholder:SetText("Realm name...")

    inputBox:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
    end)

    local addBtn = CreateFrame("Button", nil, inputRow, "UIPanelButtonTemplate")
    addBtn:SetSize(76, 26)
    addBtn:SetPoint("RIGHT", inputRow, "RIGHT", -4, 0)
    addBtn:SetText("Add")
    addBtn:GetFontString():SetTextColor(0.0, 0.9, 1.0)

    local function DoAdd()
        local raw = NormaliseRealm(inputBox:GetText())
        if raw == "" then return end
        if OCE_REALMS[raw] then
            panel.statusLabel:SetText("|cFFFFCC00'" .. raw .. "' is already in the list.|r")
            return
        end
        OCE_REALMS[raw] = true
        OCEGroupFinderDB.customRealms  = OCEGroupFinderDB.customRealms or {}
        OCEGroupFinderDB.removedRealms = OCEGroupFinderDB.removedRealms or {}
        OCEGroupFinderDB.customRealms[raw]  = true
        OCEGroupFinderDB.removedRealms[raw] = nil
        inputBox:SetText("")
        placeholder:Show()
        panel.statusLabel:SetText("|cFF00C8FFAdded '|r" .. raw .. "|cFF00C8FF'.|r")
        RenderList()
    end

    addBtn:SetScript("OnClick", DoAdd)
    inputBox:SetScript("OnEnterPressed", DoAdd)

    -- ── Divider ───────────────────────────────────────────────────────────────

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",  10, -90)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -90)
    divider:SetColorTexture(0.0, 0.78, 1.0, 0.3)

    -- ── Count label ───────────────────────────────────────────────────────────

    local countLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -98)
    countLabel:SetTextColor(0.55, 0.55, 0.55)
    panel.countLabel = countLabel

    -- ── Scrollable realm list ─────────────────────────────────────────────────

    local listContainer = CreateFrame("Frame", nil, panel)
    listContainer:SetPoint("TOPLEFT",  panel, "TOPLEFT",   10, -114)
    listContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 50)

    local listFrame = CreateFrame("Frame", nil, listContainer)
    listFrame:SetAllPoints(listContainer)
    panel.listFrame = listFrame

    -- Scrollbar
    local scrollbar = CreateFrame("Slider", ADDON_NAME .. "Scrollbar", panel,
                                  "UIPanelScrollBarTemplate")
    scrollbar:SetPoint("TOPRIGHT",    panel, "TOPRIGHT",  -8, -116)
    scrollbar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 52)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValue(0)
    scrollbar:SetValueStep(1)
    scrollbar:SetScript("OnValueChanged", function(self, val)
        scrollOffset = math.floor(val + 0.5)
        RenderList()
    end)
    -- Mouse wheel on list
    listContainer:EnableMouseWheel(true)
    listContainer:SetScript("OnMouseWheel", function(_, delta)
        local realms  = GetSortedRealms()
        local maxScr  = math.max(0, #realms - MAX_VISIBLE)
        scrollOffset  = math.max(0, math.min(scrollOffset - delta, maxScr))
        scrollbar:SetValue(scrollOffset)
        RenderList()
    end)
    panel.scrollbar = scrollbar

    -- Empty-state message
    local emptyLabel = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyLabel:SetPoint("CENTER", listFrame, "CENTER", 0, 0)
    emptyLabel:SetText("No realms configured.\nType a name above and click Add.")
    emptyLabel:SetJustifyH("CENTER")
    emptyLabel:Hide()
    panel.emptyLabel = emptyLabel

    -- ── Status / feedback label ───────────────────────────────────────────────

    local statusLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusLabel:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  12,  10)
    statusLabel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 10)
    statusLabel:SetJustifyH("LEFT")
    statusLabel:SetText("")
    panel.statusLabel = statusLabel

    -- Clear status after 4 seconds
    local statusTimer
    local origSetText = statusLabel.SetText
    statusLabel.SetText = function(self, txt)
        origSetText(self, txt)
        if statusTimer then statusTimer:Cancel() end
        if txt ~= "" then
            statusTimer = C_Timer.NewTimer(4, function()
                origSetText(statusLabel, "")
            end)
        end
    end

    -- ── Bottom divider ────────────────────────────────────────────────────────

    local divider2 = panel:CreateTexture(nil, "ARTWORK")
    divider2:SetHeight(1)
    divider2:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  0, 26)
    divider2:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 26)
    divider2:SetColorTexture(0.0, 0.78, 1.0, 0.15)

    -- ── Reset-to-defaults button ──────────────────────────────────────────────

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 3)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        -- Wipe custom additions and removals; restore built-in list
        OCEGroupFinderDB.customRealms  = {}
        OCEGroupFinderDB.removedRealms = {}
        -- Re-populate OCE_REALMS from the defaults embedded in this file
        for k in pairs(OCE_REALMS) do OCE_REALMS[k] = nil end
        for _, r in ipairs(DEFAULT_REALMS) do OCE_REALMS[r] = true end
        scrollOffset = 0
        panel.statusLabel:SetText("|cFF00C8FFReset to default OCE realm list.|r")
        RenderList()
    end)

    -- Close on Escape
    panel:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    panel:SetPropagateKeyboardInput(true)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

function OCEGroupFinder_OpenSettings()
    BuildPanel()
    RenderList()
    panel:Show()
    panel:Raise()
end

function OCEGroupFinder_CloseSettings()
    if panel then panel:Hide() end
end

-- ─── Persist custom realms across sessions ────────────────────────────────────
-- Called from the main file's ADDON_LOADED handler (see OCEGroupFinder.lua)

function OCEGroupFinder_LoadSavedRealms()
    local db = OCEGroupFinderDB
    if not db then return end

    -- Remove realms the user deleted
    if db.removedRealms then
        for realm in pairs(db.removedRealms) do
            OCE_REALMS[realm] = nil
        end
    end
    -- Add custom realms the user added
    if db.customRealms then
        for realm in pairs(db.customRealms) do
            OCE_REALMS[realm] = true
        end
    end
end
