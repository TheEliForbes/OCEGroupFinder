-- GroupLatencyFinder.lua
-- Highlights premade Group Finder listings led by players on OCE (Oceanic) realms.
-- Compatible with World of Warcraft: Midnight (patch 12.0.5, interface 120005)

local ADDON_NAME = "GroupLatencyFinder"

-- ─── OCE realm list ───────────────────────────────────────────────────────────
-- All Oceanic realms physically hosted in Australia (US region, OCE flag).
local OCE_REALMS = {
    ["Barthilas"]   = true,
    ["Caelestrasz"] = true,
    ["Dath'Remar"]  = true,
    ["Dreadmaul"]   = true,
    ["Frostmourne"] = true,
    ["Gundrak"]     = true,
    ["Jubei'Thos"]  = true,
    ["Khaz'goroth"] = true,
    ["Nagrand"]     = true,
    ["Saurfang"]    = true,
    ["Thaurissan"]  = true,
}

local OCE_BADGE_COLOR = { r = 0.0, g = 0.78, b = 1.0, a = 1.0 }

-- ─── Utilities ────────────────────────────────────────────────────────────────

local function IsOCERealm(realm)
    if not realm or realm == "" then return false end
    -- Handle connected realms separated by " / "
    for part in realm:gmatch("[^/]+") do
        if OCE_REALMS[part:match("^%s*(.-)%s*$")] then return true end
    end
    return false
end

local function GetRealmFromNameRealm(nameRealm)
    if not nameRealm then return GetRealmName() end
    -- "Name-Realm" format; realm may itself contain hyphens (e.g. Khaz'goroth has none,
    -- but some future-proofing: grab everything after the LAST hyphen-separated name part)
    local realm = nameRealm:match("^.+%-(.+)$")
    return realm or GetRealmName()
end

-- ─── Per-button badge elements ────────────────────────────────────────────────

local function EnsureBadge(button)
    if button._oceLabel then return button._oceLabel end
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -4)
    label:SetText("|cFF00C8FF[OCE]|r")
    label:Hide()
    button._oceLabel = label
    return label
end

local function EnsureBorder(button)
    if button._oceBorder then return button._oceBorder end
    local tex = button:CreateTexture(nil, "BACKGROUND")
    tex:SetWidth(4)
    tex:SetPoint("TOPLEFT",    button, "TOPLEFT",    0, 0)
    tex:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    tex:SetColorTexture(OCE_BADGE_COLOR.r, OCE_BADGE_COLOR.g, OCE_BADGE_COLOR.b, OCE_BADGE_COLOR.a)
    tex:Hide()
    button._oceBorder = tex
    return tex
end

local function SetOCEBadge(button, show)
    local label  = EnsureBadge(button)
    local border = EnsureBorder(button)
    if show then
        label:Show()
        border:Show()
    else
        label:Hide()
        border:Hide()
    end
end

-- ─── Core evaluation ──────────────────────────────────────────────────────────

local function EvaluateButton(button)
    local resultID = button.resultID
    if not resultID then
        SetOCEBadge(button, false)
        return
    end

    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then
        SetOCEBadge(button, false)
        return
    end

    local realm = GetRealmFromNameRealm(info.leaderName)
    SetOCEBadge(button, IsOCERealm(realm))
end

-- ─── Button discovery & hooking ───────────────────────────────────────────────
-- In Midnight, scroll frame children are anonymous frames — numbered _G globals
-- like "LFGListSearchPanelScrollFrameButton1" no longer exist. We walk the
-- frame hierarchy directly instead.
--
-- hooksecurefunc() on an *object table key* (2-arg form) is still permitted;
-- only hooking named global string functions was restricted in patch 11.0+.

local hookedButtons = {}

local function HookButton(button)
    if hookedButtons[button] then return end
    hookedButtons[button] = true

    if button.SetSearchResult then
        hooksecurefunc(button, "SetSearchResult", function(self)
            EvaluateButton(self)
        end)
    end
    if button.Update then
        hooksecurefunc(button, "Update", function(self)
            EvaluateButton(self)
        end)
    end
end

-- Recursively search a frame's children for result buttons
local function FindAndHookInFrame(frame, depth)
    if not frame or depth > 4 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.resultID ~= nil or child.SetSearchResult ~= nil then
            HookButton(child)
            EvaluateButton(child)
        end
        FindAndHookInFrame(child, depth + 1)
    end
end

