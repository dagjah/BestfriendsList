local addonName, BFL = ...
local db, window, refresh, clearSearch
local lastAlert = {}
local bffPresent = {}
local partyTab, bffTab, recentTab = false, false, false
local recentPresent = {}
local function say(message)
    DEFAULT_CHAT_FRAME:AddMessage('|cffff5555BestfriendsList:|r ' .. message)
end

local function announce(message, color)
    color = color or {r = 1, g = 0.25, b = 0.25}
    DEFAULT_CHAT_FRAME:AddMessage(message, color.r, color.g, color.b)
    if RaidNotice_AddMessage and RaidWarningFrame then RaidNotice_AddMessage(RaidWarningFrame, message, color) end
    if db.sound then PlaySound(8959, 'Master') end
end

-- Forever's second UnitName return is a surname, not a realm.
local normalize = BFL.Name

local function fullName(unit)
    local first, surname = UnitName(unit)
    if issecretvalue and (issecretvalue(first) or issecretvalue(surname)) then return end
    if not first then return end
    if surname and surname ~= '' and not first:find(' ', 1, true) then
        return first .. ' ' .. surname
    end
    return first
end

local function isEligible(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    if UnitIsUnit(unit, 'player') then return false end
    local ours, theirs = UnitFactionGroup('player'), UnitFactionGroup(unit)
    if issecretvalue and (issecretvalue(ours) or issecretvalue(theirs)) then return false end
    if not ours or not theirs or ours == 'Neutral' or theirs == 'Neutral' then return false end
    return ours ~= theirs
end

local function readableCall(func, ...)
    local ok, value = pcall(func, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return end
    return value
end

local function updateDetails(entry, unit)
    local changed = false
    local function store(field, value)
        if value ~= nil and entry[field] ~= value then
            entry[field] = value
            changed = true
        end
    end
    local ok, class, token = pcall(UnitClass, unit)
    if ok then
        if not (issecretvalue and issecretvalue(token)) and type(token) == 'string' and token ~= '' then
            store('class', token)
        elseif not (issecretvalue and issecretvalue(class)) and type(class) == 'string' and class ~= '' then
            store('class', class)
        end
    end
    local guid = readableCall(UnitGUID, unit)
    if type(guid) == 'string' and guid ~= '' then store('guid', guid) end
    store('faction', BFL.UnitFaction(unit))
    local level = readableCall(UnitLevel, unit)
    -- Unknown/skull levels must not overwrite a previously observed level.
    if type(level) == 'number' and level > 0 then store('level', level) end
    store('lastSeen', time())
    local zone = readableCall(GetRealZoneText)
    if type(zone) == 'string' and zone ~= '' then store('lastSeenZone', zone) end
    return changed
end

local function openPlayerMenu(entry)
    local key = entry and normalize(entry.name)
    if not key then return end
    local guid = type(entry.guid) == 'string' and entry.guid or nil
    if not guid then
        local units = {'target', 'mouseover'}
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do units[#units + 1] = 'raid' .. i end
        elseif IsInGroup() then
            for i = 1, 4 do units[#units + 1] = 'party' .. i end
        end
        for _, unit in ipairs(units) do
            local ok, found = pcall(function()
                if UnitExists(unit) and UnitIsPlayer(unit) and normalize(fullName(unit)) == key then
                    return readableCall(UnitGUID, unit)
                end
            end)
            if ok and type(found) == 'string' and found ~= '' then guid = found; break end
        end
    end
    if not FriendsFrame_ShowDropdown and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, 'Blizzard_FriendsFrame')
    end
    -- Use a complete Forever first/surname, never surname-as-realm or a stale
    -- cached unit token. A real ChatFrame keeps the native Whisper action valid.
    local ok
    if FriendsFrame_ShowDropdown then
        ok = pcall(FriendsFrame_ShowDropdown, entry.name, 1, nil, nil, DEFAULT_CHAT_FRAME,
            nil, nil, nil, nil, nil, guid)
    elseif UnitPopup_OpenMenu then
        ok = pcall(UnitPopup_OpenMenu, 'FRIEND', {
            name = entry.name, chatTarget = entry.name, chatFrame = DEFAULT_CHAT_FRAME, guid = guid,
        })
    end
    if not ok then say('The player menu is currently unavailable on this client.') end
end

local function scanBFF()
    if not db then return end
    local members, unresolved, detailsChanged = {}, false, false
    local function inspectMember(unit)
        if not UnitExists(unit) then unresolved = true; return end
        if UnitIsUnit(unit, 'player') then return end
        local key, display = normalize(fullName(unit))
        if not key then unresolved = true; return end
        if BFL.RememberFaction(key, BFL.UnitFaction(unit)) then
            detailsChanged = true
            if BFL.Own()[key] then BFL.ListChanged() end
        end
        members[key] = true
        local joined = not recentPresent[key]
        if joined or BFL.RecentPlayer(key) then
            local details = {groupType = IsInRaid() and 'raid' or 'party'}
            updateDetails(details, unit)
            if BFL.RecordRecent(display, details, time(), joined) then detailsChanged = true end
            if BFL.RememberFaction(key, details.faction) then detailsChanged = true end
        end
        local entry = db.bffEntries[key]
        if entry then
            if updateDetails(entry, unit) then detailsChanged = true end
            entry.lastGrouped, entry.lastGroupedZone = entry.lastSeen, entry.lastSeenZone
        end
    end
    local count = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, count do
            if not pcall(inspectMember, 'raid' .. i) then unresolved = true end
        end
    elseif IsInGroup() then
        for i = 1, math.min(4, math.max(0, count - 1)) do
            if not pcall(inspectMember, 'party' .. i) then unresolved = true end
        end
    end
    -- Unavailable roster identities must not cause repeat alerts when resolved.
    if unresolved then
        for key in pairs(bffPresent) do members[key] = true end
    end
    local nextRecent = {}
    for key in pairs(members) do nextRecent[key] = true end
    if unresolved then for key in pairs(recentPresent) do nextRecent[key] = true end end
    recentPresent = nextRecent
    local present, joined = BFL.BFFTransitions(db.bffEntries, members, bffPresent)
    local changed = detailsChanged or #joined > 0
    for key in pairs(bffPresent) do if not present[key] then changed = true end end
    bffPresent = present
    for _, key in ipairs(joined) do
        local label = BFL.BFFLabel(db.bffEntries[key])
        announce(BFL.GroupAlert(db.bffEntries[key].name, label, IsInRaid()), {r = 0.7, g = 0.4, b = 1})
    end
    if changed and refresh then refresh() end
end
local function addBFF(name, faction, details)
    local key, display = normalize(name)
    if not key then say('Enter the full first name and surname.'); return end
    if faction == nil then faction = BFL.CurrentFaction() end
    if db.bffEntries[key] then
        if BFL.ValidFaction(faction) then BFL.RememberFaction(key, faction) end
        if details then
            for _, field in ipairs({'class', 'level', 'guid', 'lastGrouped', 'lastGroupedZone'}) do
                if details[field] ~= nil then db.bffEntries[key][field] = details[field] end
            end
        end
        say(display .. ' is already on your BFF List; faction updated when provided.')
        if refresh then refresh() end
        return
    end
    db.bffEntries[key] = {name = display, added = time(), faction = BFL.ValidFaction(faction) and faction or nil,
        class = details and details.class, level = details and details.level, guid = details and details.guid,
        lastGrouped = details and details.lastGrouped, lastGroupedZone = details and details.lastGroupedZone}
    if BFL.ValidFaction(faction) then BFL.RememberFaction(key, faction) end
    say('Added ' .. display .. ' to your BFF List.')
    scanBFF()
    if refresh then refresh() end
end
local function addBFFTarget()
    local ok, name = pcall(function()
        if UnitExists('target') and UnitIsPlayer('target') and not UnitIsUnit('target', 'player') then
            return fullName('target')
        end
    end)
    if not ok or not name then say('Target another player to add to your BFF List.'); return end
    addBFF(name, BFL.UnitFaction('target') or false)
    local key = normalize(name)
    local entry = key and db.bffEntries[key]
    if entry then
        local details = {}
        pcall(updateDetails, details, 'target')
        entry.class = details.class or entry.class
        entry.level = details.level or entry.level
        entry.faction = details.faction or entry.faction
        entry.guid = details.guid or entry.guid
        if refresh then refresh() end
    end
end
local function removeBFF(name)
    local key = normalize(name)
    if not key or not db.bffEntries[key] then say('That full name is not on your BFF List.'); return end
    db.bffEntries[key], bffPresent[key] = nil, nil
    say('Removed ' .. name .. ' from your BFF List.')
    if refresh then refresh() end
end

local function inspect(unit)
    if not db or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local key = normalize(fullName(unit))
    if not key then return end
    if BFL.RememberFaction(key, BFL.UnitFaction(unit)) then
        if BFL.Own()[key] then BFL.ListChanged() end
        if refresh then refresh() end
    end
    if not isEligible(unit) then return end
    local matches = BFL.Matches(key)
    if #matches == 0 then return end
    local entry, changed = matches[1].entry, false
    for _, match in ipairs(matches) do
        if updateDetails(match.entry, unit) then changed = true end
    end
    if changed and refresh then refresh() end
    local now = GetTime()
    if lastAlert[key] and now - lastAlert[key] < 30 then return end
    lastAlert[key] = now
    announce(BFL.WatchAlert(entry.name, BFL.NameLabel(key)))
end

-- Restricted/secret unit data must never break the event handler.
local function check(unit) pcall(inspect, unit) end
local function scan()
    check('target')
    check('mouseover')
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.namePlateUnitToken then check(plate.namePlateUnitToken) end
        end
    end
end

local function add(name, details, faction)
    local key, display = normalize(name)
    if not key then say('Enter the full first name and surname, e.g. Arthas Menethil.'); return end
    if faction == nil then
        if details then faction = BFL.EntryFaction(details, key)
        else faction = BFL.OppositeFaction(BFL.CurrentFaction()) end
    end
    if BFL.Own()[key] then
        if BFL.ValidFaction(faction) then BFL.RememberFaction(key, faction); BFL.ListChanged() end
        say(display .. ' is already listed; faction updated when provided.')
        if refresh then refresh() end
        return
    end
    BFL.Own()[key] = {
        name = display, added = time(),
        class = details and details.class,
        level = details and details.level,
        guid = details and details.guid,
        lastSeen = details and details.lastSeen,
        lastSeenZone = details and details.lastSeenZone,
        faction = BFL.ValidFaction(faction) and faction or nil,
    }
    if BFL.ValidFaction(faction) then BFL.RememberFaction(key, faction) end
    BFL.ListChanged()
    say('Added ' .. display .. ' to ' .. BFL.ListTitle() .. '.')
    if refresh then refresh() end
    scan()
end
local function addTarget()
    local ok, name = pcall(function()
        if UnitExists('target') and UnitIsPlayer('target') and not UnitIsUnit('target', 'player') then
            return fullName('target')
        end
    end)
    if not ok or not name then say('Target another player first.'); return end
    local ours, theirs = BFL.CurrentFaction(), BFL.UnitFaction('target')
    if not ours or not theirs then say('The client is currently hiding the player faction. Try again when it is readable.'); return end
    local details = {}
    pcall(updateDetails, details, 'target')
    if ours == theirs then addBFF(name, theirs, details)
    else add(name, details, theirs) end
end
local function remove(name)
    local key = normalize(name)
    if not key or not BFL.Own()[key] then say('That full name is not on your list.'); return end
    BFL.Own()[key], lastAlert[key] = nil, nil
    BFL.ListChanged()
    say('Removed ' .. name .. ' from ' .. BFL.ListTitle() .. '.')
    if refresh then refresh() end
end

local LIST_TAB_WIDTH, LIST_TAB_PADDING = 124, 24
local UI = {
    bg = {0.055, 0.065, 0.085, 0.98},
    border = {0.20, 0.24, 0.30, 1},
    accent = {0.36, 0.72, 1, 1},
}
local function surface(frame, color)
    frame:SetBackdrop({bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1})
    frame:SetBackdropColor(unpack(color or UI.bg))
    frame:SetBackdropBorderColor(unpack(UI.border))
end
local function button(parent, text, width, x, y, callback)
    local b = CreateFrame('Button', nil, parent, 'BackdropTemplate')
    b:SetSize(width, 24)
    b:SetPoint('TOPLEFT', x, y)
    surface(b, {0.11, 0.13, 0.17, 1})
    local label = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    label:SetPoint('CENTER')
    b:SetFontString(label)
    b:SetText(text)
    b:SetScript('OnClick', callback)
    local underline = b:CreateTexture(nil, 'ARTWORK')
    underline:SetColorTexture(unpack(UI.accent))
    underline:SetPoint('BOTTOMLEFT', 1, 1); underline:SetPoint('BOTTOMRIGHT', -1, 1)
    underline:SetHeight(2); underline:Hide()
    local function paint()
        local enabled = b:IsEnabled()
        if b.selected then b:SetBackdropColor(0.12, 0.22, 0.31, 1)
        elseif b.tone == 'primary' then b:SetBackdropColor(0.12, b.hovered and 0.29 or 0.23, b.hovered and 0.41 or 0.33, 1)
        elseif b.hovered and enabled then b:SetBackdropColor(0.16, 0.21, 0.27, 1)
        else b:SetBackdropColor(0.10, 0.12, 0.16, 1) end
        if b.selected or b.tone == 'primary' or (b.hovered and enabled) then b:SetBackdropBorderColor(0.32, 0.48, 0.62, 1)
        else b:SetBackdropBorderColor(0.20, 0.24, 0.30, 1) end
        if not enabled then label:SetTextColor(0.42, 0.47, 0.54)
        elseif b.tone == 'danger' then label:SetTextColor(1, 0.48, 0.48)
        elseif b.selected then label:SetTextColor(0.72, 0.88, 1)
        else label:SetTextColor(0.84, 0.88, 0.93) end
        underline:SetShown(b.selected == true)
    end
    function b:SetSelected(selected) self.selected = selected; paint() end
    function b:SetTone(tone) self.tone = tone; paint() end
    b:HookScript('OnEnter', function() b.hovered = true; paint() end)
    b:HookScript('OnLeave', function() b.hovered = false; paint() end)
    b:HookScript('OnEnable', paint); b:HookScript('OnDisable', paint)
    paint()
    return b
end
local function field(parent, width, x, y, placeholder)
    local edit = CreateFrame('EditBox', nil, parent, 'BackdropTemplate')
    edit:SetSize(width, 28); edit:SetPoint('TOPLEFT', x, y)
    surface(edit, {0.035, 0.045, 0.06, 1})
    edit:SetFontObject(ChatFontNormal); edit:SetTextInsets(10, 28, 0, 0)
    edit:SetAutoFocus(false)
    local hint = edit:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    hint:SetPoint('LEFT', 10, 0); hint:SetText(placeholder or '')
    edit:SetScript('OnTextChanged', function(self, userInput)
        hint:SetShown((self:GetText() or '') == '')
        if self.onTextChanged then self.onTextChanged(self, userInput) end
    end)
    edit:HookScript('OnEditFocusGained', function() edit:SetBackdropBorderColor(unpack(UI.accent)) end)
    edit:HookScript('OnEditFocusLost', function() edit:SetBackdropBorderColor(unpack(UI.border)) end)
    edit:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    edit:SetText('')
    return edit
end
local function shell(name, width, height, title)
    local f = CreateFrame('Frame', name, UIParent, 'BackdropTemplate')
    f:SetSize(width, height); f:SetPoint('CENTER'); f:SetClampedToScreen(true)
    f:SetMovable(true); f:EnableMouse(true); f:SetToplevel(true)
    surface(f)
    local titlebar = CreateFrame('Frame', nil, f)
    titlebar:SetPoint('TOPLEFT', 1, -1); titlebar:SetPoint('TOPRIGHT', -1, -1); titlebar:SetHeight(40)
    local fill = titlebar:CreateTexture(nil, 'BACKGROUND')
    fill:SetAllPoints(); fill:SetColorTexture(0.08, 0.10, 0.13, 1)
    titlebar:EnableMouse(true); titlebar:RegisterForDrag('LeftButton')
    titlebar:SetScript('OnDragStart', function() f:StartMoving() end)
    titlebar:SetScript('OnDragStop', function() f:StopMovingOrSizing() end)
    f.TitleText = titlebar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    f.TitleText:SetPoint('LEFT', 16, 0); f.TitleText:SetText(title); f.TitleText:SetTextColor(0.9, 0.94, 1)
    local close = button(titlebar, 'X', 22, width - 34, -9, function() f:Hide() end)
    close:SetSize(22, 22); close:SetTone('danger')
    tinsert(UISpecialFrames, name)
    return f
end
local labelsWindow
local function showLabels()
    if not labelsWindow then
        local f = shell('BestfriendsListBFFLabels', 360, 250, 'BFF labels')
        labelsWindow = f
        f:SetFrameStrata('DIALOG')
        f.fields = {}
        for i = 1, 4 do
            local number = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
            number:SetPoint('TOPLEFT', 16, -55 - (i - 1) * 32); number:SetText(i .. '.')
            local edit = field(f, 288, 48, -48 - (i - 1) * 32)
            edit:SetMaxLetters(24)
            f.fields[i] = edit
        end
        button(f, 'Save labels', 150, 16, -204, function()
            local names = {}
            for i, field in ipairs(f.fields) do names[i] = field:GetText() end
            local ok, err = BFL.SetBFFLabels(names)
            if not ok then say(err); return end
            f:Hide()
            if refresh then refresh() end
            say('BFF label names saved. Existing assignments use the new names.')
        end)
        button(f, 'Cancel', 166, 178, -204, function() f:Hide() end)
    end
    for i, field in ipairs(labelsWindow.fields) do field:SetText(db.bffLabels[i]) end
    labelsWindow:Show()
end
local optionsWindow
local function showOptions()
    if not optionsWindow then
        local f = shell('BestfriendsListOptions', 400, 250, 'BestfriendsList options')
        optionsWindow = f; f:SetFrameStrata('DIALOG')
        local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        title:SetPoint('TOPLEFT', 18, -52); title:SetText('Name of your opposing-faction list')
        f.name = field(f, 364, 18, -72, 'Ex-friend')
        f.measure = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        f.measure:SetPoint('TOPLEFT', 0, 0); f.measure:SetAlpha(0)
        f.measure:SetWordWrap(false)
        f.feedback = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        f.feedback:SetPoint('TOPLEFT', 18, -110); f.feedback:SetWidth(364); f.feedback:SetJustifyH('LEFT')
        local function validate()
            local name, err = BFL.NormalizeListTitle(f.name:GetText())
            if not name then return nil, nil, err end
            f.measure:SetText(name)
            local width = f.measure:GetStringWidth()
            if width > LIST_TAB_WIDTH - LIST_TAB_PADDING then
                return nil, nil, 'That name is too wide for the tab. Choose a shorter name.'
            end
            return name, width
        end
        local function save()
            local name, width, err = validate()
            if not name then f.feedback:SetText(err); return end
            local ok, saveError = BFL.SetListTitle(name, width, LIST_TAB_WIDTH - LIST_TAB_PADDING)
            if not ok then f.feedback:SetText(saveError); return end
            f:Hide()
            if refresh then refresh() end
        end
        f.name:SetScript('OnEnterPressed', save)
        button(f, 'Edit BFF labels', 364, 18, -144, function()
            showLabels(); labelsWindow:Raise()
        end)
        local hint = f:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
        hint:SetPoint('TOPLEFT', 18, -178); hint:SetWidth(364); hint:SetJustifyH('LEFT')
        hint:SetText('Your list name is shared by your characters and used in nearby alerts.')
        f.save = button(f, 'Save options', 174, 18, -210, save)
        f.save:SetTone('primary')
        button(f, 'Cancel', 182, 200, -210, function() f:Hide() end)
        f.update = function()
            local name, _, err = validate()
            f.save:SetEnabled(name ~= nil)
            f.feedback:SetText(name and 'Name fits the tab.' or err)
            f.feedback:SetTextColor(name and 0.48 or 1, name and 0.78 or 0.48, name and 0.62 or 0.48)
        end
        f.name.onTextChanged = function() f.update() end
        f:SetScript('OnShow', function() f.update() end)
    end
    optionsWindow.name:SetText(BFL.ListTitle())
    optionsWindow:Show(); optionsWindow.update()
end
local filterWindow
local function showFilters()
    if not filterWindow then
        local f = shell('BestfriendsListFilters', 430, 352, 'Faction and label filters')
        filterWindow = f; f:SetFrameStrata('DIALOG')
        f.summary = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        f.summary:SetPoint('TOPLEFT', 18, -52); f.summary:SetWidth(394)
        f.summary:SetJustifyH('LEFT')
        f.choices = {}
        local function choice(text, y, callback)
            local b = button(f, text, 394, 18, y, callback)
            b:SetHeight(26)
            b:GetFontString():ClearAllPoints(); b:GetFontString():SetPoint('LEFT', 34, 0)
            b:GetFontString():SetWidth(346); b:GetFontString():SetJustifyH('LEFT')
            b.check = b:CreateTexture(nil, 'OVERLAY')
            b.check:SetTexture('Interface\\Buttons\\UI-CheckBox-Check')
            b.check:SetSize(20, 20); b.check:SetPoint('LEFT', 6, 0)
            return b
        end
        for i = 1, 4 do
            local slot = i
            f.choices[i] = choice('', -92 - (i - 1) * 32, function()
                f.labels[slot] = not f.labels[slot]; f.repaint()
            end)
        end
        f.unknown = choice('Include entries whose faction is still unknown', -232, function()
            f.showUnknown = not f.showUnknown; f.repaint()
        end)
        f.repaint = function()
            for i, b in ipairs(f.choices) do
                b:SetText(db.bffLabels[i]); b:SetSelected(f.labels[i] == true)
                b.check:SetShown(f.labels[i] == true)
            end
            f.unknown:SetSelected(f.showUnknown); f.unknown.check:SetShown(f.showUnknown)
        end
        local hint = f:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
        hint:SetPoint('TOPLEFT', 18, -269); hint:SetWidth(394); hint:SetJustifyH('LEFT')
        hint:SetText('BFF shows your faction. Your watchlist shows the opposing faction. Choices are saved per faction.')
        button(f, 'Apply filters', 190, 18, -300, function()
            local filters = BFL.Filters()
            filters.labels, filters.showUnknown = f.labels, f.showUnknown
            f:Hide()
            if BFL.FiltersChanged then BFL.FiltersChanged() end
        end):SetTone('primary')
        button(f, 'Cancel', 197, 215, -300, function() f:Hide() end)
    end
    local filters = BFL.Filters()
    filterWindow.labels = {}
    for i = 1, 4 do filterWindow.labels[i] = filters.labels[i] == true end
    filterWindow.showUnknown = filters.showUnknown == true
    filterWindow.summary:SetText('Playing ' .. (BFL.CurrentFaction() or 'unknown faction') .. '. Include '
        .. (BFL.OppositeFaction(BFL.CurrentFaction()) or 'enemy') .. ' BFF players in your watchlist with these labels:')
    filterWindow.repaint(); filterWindow:Show()
end
local addWindow
local function showAddPlayer(recent)
    if not addWindow then
        local f = shell('BestfriendsListAddPlayer', 380, 214, 'Add player')
        addWindow = f; f:SetFrameStrata('DIALOG')
        local hint = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        hint:SetPoint('TOPLEFT', 18, -52); hint:SetText('Full first name and surname')
        f.input = field(f, 344, 18, -72, 'Firstname Surname')
        f.input:SetMaxLetters(80)
        local function submit()
            if not normalize(f.input:GetText()) then say('Enter the full first name and surname.'); return end
            local forBFF = f.forBFF
            if f.chooseByFaction then
                if not BFL.ValidFaction(f.faction) then say('Choose Alliance or Horde for this recent player.'); return end
                forBFF = f.faction == BFL.CurrentFaction()
            end
            local details = f.fromRecent
            if details and normalize(f.input:GetText()) ~= normalize(details.name) then details = nil end
            if forBFF then addBFF(f.input:GetText(), f.faction or false, details)
            else add(f.input:GetText(), details, f.faction or false) end
            f:Hide()
            if clearSearch then clearSearch() end
        end
        local factionLabel = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        factionLabel:SetPoint('TOPLEFT', 18, -115); factionLabel:SetText('Faction')
        f.factionButtons = {}
        for i, choice in ipairs({'Alliance', 'Horde', 'Unknown'}) do
            local value = choice
            f.factionButtons[choice] = button(f, choice, 80, 104 + (i - 1) * 84, -108, function()
                f.faction = value ~= 'Unknown' and value or nil
                for key, option in pairs(f.factionButtons) do option:SetSelected(key == (f.faction or 'Unknown')) end
            end)
        end
        f.input:SetScript('OnEnterPressed', submit)
        button(f, 'Add player', 164, 18, -158, submit)
        button(f, 'Cancel', 172, 190, -158, function() f:Hide() end)
    end
    addWindow.forBFF = bffTab
    addWindow.fromRecent = recent
    addWindow.chooseByFaction = recentTab or recent ~= nil
    addWindow.faction = recent and BFL.EntryFaction(recent) or ((bffTab or recentTab) and BFL.CurrentFaction() or BFL.OppositeFaction(BFL.CurrentFaction()))
    if recent and not BFL.EntryFaction(recent) then addWindow.faction = nil end
    for key, option in pairs(addWindow.factionButtons) do option:SetSelected(key == (addWindow.faction or 'Unknown')) end
    addWindow.TitleText:SetText(recentTab and 'Add player by faction' or (bffTab and 'Add to BFF List' or ('Add to ' .. BFL.ListTitle())))
    addWindow.input:SetText(recent and recent.name or ''); addWindow:Show(); addWindow.input:SetFocus()
end
local function showWindow()
    if window then window:SetShown(not window:IsShown()); return end
    window = shell('BestfriendsListWindow', 540, 620, 'BestfriendsList')
    local sound = button(window, '', 88, 414, -10, function()
        db.sound = not db.sound; refresh()
    end)
    local mine = button(window, BFL.ListTitle(), LIST_TAB_WIDTH, 16, -48, function()
        partyTab, bffTab, recentTab = false, false, false; refresh()
    end)
    local party = button(window, 'Party List', LIST_TAB_WIDTH, 144, -48, function()
        partyTab, bffTab, recentTab = true, false, false; refresh()
    end)
    local bff = button(window, 'BFF List', LIST_TAB_WIDTH, 272, -48, function()
        partyTab, bffTab, recentTab = false, true, false; refresh()
    end)
    local recent = button(window, 'Recent', LIST_TAB_WIDTH, 400, -48, function()
        partyTab, bffTab, recentTab = false, false, true; refresh()
    end)
    mine:SetHeight(30); party:SetHeight(30); bff:SetHeight(30); recent:SetHeight(30)
    mine:GetFontString():SetWidth(LIST_TAB_WIDTH - LIST_TAB_PADDING)
    mine:GetFontString():SetWordWrap(false)
    mine:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(BFL.ListTitle()); GameTooltip:Show()
    end)
    mine:SetScript('OnLeave', function() GameTooltip:Hide() end)
    local search = field(window, 300, 16, -88, 'Search names...')
    search:SetMaxLetters(80)
    clearSearch = function() search:SetText('') end
    search:SetScript('OnEscapePressed', function(self) self:SetText(''); self:ClearFocus() end)
    local clear = button(search, 'X', 20, 274, -4, function() search:SetText(''); search:ClearFocus() end)
    clear:SetSize(20, 20)
    local target = button(window, 'Add target', 96, 320, -88, addTarget)
    target:SetHeight(28)
    local addPlayer = button(window, '+ Add player', 104, 420, -88, function() showAddPlayer() end)
    addPlayer:SetHeight(28)
    addPlayer:SetTone('primary')
    local filter = button(window, 'Filter', 64, 16, -124, showFilters)
    local context = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    context:SetPoint('TOPLEFT', 18, -132); context:SetWidth(180); context:SetJustifyH('LEFT')
    context:SetTextColor(0.57, 0.65, 0.74); context:SetWordWrap(false)
    button(window, 'Options', 118, 406, -124, showOptions)
    local resync = button(window, 'Resync', 90, 312, -124, function()
        BFL.RequestSync(); say(BFL.SyncStatus()); refresh()
    end)
    local collapseAll = button(window, 'Collapse all', 102, 206, -124, function()
        local entries, expanded = BFL.ListRows('party', ''), false
        for _, item in ipairs(entries) do if item.header and not item.collapsed then expanded = true end end
        local collapsed = db.partyCollapsed
        for _, item in ipairs(entries) do if item.header then collapsed[item.id] = expanded end end
        refresh()
    end)
    local listPanel = CreateFrame('Frame', nil, window, 'BackdropTemplate')
    listPanel:SetPoint('TOPLEFT', 16, -158); listPanel:SetPoint('BOTTOMRIGHT', -16, 44)
    surface(listPanel, {0.035, 0.045, 0.06, 1})
    local scroll = CreateFrame('ScrollFrame', nil, window, 'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', 20, -162); scroll:SetPoint('BOTTOMRIGHT', -36, 48)
    local content = CreateFrame('Frame', nil, scroll)
    content:SetSize(484, 1)
    scroll:SetScrollChild(content)
    local status = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    status:SetPoint('BOTTOMLEFT', 18, 18); status:SetWidth(504); status:SetJustifyH('LEFT')
    status:SetTextColor(0.57, 0.65, 0.74); status:SetWordWrap(false)
    local rows, headers = {}, {}
    local empty = content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    empty:SetPoint('TOP', 0, -44); empty:SetWidth(440); empty:SetJustifyH('CENTER')
    empty:SetTextColor(0.57, 0.65, 0.74)
    refresh = function()
        mine:SetText(BFL.ListTitle())
        mine:SetSelected(not partyTab and not bffTab and not recentTab)
        party:SetSelected(partyTab); bff:SetSelected(bffTab); recent:SetSelected(recentTab)
        resync:SetShown(partyTab)
        collapseAll:SetShown(partyTab)
        collapseAll:SetEnabled(search:GetText() == '')
        clear:SetShown(search:GetText() ~= '')
        local groupMatches, ownCount, bffCount = 0, 0, 0
        for _ in pairs(bffPresent) do groupMatches = groupMatches + 1 end
        ownCount = #BFL.ListRows('mine', '')
        bffCount = #BFL.ListRows('bff', '')
        local unknownCount, storedCount = 0, 0
        local stored = bffTab and db.bffEntries or BFL.Own()
        for key, entry in pairs(stored) do
            storedCount = storedCount + 1
            if not BFL.EntryFaction(entry, key) then unknownCount = unknownCount + 1 end
        end
        filter:SetShown(not partyTab and not recentTab)
        local hasFilter = BFL.Filters().showUnknown == true
        for i = 1, 4 do if BFL.Filters().labels[i] then hasFilter = true end end
        filter:SetSelected(hasFilter)
        context:ClearAllPoints(); context:SetPoint('TOPLEFT', (partyTab or recentTab) and 18 or 86, -132)
        context:SetWidth(partyTab and 184 or (recentTab and 380 or 315))
        context:SetText(recentTab and ('Recent / ' .. #db.recentPlayers .. ' players') or (bffTab and ('BFF List / ' .. bffCount .. ' players')
            or (partyTab and 'Party watchlists' or (BFL.ListTitle() .. ' / ' .. ownCount .. ' players'))))
        status:SetText(recentTab and 'Last 10 group members / Add them without targeting' or (bffTab and (groupMatches .. ' in your group / Party and raid alerts')
            or (partyTab and BFL.SyncStatus() or 'Opposing-faction alerts / Enable enemy nameplates')))
        if not partyTab and not recentTab and unknownCount > 0 then
            status:SetText(status:GetText() .. ' / ' .. unknownCount .. ' unknown: Filter')
        end
        sound:SetText(db.sound and 'Sound: On' or 'Sound: Off')
        local entries = BFL.ListRows(recentTab and 'recent' or (bffTab and 'bff' or (partyTab and 'party' or 'mine')), search:GetText())
        local expanded = false
        for _, item in ipairs(entries) do if item.header and not item.collapsed then expanded = true end end
        collapseAll:SetText(expanded and 'Collapse all' or 'Expand all')
        local rowHeight = 36
        for _, row in ipairs(rows) do row:Hide() end
        for _, header in ipairs(headers) do header:Hide() end
        empty:SetText(search:GetText() ~= '' and 'No matching names.\nTry part of a first name or surname.'
            or (recentTab and 'No recent group members yet.\nPlayers will appear here after you join a party or raid.'
            or (storedCount > 0 and 'No players for the current faction filters.\nUse Filter to review unknown factions or include BFF labels.'
            or 'Your list is empty.\nUse Add player or Add target to get started.')))
        empty:SetShown(#entries == 0)
        local offset, targetIndex, headerIndex = 0, 0, 0
        for _, item in ipairs(entries) do
            if item.header then
                headerIndex = headerIndex + 1
                local header = headers[headerIndex]
                if not header then
                    header = button(content, '', 484, 0, 0, function(self)
                        local collapsed = db.partyCollapsed
                        collapsed[self.ownerId] = not collapsed[self.ownerId]
                        refresh()
                    end)
                    header:SetHeight(26)
                    header:GetFontString():ClearAllPoints()
                    header:GetFontString():SetPoint('LEFT', 30, 0)
                    header:GetFontString():SetWidth(360)
                    header:GetFontString():SetJustifyH('LEFT')
                    header:GetFontString():SetWordWrap(false)
                    header.arrow = header:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
                    header.arrow:SetPoint('LEFT', 10, 0); header.arrow:SetTextColor(0.45, 0.73, 0.94)
                    header.count = header:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    header.count:SetPoint('RIGHT', -12, 0); header.count:SetTextColor(0.57, 0.65, 0.74)
                    headers[headerIndex] = header
                end
                header.ownerId = item.id
                header:ClearAllPoints(); header:SetPoint('TOPLEFT', 0, -offset)
                header:SetText(item.name)
                header.arrow:SetText(item.collapsed and '+' or '-')
                header.count:SetText(item.searching and (item.count .. ' / ' .. item.total) or tostring(item.total))
                header:SetEnabled(not item.searching)
                header:Show()
                offset = offset + 28
            else
                targetIndex = targetIndex + 1
                local entry = item.entry
                local row = rows[targetIndex]
                if not row then
                    row = CreateFrame('Frame', nil, content)
                    row:SetSize(484, 34)
                    row:EnableMouse(true)
                    row.background = row:CreateTexture(nil, 'BACKGROUND')
                    row.background:SetAllPoints()
                    row.highlight = row:CreateTexture(nil, 'ARTWORK')
                    row.highlight:SetAllPoints(); row.highlight:SetColorTexture(0.22, 0.37, 0.5, 0.2)
                    row.highlight:Hide()
                    local divider = row:CreateTexture(nil, 'BORDER')
                    divider:SetPoint('BOTTOMLEFT', 8, 0); divider:SetPoint('BOTTOMRIGHT', -8, 0)
                    divider:SetHeight(1); divider:SetColorTexture(1, 1, 1, 0.035)
                    row.label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
                    row.label:SetPoint('TOPLEFT', 2, -2)
                    row.label:SetWidth(255)
                    row.label:SetWordWrap(false)
                    row.label:SetJustifyH('LEFT')
                    row.seen = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    row.seen:SetPoint('TOPLEFT', 2, -17)
                    row.seen:SetWidth(310)
                    row.seen:SetHeight(14)
                    row.seen:SetWordWrap(false)
                    row.seen:SetJustifyV('TOP')
                    row.seen:SetJustifyH('LEFT')
                    row.remove = button(row, 'Remove', 78, 316, 0, function()
                        GameTooltip:Hide()
                        if row.useBFF then removeBFF(row.name) else remove(row.name) end
                    end)
                    row.remove:SetTone('danger')
                    row.remove:SetScript('OnEnter', function(self)
                        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                        GameTooltip:SetText(row.useBFF and 'Remove from BFF List' or ('Remove from ' .. BFL.ListTitle()))
                        GameTooltip:AddLine(row.name, 1, 1, 1)
                        if not row.useBFF and BFL.BFFPromoted(BFL.Name(row.name)) then
                            GameTooltip:AddLine('This player may remain visible through your BFF label filter.', 1, 1, 1, true)
                        end
                        if partyTab then
                            GameTooltip:AddLine('Other party members keep their own entries.', 1, 1, 1, true)
                        end
                        GameTooltip:Show()
                    end)
                    row.remove:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    row.add = button(row, '', 22, 4, 0, function()
                        GameTooltip:Hide()
                        if recentTab and row.recentBFF then addBFF(row.name, row.recentFaction, row.entry)
                        elseif recentTab and not row.recentFaction then showAddPlayer(row.entry)
                        else add(row.name, row.entry) end
                    end)
                    local checkmark = row.add:CreateTexture(nil, 'OVERLAY')
                    checkmark:SetTexture('Interface\\Buttons\\UI-CheckBox-Check')
                    checkmark:SetVertexColor(0.4, 1, 0.65)
                    checkmark:SetPoint('TOPLEFT', 2, -2)
                    checkmark:SetPoint('BOTTOMRIGHT', -2, 2)
                    row.add:SetScript('OnEnter', function(self)
                        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                        GameTooltip:SetText((recentTab and row.recentBFF) and 'Add to BFF List' or ((recentTab and not row.recentFaction) and 'Choose faction and add player' or ('Add to ' .. BFL.ListTitle())))
                        GameTooltip:AddLine(row.name, 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    row.add:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    row.bffLabel = button(row, '', 100, 210, 0, function()
                        local slot = (((row.labelEntry and row.labelEntry.label) or 0) + 1) % 5
                        local ok, err = BFL.SetBFFLabel(row.name, slot)
                        if not ok then say(err); return end
                        refresh()
                    end)
                    row.bffLabel:SetHeight(22)
                    row.bffLabel:ClearAllPoints()
                    row.bffLabel:SetPoint('LEFT', row.remove, 'RIGHT', 3, 0)
                    row.bffLabel:GetFontString():SetWidth(90)
                    row.bffLabel:GetFontString():SetWordWrap(false)
                    row.bffLabel:SetScript('OnEnter', function(self)
                        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                        GameTooltip:SetText(BFL.BFFLabel(row.labelEntry) or 'No label')
                        GameTooltip:AddLine('Click to cycle through your four labels and No label.', 1, 1, 1, true)
                        GameTooltip:AddLine('Rename them with Edit labels.', 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    row.bffLabel:SetScript('OnLeave', function() GameTooltip:Hide() end)
                    row:SetScript('OnMouseUp', function(self, mouseButton)
                        if mouseButton == 'RightButton' and (bffTab or recentTab) then
                            GameTooltip:Hide()
                            openPlayerMenu(self.entry)
                        end
                    end)
                    row:SetScript('OnEnter', function(self)
                        self.highlight:Show()
                        local e = self.entry
                        if not e then return end
                        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
                        GameTooltip:SetText(e.name)
                        GameTooltip:AddLine('Level ' .. (e.level or '?') .. ' ' .. BFL.ClassName(e.class), 1, 1, 1)
                        local seenAt, seenZone = e.lastSeen, e.lastSeenZone
                        if bffTab or recentTab then seenAt, seenZone = e.lastGrouped, e.lastGroupedZone end
                        GameTooltip:AddLine(seenAt and (((bffTab or recentTab) and 'Last grouped: ' or 'Last seen: ') .. date('%d %b %Y %H:%M:%S', seenAt)) or 'Never seen', 1, 1, 1)
                        if seenZone then GameTooltip:AddLine('Zone: ' .. seenZone, 1, 1, 1, true) end
                        GameTooltip:AddLine('Faction: ' .. (BFL.EntryFaction(e) or 'Unknown'), 1, 1, 1)
                        GameTooltip:AddLine('Listed by: ' .. table.concat(self.listOwners, ', '), 1, 1, 1, true)
                        local label = BFL.NameLabel(BFL.Name(e.name))
                        if label then GameTooltip:AddLine('Label: ' .. label, 1, 1, 1, true) end
                        if not BFL.EntryFaction(e) then
                            GameTooltip:AddLine('Unknown faction: add this name again and choose its faction, or target the player to learn it.', 1, 1, 1, true)
                        end
                        if bffTab or recentTab then
                            GameTooltip:AddLine('Right-click for player menu', 0.6, 0.7, 0.8)
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript('OnLeave', function(self) self.highlight:Hide(); GameTooltip:Hide() end)
                    rows[targetIndex] = row
                end
                row.name = entry.name
                row.entry = entry
                row.listOwners = item.owners
                row:SetHeight(rowHeight)
                local shade = targetIndex % 2 == 0 and 0.085 or 0.065
                row.background:SetColorTexture(shade, shade + 0.012, shade + 0.028, 1)
                row:SetPoint('TOPLEFT', 0, -offset)
                row.remove:ClearAllPoints()
                row.remove:SetPoint('TOPLEFT', 4, 0)
                row.remove:SetSize(22, 22)
                row.remove:SetText('X')
                row.recentFaction = recentTab and BFL.EntryFaction(entry, item.key) or nil
                row.recentBFF = recentTab and row.recentFaction ~= nil and row.recentFaction == BFL.CurrentFaction()
                row.useBFF = bffTab or row.recentBFF
                row.labelEntry = db.bffEntries[item.key]
                local personallyListed = row.useBFF and row.labelEntry ~= nil or (not row.useBFF and BFL.Own()[item.key] ~= nil)
                local showLabel = bffTab or (row.recentBFF and personallyListed)
                row.remove:SetShown(bffTab or personallyListed)
                row.add:SetShown(not bffTab and not personallyListed)
                row.bffLabel:SetShown(showLabel)
                row.bffLabel:SetText(showLabel and (BFL.BFFLabel(row.labelEntry) or 'No label') or '')
                row.seen:ClearAllPoints()
                local textLeft = showLabel and 139 or 34
                local textWidth = 484 - textLeft - 12
                row.seen:SetPoint('TOPLEFT', textLeft, -20)
                row.seen:SetTextColor(0.53, 0.61, 0.70)
                row.seen:SetWidth(textWidth)
                row.label:ClearAllPoints()
                row.label:SetPoint('TOPLEFT', textLeft, -4)
                row.label:SetWidth(textWidth)
                row.label:SetText(entry.name .. ' |cffa2afbd(' .. (entry.level or '?') .. ')|r'
                    .. ((not row.useBFF and not personallyListed and BFL.BFFPromoted(item.key)) and (' |cffb994eb[' .. (BFL.NameLabel(item.key) or 'BFF') .. ']|r') or '')
                    .. (not BFL.EntryFaction(entry, item.key) and ' |cff8a96a6[?]|r' or ''))
                row.label:SetTextColor(BFL.ClassColor(entry.class))
                local seenAt, seenZone = entry.lastSeen, entry.lastSeenZone
                if bffTab or recentTab then seenAt, seenZone = entry.lastGrouped, entry.lastGroupedZone end
                row.seen:SetText((recentTab and 'Last grouped: ' or (bffTab and (bffPresent[item.key] and 'In group / ' or 'Last grouped: ') or 'Seen: ')) .. (seenAt and (date('%d/%m %H:%M', seenAt)
                    .. (seenZone and (' - ' .. seenZone) or '')) or 'Never'))
                row:Show()
                offset = offset + rowHeight
            end
        end
        if search:GetText() ~= '' then context:SetText(targetIndex .. ' matching entries') end
        content:SetHeight(math.max(100, offset))
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, offset - scroll:GetHeight())))
    end
    search.onTextChanged = function()
        scroll:SetVerticalScroll(0)
        if refresh then refresh() end
    end
    refresh()
end

SLASH_BESTFRIENDSLIST1 = '/bfl'
SLASH_BESTFRIENDSLIST2 = '/bestfriendslist'
SLASH_BESTFRIENDSLIST3 = '/kos'
SlashCmdList.BESTFRIENDSLIST = function(message)
    if not db then return end
    local command, rest = message:match('^%s*(%S*)%s*(.-)%s*$')
    command = command:lower()
    if command == '' then showWindow()
    elseif command == 'add' then
        if rest == '' or rest:lower() == 'target' then addTarget() else add(rest) end
    elseif command == 'remove' then remove(rest)
    elseif command == 'scan' then scan(); scanBFF()
    elseif command == 'bff' then
        local action, name = rest:match('^(%S*)%s*(.-)$')
        action = action:lower()
        if action == 'add' then
            if name == '' then addBFFTarget() else addBFF(name) end
        elseif action == 'remove' then removeBFF(name)
        elseif action == 'labels' then showLabels()
        elseif action == 'label' then
            local slot, player = name:match('^(%d+)%s+(.+)$')
            local ok, err = BFL.SetBFFLabel(player, tonumber(slot))
            if not ok then say(err); return end
            if refresh then refresh() end
            say('BFF label updated for ' .. player .. '.')
        elseif action == '' then
            partyTab, bffTab, recentTab = false, true, false
            if window then refresh(); window:Show() else showWindow() end
        else say('/bfl bff; /bfl bff add [Firstname Surname]; /bfl bff remove Firstname Surname; /bfl bff labels; /bfl bff label 1-4 Firstname Surname (0 clears).') end
    elseif command == 'recent' then
        partyTab, bffTab, recentTab = false, false, true
        if window then refresh(); window:Show() else showWindow() end
    elseif command == 'options' then showOptions()
    elseif command == 'filter' then showFilters()
    elseif command == 'faction' then
        local faction, name = rest:match('^(%S+)%s+(.+)$')
        faction = faction and faction:lower()
        faction = faction == 'alliance' and 'Alliance' or (faction == 'horde' and 'Horde' or nil)
        local key = name and normalize(name)
        if not faction or not key then say('/bfl faction Horde Firstname Surname (or Alliance)'); return end
        if not (BFL.Own()[key] or db.bffEntries[key]) then say('Add that player to a personal list first.'); return end
        BFL.RememberFaction(key, faction)
        BFL.FiltersChanged()
        say('Faction set to ' .. faction .. ' for ' .. name .. '.')
    elseif command == 'sync' then BFL.RequestSync(); say(BFL.SyncStatus())
    elseif command == 'help' then
        say('/bfl filter chooses enemy BFF labels for your watchlist. /bfl faction Horde Firstname Surname (or Alliance) fixes a saved faction.')
        say('/bfl options renames your personal list and edits BFF labels. /kos remains available for existing macros.')
        say('/bfl recent opens your last 10 group members, with add buttons.')
        say('/bfl opens the list; /bfl add target routes your target by faction; /bfl add Firstname Surname; /bfl remove Firstname Surname; /bfl scan.')
        say('/bfl sync requests party lists. Party syncing excludes raids.')
        say('/bfl bff opens BFF List; /bfl bff add [Firstname Surname]; /bfl bff remove Firstname Surname. BFF alerts only for party/raid membership.')
        say('/bfl bff labels renames your four labels. /bfl bff label 1-4 Firstname Surname assigns one; 0 clears it. Click a row label to cycle.')
        say('Class colors (unknown classes use white):')
        local tokens = {}
        for token in pairs(RAID_CLASS_COLORS or {}) do tokens[#tokens + 1] = token end
        table.sort(tokens)
        local labels = {}
        for _, token in ipairs(tokens) do
            local r, g, b = BFL.ClassColor(token)
            labels[#labels + 1] = string.format('|cff%02x%02x%02x%s|r', math.floor(r * 255 + 0.5),
                math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), BFL.ClassName(token))
            if #labels == 5 then say(table.concat(labels, ' / ')); labels = {} end
        end
        if #labels > 0 then say(table.concat(labels, ' / ')) end
    else say('Unknown command. Use /bfl help.') end
end

BFL.Notify = say
BFL.Changed = function() if refresh then refresh() end end
BFL.FiltersChanged = function()
    BFL.ListChanged()
    scan(); scanBFF()
    if refresh then refresh() end
end

local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:SetScript('OnEvent', function(_, event, arg)
    if event == 'ADDON_LOADED' then
        if arg ~= addonName then return end
        -- The old global is read only to migrate lists from previous installations.
        BestfriendsListDB = BestfriendsListDB or KillOnSightDB or KillOnSiteDB or KillListDB or {}
        db = BestfriendsListDB
        BFL.Init(db)
        if db.sound == nil then db.sound = true end
        BFL.StartSync()
        events:RegisterEvent('PLAYER_ENTERING_WORLD')
        events:RegisterEvent('PLAYER_TARGET_CHANGED')
        events:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
        events:RegisterEvent('NAME_PLATE_UNIT_ADDED')
        events:RegisterEvent('GROUP_ROSTER_UPDATE')
        events:RegisterEvent('UNIT_NAME_UPDATE')
        scanBFF()
        say('Loaded. /bfl opens your lists. Opposing-faction alerts active; enable enemy nameplates.')
    elseif event == 'GROUP_ROSTER_UPDATE' or event == 'UNIT_NAME_UPDATE' then scanBFF()
    elseif event == 'NAME_PLATE_UNIT_ADDED' then check(arg)
    else scan(); scanBFF() end
end)
local elapsed = 0
events:SetScript('OnUpdate', function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 2 then elapsed = 0; if db then scan(); scanBFF() end end
end)
