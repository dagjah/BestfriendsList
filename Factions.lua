local _, BFL = ...
function BFL.ValidFaction(faction)
    return faction == 'Alliance' or faction == 'Horde'
end
function BFL.UnitFaction(unit)
    if not UnitFactionGroup then return end
    local ok, faction = pcall(UnitFactionGroup, unit)
    if ok and not (issecretvalue and issecretvalue(faction)) and BFL.ValidFaction(faction) then return faction end
end
function BFL.CurrentFaction()
    return BFL.UnitFaction('player')
end
function BFL.OppositeFaction(faction)
    if faction == 'Alliance' then return 'Horde' end
    if faction == 'Horde' then return 'Alliance' end
end
function BFL.InitFactions(db)
    db.playerFactions = db.playerFactions or {}
    db.kosFilters = db.kosFilters or {}
    for _, faction in ipairs({'Alliance', 'Horde', 'Unknown'}) do
        db.kosFilters[faction] = db.kosFilters[faction] or {labels = {}, showUnknown = false}
        db.kosFilters[faction].labels = db.kosFilters[faction].labels or {}
    end
    if not db.factionVersion then
        db.factionVersion = 1
        for _, entry in pairs(db.bffEntries) do
            entry.lastGrouped, entry.lastGroupedZone = entry.lastSeen, entry.lastSeenZone
        end
    end
    for _, entries in ipairs({db.ownEntries, db.bffEntries}) do
        for key, entry in pairs(entries) do
            if BFL.ValidFaction(entry.faction) then db.playerFactions[key] = entry.faction end
        end
    end
end
function BFL.Filters()
    return BFL.db.kosFilters[BFL.CurrentFaction() or 'Unknown']
end
function BFL.EntryFaction(entry, key)
    return BFL.db.playerFactions[key or BFL.Name(entry.name)] or (BFL.ValidFaction(entry.faction) and entry.faction or nil)
end
function BFL.RememberFaction(key, faction)
    if not key or not BFL.ValidFaction(faction) then return false end
    local tracked = BFL.Own()[key] or BFL.db.bffEntries[key] or BFL.RecentPlayer(key)
    if not tracked then
        for _, list in pairs(BFL.party) do if list.entries[key] then tracked = true; break end end
    end
    if not tracked then return false end
    local changed = BFL.db.playerFactions[key] ~= faction
    BFL.db.playerFactions[key] = faction
    for _, entries in ipairs({BFL.Own(), BFL.db.bffEntries}) do
        if entries[key] and entries[key].faction ~= faction then entries[key].faction = faction; changed = true end
    end
    for _, list in pairs(BFL.party) do
        if list.entries[key] then list.entries[key].faction = faction end
    end
    return changed
end
function BFL.KoSVisible(entry, key)
    local faction, ours = BFL.EntryFaction(entry, key), BFL.CurrentFaction()
    if not faction then return BFL.Filters().showUnknown == true end
    if not ours then return false end
    local wanted = BFL.OppositeFaction(ours)
    return faction == wanted
end
function BFL.BFFVisible(entry, key)
    local faction, ours = BFL.EntryFaction(entry, key), BFL.CurrentFaction()
    if not faction then return BFL.Filters().showUnknown == true end
    return ours ~= nil and faction == ours
end
function BFL.BFFPromoted(key)
    local entry = BFL.db.bffEntries[key]
    if not entry then return false end
    local faction = BFL.EntryFaction(entry, key)
    return BFL.ValidFaction(faction) and faction == BFL.OppositeFaction(BFL.CurrentFaction())
        and BFL.Filters().labels[entry.label] == true
end
function BFL.OwnKoS()
    local entries = {}
    for key, entry in pairs(BFL.Own()) do
        if BFL.KoSVisible(entry, key) then entries[key] = entry end
    end
    for key, entry in pairs(BFL.db.bffEntries) do
        if not entries[key] and BFL.BFFPromoted(key) then entries[key] = entry end
    end
    return entries
end
function BFL.NameLabel(key)
    return BFL.BFFLabel(BFL.db.bffEntries[key])
end
