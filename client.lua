local QBCore = exports['qb-core']:GetCoreObject()
local currentTicket = nil
local isUIOpen = false
local playerData = {}

-- Initialize
CreateThread(function()
    Wait(1000)
    playerData = QBCore.Functions.GetPlayerData()
end)

-- Update player data on job change
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    playerData.job = job
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    playerData = data
end)

-- Helper Functions
local function HasPermission(permission)
    if not playerData.job then return false end
    
    local permissionList = Config.Permissions[permission]
    if not permissionList then return false end
    
    for _, role in ipairs(permissionList) do
        if playerData.job.name == role then
            return true
        end
    end
    
    return false
end

local function ShowNotification(title, message, type, duration)
    QBCore.Functions.Notify(message, type, duration or Config.NotificationDuration)
end

local function GetOnlinePlayers()
    local players = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= PlayerPedId() then
            local serverId = GetPlayerServerId(player)
            local playerName = GetPlayerName(player)
            table.insert(players, {
                id = serverId,
                name = playerName
            })
        end
    end
    return players
end

local function OpenUI(type, data)
    if isUIOpen then return end
    
    isUIOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openUI',
        type = type,
        data = data or {}
    })
end

local function CloseUI()
    if not isUIOpen then return end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeUI'
    })
end

-- Commands
RegisterCommand(Config.Commands.playerReport, function()
    QBCore.Functions.TriggerCallback('rx_reports:server:isBlocked', function(isBlocked, blockData)
        if isBlocked then
            local expiryText = blockData.is_permanent and 'Permanent' or os.date('%Y-%m-%d %H:%M', blockData.expires_at)
            ShowNotification('Blocked', string.format('You are blocked from submitting reports. Reason: %s. Expires: %s', blockData.reason, expiryText), 'error')
            return
        end
        
        QBCore.Functions.TriggerCallback('rx_reports:server:getPlayerTickets', function(tickets)
            local openCount = 0
            for _, ticket in ipairs(tickets) do
                if ticket.status ~= 'closed' then
                    openCount = openCount + 1
                end
            end
            
            if openCount >= Config.MaxOpenTicketsPerPlayer then
                ShowNotification('Limit Reached', 'You have reached the maximum number of open tickets.', 'error')
                return
            end
            
            OpenUI('player', {
                forms = Config.Forms,
                priorities = Config.Priorities,
                onlinePlayers = GetOnlinePlayers(),
                myTickets = tickets
            })
        end)
    end)
end)

RegisterCommand(Config.Commands.staffDashboard, function()
    if not HasPermission('viewReports') then
        ShowNotification('No Permission', 'You do not have permission to access this.', 'error')
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:getAllTickets', function(tickets)
        QBCore.Functions.TriggerCallback('rx_reports:server:getStaffStats', function(stats)
            OpenUI('staff', {
                tickets = tickets,
                stats = stats,
                actions = Config.Actions,
                quickResponses = Config.QuickResponses,
                permissions = {
                    claim = HasPermission('claimReports'),
                    close = HasPermission('closeReports'),
                    delete = HasPermission('deleteReports'),
                    block = HasPermission('blockPlayers'),
                    notes = HasPermission('viewNotes'),
                    addNotes = HasPermission('addNotes'),
                    teleport = HasPermission('teleportActions'),
                    freeze = HasPermission('freezeActions'),
                    warn = HasPermission('warnActions')
                }
            })
        end)
    end)
end)

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('createTicket', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:createTicket', function(success, ticketData)
        if success then
            ShowNotification('Success', 'Your report has been submitted successfully.', 'success')
            cb({success = true, ticket = ticketData})
        else
            ShowNotification('Error', 'Failed to submit report.', 'error')
            cb({success = false})
        end
    end, data)
end)

RegisterNUICallback('getOnlinePlayers', function(data, cb)
    cb({players = GetOnlinePlayers()})
end)

RegisterNUICallback('getMyTickets', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:getPlayerTickets', function(tickets)
        cb({tickets = tickets})
    end)
end)

