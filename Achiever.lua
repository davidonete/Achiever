


local _G, _ = _G or getfenv()

ACHIEVER_ADDON_NAME = 'Achiever'
local ACHIEVER_ADDON_VERSION = '0.0.2.0'
local ACHIEVER_ADDON_CHANNEL = 'ACHIEVER_CHANNEL'
local ACHIEVER_REQUESTED_DATA = false
local ACHIEVER_STARTED = false

local function debug(msg)
    if achieverDBpc.debug == "enabled" then
	    DEFAULT_CHAT_FRAME:AddMessage('|cffc663fcDEBUG: |cffff55ff'.. (msg or 'nil'))
    end
end
local function warn(msg)
	DEFAULT_CHAT_FRAME:AddMessage('|cf3f3f66cWARN: |cffff55ff'.. (msg or 'nil'))
end

local function toggleDebug()
    if achieverDBpc.debug == "enabled" then
        achieverDBpc.debug = "disabled"
        DEFAULT_CHAT_FRAME:AddMessage('Achiever DEBUG mode disabled')
    else
        achieverDBpc.debug = "enabled"
        DEFAULT_CHAT_FRAME:AddMessage('Achiever DEBUG mode enabled')
    end
end

SLASH_ACHIEVERDEBUG1 = "/acdebug"
SlashCmdList.ACHIEVERDEBUG = function()
    toggleDebug()
end

Achiever = CreateFrame("Frame")
achieverDBpc = {
    criteria = {},
    achievements = {}
}
SLASH_RELOADUI1 = "/rl"
SlashCmdList.RELOADUI = ReloadUI

local function split(str, sep)
    if sep == nil then
        sep = '%s'
    end

    local res = {}
    local func = function(w)
        table.insert(res, w)
    end

    string.gsub(str, '[^'..sep..']+', func)
    return res
end


Achiever:RegisterEvent("ADDON_LOADED")
Achiever:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
Achiever:RegisterEvent("PLAYER_ENTERING_WORLD")
Achiever:RegisterEvent("VARIABLES_LOADED")


Achiever.version = ACHIEVER_ADDON_VERSION
Achiever.channel = ACHIEVER_ADDON_CHANNEL
Achiever.channelIndex = nil

Achiever.hookChatFrame = function(self, frame)
    if (not frame) then
        warn('Achiever failed to hook chat frame')
        return
    end

    local original = frame.AddMessage
    if (original) then
        frame.AddMessage = function(t, message, ...)
            local s, e  = string.find(message, 'ACHI|', 1, true)
            if (s == 1 and e == 5) then
                -- if (ACHIEVER_ADDON_DEBUG) then
                --     debug('hidden achievement server message: ' .. (message or 'nil'))
                -- end
                self:processServerMessage(message)
                return false --hide this message
            end
            original(t, message, unpack(arg))
        end
    else
        warn('failed to hook non-chat frame.')
    end
end

Achiever.achievementFrameSummaryCategorySubscribers = {}

