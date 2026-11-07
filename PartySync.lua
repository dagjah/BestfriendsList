local _, BFL = ...
local roster, incoming, lastVersion = {}, {}, {}
local outgoing, dirty, request, ready, active = nil, false, false, false, false
local revision, tick, heartbeat, lastRequest = 0, 0, 0, -10
local session = tostring(time()) .. '-' .. tostring(math.random(100000, 999999))
local function changed() if BFL.Changed then BFL.Changed() end end
local function notify(message) if BFL.Notify then BFL.Notify(message) end end
local function inParty() return IsInGroup() and not IsInRaid() end
local function unitName(unit)
    local first, last = UnitName(unit)
    if issecretvalue and (issecretvalue(first) or issecretvalue(last)) then return end
    if not first then return end
    if last and last ~= '' and not first:find(' ', 1, true) then first = first .. ' ' .. last end
    return BFL.Name(first)
end
local function senderKey(sender)
    return BFL.SenderKey(sender, roster)
end
local function restricted()
    return C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
        and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()
end
function BFL.SyncStatus()
    if not inParty() then return IsInRaid() and 'Party sync disabled in raids.' or 'Join a party to sync lists automatically.' end
    if not ready then return 'Party messaging unavailable on this client.' end
    if restricted() then return 'Party messaging is restricted by the client.' end
    local total, synced = 0, 0
    for key in pairs(roster) do
        total = total + 1
        if BFL.party[key] then synced = synced + 1 end
    end
    return 'Party lists received: ' .. synced .. '/' .. total .. '. Everyone needs BestfriendsList.'
end
function BFL.ListChanged()
    dirty = true
end
local function refreshRoster()
    if not BFL.db then return end
    local nextRoster = {}
    local isActive = inParty()
    if isActive then
        for i = 1, 4 do
            local unit = 'party' .. i
            if UnitExists(unit) then
                local key, name = unitName(unit)
                local guid = UnitGUID(unit)
                if key and not (issecretvalue and issecretvalue(guid)) then nextRoster[key] = {name = name, guid = guid} end
            end
        end
    end
    local altered = active ~= isActive
    for key, member in pairs(roster) do
        if not nextRoster[key] or nextRoster[key].guid ~= member.guid then
            BFL.party[key], incoming[key], lastVersion[key] = nil, nil, nil
            altered = true
        end
    end
    for key, member in pairs(nextRoster) do
        if not roster[key] or roster[key].guid ~= member.guid then altered = true end
    end
    roster, active = nextRoster, isActive
    if not active then outgoing, dirty, request = nil, false, false
    elseif altered then
        -- Discard packets prepared for the previous party composition.
        outgoing, incoming, dirty, request = nil, {}, true, true
    end
    if altered then changed() end
end
function BFL.StartSync()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok = pcall(C_ChatInfo.RegisterAddonMessagePrefix, BFL.PREFIX)
        ready = ok and C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(BFL.PREFIX) or false
    end
    refreshRoster()
    dirty, request = true, true
end
function BFL.RequestSync()
    refreshRoster()
    dirty, request = true, true
end
local function receive(prefix, message, channel, sender)
    if not BFL.db or prefix ~= BFL.PREFIX or channel ~= 'PARTY' or not inParty() then return end
    refreshRoster()
    local owner = senderKey(sender)
    if not owner or type(message) ~= 'string' then return end
    if message == 'REQUEST' then
        -- One response at most per completed snapshot / pending send.
        if GetTime() - lastRequest >= 3 then dirty = true; lastRequest = GetTime() end
        return
    end
    local epoch, rev, index, total, chunk = message:match('^([%d%-]+):(%d+):(%d+):(%d+):(.*)$')
    rev, index, total = tonumber(rev), tonumber(index), tonumber(total)
    if not epoch or #epoch > 40 or not rev or rev > 1000000000 or not index or not total or total < 1 or total > 667 or index < 1 or index > total or #chunk > 180 then return end
    local previous = lastVersion[owner]
    if previous and previous.epoch == epoch and rev <= previous.rev then return end
    local now = GetTime()
    local transfer = incoming[owner]
    if transfer and now - transfer.started > 240 then transfer = nil; incoming[owner] = nil end
    if transfer and transfer.epoch == epoch and rev < transfer.rev then return end
    if not transfer or transfer.epoch ~= epoch or transfer.rev ~= rev then
        transfer = {epoch = epoch, rev = rev, total = total, count = 0, chunks = {}, started = now}
        incoming[owner] = transfer
    end
    if transfer.total ~= total or transfer.chunks[index] then return end
    transfer.chunks[index], transfer.count = chunk, transfer.count + 1
    if transfer.count == total then
        incoming[owner] = nil
        local parsed = BFL.Parse(table.concat(transfer.chunks))
        if not parsed then return end
        -- Local sightings survive refreshes, but are never taken from a sender.
        local old = BFL.party[owner]
        if old then
            for key, entry in pairs(parsed.entries) do
                local prior = old.entries[key]
                if prior then entry.lastSeen, entry.lastSeenZone = prior.lastSeen, prior.lastSeenZone end
            end
        end
        BFL.party[owner] = {name = roster[owner].name, entries = parsed.entries}
        lastVersion[owner] = {epoch = epoch, rev = rev}
        changed()
    end
end
local function send(message)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, BFL.PREFIX, message, 'PARTY')
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    return ok and (result == nil or result == success)
end
local function update(_, delta)
    if not BFL.db then return end
    tick, heartbeat = tick + delta, heartbeat + delta
    if tick < 0.25 then return end
    tick = 0
    refreshRoster()
    if not active or not ready or restricted() then return end
    if heartbeat >= 60 then heartbeat = 0; dirty, request = true, true end
    if request then
        if send('REQUEST') then request = false end
        return
    end
    if not outgoing and dirty then
        local data, err = BFL.Serialize()
        dirty = false
        if not data then notify(err); return end
        revision = revision + 1
        outgoing = {data = data, rev = revision, index = 1, total = math.ceil(#data / 180)}
    end
    if not outgoing then return end
    local q = outgoing
    local message = session .. ':' .. q.rev .. ':' .. q.index .. ':' .. q.total .. ':' .. q.data:sub((q.index - 1) * 180 + 1, q.index * 180)
    -- Retry the same packet after throttling; never publish an incomplete list.
    if not send(message) then return end
    q.index = q.index + 1
    if q.index > q.total then outgoing = nil end
end
local frame = CreateFrame('Frame')
frame:RegisterEvent('CHAT_MSG_ADDON')
frame:RegisterEvent('GROUP_ROSTER_UPDATE')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:SetScript('OnEvent', function(_, event, ...)
    if event == 'CHAT_MSG_ADDON' then pcall(receive, ...)
    else pcall(refreshRoster) end
end)
frame:SetScript('OnUpdate', function(...) pcall(update, ...) end)