RegisterNUICallback('getAllTickets', function(data, cb)
    if not HasPermission('viewReports') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:getAllTickets', function(tickets)
        cb({success = true, tickets = tickets})
    end)
end)

RegisterNUICallback('getTicketDetails', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:getTicketDetails', function(ticket)
        if ticket then
            cb({success = true, ticket = ticket})
        else
            cb({success = false})
        end
    end, data.ticketId)
end)

RegisterNUICallback('claimTicket', function(data, cb)
    if not HasPermission('claimReports') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:claimTicket', function(success)
        if success then
            ShowNotification('Success', 'Ticket claimed successfully.', 'success')
        end
        cb({success = success})
    end, data.ticketId)
end)

RegisterNUICallback('unclaimTicket', function(data, cb)
    if not HasPermission('claimReports') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:unclaimTicket', function(success)
        if success then
            ShowNotification('Success', 'Ticket unclaimed.', 'success')
        end
        cb({success = success})
    end, data.ticketId)
end)

RegisterNUICallback('closeTicket', function(data, cb)
    if not HasPermission('closeReports') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:closeTicket', function(success)
        if success then
            ShowNotification('Success', 'Ticket closed.', 'success')
        end
        cb({success = success})
    end, data.ticketId, data.reason)
end)

RegisterNUICallback('reopenTicket', function(data, cb)
    if not HasPermission('closeReports') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:reopenTicket', function(success)
        if success then
            ShowNotification('Success', 'Ticket reopened.', 'success')
        end
        cb({success = success})
    end, data.ticketId)
end)

RegisterNUICallback('sendMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:sendMessage', function(success, messageData)
        if success then
            cb({success = true, message = messageData})
        else
            cb({success = false})
        end
    end, data.ticketId, data.message, data.isQuickResponse or false)
end)

RegisterNUICallback('executeAction', function(data, cb)
    local action = data.action
    
    if action.permission and not HasPermission(action.permission) then
        cb({success = false, message = 'No permission'})
        return
    end
    
    TriggerServerEvent('rx_reports:server:executeAction', data.ticketId, action, data.targetId)
    cb({success = true})
end)

RegisterNUICallback('rateTicket', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:rateTicket', function(success)
        if success then
            ShowNotification('Thank You', 'Your feedback has been submitted.', 'success')
        end
        cb({success = success})
    end, data.ticketId, data.rating, data.comment)
end)

RegisterNUICallback('blockPlayer', function(data, cb)
    if not HasPermission('blockPlayers') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:blockPlayer', function(success)
        if success then
            ShowNotification('Success', 'Player blocked successfully.', 'success')
        end
        cb({success = success})
    end, data.playerId, data.reason, data.duration)
end)

RegisterNUICallback('unblockPlayer', function(data, cb)
    if not HasPermission('blockPlayers') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:unblockPlayer', function(success)
        if success then
            ShowNotification('Success', 'Player unblocked.', 'success')
        end
        cb({success = success})
    end, data.playerId)
end)

RegisterNUICallback('addNote', function(data, cb)
    if not HasPermission('addNotes') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:addNote', function(success, noteData)
        if success then
            ShowNotification('Success', 'Note added successfully.', 'success')
            cb({success = true, note = noteData})
        else
            cb({success = false})
        end
    end, data.playerId, data.note)
end)

RegisterNUICallback('deleteNote', function(data, cb)
    if not HasPermission('addNotes') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:deleteNote', function(success)
        if success then
            ShowNotification('Success', 'Note deleted.', 'success')
        end
        cb({success = success})
    end, data.noteId)
end)

RegisterNUICallback('getPlayerNotes', function(data, cb)
    if not HasPermission('viewNotes') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:getPlayerNotes', function(notes)
        cb({success = true, notes = notes})
    end, data.playerId)
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    QBCore.Functions.TriggerCallback('rx_reports:server:searchPlayers', function(players)
        cb({players = players})
    end, data.query)
end)

RegisterNUICallback('getStaffStats', function(data, cb)
    if not HasPermission('viewStats') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:getStaffStats', function(stats)
        cb({success = true, stats = stats})
    end)
