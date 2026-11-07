local _, BFL = ...
BFL.PREFIX = 'BFLParty4'
local function clean(value, limit)
    return type(value) == 'string' and #value > 0 and #value <= limit and not value:find('[%c|]')
end
function BFL.Name(name)
    if type(name) ~= 'string' then return end
    name = name:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if not clean(name, 80) or not name:match('^%S+ %S+$') or name:find('%d') then return end
    return (strlower or string.lower)(name), name
end
function BFL.NormalizeListTitle(name)
    if type(name) ~= 'string' then return nil, 'Enter a list name.' end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or name:find('[%c|]') then
        return nil, 'Use a non-empty list name without formatting or line breaks.'
    end
    return name
end
function BFL.ListTitle()
    return BFL.NormalizeListTitle(BFL.db.listTitle) or 'Ex-friend'
end
function BFL.SetListTitle(name, textWidth, availableWidth)
    local title, err = BFL.NormalizeListTitle(name)
    if not title then return nil, err end
    if type(textWidth) ~= 'number' or type(availableWidth) ~= 'number' or textWidth <= 0 or availableWidth <= 0 or textWidth > availableWidth then
        return nil, 'That name is too wide for the tab. Choose a shorter name.'
    end
    BFL.db.listTitle = title
    return true
end
function BFL.WatchAlert(name, label)
    return BFL.ListTitle() .. ': ' .. name .. ((label and label ~= '') and (' - ' .. label) or '')
end
function BFL.GroupAlert(name, label, raid)
    return ((label and label ~= '') and (label .. ': ') or '') .. name .. ' joined the ' .. (raid and 'raid' or 'party')
end
function BFL.ClassToken(class)
    if type(class) ~= 'string' then return end
    local token = class:upper():gsub('%s+', '')
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then return token end
    for _, names in ipairs({LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {}}) do
        for classToken, name in pairs(names) do
            if class == name then return classToken end
        end
    end
