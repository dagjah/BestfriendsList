-- Run from the addon root with Lua 5.1+; none of these files ship in the addon.
local BFL = {}
assert(loadfile('Lists.lua'))('BestfriendsList', BFL)
assert(loadfile('Factions.lua'))('BestfriendsList', BFL)
assert(loadfile('tests/data_spec.lua'))('BestfriendsList', BFL)
local ok, result = BFL.RunDataTests()
assert(ok, result)
assert(dofile('tests/field_spec.lua'))
assert(dofile('tests/menu_spec.lua'))
assert(not BFL.SetPartyDemo and not BFL.DisplayOwn and not BFL.DisplayCollapsed, 'Release must not expose development features')
print('Passed ' .. result .. ' data assertions and shared-field and player-menu regressions.')
