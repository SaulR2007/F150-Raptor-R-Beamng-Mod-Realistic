-- playlist_config.lua
local M = {}

-- Initialize with empty default playlist
M.playlists = {
    default = {}  -- Empty default playlist
}

function M.addPlaylist(name, songs)
    M.playlists[name] = songs
    print("Added new playlist: " .. name .. " with " .. #songs .. " songs")
end

function M.mergePlaylist(name, songs)
    print("Attempting to merge " .. #songs .. " songs into playlist " .. name)
    if M.playlists[name] then
        local originalSize = #M.playlists[name]
        for _, song in ipairs(songs) do
            table.insert(M.playlists[name], song)
        end
        print("Successfully merged songs. Size before: " .. originalSize .. ", Size after: " .. #M.playlists[name])
    else
        M.playlists[name] = songs
        print("Created new playlist: " .. name .. " with " .. #songs .. " songs")
    end
end

local function loadAdditionalSongs()
    print("Scanning for additional song files...")
    local paths = {
        "/vehicles/common/lua/songs/",
        "/lua/common/songs/",
        "/lua/songs/"
    }
    
    for _, basePath in ipairs(paths) do
        local songFiles = FS:findFiles(basePath, "*.lua", -1, true, false)
        for _, file in ipairs(songFiles) do
            print("Processing song file: " .. file)
            local status, result = pcall(function()
                dofile(file)
            end)
            if status then
                print("Successfully loaded: " .. file)
            else
                print("Error loading file: " .. file .. "\nError: " .. tostring(result))
            end
        end
    end
end

function M.getAllSongs()
    loadAdditionalSongs()
    local allSongs = {}
    for playlistName, playlist in pairs(M.playlists) do
        print("Getting songs from playlist: " .. playlistName)
        for _, song in ipairs(playlist) do
            table.insert(allSongs, song)
        end
    end
    print("Total songs gathered: " .. #allSongs)
    return allSongs
end

return M