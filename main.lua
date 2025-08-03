-- SPDX-License-Identifier: MIT

-- local BEAMPAINT_URL = "http://127.0.0.1:3030"
local BEAMPAINT_URL = "https://cdn.beampaint.com/api/v2"
-- either "release" or "testing"
local CHANNEL = "release"

-- Thanks Bouboule for this function
function httpRequest(url)
    local response = ""

    if MP.GetOSName() == "Windows" then
        response = os.execute('powershell -Command "Invoke-WebRequest -Uri ' .. url .. ' -OutFile temp.txt"')
    else
        response = os.execute("wget -q -O temp.txt " .. url)
    end

    if response then
        local file = io.open("temp.txt", "r")
        local content = file:read("*all")
        file:close()
        os.remove("temp.txt")
        return content
    else
        return nil
    end
end

function httpRequestJson(url)
    local raw = httpRequest(url)
    return Util.JsonDecode(raw)
end

function httpRequestSaveFile(url, filename)
    local response = ""

    if MP.GetOSName() == "Windows" then
        response = os.execute('powershell -Command "Invoke-WebRequest -Uri ' .. url .. ' -OutFile ' .. filename .. '"')
    else
        response = os.execute("wget -q -O " .. filename .. " " .. url)
    end

    return response
end

function loadCurrentClientVersion()
    local file = io.open("Resources/Server/BeamPaintServerPlugin/client-version.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        return Util.JsonDecode(content)
    end
end

function loadCurrentServerVersion()
    local file = io.open("Resources/Server/BeamPaintServerPlugin/server-version.json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        return Util.JsonDecode(content)
    end
end

function getClientVersion()
    local url = BEAMPAINT_URL .. "/version/" .. CHANNEL .. "/client"
    local resp = httpRequest(url)
    if resp then
        return true, Util.JsonDecode(resp)
    end
    return false, "Could not get latest version from the BeamPaint API!"
end

function getServerVersion()
    local url = BEAMPAINT_URL .. "/version/" .. CHANNEL .. "/server"
    local resp = httpRequest(url)
    if resp then
        return true, Util.JsonDecode(resp)
    end
    return false, "Could not get latest version from the BeamPaint API!"
end

function writeClientVersion(version)
    local json = Util.JsonEncode(version)
    local file = io.open("Resources/Server/BeamPaintServerPlugin/client-version.json", "w")
    if file then
        file:write(json)
        file:close()
    end
end

function writeServerVersion(version)
    local json = Util.JsonEncode(version)
    local file = io.open("Resources/Server/BeamPaintServerPlugin/server-version.json", "w")
    if file then
        file:write(json)
        file:close()
    end
end

function downloadClientMod()
    local url = BEAMPAINT_URL .. "/download/" .. CHANNEL .. "/client/BeamPaint.zip"
    httpRequestSaveFile(url, "Resources/Client/BeamPaint.zip")
end

function downloadServerPlugin()
    FS.CreateDirectory("Resources/Server/BeamPaintServerPlugin")
    local files = httpRequestJson(BEAMPAINT_URL .. "/list/" .. CHANNEL .. "/server")
    for i, file in pairs(files) do
        print(file)
        httpRequestSaveFile(BEAMPAINT_URL .. "/download/" .. CHANNEL .. "/server/" .. file, "Resources/Server/BeamPaintServerPlugin/" .. file)
    end
end

function onInitClient()
    local installedVersion = loadCurrentClientVersion() or { major = 0, minor = 0 }

    print("[BeamPaint] Current client version: v" .. installedVersion.major .. "." .. installedVersion.minor)
    print("[BeamPaint] Checking for updates, selected channel '" .. CHANNEL ..  "'...")

    local success, version = getClientVersion()
    if not success then
        print("[BeamPaint] Error: " .. version)
        print("[BeamPaint] The backend API might be down, aborting...")
        return
    end
    print("[BeamPaint] Latest client version: v" .. version.major .. "." .. version.minor .. " (" .. CHANNEL .. ")")
    local needsUpdate = version.major > installedVersion.major
    if version.major == installedVersion.major then
        needsUpdate = version.minor > installedVersion.minor
    end
    if not needsUpdate then
        print("[BeamPaint] BeamPaint is up-to-date! Have fun using BeamPaint!")
        return
    end
    print("[BeamPaint] BeamPaint is out-of-date or not installed. Updating...")

    downloadClientMod()
    writeClientVersion(version)
end

function onInitServer()
    local installedVersion = loadCurrentServerVersion() or { major = 0, minor = 0 }

    print("[BeamPaint] Current server version: v" .. installedVersion.major .. "." .. installedVersion.minor)
    print("[BeamPaint] Checking for updates...")

    local success, version = getServerVersion()
    if not success then
        print("[BeamPaint] Error: " .. version)
        print("[BeamPaint] The backend API might be down, aborting...")
        return
    end
    print("[BeamPaint] Latest server version: v" .. version.major .. "." .. version.minor)
    local needsUpdate = version.major > installedVersion.major
    if version.major == installedVersion.major then
        needsUpdate = version.minor > installedVersion.minor
    end
    if not needsUpdate then
        print("[BeamPaint] BeamPaint is up-to-date! Have fun using BeamPaint!")
        return
    end
    print("[BeamPaint] BeamPaint is out-of-date or not installed. Updating...")

    downloadServerPlugin()
    writeServerVersion(version)
end

function onInit()
    onInitClient()
    onInitServer()

    print("[BeamPaint] Done! Please restart the server to finalize the update.")
end

MP.RegisterEvent("onInit", "onInit")