end)

RegisterNUICallback('sendStaffMessage', function(data, cb)
    if not HasPermission('staffChat') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    TriggerServerEvent('rx_reports:server:sendStaffMessage', data.message, data.isBroadcast or false)
    cb({success = true})
end)

RegisterNUICallback('getStaffMessages', function(data, cb)
    if not HasPermission('staffChat') then
        cb({success = false, message = 'No permission'})
        return
    end
    
    QBCore.Functions.TriggerCallback('rx_reports:server:getStaffMessages', function(messages)
        cb({success = true, messages = messages})
    end, data.limit or 50)
end)

-- Client Events
RegisterNetEvent('rx_reports:client:ticketUpdated', function(ticketData)
    if isUIOpen then
        SendNUIMessage({
            action = 'ticketUpdated',
            ticket = ticketData
        })
    end
    
    -- Check if this ticket belongs to the player
    if ticketData.reporter_identifier == playerData.citizenid then
        if ticketData.status == 'claimed' and ticketData.claimed_by then
            ShowNotification('Report Update', 'A staff member is now handling your report.', 'info')
        elseif ticketData.status == 'closed' then
            ShowNotification('Report Closed', 'Your report has been closed.', 'info')
        end
    end
end)

RegisterNetEvent('rx_reports:client:newMessage', function(ticketId, messageData)
    if isUIOpen then
        SendNUIMessage({
            action = 'newMessage',
            ticketId = ticketId,
            message = messageData
        })
    end
    
    -- Notify if message is for player's ticket
    QBCore.Functions.TriggerCallback('rx_reports:server:getTicketDetails', function(ticket)
        if ticket and ticket.reporter_identifier == playerData.citizenid and messageData.sender_identifier ~= playerData.citizenid then
            ShowNotification('New Message', 'You have received a message on your report.', 'info')
        end
    end, ticketId)
end)

RegisterNetEvent('rx_reports:client:newTicket', function(ticketData)
    if HasPermission('viewReports') then
        ShowNotification('New Report', string.format('New %s report submitted.', ticketData.priority), 'warning')
        
        if isUIOpen then
            SendNUIMessage({
                action = 'newTicket',
                ticket = ticketData
            })
        end
    end
end)

RegisterNetEvent('rx_reports:client:staffMessage', function(messageData)
    if HasPermission('staffChat') and isUIOpen then
        SendNUIMessage({
            action = 'newStaffMessage',
            message = messageData
        })
    end
end)

RegisterNetEvent('rx_reports:client:teleportToPlayer', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    ShowNotification('Teleported', 'You have been teleported to the player.', 'success')
end)

RegisterNetEvent('rx_reports:client:bringPlayer', function(targetId)
    -- Server will handle the actual teleport
    ShowNotification('Success', 'Player has been brought to you.', 'success')
end)

RegisterNetEvent('rx_reports:client:freezePlayer', function(freeze)
    FreezeEntityPosition(PlayerPedId(), freeze)
    if freeze then
        ShowNotification('Frozen', 'You have been frozen by staff.', 'warning')
    else
        ShowNotification('Unfrozen', 'You have been unfrozen by staff.', 'success')
    end
end)

RegisterNetEvent('rx_reports:client:takeScreenshot', function()
    exports['screenshot-basic']:requestScreenshotUpload(Config.Screenshot.webhook, 'files[]', function(data)
        local resp = json.decode(data)
        if resp and resp.attachments and resp.attachments[1] then
            TriggerServerEvent('rx_reports:server:screenshotUploaded', resp.attachments[1].proxy_url)
        end
    end)
end)

-- Keybinds (optional)
-- RegisterKeyMapping(Config.Commands.playerReport, 'Open Report System', 'keyboard', '')

-- Exports
exports('OpenReportUI', function()
    ExecuteCommand(Config.Commands.playerReport)
end)

exports('OpenStaffDashboard', function()
    ExecuteCommand(Config.Commands.staffDashboard)
end)

exports('HasPermission', HasPermission)