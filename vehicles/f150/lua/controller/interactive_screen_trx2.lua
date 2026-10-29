local M = {}
M.type = "auxiliary"

local playlistConfig = require("vehicles/common/lua/playlist_config")
print("Music player controller started - loading playlist config")

local htmlTexture = require("htmlTexture")

-- Forward declare functions that need to reference each other
local handleMusicControls
local playNextTrack
local updateMusicDisplay
local loadSong
local playSong
local updateUI
local moveVertical
local updateProgressDisplay
local directButtons

local screenMaterialName = nil
local htmlFilePath = nil
local textureWidth = 0
local textureHeight = 0
local textureFPS = 0
local updateTimer = 0
local invFPS = 1 / 15 -- 15 FPS

-- Track last values for detecting changes
local lastMenuNav = 0
local lastMenuSelect = 0
local lastMenuVertical = 0
local lastTime = 0
local debugInterval = 0.1 -- Check for changes every 0.1 seconds

-- Audio system variables
local sfx_table = {}
local current_sfx_playing = nil
local timer = 0
local volume = 50
local soundNode = 614
local play_song_dir = nil
local songTimer = 0
local isShuffled = false
local shuffledPlaylist = {}
local progressUpdateTimer = 0
local PROGRESS_UPDATE_INTERVAL = 1.0  -- Update every second

-- Direct keyboard controls for testing
directButtons = function(dt)
    -- Check for key presses to control music directly
    if input and input.keyboard then
        if input.keyboard.buttonPressed(input.key.left) then
            print("[DEBUG] Left arrow pressed - previous track")
            handleMusicControls("previous")
        end
        
        if input.keyboard.buttonPressed(input.key.right) then
            print("[DEBUG] Right arrow pressed - next track")
            handleMusicControls("next")
        end
        
        if input.keyboard.buttonPressed(input.key.space) then
            print("[DEBUG] Space pressed - toggle playback")
            handleMusicControls("toggle")
        end
    end
end