end
function BFL.ClassName(class)
    local token = BFL.ClassToken(class)
    return (token and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or class or 'Unknown class'
end
function BFL.ClassColor(class)
    local token = BFL.ClassToken(class)
    local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end
function BFL.Init(db)
    BFL.db = db
    db.testMode = nil -- Retire the development setting on existing installations.
    if BFL.NormalizeListTitle(db.listTitle) == 'My List' then db.listTitle = nil end
    -- Keep previous profiles as an inactive backup; only My List is migrated.
    if not db.ownEntries then
        db.ownEntries = db.entries or (db.profiles and db.profiles['My List'] and db.profiles['My List'].entries) or {}
        db.entries = nil
    end
    BFL.party = {}
    db.bffEntries = db.bffEntries or {}
    local stockLabels = true
    for i = 1, 4 do
        if db.bffLabels and db.bffLabels[i] and db.bffLabels[i] ~= 'Label ' .. i then stockLabels = false end
    end
    if stockLabels then db.bffLabels = {'Avoid', 'Ninja', 'Rude', 'Tank'} end
    db.partyCollapsed = db.partyCollapsed or {}
    db.recentPlayers = db.recentPlayers or {}
    while #db.recentPlayers > 10 do table.remove(db.recentPlayers) end
    BFL.InitFactions(db)
end
function BFL.Own() return BFL.db.ownEntries end
function BFL.RecentPlayer(key)
    for _, entry in ipairs(BFL.db.recentPlayers) do
        if BFL.Name(entry.name) == key then return entry end
    end
end
function BFL.RecordRecent(name, details, stamp, joined)
    local key, display = BFL.Name(name)
    if not key then return false end
    local players, index = BFL.db.recentPlayers
    for i, entry in ipairs(players) do if BFL.Name(entry.name) == key then index = i; break end end
    -- Existing group members update their metadata without displacing history.
    if not index and not joined then return false end
    local entry = index and players[index] or {name = display}
    local changed = joined == true
    for _, field in ipairs({'class', 'level', 'faction', 'guid', 'lastSeen', 'lastSeenZone', 'groupType'}) do
        local value = details[field]
        if value ~= nil and entry[field] ~= value then entry[field] = value; changed = true end
    end
    if entry.lastGrouped ~= stamp then entry.lastGrouped = stamp; changed = true end
    entry.lastGroupedZone = details.lastSeenZone or entry.lastGroupedZone
    if joined then
        if index then table.remove(players, index) end
        table.insert(players, 1, entry)
        while #players > 10 do table.remove(players) end
    end
    return changed
end
function BFL.BFFLabel(entry)
    return entry and BFL.db.bffLabels[entry.label]
end
function BFL.SetBFFLabels(names)
    if type(names) ~= 'table' then return nil, 'Enter a name for all four labels.' end
    local labels, used = {}, {}
    for i = 1, 4 do
        local label = names[i]
        if type(label) ~= 'string' then return nil, 'Enter a name for all four labels.' end
        label = label:gsub('^%s+', ''):gsub('%s+$', '')
        if label == '' or (strlenutf8 and strlenutf8(label) or #label) > 24 or label:find('[%c|]') then
            return nil, 'Label names must be 1-24 characters without formatting or line breaks.'
        end
        local key = (strlower or string.lower)(label)
        if used[key] then return nil, 'Give each label a different name.' end
        used[key], labels[i] = true, label
    end
    BFL.db.bffLabels = labels
    return true
end
function BFL.SetBFFLabel(name, slot)
    local key = BFL.Name(name)
    local entry = key and BFL.db.bffEntries[key]
    if not entry then return nil, 'That player is not on your BFF List.' end
    if type(slot) ~= 'number' or slot % 1 ~= 0 or slot < 0 or slot > 4 then
        return nil, 'Choose label 1-4, or 0 for no label.'
    end
    entry.label = slot ~= 0 and slot or nil
    return true
end
function BFL.BFFView()
    local rows = {}
    for key, entry in pairs(BFL.db.bffEntries) do
        if BFL.BFFVisible(entry, key) then rows[#rows + 1] = {key = key, entry = entry, owners = {'You'}} end
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rows
end
function BFL.BFFTransitions(entries, members, previous)
    local present, joined = {}, {}
    for key in pairs(members) do
        if entries[key] and BFL.BFFVisible(entries[key], key) then
            present[key] = true
            if not previous[key] then joined[#joined + 1] = key end
        end
    end
    table.sort(joined)
    return present, joined
end
function BFL.SenderKey(sender, roster)
    if type(sender) ~= 'string' then return end
    local function lookup(name)
        local key = BFL.Name(name)
        if key and roster[key] then return key end
        -- Some Forever chat paths use First-Surname instead of First Surname.
        local first, last = name:match('^([^%s%-]+)%-([^%s%-]+)$')
        key = first and BFL.Name(first .. ' ' .. last)
        return key and roster[key] and key or nil
    end
    local key = lookup(sender)
    if key then return key end
    local withoutRealm = sender:match('^(.-)%-[^%-]+$')
    return withoutRealm and lookup(withoutRealm) or nil
end
function BFL.Matches(key)
    local matches = {}
    local own = BFL.Own()[key]
    if own and BFL.KoSVisible(own, key) then
        matches[#matches + 1] = {owner = 'You', entry = own, label = BFL.NameLabel(key)}
    elseif BFL.BFFPromoted(key) then
        matches[#matches + 1] = {owner = 'You (BFF)', entry = BFL.db.bffEntries[key], label = BFL.NameLabel(key)}
    end
    local owners = {}
    for owner in pairs(BFL.party) do owners[#owners + 1] = owner end
    table.sort(owners)
    for _, owner in ipairs(owners) do
        local entry = BFL.party[owner].entries[key]
        if entry and BFL.KoSVisible(entry, key) then matches[#matches + 1] = {owner = BFL.party[owner].name or owner, entry = entry} end
    end
    return matches
end
function BFL.View(includeParty)
    local own, keys, rows = BFL.OwnKoS(), {}, {}
    for key in pairs(own) do keys[key] = true end
    if includeParty then
        for _, list in pairs(BFL.party) do
            for key, entry in pairs(list.entries) do if BFL.KoSVisible(entry, key) then keys[key] = true end end
        end
    end
    for key in pairs(keys) do
        local matches = includeParty and BFL.Matches(key) or {{owner = 'You', entry = own[key]}}
        local row = {key = key, entry = matches[1].entry, owners = {}}
        for _, match in ipairs(matches) do row.owners[#row.owners + 1] = match.owner end
        for _, match in ipairs(matches) do
            if match.entry.lastSeen and (not row.entry.lastSeen or match.entry.lastSeen > row.entry.lastSeen) then row.entry = match.entry end
        end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rows
end
local function searchKey(text)
    return (strlower or string.lower)((text or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' '))
end
function BFL.ListRows(mode, query)
    local rows = {}
    query = searchKey(query)
    local function matches(entry)
        return searchKey(entry.name):find(query, 1, true) ~= nil
    end
    if mode == 'recent' then
        for _, entry in ipairs(BFL.db.recentPlayers) do
            if matches(entry) then rows[#rows + 1] = {key = BFL.Name(entry.name), entry = entry, owners = {'Recent group'}} end
        end
        return rows
    end
    if mode ~= 'party' then
        local entries = mode == 'bff' and BFL.db.bffEntries or BFL.OwnKoS()
        for key, entry in pairs(entries) do
            if matches(entry) and (mode ~= 'bff' or BFL.BFFVisible(entry, key)) then rows[#rows + 1] = {key = key, entry = entry, owners = {'You'}} end
        end
        table.sort(rows, function(a, b) return a.key < b.key end)
        return rows
    end
    local party = BFL.party
    local groups = {{id = '__self', name = 'You', entries = BFL.OwnKoS()}}
    local owners = {}
    for owner in pairs(party) do owners[#owners + 1] = owner end
    table.sort(owners)
    for _, owner in ipairs(owners) do
        groups[#groups + 1] = {id = owner, name = party[owner].name or owner, entries = party[owner].entries}
    end
    for _, group in ipairs(groups) do
        local filtered, total = {}, 0
        for key, entry in pairs(group.entries) do
            if BFL.KoSVisible(entry, key) then
                total = total + 1
                if matches(entry) then filtered[#filtered + 1] = {key = key, entry = entry, owners = {group.name}} end
            end
        end
        table.sort(filtered, function(a, b) return a.key < b.key end)
        if query == '' or #filtered > 0 then
            local collapsed = query == '' and BFL.db.partyCollapsed[group.id] == true
            rows[#rows + 1] = {header = true, id = group.id, name = group.name,
                count = #filtered, total = total, collapsed = collapsed, searching = query ~= ''}
            if not collapsed then
                for _, row in ipairs(filtered) do rows[#rows + 1] = row end
            end
        end
    end
    return rows
end
-- Internal party snapshot format. Sightings/settings are never transmitted.
local function encode(s)
    return (s:gsub('[^%w ._-]', function(c) return string.format('%%%02X', c:byte()) end))
end
local function decode(s)
    if s:gsub('%%%x%x', ''):find('%%') then return end
    return (s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end))
end
function BFL.Serialize()
    local lines = {'BFLP4', 'Own'}
    local keys = {}
    for key, entry in pairs(BFL.Own()) do if BFL.KoSVisible(entry, key) then keys[#keys + 1] = key end end
    table.sort(keys)
    if #keys > 1000 then return nil, 'Party sync supports up to 1000 entries.' end
    for _, key in ipairs(keys) do
        local e = BFL.Own()[key]
        lines[#lines + 1] = encode(e.name) .. '\t' .. encode(BFL.ClassToken(e.class) or e.class or '') .. '\t' .. tostring(e.level or '') .. '\t' .. (BFL.EntryFaction(e, key) or '')
    end
    local data = table.concat(lines, '\n')
    if #data > 120000 then return nil, 'List is too large to sync.' end
    return data
end
function BFL.Parse(data)
    if type(data) ~= 'string' or #data > 120000 then return nil, 'Invalid or oversized list.' end
    data = data:gsub('\r\n', '\n')
    local version, title, body = data:match('^(BFLP4)\n([^\n]+)\n?(.*)$')
    if not version then version, title, body = data:match('^(KOSP[34])\n([^\n]+)\n?(.*)$') end
    title = title and decode(title)
    if not version or not clean(title, 60) then return nil, 'Invalid party snapshot header.' end
    local entries, count = {}, 0
    for line in body:gmatch('[^\n]+') do
        local n, c, l, faction
        if version == 'BFLP4' or version == 'KOSP4' then n, c, l, faction = line:match('^([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$')
        else n, c, l = line:match('^([^\t]+)\t([^\t]*)\t([^\t]*)$') end
        n, c = n and decode(n), c and decode(c)
        local key, name = BFL.Name(n)
        local level = l and l ~= '' and tonumber(l) or nil
        if (faction and faction ~= '' and not BFL.ValidFaction(faction)) or not key or not c or #c > 60 or c:find('[%c|]') or (l ~= '' and (not level or level < 1 or level > 1000 or level % 1 ~= 0)) then
            return nil, 'Invalid player entry.'
        end
        count = count + 1
        if count > 1000 then return nil, 'Too many entries (maximum 1000).' end
        entries[key] = {name = name, class = c ~= '' and c or nil, level = level, faction = faction ~= '' and faction or nil}
    end
    return {title = title, entries = entries, count = count}
end
