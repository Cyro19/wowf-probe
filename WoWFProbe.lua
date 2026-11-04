-- WoWFProbe 1.0.0 - WoW: Forever (wowf) capability probe. Interface 16001, Lua 5.1.
-- Purpose: settle, on the live build, every question the beta left open:
--   interface number, project constants, secret-value behavior, combat-log
--   restriction state, secure handler availability, SavedVariables persistence.
-- NOTE: this addon intentionally touches restricted surfaces (CLEU registration,
-- secret arithmetic) inside pcall probes. Static linters will flag them; that is
-- the point. Probe results are printed and stored in WoWFProbeDB.lastReport.
local addonName, ns = ...

local C_YELLOW = "|cffd4a85a"
local C_GREEN  = "|cff7fd65a"
local C_RED    = "|cffe05a5a"
local C_GREY   = "|cff9a9a9a"
local C_END    = "|r"

local results = {}

local function Record(key, ok, detail)
    local tag = ok == nil and C_GREY .. "INFO" or (ok and C_GREEN .. "PASS" or C_RED .. "FAIL")
    local line = string.format("%s%s|r %s: %s", tag, C_END, key, detail)
    print(line)
    table.insert(results, string.format("%s | %s | %s", ok == nil and "INFO" or (ok and "PASS" or "FAIL"), key, detail))
end

local function Have(fn)
    return type(fn) == "function"
end

-- Individual probes ------------------------------------------------------------

local function ProbeBuild()
    local version, build, date, iface = GetBuildInfo()
    Record("build", iface == 16001,
        string.format("GetBuildInfo = %s / %s / %s / interface %d (expected 16001)", version, build, date, iface))
end

local function ProbeProject()
    local id = WOW_PROJECT_ID
    Record("project-id", WOW_PROJECT_CAMELOT ~= nil and id == WOW_PROJECT_CAMELOT,
        string.format("WOW_PROJECT_ID=%s WOW_PROJECT_MAINLINE=%s WOW_PROJECT_CLASSIC=%s WOW_PROJECT_CAMELOT=%s",
            tostring(id), tostring(WOW_PROJECT_MAINLINE), tostring(WOW_PROJECT_CLASSIC), tostring(WOW_PROJECT_CAMELOT)))
end

local function ProbeSecretAPI()
    Record("secret-api", Have(issecretvalue),
        string.format("issecretvalue=%s canaccessvalue=%s issecrettable=%s canaccesstable=%s",
            tostring(issecretvalue), tostring(canaccessvalue), tostring(issecrettable), tostring(canaccesstable)))
end

local function ProbeSecretHealth()
    if not Have(issecretvalue) then
        Record("secret-health", nil, "issecretvalue missing; cannot probe")
        return
    end
    local h = UnitHealth("player")
    local okArith = pcall(function() return h + 1 end)
    local okCmp = pcall(function() return h > 0 end)
    Record("secret-health", nil, string.format(
        "UnitHealth('player'): type=%s secret=%s arithmetic=%s comparison=%s",
        type(h), tostring(issecretvalue(h)),
        okArith and "allowed" or "BLOCKED", okCmp and "allowed" or "BLOCKED"))
end

local function ProbeCombatLog()
    local hasFn = C_CombatLog and Have(C_CombatLog.IsCombatLogRestricted)
    local restricted = nil
    if hasFn then
        local ok, val = pcall(C_CombatLog.IsCombatLogRestricted)
        if ok then restricted = val end
    end
    Record("combatlog-api", hasFn ~= nil, "C_CombatLog.IsCombatLogRestricted = " .. tostring(restricted))

    local f = CreateFrame("Frame")
    local okReg, err = pcall(function() f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end)
    if okReg then pcall(function() f:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end) end
    Record("combatlog-cleu", okReg, okReg and "RegisterEvent(CLEU) accepted (restriction is runtime, not load-time)"
        or ("RegisterEvent(CLEU) threw: " .. tostring(err)))
end