Achiever.processServerMessage = function(self, message)

    local params = split(message, '|')
    if (params[1] == 'ACHI') then
        if (params[2] == 'AC') then
            --debug('server response: new achievement entry ')
            local a = split(params[3], ';')
            local id = tonumber(a[1])
            achieverDB.achievements.data[id] = {}
            achieverDB.achievements.data[id].id = tonumber(id)
            achieverDB.achievements.data[id].faction = tonumber(a[2])
            achieverDB.achievements.data[id].previousId = tonumber(a[3])
            local name = ''
            if (a[4] ~= '_') then name = a[4] end
            achieverDB.achievements.data[id].name = name
            local description = ''
            if (a[5] ~= '_') then description = a[5] end
            achieverDB.achievements.data[id].description = description
            achieverDB.achievements.data[id].categoryId = tonumber(a[6])
            achieverDB.achievements.data[id].points = tonumber(a[7])
            achieverDB.achievements.data[id].order = tonumber(a[8])
            achieverDB.achievements.data[id].flags = tonumber(a[9])
            achieverDB.achievements.data[id].icon = tonumber(a[10])
            local titleReward = ''
            if (a[11] ~= '_') then titleReward = a[11] end
            achieverDB.achievements.data[id].titleReward = titleReward
            achieverDB.achievements.data[id].count = tonumber(a[12])
            achieverDB.achievements.data[id].refAchievement = tonumber(a[13])
            achieverDB.achievements.totalPoints = achieverDB.achievements.totalPoints + tonumber(a[7])

            local n = tonumber(a[14])
            local c = tonumber(a[15])

            local categoryId = tonumber(a[6])
            if (achieverDB.achievements.byCategory[categoryId] == nil) then
                achieverDB.achievements.byCategory[categoryId] = {}
            end
            -- table.insert(achieverDB.achievements.byCategory[categoryId], id)
            achieverDB.achievements.byCategory[categoryId][tonumber(a[8])] = id

            local previousId = tonumber(a[3])
            if (previousId == 0) then previousId = nil end
            if (previousId) then
                achieverDB.achievements.previousById[id] = previousId
                achieverDB.achievements.nextById[previousId] = id
            end

            ACHIEVER_STARTED = true
            
            if (n == c) then
                --debug('loaded achievements from server')
            end

        elseif (params[2] == 'ACV') then
            debug('server response: achievement data version')
            achieverDB.achievements.version = tonumber(params[3])
            ACHIEVER_STARTED = true
        elseif (params[2] == 'CA') then
            --debug('server response: get all categories')
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            achieverDB.categories.data[id] = {}
            achieverDB.categories.data[id].id = tonumber(id)
            achieverDB.categories.data[id].parentId = tonumber(a[2])
            local name = ''
            if (a[3] ~= '_') then name = a[3] end
            achieverDB.categories.data[id].name = name
            achieverDB.categories.data[id].order = tonumber(a[4])
            local n = tonumber(a[5])
            local c = tonumber(a[6])

            local parentId = a[2]
            if (achieverDB.categories.byParent[parentId] == nil) then
                achieverDB.categories.byParent[parentId] = {}
            end
            -- table.insert(achieverDB.categories.byParent[parentId], id)
            achieverDB.categories.byParent[parentId][tonumber(a[4])] = id
            ACHIEVER_STARTED = true

            if (n == c) then
                debug('loaded categories from server')
            end
        elseif (params[2] == 'CAV') then
            debug('server response: criteria data version')
            achieverDB.categories.version = tonumber(params[3])
            ACHIEVER_STARTED = true
        elseif (params[2] == 'CR') then
            --debug('server response: get all criteria')
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            achieverDB.criteria.data[id] = {}
            achieverDB.criteria.data[id].id = tonumber(id)
            achieverDB.criteria.data[id].achievementId = tonumber(a[2])
            achieverDB.criteria.data[id].type = tonumber(a[3])
            achieverDB.criteria.data[id].assetId = tonumber(a[4])
            achieverDB.criteria.data[id].count = tonumber(a[5])
            achieverDB.criteria.data[id].assetId1 = tonumber(a[6])
            achieverDB.criteria.data[id].count1 = tonumber(a[7])
            achieverDB.criteria.data[id].assetId2 = tonumber(a[8])
            achieverDB.criteria.data[id].count2 = tonumber(a[9])
            local name = ''
            if (a[10] ~= '_') then name = a[10] end
            achieverDB.criteria.data[id].name = name
            achieverDB.criteria.data[id].flags = tonumber(a[11])
            achieverDB.criteria.data[id].timedType = tonumber(a[12])
            achieverDB.criteria.data[id].timerStartEvent = tonumber(a[13])
            achieverDB.criteria.data[id].timeLimit = tonumber(a[14])
            achieverDB.criteria.data[id].order = tonumber(a[15])
            local n = tonumber(a[16])
            local c = tonumber(a[17])

            local achievementId = tonumber(a[2])
            if (achieverDB.criteria.byAchievement[achievementId] == nil) then
                achieverDB.criteria.byAchievement[achievementId] = {}
            end
            achieverDB.criteria.byAchievement[achievementId][tonumber(a[15])] = id
            -- table.insert(achieverDB.criteria.byAchievement[achievementId], id)
            ACHIEVER_STARTED = true

            if (n == c) then
                --debug('loaded criteria from server')
            end
        elseif (params[2] == 'CRV') then
            debug('server response: criteria data version')
            achieverDB.criteria.version = tonumber(params[3])
            ACHIEVER_STARTED = true
        elseif (params[2] == 'CH_AC') then
            --debug('server response: char achievements')
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            achieverDBpc.achievements[id] = {}
            achieverDBpc.achievements[id].date = tonumber(a[2])
            ACHIEVER_STARTED = true
        elseif (params[2] == 'CH_CR') then
            --debug('server response: char criteria')
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            achieverDBpc.criteria[id] = {}
            achieverDBpc.criteria[id].counter = tonumber(a[2])
            achieverDBpc.criteria[id].date = tonumber(a[3])
            ACHIEVER_STARTED = true
        elseif (params[2] == 'AE') then
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            if (not achieverDBpc.achievements) then achieverDBpc.achievements = {} end
            achieverDBpc.achievements[id] = {}
            achieverDBpc.achievements[id].date = tonumber(a[2])
            AchievementFrameAchievements_OnEvent(_G['AchievementFrameAchievements'], 'ACHIEVEMENT_EARNED', id)
            for k, v in pairs(self.achievementFrameSummaryCategorySubscribers) do
                AchievementFrameSummaryCategory_OnEvent(v, 'ACHIEVEMENT_EARNED', id)
            end
            AchievementFrameSummary_Update()
            -- AchievementFrameComparison_OnEvent(_G['AchievementFrameComparison'], 'ACHIEVEMENT_EARNED', id)
            debug("ACHIEVEMENT EARNED " .. achieverDB.achievements.data[id].name)
            AlertFrame_ShowAchievementEarned(id)
            ACHIEVER_STARTED = true
        elseif (params[2] == 'ACU') then
            local a = split(params[3], ";")
            local id = tonumber(a[1])
            if (not achieverDBpc.criteria) then achieverDBpc.criteria = {} end
            achieverDBpc.criteria[id] = {}
            achieverDBpc.criteria[id].achievementId = tonumber(a[2])
            achieverDBpc.criteria[id].counter = tonumber(a[3])
            achieverDBpc.criteria[id].date = tonumber(a[4])
            AchievementFrameAchievements_OnEvent(_G['AchievementFrameAchievements'], 'CRITERIA_UPDATE', id)
            AchievementFrameStats_OnEvent(_G['AchievementFrameStats'], 'CRITERIA_UPDATE', id)
            debug("ACHIEVEMENT CRITERIA UPDATE ".. achieverDB.achievements.data[tonumber(a[2])].name .. '[' .. achieverDB.criteria.data[id].name .. ']')
            ACHIEVER_STARTED = true
        else
            warn('server response: unhandled ' .. params[2])
        end
    end
