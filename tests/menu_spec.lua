-- Exercise the actual menu helper without loading the UI or logging into WoW.
local source = assert(io.open('BestfriendsList.lua')):read('*a')
local helper = assert(source:match('(local function openPlayerMenu%(entry%).-)\nlocal function scanBFF'))
local compile = loadstring or load
local calls, messages = {}, {}
local chat = {}
local env = {
    normalize = function(name) return name and name:lower() end,
    readableCall = function(fn, ...) return fn(...) end,
    fullName = function(unit) return unit == 'target' and 'King Arthur' or 'Other Player' end,
    IsInRaid = function() return false end,
    IsInGroup = function() return false end,
    UnitExists = function() return true end,
    UnitIsPlayer = function() return true end,
    UnitGUID = function(unit) return unit == 'target' and 'Player-current' or 'Player-other' end,
    DEFAULT_CHAT_FRAME = chat,
    say = function(message) messages[#messages + 1] = message end,
    FriendsFrame_ShowDropdown = function(...) calls[#calls + 1] = {...} end,
}
setmetatable(env, {__index = _G})
local chunk
if setfenv then
    chunk = assert(compile(helper .. '\nreturn openPlayerMenu'))
    setfenv(chunk, env)
else
    chunk = assert(load(helper .. '\nreturn openPlayerMenu', 'menu helper', 't', env))
end
local openMenu = chunk()
openMenu({name = 'King Arthur', guid = 'Player-saved'})
assert(calls[1][1] == 'King Arthur', 'Preserve the full Forever identity')
assert(calls[1][5] == chat, 'Whisper needs a real chat frame')
assert(calls[1][11] == 'Player-saved', 'Pass the saved GUID')
openMenu({name = 'King Arthur'})
assert(calls[2][11] == 'Player-current', 'Resolve a matching current unit')
openMenu({name = 'Absent Person'})
assert(calls[3][11] == nil, 'Never use another player GUID')
env.FriendsFrame_ShowDropdown = nil
env.UnitPopup_OpenMenu = function(which, context)
    assert(which == 'FRIEND' and context.name == 'King Arthur')
    assert(context.chatFrame == chat and context.chatTarget == 'King Arthur')
    assert(context.unit == nil, 'Do not pass stale unit tokens')
    calls[#calls + 1] = context
end
openMenu({name = 'King Arthur'})
assert(#calls == 4, 'Use the native popup fallback')
env.UnitPopup_OpenMenu = nil
openMenu({name = 'Absent Person'})
assert(#messages == 1, 'Explain when native menus are unavailable')
return true