-- Get playlist from config
local playlist = playlistConfig.getAllSongs()
print("Loaded playlist with " .. #playlist .. " songs")

-- UI state
local currentState = {
    selectedIndex = 1,
    lastInputTime = 0,
    inputDelay = 0.1,
    isPlaying = false,
    currentTrack = 0
}

-- Function to shuffle playlist
local function shufflePlaylist()
    -- Reseed the random number generator
    math.randomseed(os.time())

    shuffledPlaylist = {}
    for i = 1, #playlist do
        shuffledPlaylist[i] = i
    end
    for i = #shuffledPlaylist, 2, -1 do
        local j = math.random(i)
        shuffledPlaylist[i], shuffledPlaylist[j] = shuffledPlaylist[j], shuffledPlaylist[i]
    end

    print("Shuffled playlist")
end


local function getCurrentTrackDuration()
    if currentState.currentTrack > 0 then
        return playlist[currentState.currentTrack].duration
    end
    return 0
end

-- New function for progress updates
updateProgressDisplay = function(elapsed, duration)
    if screenMaterialName then
        local progress = (elapsed / duration) * 100
        
        htmlTexture.call(screenMaterialName, string.format([[
            (function() {
                const frame = document.getElementById('music-frame');
                if (frame && frame.contentWindow) {
                    frame.contentWindow.postMessage({
                        type: 'setProgress',
                        progress: %f,
                        currentTime: %f,
                        totalTime: %f
                    }, '*');
                }
            })();
        ]], progress, elapsed, duration))
    end
end

updateMusicDisplay = function(title, artist)
    if screenMaterialName then
        local track = playlist[currentState.currentTrack] or {}
        local displayTitle = title
        local displayArtist = artist
        local displayArt = "local://local/vehicles/f150/Screen/album_covers/placeholder.png"
        local noMusic = #playlist == 0
        
        if track.albumArt then
            displayArt = track.albumArt
        end
        
        htmlTexture.call(screenMaterialName, string.format([[
            (function() {
                try {
                    var musicFrame = document.getElementById('music-frame');
                    if (musicFrame && musicFrame.contentWindow) {
                        musicFrame.contentWindow.postMessage({
                            type: 'updateTrack',
                            data: {
                                title: '%s',
                                artist: '%s',
                                albumArt: '%s',
                                isPlaying: %s,
                                noMusic: %s
                            }
                        }, '*');
                    }
                } catch(e) {
                    console.error("Error updating track display:", e);
                }
            })();
        ]], displayTitle, displayArtist, displayArt, currentState.isPlaying and 'true' or 'false', noMusic and 'true' or 'false'))
    end
end

loadSong = function(song_dir)
    if song_dir and not sfx_table[song_dir] then
        sfx_table[song_dir] = obj:createSFXSource(song_dir, "AudioDefaultLoop3D", "", soundNode)
        return true
    end
    return sfx_table[song_dir] ~= nil
end

playSong = function(song_dir)
    if song_dir and sfx_table[song_dir] then
        if current_sfx_playing then
            obj:stopSFX(current_sfx_playing)
            current_sfx_playing = nil
        end
        
        local sfx_to_play = sfx_table[song_dir]
        if sfx_to_play then
            local rawVolume = electrics.values.Volume or 500
            local normalizedVolume = (math.max(0, math.min(rawVolume, 1000)) / 1000)
            obj:setVolumePitch(sfx_to_play, normalizedVolume, 1)
            obj:playSFX(sfx_to_play)
            current_sfx_playing = sfx_to_play
        end
    end
end

handleMusicControls = function(action)
    print("[TRIGGER] Processing music action: " .. action)

    -- Check if ignition is off
    if electrics.values.ignitionLevel == 0 then
        if current_sfx_playing then
            obj:stopSFX(current_sfx_playing)
            current_sfx_playing = nil
            currentState.isPlaying = false
            updateMusicDisplay("Select a song", " ")
            updateProgressDisplay(0, 0)
        end
        return
    end

    -- If playlist is empty, just update display
    if #playlist == 0 then
        updateMusicDisplay("No music found", "Get some here")
        return
    end

    if action == "next" or action == "previous" then
        if current_sfx_playing then
            obj:stopSFX(current_sfx_playing)
            current_sfx_playing = nil
        end
        play_song_dir = nil
        songTimer = 0
        updateProgressDisplay(0, getCurrentTrackDuration())

        if isShuffled then
            local currentShuffleIndex = 1
            for i, v in ipairs(shuffledPlaylist) do
                if v == currentState.currentTrack then
                    currentShuffleIndex = i
                    break
                end
            end
            if action == "next" then
                currentShuffleIndex = (currentShuffleIndex % #shuffledPlaylist) + 1
            else
                currentShuffleIndex = ((currentShuffleIndex - 2 + #shuffledPlaylist) % #shuffledPlaylist) + 1
            end
            currentState.currentTrack = shuffledPlaylist[currentShuffleIndex]
        else
            if action == "next" then
                currentState.currentTrack = (currentState.currentTrack % #playlist) + 1
            else
                currentState.currentTrack = ((currentState.currentTrack - 2 + #playlist) % #playlist) + 1
            end
        end

        local track = playlist[currentState.currentTrack]
        if track and loadSong(track.songPath) then
            playSong(track.songPath)
            currentState.isPlaying = true
            updateProgressDisplay(0, track.duration)
            updateMusicDisplay(track.title, track.artist)
            print("[TRIGGER] Now playing: " .. track.title)
        end

    elseif action == "toggle" then
        if #playlist > 0 then
            if currentState.currentTrack == 0 then
                currentState.currentTrack = 1
                local track = playlist[currentState.currentTrack]
                if loadSong(track.songPath) then
                    playSong(track.songPath)
                    currentState.isPlaying = true
                    updateMusicDisplay(track.title, track.artist)
                    updateProgressDisplay(0, track.duration)
                    print("[TRIGGER] Started playback: " .. track.title)
                end
            else
                if current_sfx_playing then
                    obj:stopSFX(current_sfx_playing)
                    current_sfx_playing = nil
                    currentState.isPlaying = false
                    updateProgressDisplay(songTimer, getCurrentTrackDuration())
                    print("[TRIGGER] Paused playback")
                else
                    local track = playlist[currentState.currentTrack]
                    if loadSong(track.songPath) then
                        playSong(track.songPath)
                        currentState.isPlaying = true
                        print("[TRIGGER] Resumed playback: " .. track.title)
                    end
                end
                updateMusicDisplay(
                    playlist[currentState.currentTrack].title,
                    playlist[currentState.currentTrack].artist
                )
            end
        end
    elseif action == "shuffle" then
        isShuffled = not isShuffled
        if isShuffled then
            shufflePlaylist()
        end
        guihooks.message(isShuffled and "Shuffle: On" or "Shuffle: Off", 2)
    end
end

playNextTrack = function()
    if currentState.isPlaying then
        handleMusicControls("next")
    end
end

updateUI = function()
    if screenMaterialName then
        htmlTexture.call(screenMaterialName, string.format([[
            try {
                currentIndex = %d;
                if (typeof updateSelection === 'function') {
                    updateSelection();
                }
            } catch(e) {
                console.error("Error in updateSelection:", e);
            }
        ]], currentState.selectedIndex - 1))
    end
end

moveVertical = function(direction)
    local newIndex = currentState.selectedIndex + direction
    if newIndex >= 1 and newIndex <= 5 then
        currentState.selectedIndex = newIndex
        updateUI()
    end
end

-- Function to monitor changes in electrical values
local function checkTriggerInputs()
    -- Check menuNav value
    if electrics.values.menuNav ~= lastMenuNav then
        print("[TRIGGER PRESSED] menuNav changed from " .. tostring(lastMenuNav) .. " to " .. tostring(electrics.values.menuNav))
        lastMenuNav = electrics.values.menuNav
    end
    
    -- Check menuSelect value
    if electrics.values.menuSelect ~= lastMenuSelect then
        print("[TRIGGER PRESSED] menuSelect changed from " .. tostring(lastMenuSelect) .. " to " .. tostring(electrics.values.menuSelect))
        lastMenuSelect = electrics.values.menuSelect
    end
    
    -- Check menuVertical value
    if electrics.values.menuVertical ~= lastMenuVertical then
        print("[TRIGGER PRESSED] menuVertical changed from " .. tostring(lastMenuVertical) .. " to " .. tostring(electrics.values.menuVertical))
        lastMenuVertical = electrics.values.menuVertical
    end
end

local function updateGFX(dt)
    -- Monitor trigger inputs
    local currentTime = os.clock()
    if currentTime - lastTime >= debugInterval then
        lastTime = currentTime
        checkTriggerInputs()
    end

    -- Add direct keyboard control for testing
    directButtons(dt)

    -- Check ignition state first
    if electrics.values.ignitionLevel == 0 then
        -- Stop any playing music if ignition is off
        if current_sfx_playing then
            obj:stopSFX(current_sfx_playing)
            current_sfx_playing = nil
            currentState.isPlaying = false
            songTimer = 0
            updateMusicDisplay("Select a song", " ")
            updateProgressDisplay(0, 0)  -- Reset progress
        end
        return  -- Exit the function early if ignition is off
    end

    -- Handle input with delay
    local currentTime = os.clock()
    if currentTime - currentState.lastInputTime >= currentState.inputDelay then
        -- Process menuNav input for music navigation
        if electrics.values.menuNav ~= 0 then
            local direction = electrics.values.menuNav > 0 and 1 or -1
            print("[TRIGGER] Processing menuNav = " .. electrics.values.menuNav .. ", direction = " .. direction)
            
            -- Process navigation action directly
            if direction > 0 then
                handleMusicControls("next")
            else
                handleMusicControls("previous")
            end
            
            electrics.values.menuNav = 0
            currentState.lastInputTime = currentTime
        end
        
        -- Process menuSelect input for play/pause
        if electrics.values.menuSelect > 0 then
            print("[TRIGGER] Processing menuSelect = " .. electrics.values.menuSelect)
            handleMusicControls("toggle")
            electrics.values.menuSelect = 0
            currentState.lastInputTime = currentTime
        end
        
        -- Handle vertical menu navigation
        if electrics.values.menuVertical ~= 0 then
            print("[TRIGGER] Processing menuVertical = " .. electrics.values.menuVertical)
            moveVertical(electrics.values.menuVertical)
            electrics.values.menuVertical = 0
            currentState.lastInputTime = currentTime
        end
    end

    updateTimer = updateTimer + dt
    progressUpdateTimer = progressUpdateTimer + dt
    
    -- If a song is selected and playing, update progress every second
    if currentState.currentTrack > 0 then
        if currentState.isPlaying then
            songTimer = songTimer + dt
            
            -- Update progress display every second
            if progressUpdateTimer >= PROGRESS_UPDATE_INTERVAL then
                local currentDuration = getCurrentTrackDuration()
                updateProgressDisplay(songTimer, currentDuration)
                progressUpdateTimer = 0  -- Reset the timer
            end
            
            -- Check if song is finished
            if songTimer >= getCurrentTrackDuration() then
                songTimer = 0
                playNextTrack()
            end
        end
    end
    
    -- Adjust currently playing sound's volume
    if current_sfx_playing then
        local volume = (electrics.values.Volume or 35) / 200
        obj:setVolumePitch(current_sfx_playing, volume, 1)
    end

    if updateTimer > invFPS and playerInfo.anyPlayerSeated then
        updateTimer = 0

        -- Update the time display
        local time = os.date("%I:%M %p")
        if screenMaterialName then
            htmlTexture.call(screenMaterialName, string.format([[
                (function() {
                    try {
                        var timeElement = document.querySelector('.time');
                        if (timeElement) {
                            timeElement.textContent = '%s';
                        }
                    } catch(e) {
                        console.error("Error updating time:", e);
                    }
                })();
            ]], time))
        end
    end
end

local function init(jbeamData)
    -- Initialize electrical values for menu controls
    electrics.values.menuNav = 0
    electrics.values.menuSelect = 0
    electrics.values.menuVertical = 0
    
    -- Initialize debug tracking variables
    lastMenuNav = 0
    lastMenuSelect = 0
    lastMenuVertical = 0
    
    -- Debug print vehicle controller info
    print("[TRIGGER] Starting interactive_screen_trx2 controller")
    print("[TRIGGER] Monitoring trigger inputs - check log for [TRIGGER PRESSED] messages")

    -- Find sound node
    for v, node in pairs(v.data.nodes) do
        if node.name == "dsh1" then
            soundNode = v
            print("[TRIGGER] Found sound node: " .. v)
            break
        end
    end

    -- Set up screen with higher resolution for vertical layout
    screenMaterialName = jbeamData.screenMaterialName or "@sdd_trx2_screen"
    htmlFilePath = jbeamData.htmlFilePath or "local://local/vehicles/f150/Screen/screen.html"
    textureWidth = 480  -- Higher width for vertical screen
    textureHeight = 800 -- Higher height for vertical screen
    textureFPS = jbeamData.textureFPS or 30

    print("[TRIGGER] Creating HTML texture: " .. screenMaterialName)
    print("[TRIGGER] HTML file path: " .. htmlFilePath)
    print("[TRIGGER] Texture dimensions: " .. textureWidth .. "x" .. textureHeight)
    
    htmlTexture.create(screenMaterialName, htmlFilePath, textureWidth, textureHeight, textureFPS, "automatic")
    
    -- Initialize shuffle and timer states
    isShuffled = true  -- Set shuffle to true by default
    shufflePlaylist()
    songTimer = 0
    
    -- Initialize UI state
    updateUI()
    
    -- Initial song state
    updateMusicDisplay("Select a song", " ")
    updateProgressDisplay(0, 0)
    
    -- Debug print
    print("[TRIGGER] Controller initialized successfully")
    guihooks.message("Trigger debugging enabled - Press triggers to see debug output", 5)
end

local function reset()
    -- Store currently playing song info before reset
    local wasPlaying = currentState.isPlaying
    local currentTrack = currentState.currentTrack
    local currentSong = current_sfx_playing
    
    print("[TRIGGER] Resetting controller. Was playing: " .. tostring(wasPlaying))
    
    -- Clear stopped songs but preserve currently playing one
    for song_dir, sfx in pairs(sfx_table) do
        if sfx and sfx ~= current_sfx_playing then
            obj:stopSFX(sfx)
            obj:deleteSFXSource(sfx)
            sfx_table[song_dir] = nil
        end
    end
    
    progressUpdateTimer = 0

    -- If a song was playing, maintain its state
    if wasPlaying and currentSong then
        -- Keep current song state
        print("[TRIGGER] Maintaining current song state")
        return
    else
        -- Reset everything if no song was playing
        print("[TRIGGER] Full reset - no song was playing")
        sfx_table = {}
        current_sfx_playing = nil
        play_song_dir = nil
        songTimer = 0
        currentState.isPlaying = false
        currentState.currentTrack = 0
        updateProgressDisplay(0, 0)
        currentState.selectedIndex = 1
        updateMusicDisplay("Select a song", " ")
        updateUI()
    end
end

local function destroy()
    -- Clean up all SFX sources
    print("[TRIGGER] Destroying controller")
    for _, sfx in pairs(sfx_table) do
        if sfx then
            obj:stopSFX(sfx)
            obj:deleteSFXSource(sfx)
        end
    end
    sfx_table = {}
    current_sfx_playing = nil
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.destroy = destroy

return M