end

Achiever.apiEnableDataSend = function(self, version)

    debug('request to enable sending achievement info, ' .. version)
    SendChatMessage('.achievements enableAchiever ' .. version)
    --SendChatMessage('!achievements getCategoties ' .. version, 'CHANNEL', nil, Achiever.channelIndex)
end
Achiever.apiRequestCategoryInfo = function(self, version)

    --debug('requested information about categories from server, ' .. version)
    SendChatMessage('.achievements getCategoties ' .. version)
    --SendChatMessage('!achievements getCategoties ' .. version, 'CHANNEL', nil, Achiever.channelIndex)
end
Achiever.apiRequestAchievementInfo = function(self, version)

    --debug('requested information about achievements from server, ' .. version)
    SendChatMessage('.achievements getAchievements ' .. version)
    --SendChatMessage('!achievements getAchievements ' .. version, 'CHANNEL', nil, Achiever.channelIndex)
end
Achiever.apiRequestCriteriaInfo = function(self, version)

    --debug('requested information about criteria from server, ' .. version)
    SendChatMessage('.achievements getCriteria ' .. version)
    --SendChatMessage('!achievements getCriteria ' .. version, 'CHANNEL', nil, Achiever.channelIndex)
end
Achiever.apiRequestCharacterCriteria = function(self)
    debug('requested character criteria progress from server')
    achieverDBpc.criteria = {}
    SendChatMessage('.achievements getCharacterCriteria')
    --SendChatMessage('!achievements getCharacterCriteria', 'CHANNEL', nil, Achiever.channelIndex)
end
Achiever.apiRequestCharacterAchievements = function(self)
    debug('requested character achievements from server')
    achieverDBpc.achievements = {}
    SendChatMessage('.achievements getCharacterAchievements')
    --SendChatMessage('.achievements getCharacterAchievements', 'CHANNEL', nil, Achiever.channelIndex)
end