local function ScanAndHookButtons()
    if not LFGListFrame then return end

    -- Try known panel paths — Blizzard sometimes renames these between patches
    local searchPanel = LFGListFrame.SearchPanel
                     or LFGListFrame.searchPanel
    if not searchPanel then return end

    local scrollFrame = searchPanel.ScrollFrame
                     or searchPanel.scrollFrame
                     or searchPanel.ResultsScrollFrame
    if not scrollFrame then
        -- Fallback: just recurse the whole search panel
        FindAndHookInFrame(searchPanel, 0)
        return
    end

    -- Walk scroll child (virtual scroll) and direct children
    local scrollChild = scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()
    if scrollChild then
        FindAndHookInFrame(scrollChild, 0)
    end
    FindAndHookInFrame(scrollFrame, 0)
end

-- ─── Tooltip enhancement ──────────────────────────────────────────────────────
-- Hook the tooltip *frame script* (HookScript) rather than a named global
-- function — the named-global form of hooksecurefunc is restricted in Midnight.

local function SetupTooltipHook()
    -- LFGListSearchEntry_OnEnter is called as a frame OnEnter script.
    -- We hook each result button's OnEnter after we discover it.
end

-- Attach a tooltip hook to a button once we know about it
local function HookButtonTooltip(button)
    if button._oceTooltipHooked then return end
    button._oceTooltipHooked = true

    button:HookScript("OnEnter", function(self)
        local resultID = self.resultID
        if not resultID then return end
        local info = C_LFGList.GetSearchResultInfo(resultID)
        if not info then return end
        local realm = GetRealmFromNameRealm(info.leaderName)
        if IsOCERealm(realm) then
            if GameTooltip:IsShown() then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFF00C8FF\xF0\x9F\x8C\x8F Oceanic Realm Leader|r")
                GameTooltip:AddLine("Realm: " .. (realm or "Unknown"), 0.7, 0.9, 1.0)
                GameTooltip:Show()
            end
        end
    end)
end

-- Extended scan that also wires up tooltips
local function FullScanButtons()
    if not LFGListFrame then return end
    local searchPanel = LFGListFrame.SearchPanel or LFGListFrame.searchPanel
    if not searchPanel then return end

    local function Recurse(frame, depth)
        if not frame or depth > 4 then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child.resultID ~= nil or child.SetSearchResult ~= nil then
                HookButton(child)
                HookButtonTooltip(child)
                EvaluateButton(child)
            end
            Recurse(child, depth + 1)
        end
    end

    local scrollFrame = searchPanel.ScrollFrame
                     or searchPanel.scrollFrame
                     or searchPanel.ResultsScrollFrame
    if scrollFrame then
        local sc = scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()
        if sc then Recurse(sc, 0) end
        Recurse(scrollFrame, 0)
    else
        Recurse(searchPanel, 0)
    end
end

-- ─── Event frame ──────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame", ADDON_NAME .. "EventFrame", UIParent)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
eventFrame:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        GroupLatencyFinderDB = GroupLatencyFinderDB or { enabled = true }
        print("|cFF00C8FF[GroupLatencyFinder]|r Loaded \xe2\x80\x94 OCE realm groups will be highlighted in the Group Finder. (/ocegf help)")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED"
        or event == "LFG_LIST_AVAILABILITY_UPDATE"
        or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        -- Defer one frame so Blizzard's UI has time to populate resultID fields
        C_Timer.After(0.05, FullScanButtons)
    end
end)

-- ─── Slash commands ───────────────────────────────────────────────────────────

SLASH_GroupLatencyFinder1 = "/ocegf"
SLASH_GroupLatencyFinder2 = "/ocegroup"

SlashCmdList["GroupLatencyFinder"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")  -- trim whitespace

    if msg == "" or msg == "help" then
        print("|cFF00C8FF[GroupLatencyFinder]|r Commands:")
        print("  |cFFFFD700/ocegf realms|r  \xe2\x80\x93 List all tracked OCE realms")
        print("  |cFFFFD700/ocegf refresh|r \xe2\x80\x93 Re-scan the current Group Finder results")
        print("  |cFFFFD700/ocegf help|r    \xe2\x80\x93 Show this message")

    elseif msg == "realms" then
        print("|cFF00C8FF[GroupLatencyFinder]|r Tracked OCE realms:")
        local sorted = {}
        for realm in pairs(OCE_REALMS) do sorted[#sorted + 1] = realm end
        table.sort(sorted)
        for _, realm in ipairs(sorted) do
            print("  |cFF00C8FF\xe2\x80\xa2|r " .. realm)
        end

    elseif msg == "refresh" then
        FullScanButtons()
        print("|cFF00C8FF[GroupLatencyFinder]|r Results refreshed.")

    else
        print("|cFF00C8FF[GroupLatencyFinder]|r Unknown command. Type |cFFFFD700/ocegf help|r for options.")
    end
end
