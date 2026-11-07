-- Exercise the actual shared field function without loading the WoW UI.
local file = assert(io.open('BestfriendsList.lua', 'r'))
local source = file:read('*a'); file:close()
local first = assert(source:find('local function field(', 1, true))
local last = assert(source:find('\nlocal function shell(', first, true))
local snippet = source:sub(first, last - 1) .. '\nreturn field'
local function noop() end
local function createEdit()
    local edit = {scripts = {}, text = ''}
    for _, method in ipairs({'SetSize', 'SetPoint', 'SetFontObject', 'SetTextInsets', 'SetAutoFocus', 'SetBackdropBorderColor', 'ClearFocus'}) do edit[method] = noop end
    function edit:CreateFontString()
        local hint = {shown = true, SetPoint = noop}
        function hint:SetText(text) self.text = text end
        function hint:SetShown(shown) self.shown = shown end
        self.hint = hint
        return hint
    end
    function edit:SetScript(event, callback) self.scripts[event] = callback end
    function edit:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function edit:GetText() return self.text end
    function edit:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    return edit
end
local env = setmetatable({
    CreateFrame = createEdit, surface = noop, ChatFontNormal = {},
    UI = {accent = {}, border = {}}, unpack = unpack or table.unpack,
}, {__index = _G})
local chunk
if loadstring then
    chunk = assert(loadstring(snippet, '@shared-field'))
    setfenv(chunk, env)
else chunk = assert(load(snippet, '@shared-field', 't', env)) end
local field = chunk()
local search = field({}, 300, 0, 0, 'Search names...')
assert(search.hint.shown, 'Empty search must show its placeholder')
local calls = 0
search.onTextChanged = function(self)
    calls = calls + 1
    assert(self.hint.shown == (self:GetText() == ''), 'Placeholder must update before the search handler')
end
search:SetText('King Arthur')
assert(not search.hint.shown and calls == 1, 'Typing must hide placeholder and still invoke search')
search:SetText('')
assert(search.hint.shown and calls == 2, 'Clearing search must restore placeholder')
local name = field({}, 364, 0, 0, 'Ex-friend')
local changed = false
name.onTextChanged = function() changed = true end
name:SetText('My custom list')
assert(not name.hint.shown and changed, 'Rename handler must not replace placeholder updates')
name:SetText('')
assert(name.hint.shown, 'Clearing rename input must restore its placeholder')
name:SetText('Ex-friend')
assert(not name.hint.shown, 'A saved value matching placeholder text must still hide the placeholder')
assert(not source:find("search:SetScript('OnTextChanged'", 1, true), 'Search must use the shared callback')
assert(not source:find("f.name:SetScript('OnTextChanged'", 1, true), 'Rename must use the shared callback')
return true