Achiever.getChannelIndex = function(self, channelName)
    local lastVal = 0
    local chanList = { GetChannelList() }
    local result = nil
    for _, value in next, chanList do
        if value == channelName then
            result = lastVal
            break
        end
        lastVal = value
    end
    return result
end

Achiever.joinChannel = function(self)
    self.channelIndex = self:getChannelIndex(self.channel)
    if (self.channelIndex == nil) then
        JoinChannelByName(self.channel)
    else
        --self:startup()
    end
end

Achiever.startup = function(self)
    if (ACHIEVER_STARTED == true) then
        return
    end

    local factionGroup, localedFaction = UnitFactionGroup("player");

    if (not achieverDBpc.debug) then achieverDBpc.debug = "disabled" end
    if (not achieverDBpc.version) then achieverDBpc.version = 0 end

    if (factionGroup == "Alliance") then
        if (not achieverDB.Alliance) then
            achieverDB.Alliance = true
            achieverDB.Horde = false
            achieverDB = nil
        end
        --if (ACHIEVER_STARTED == false) then achieverDB = achieverDB.Alliance end
    end
    if (factionGroup == "Horde") then
        if (not achieverDB.Horde) then
            achieverDB.Horde = true
            achieverDB.Alliance = false
            achieverDB = nil
        end
        --if (ACHIEVER_STARTED == false) then achieverDB = achieverDB.Horde end
    end
    -- always reload data for now
    achieverDB = nil
    if (not achieverDB) then achieverDB = {} end
    if (not achieverDB.categories) then
        achieverDB.categories = { version = achieverDBpc.version }
        achieverDB.categories.data = {}
        achieverDB.categories.byParent = {}
    end
    if (not achieverDB.achievements) then
        achieverDB.achievements = { version = achieverDBpc.version }
        achieverDB.achievements.totalPoints = 0
        achieverDB.achievements.data = {}
        achieverDB.achievements.byCategory = {}
        achieverDB.achievements.nextById = {}
        achieverDB.achievements.previousById = {}
    end
    if (not achieverDB.criteria) then
        achieverDB.criteria = { version = achieverDBpc.version }
        achieverDB.criteria.data = {}
        achieverDB.criteria.byAchievement = {}
    end
    if (not achieverDBpc) then achieverDBpc = {} end
    --self:apiRequestCategoryInfo(achieverDB.categories.version)
    --self:apiRequestAchievementInfo(achieverDB.achievements.version)
    --self:apiRequestCriteriaInfo(achieverDB.criteria.version)
    --self:apiRequestCharacterCriteria()
    --self:apiRequestCharacterAchievements()
    debug('request data to UI ' .. achieverDBpc.version)
    self:apiEnableDataSend(achieverDBpc.version)
    -- ACHIEVER_STARTED = true
end



Achiever:SetScript("OnEvent", function()
    if (not event) then
        warn('OnEvent with no event')
		return
	elseif (event == "ADDON_LOADED" and arg1 == ACHIEVER_ADDON_NAME) then
        debug('ADDON_LOADED')
        Achiever:hookChatFrame(ChatFrame1)
        Achiever:startup()
        --Achiever:joinChannel()
        -- AchievementFrameCategories_OnEvent(AchievementFrameCategories, "ADDON_LOADED", ACHIEVER_ADDON_NAME)
        -- AchievementFrameAchievements_OnEvent(AchievementFrameCategories, "ADDON_LOADED", ACHIEVER_ADDON_NAME)
	elseif (event == 'CHAT_MSG_CHANNEL_LEAVE') then
        debug('OnEvent CHAT_MSG_CHANNEL_LEAVE')
	elseif (event == 'CHAT_MSG_ADDON') then
        debug('OnEvent CHAT_MSG_ADDON')
    elseif (event == 'VARIABLES_LOADED') then
        debug('VARIABLES_LOADED')
        --Achiever:joinChannel()
	--elseif (event == 'CHAT_MSG_CHANNEL_NOTICE') then
	--	if (arg9 == Achiever.channel and arg1 == 'YOU_JOINED') then
	--		Achiever.channelIndex = arg8
	--		debug('just joined chan index ' .. Achiever.channelIndex)
    --        debug('just joined chan name ' .. arg9)
    --        --Achiever:startup()
	--	end
	elseif (event == 'PLAYER_ENTERING_WORLD') then
        --Achiever:joinChannel()
        Achiever:hookChatFrame(ChatFrame1)
        Achiever:startup()
	end
end)