local function ProbeSecureHandlers()
    Record("secure-handlers", Have(SecureHandlerWrapScript) and Have(RegisterStateDriver),
        string.format("SecureHandlerWrapScript=%s RegisterStateDriver=%s SecureCmdOptionParse=%s",
            tostring(SecureHandlerWrapScript), tostring(RegisterStateDriver), tostring(SecureCmdOptionParse)))
end

local function ProbeForeverAPIs()
    local preset = C_GameRules and Have(C_GameRules.GetForeverExperiencePreset)
    local val
    if preset then
        local ok, v = pcall(C_GameRules.GetForeverExperiencePreset)
        if ok then val = tostring(v) end
    end
    Record("forever-gamerules", preset ~= nil, "C_GameRules.GetForeverExperiencePreset = " .. tostring(val))
end

local function ProbePlatform()
    Record("timer", C_Timer and Have(C_Timer.NewTicker), "C_Timer.NewTicker present")
    Record("compartment", type(AddonCompartmentFrame) == "table" or AddonCompartmentFrame ~= nil,
        "AddonCompartmentFrame = " .. tostring(AddonCompartmentFrame))
    Record("settings", type(Settings) == "table" and Have(Settings.RegisterVerticalLayoutCategory),
        "Settings.RegisterVerticalLayoutCategory present")
    Record("curves", C_CurveUtil and Have(C_CurveUtil.CreateColorCurve), "C_CurveUtil.CreateColorCurve present")
    Record("durations", C_DurationUtil and Have(C_DurationUtil.CreateDuration), "C_DurationUtil.CreateDuration present")
    Record("restricted-state", C_RestrictedActions ~= nil, "C_RestrictedActions namespace = " .. tostring(C_RestrictedActions))
    local ok, region = pcall(GetCurrentRegion)
    Record("region", nil, "GetCurrentRegion = " .. tostring(ok and region or ("error: " .. tostring(region)))
        .. " (old AceDB broke here on beta)")
end

local function ProbeAuras()
    Record("auras", C_UnitAuras and Have(C_UnitAuras.GetAuraDataByIndex),
        "C_UnitAuras.GetAuraDataByIndex present (payloads may be secret in combat)")
end

local function ProbeSavedVars()
    WoWFProbeDB.bootCount = (WoWFProbeDB.bootCount or 0) + 1
    WoWFProbeDB.lastReport = results
    Record("savedvars", nil, string.format(
        "bootCount=%d - /reload and re-run /wowfprobe; persistence works if this increments", WoWFProbeDB.bootCount))
end

function ns.RunAll()
    results = {}
    print(C_YELLOW .. "[WoWFProbe]" .. C_END .. " probing client capability surface...")
    ProbeBuild()
    ProbeProject()
    ProbeSecretAPI()
    ProbeSecretHealth()
    ProbeCombatLog()
    ProbeSecureHandlers()
    ProbeForeverAPIs()
    ProbePlatform()
    ProbeAuras()
    ProbeSavedVars()
    print(C_YELLOW .. "[WoWFProbe]" .. C_END .. " done. Report stored in WoWFProbeDB.lastReport (SavedVariables).")
    print(C_GREY .. "Tip: /run C_CVar.RegisterCVar('addonCombatRestrictionsForced'); SetCVar('addonCombatRestrictionsForced','1')" .. C_END)
    print(C_GREY .. "     re-runs probes under forced combat restriction (session only)." .. C_END)
end

function WoWFProbe_OnCompartmentClick()
    ns.RunAll()
end

-- Wiring ------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

function handlers:ADDON_LOADED(loaded)
    if loaded ~= addonName then return end
    WoWFProbeDB = WoWFProbeDB or {}
    ns.db = WoWFProbeDB
    frame:UnregisterEvent("ADDON_LOADED")
end

function handlers:PLAYER_LOGIN()
    print(C_YELLOW .. "[WoWFProbe]" .. C_END .. " loaded. /wowfprobe to probe.")
end

frame:SetScript("OnEvent", function(self, event, ...)
    local h = handlers[event]
    if h then h(self, ...) end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

SLASH_WOWFPROBE1 = "/wowfprobe"
SlashCmdList["WOWFPROBE"] = function(msg)
    ns.RunAll()
end
