local _, BFL = ...
-- Isolated data tests: no network sends and no changes to the live lists.
function BFL.RunDataTests()
    local savedDB, savedParty, checks = BFL.db, BFL.party, 0
    local savedFactionAPI = UnitFactionGroup
    local currentFaction = 'Alliance'
    UnitFactionGroup = function(unit)
        if unit == 'player' then return currentFaction end
        return savedFactionAPI and savedFactionAPI(unit)
    end
    local function check(condition, message)
        assert(condition, message)
        checks = checks + 1
    end
    -- Legacy tests explicitly opt into unknown entries; new faction tests below
    -- exercise strict defaults separately.
    local function init(db)
        db.factionVersion = 1
        BFL.Init(db)
        BFL.Filters().showUnknown = true
    end
    local ok, err = pcall(function()
        local old = {['arthas menethil'] = {name = 'Arthas Menethil', class = 'Paladin', level = 60, lastSeen = 123, lastSeenZone = 'Local zone'}}
        local db = {entries = old, testMode = true, sound = false}
        init(db)
        check(BFL.Own() == old and db.entries == nil, 'Legacy list migration')
        check(db.testMode == nil and db.sound == false, 'Retire test setting while preserving sound preference')
        local data = assert(BFL.Serialize())
        local parsed = assert(BFL.Parse(data))
        check(parsed.count == 1, 'Snapshot count')
        local entry = parsed.entries['arthas menethil']
        check(entry.class == (BFL.ClassToken('Paladin') or 'Paladin') and entry.level == 60, 'Metadata round trip')
        check(not entry.lastSeen and not entry.lastSeenZone, 'Sightings stay local')
        BFL.party['friend person'] = {name = 'Friend Person', entries = parsed.entries}
        check(#BFL.Matches('arthas menethil') == 2, 'Match own and party lists')
        check(#BFL.View(false) == 1 and #BFL.View(true) == 1, 'Deduplicate party view')
        check(#BFL.View(true)[1].owners == 2, 'Display both owners')
        BFL.party['friend person'].entries['jaina proudmoore'] = {name = 'Jaina Proudmoore'}
        check(#BFL.View(false) == 1 and #BFL.View(true) == 2, 'Own view excludes friend-only entries')
        check(#BFL.Matches('jaina proudmoore') == 1, 'Friend-only detection')
        BFL.party['friend person'].entries['arthas menethil'] = nil
        check(#BFL.Matches('arthas menethil') == 1 and BFL.Own()['arthas menethil'], 'Snapshot deletion does not delete own entry')
        local personalOnly = assert(BFL.Parse(assert(BFL.Serialize())))
        check(not personalOnly.entries['jaina proudmoore'], 'Never relay a friend list')
        BFL.party = {}
        check(#BFL.Matches('jaina proudmoore') == 0, 'Leaving party removes friend-only detection')
        init({profiles = {['My List'] = {entries = old}, Imported = {entries = {['other person'] = {name = 'Other Person'}}}}})
        check(BFL.Own() == old and not BFL.Own()['other person'], 'Migrate only personal profile')
        check(BFL.Name('  ARTHAS   Menethil ') == 'arthas menethil', 'Name normalization')
        check(not BFL.Name('Arthas'), 'Reject first name alone')
        local roster = {['friend person'] = true}
        check(BFL.SenderKey('Friend Person', roster) == 'friend person', 'Full sender name')
        check(BFL.SenderKey('Friend-Person', roster) == 'friend person', 'Hyphen surname separator')
        check(BFL.SenderKey('Friend Person-Realm', roster) == 'friend person', 'Separate realm suffix')
        check(BFL.SenderKey('Friend-Person-Realm', roster) == 'friend person', 'Hyphen surname plus realm')
        check(not BFL.SenderKey('Stranger Person', roster), 'Reject outsiders')
        check(not BFL.SenderKey('Friend', roster), 'Reject ambiguous sender')
        check(not BFL.Parse('KOSP3\nOwn\nArthas Menethil\tPaladin\t-1'), 'Reject invalid levels')
        check(not BFL.Parse('KOSP3\nOwn\n%ZZ Menethil\t\t'), 'Reject invalid escapes')
        check(not BFL.Parse('KOSP3\nOwn\nArthas Menethil\t%7Cbad\t60'), 'Reject markup')
        check(not BFL.Parse(string.rep('x', 120001)), 'Reject oversized snapshot')
        init({ownEntries = {['élan dusk'] = {name = 'élan dusk', class = 'Test % Class'}}})
        local unicode = assert(BFL.Parse(assert(BFL.Serialize())))
        check(unicode.entries['élan dusk'].class == 'Test % Class', 'UTF-8/percent round trip')
        init({ownEntries = {}})
        check(assert(BFL.Parse(assert(BFL.Serialize()))).count == 0, 'Empty snapshot supports clearing list')
        BFL.db.bffEntries['friend person'] = {name = 'Friend Person'}
        check(#BFL.db.bffLabels == 4 and not BFL.BFFLabel(BFL.db.bffEntries['friend person']), 'Four personal labels; existing entries start unlabeled')
        check(BFL.SetBFFLabels({'Ninja', 'Rude', '0IQ', 'Micro'}), 'Customize all four label names')
        check(BFL.SetBFFLabel('Friend Person', 3) and BFL.BFFLabel(BFL.db.bffEntries['friend person']) == '0IQ', 'Assign label by stable slot')
        check(BFL.SetBFFLabels({'White', 'Green', 'Yellow', 'Red'}) and BFL.BFFLabel(BFL.db.bffEntries['friend person']) == 'Yellow', 'Renaming labels updates existing assignments')
        local labels = BFL.db.bffLabels
        check(not BFL.SetBFFLabels({'Same', 'same', 'Third', 'Fourth'}) and BFL.db.bffLabels == labels, 'Duplicate label names rejected atomically')
        check(not BFL.SetBFFLabels({'Valid', '|cffff0000Bad', 'Third', 'Fourth'}) and BFL.db.bffLabels == labels, 'Reject label formatting without changing saved names')
        check(not BFL.SetBFFLabel('Friend Person', 5) and BFL.db.bffEntries['friend person'].label == 3, 'Reject out-of-range assignment')
        check(BFL.SetBFFLabel('Friend Person', 0) and not BFL.BFFLabel(BFL.db.bffEntries['friend person']), 'Clear label independently of BFF entry')
        check(not BFL.SetBFFLabel('Missing Person', 1), 'Only existing BFF entries can receive labels')
        check(#BFL.BFFView() == 1 and #BFL.View(false) == 0, 'BFF entries stay separate from KoS')
        check(#BFL.Matches('friend person') == 0, 'BFF-only entries never match nearby scans')
        check(assert(BFL.Parse(assert(BFL.Serialize()))).count == 0, 'BFF entries never enter party KoS sync')
        local members = {['friend person'] = true, ['other person'] = true}
        local present, joined = BFL.BFFTransitions(BFL.db.bffEntries, members, {})
        check(#joined == 1 and joined[1] == 'friend person', 'Group entry alerts only for listed members')
        local same, repeats = BFL.BFFTransitions(BFL.db.bffEntries, members, present)
        check(#repeats == 0 and same['friend person'], 'Unchanged group and party-to-raid conversion do not repeat alerts')
        local absent = BFL.BFFTransitions(BFL.db.bffEntries, {}, same)
        check(not next(absent), 'Leaving group clears BFF presence')
        local _, rejoined = BFL.BFFTransitions(BFL.db.bffEntries, members, absent)
        check(#rejoined == 1, 'Rejoining group permits a fresh alert')
        BFL.db.bffEntries['friend person'] = nil
        local removed, notices = BFL.BFFTransitions(BFL.db.bffEntries, members, present)
        check(not next(removed) and #notices == 0, 'Removed BFF entries stop alerting')
        init({ownEntries = {['arthas menethil'] = {name = 'Arthas Menethil'}}})
        BFL.party['friend person'] = {name = 'Friend Person', entries = {
            ['arthas menethil'] = {name = 'Arthas Menethil'},
            ['jaina proudmoore'] = {name = 'Jaina Proudmoore'},
        }}
        BFL.party['empty person'] = {name = 'Empty Person', entries = {}}
        local grouped = BFL.ListRows('party', '')
        check(#grouped == 6 and grouped[1].header and grouped[1].name == 'You', 'Party lists have separate owner headers, including empty lists')
        BFL.db.partyCollapsed['friend person'] = true
        check(#BFL.ListRows('party', '') == 4, 'Collapse hides only that member entries')
        local searched = BFL.ListRows('party', '  jAiNa  ')
        check(#searched == 2 and searched[1].name == 'Friend Person' and searched[2].entry.name == 'Jaina Proudmoore', 'Name search ignores case and surrounding spaces, revealing collapsed matches')
        check(BFL.db.partyCollapsed['friend person'] and #BFL.ListRows('party', '') == 4, 'Clearing search restores saved collapse state')
        check(#BFL.Matches('jaina proudmoore') == 1, 'Collapsed/filtered targets still match alerts')
        check(#BFL.ListRows('party', '.') == 0, 'Search uses literal text instead of patterns')
        check(#BFL.ListRows('mine', 'menethil') == 1 and #BFL.ListRows('mine', 'jaina') == 0, 'Personal name search stays personal')
        BFL.db.bffEntries['friend person'] = {name = 'Friend Person'}
        check(#BFL.ListRows('bff', 'PERSON') == 1, 'BFF name search')
        init(BFL.db)
        check(BFL.db.partyCollapsed['friend person'], 'Collapse preferences survive initialization')
        currentFaction = 'Alliance'
        local factionDB = {
            testMode = true,
            ownEntries = {
                ['enemy person'] = {name = 'Enemy Person', faction = 'Horde'},
                ['friend person'] = {name = 'Friend Person', faction = 'Alliance'},
                ['legacy person'] = {name = 'Legacy Person'},
            },
            bffEntries = {
                ['ninja person'] = {name = 'Ninja Person', faction = 'Horde', label = 1},
                ['rude person'] = {name = 'Rude Person', faction = 'Horde', label = 2},
                ['friend person'] = {name = 'Friend Person', faction = 'Alliance', label = 3, lastSeen = 123, lastSeenZone = 'Group zone'},
            },
            bffLabels = {'Ninja', 'Rude', '0IQ', 'Micro'},
        }
        BFL.Init(factionDB)
        check(not factionDB.testMode and factionDB.factionVersion == 1, 'Faction upgrade starts in enemy mode')
        check(factionDB.bffEntries['friend person'].lastGrouped == 123
            and factionDB.bffEntries['friend person'].lastGroupedZone == 'Group zone', 'Upgrade preserves previous BFF grouped history separately from KoS sightings')
        check(#BFL.ListRows('mine', '') == 1 and BFL.ListRows('mine', '')[1].key == 'enemy person', 'Alliance KoS shows only known Horde targets by default')
        check(#BFL.ListRows('bff', '') == 1 and BFL.ListRows('bff', '')[1].key == 'friend person', 'Alliance BFF shows only known Alliance targets')
        check(#BFL.Matches('ninja person') == 0, 'Enemy BFF does not alert until its label is selected')
        BFL.Filters().labels[1] = true
        check(#BFL.ListRows('mine', '') == 2 and #BFL.Matches('ninja person') == 1, 'Selected Ninja label promotes opposing BFF into KoS view and matching')
        check(not BFL.Own()['ninja person'] and BFL.db.bffEntries['ninja person'], 'Promotion does not move or copy shared BFF records')
        currentFaction = 'Horde'
        check(#BFL.ListRows('mine', '') == 1 and BFL.ListRows('mine', '')[1].key == 'friend person', 'Horde KoS automatically switches to Alliance targets')
        check(#BFL.ListRows('bff', '') == 2, 'Horde BFF automatically shows Horde players')
        check(not BFL.Filters().labels[1] and not BFL.BFFPromoted('ninja person'), 'Horde filter choices are independent; friendly BFF is not promoted')
        BFL.Filters().labels[3] = true
        check(#BFL.ListRows('mine', '') == 1 and #BFL.Matches('friend person') == 1, 'Explicit KoS plus promoted BFF target is deduplicated')
        currentFaction = 'Alliance'
        check(BFL.Filters().labels[1] and not BFL.Filters().labels[3], 'Alliance filter selection survives faction switching')
        BFL.SetBFFLabels({'Thief', 'Rude', '0IQ', 'Micro'})
        check(BFL.BFFPromoted('ninja person') and BFL.NameLabel('ninja person') == 'Thief', 'Renaming a selected label preserves selection and reason')
        BFL.party['member person'] = {name = 'Member Person', entries = {
            ['enemy person'] = {name = 'Enemy Person', faction = 'Horde'},
            ['friend person'] = {name = 'Friend Person', faction = 'Alliance'},
        }}
        local partyRows, friendVisible = BFL.ListRows('party', ''), false
        for _, row in ipairs(partyRows) do if not row.header and row.key == 'friend person' then friendVisible = true end end
        check(not friendVisible and #BFL.Matches('enemy person') == 2, 'Party views and matching respect the receiving character faction')
        local snapshot = assert(BFL.Parse(assert(BFL.Serialize())))
        check(snapshot.count == 1 and snapshot.entries['enemy person'].faction == 'Horde', 'Party snapshot filters and round-trips faction')
        check(not snapshot.entries['ninja person'], 'Local BFF promotions and labels remain private during party sync')
        check(not BFL.Parse('KOSP4\nOwn\nBad Person\tMAGE\t60\tNeutral'), 'Reject invalid wire faction')
        check(assert(BFL.Parse('KOSP3\nOwn\nLegacy Person\tMAGE\t60')).entries['legacy person'].faction == nil, 'Legacy snapshots retain unknown faction without guessing')
        BFL.Filters().showUnknown = true
        check(#BFL.ListRows('mine', '') == 3, 'Unknown faction entries require explicit opt-in')
        BFL.db.bffEntries['unknown person'] = {name = 'Unknown Person', label = 1}
        check(not BFL.BFFPromoted('unknown person'), 'Unknown faction BFF is never guessed to be an enemy promotion')
        BFL.db.bffEntries['legacy person'] = {name = 'Legacy Person', label = 1}
        check(BFL.RememberFaction('legacy person', 'Horde') and BFL.Own()['legacy person'].faction == 'Horde'
            and BFL.db.bffEntries['legacy person'].faction == 'Horde', 'Learning faction updates both personal records')
        BFL.Filters().showUnknown = false
        check(#BFL.Matches('legacy person') == 1, 'Known enemy remains visible after unknown filter is disabled')
        BFL.RememberFaction('legacy person', 'Alliance')
        check(#BFL.Matches('legacy person') == 0 and BFL.BFFVisible(BFL.db.bffEntries['legacy person']), 'Correcting faction moves visibility without deleting data')
        local groupedBFF, groupNotices = BFL.BFFTransitions(BFL.db.bffEntries, {['friend person'] = true, ['ninja person'] = true}, {})
        check(groupedBFF['friend person'] and not groupedBFF['ninja person'] and #groupNotices == 1, 'BFF group alerts exclude known opposing faction members')
        currentFaction = 'Unknown'
        check(#BFL.ListRows('mine', '') == 0 and #BFL.ListRows('bff', '') == 0, 'Unknown player faction is handled safely')
        check(BFL.ListTitle() == 'Ex-friend', 'New default personal list title')
        BFL.Init({listTitle = 'My List', testMode = true})
        check(BFL.ListTitle() == 'Ex-friend' and BFL.db.testMode == nil, 'Migrate old default title and retire old testing preference')
        BFL.Init({listTitle = 'My custom title'})
        check(BFL.ListTitle() == 'My custom title', 'Preserve existing custom list titles')
        check(not BFL.NormalizeListTitle('   ') and not BFL.NormalizeListTitle('|cffff0000Hidden'), 'Reject empty or formatted list names')
        check(BFL.SetListTitle(' Watchlist ', 90, 140) and BFL.ListTitle() == 'Watchlist', 'Save and normalize a fitting custom list name')
        check(BFL.WatchAlert('King Arthur', 'Ninja') == 'Watchlist: King Arthur - Ninja', 'Nearby warning uses custom list name and bare label')
        check(BFL.WatchAlert('King Arthur') == 'Watchlist: King Arthur', 'Unlabeled nearby warning has no empty suffix')
        check(BFL.GroupAlert('King Arthur', 'Ninja', false) == 'Ninja: King Arthur joined the party', 'Group alert uses label as prefix')
        check(BFL.GroupAlert('King Arthur', nil, false) == 'King Arthur joined the party', 'Unlabeled group alert omits prefix')
        check(BFL.GroupAlert('King Arthur', 'Rude', true) == 'Rude: King Arthur joined the raid', 'Raid alert uses the same label format')
        check(not BFL.SetListTitle('Too wide', 141, 140) and BFL.ListTitle() == 'Watchlist', 'Reject overflow without changing the saved name')
        check(BFL.SetListTitle('Exact fit', 140, 140) and BFL.ListTitle() == 'Exact fit', 'Allow a name that exactly fits the available width')
        BFL.Init(BFL.db)
        check(BFL.ListTitle() == 'Exact fit', 'Custom list name survives initialization')
        currentFaction = 'Alliance'
        BFL.Init({})
        for i = 1, 12 do
            BFL.RecordRecent('Person' .. string.char(64 + i) .. ' Party',
                {class = 'MAGE', level = 20 + i, faction = i % 2 == 0 and 'Alliance' or 'Horde', groupType = 'party'}, i, true)
        end
        check(#BFL.db.recentPlayers == 10 and BFL.db.recentPlayers[1].name == 'PersonL Party'
            and BFL.db.recentPlayers[10].name == 'PersonC Party', 'Recent history retains only the ten newest unique people')
        BFL.RecordRecent('personD   Party', {level = 50}, 99, false)
        check(BFL.db.recentPlayers[1].name == 'PersonL Party' and #BFL.db.recentPlayers == 10, 'Roster refresh updates metadata without changing encounter order')
        check(BFL.RecentPlayer('persond party').level == 50 and BFL.RecentPlayer('persond party').class == 'MAGE', 'Recent metadata refresh preserves unavailable known details')
        check(not BFL.RecordRecent('PersonA Party', {}, 99, false) and #BFL.db.recentPlayers == 10, 'Evicted current members do not churn back into history without rejoining')
        BFL.RecordRecent('PersonD Party', {groupType = 'raid'}, 100, true)
        check(BFL.db.recentPlayers[1].name == 'PersonD Party' and #BFL.db.recentPlayers == 10, 'Rejoining moves a person to the top without duplicating them')
        check(BFL.db.recentPlayers[1].lastGrouped == 100 and BFL.db.recentPlayers[1].groupType == 'raid', 'Recent entries retain group context and time')
        check(#BFL.ListRows('recent', 'PERSOND') == 1 and #BFL.ListRows('recent', '') == 10, 'Recent name search is case-insensitive and preserves all faction history')
        check(not next(BFL.Own()) and not next(BFL.db.bffEntries) and #BFL.Matches('persond party') == 0, 'Recording history does not automatically add watchlist entries or alerts')
        check(assert(BFL.Parse(assert(BFL.Serialize()))).count == 0, 'Recent history is private and excluded from party synchronization')
        local history = BFL.db.recentPlayers
        BFL.Init(BFL.db)
        check(BFL.db.recentPlayers == history and BFL.db.recentPlayers[1].name == 'PersonD Party', 'Recent history persists across initialization')
        BFL.Init({bffLabels = {'Label 1', 'Label 2', 'Label 3', 'Label 4'},
            bffEntries = {['friend person'] = {name = 'Friend Person', label = 2}}})
        check(table.concat(BFL.db.bffLabels, ',') == 'Avoid,Ninja,Rude,Tank'
            and BFL.NameLabel('friend person') == 'Ninja', 'Upgrade stock labels without changing assignment slots')
        local customLabels = {'White', 'Green', 'Yellow', 'Red'}
        BFL.Init({bffLabels = customLabels})
        check(BFL.db.bffLabels == customLabels, 'Preserve personalized label sets when defaults change')
    end)
    BFL.db, BFL.party = savedDB, savedParty
    UnitFactionGroup = savedFactionAPI
    return ok, ok and checks or err
end
