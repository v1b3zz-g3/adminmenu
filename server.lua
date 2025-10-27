-- Continue server.lua

QBCore.Functions.CreateCallback('rx_reports:server:blockPlayer', function(source, cb, playerId, reason, duration)
    if not HasPermission(source, 'blockPlayers') then cb(false) return end
    
    local staffIdentifier = GetPlayerIdentifier(source)
    local staffName = GetPlayerName(source)
    local targetPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not targetPlayer then cb(false) return end
    
    local targetIdentifier = targetPlayer.PlayerData.citizenid
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    local isPermanent = duration <= 0 and 1 or 0
    local expiresAt = isPermanent and nil or os.time() + (duration * 24 * 60 * 60)
    
    MySQL.insert('INSERT INTO rx_player_blocks (player_identifier, player_name, reason, blocked_by, blocked_by_name, duration_days, is_permanent, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))',
        {targetIdentifier, targetName, reason, staffIdentifier, staffName, duration, isPermanent, expiresAt}, function(blockId)
        if blockId then
            if Config.Discord.events.playerBlocked then
                SendDiscordLog(
                    '🚫 Player Blocked',
                    string.format('**Player:** %s\n**Blocked by:** %s\n**Reason:** %s\n**Duration:** %s', 
                        targetName, staffName, reason, isPermanent and 'Permanent' or duration .. ' days'),
                    Config.Discord.colors.playerBlocked,
                    {
                        {name = 'Player', value = targetName, inline = true},
                        {name = 'Staff Member', value = staffName, inline = true},
                        {name = 'Reason', value = reason, inline = false}
                    }
                )
            end
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:unblockPlayer', function(source, cb, playerId)
    if not HasPermission(source, 'blockPlayers') then cb(false) return end
    
    local staffIdentifier = GetPlayerIdentifier(source)
    local targetPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not targetPlayer then cb(false) return end
    
    local targetIdentifier = targetPlayer.PlayerData.citizenid
    
    MySQL.update('UPDATE rx_player_blocks SET is_active = 0, unblocked_at = NOW(), unblocked_by = ? WHERE player_identifier = ? AND is_active = 1',
        {staffIdentifier, targetIdentifier}, function(affectedRows)
        if affectedRows > 0 then
            if Config.Discord.events.playerUnblocked then
                SendDiscordLog(
                    '✅ Player Unblocked',
                    string.format('**Player:** %s\n**Unblocked by:** %s', 
                        targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname, GetPlayerName(source)),
                    Config.Discord.colors.playerUnblocked
                )
            end
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:addNote', function(source, cb, playerId, note)
    if not HasPermission(source, 'addNotes') then cb(false) return end
    
    local staffIdentifier = GetPlayerIdentifier(source)
    local staffName = GetPlayerName(source)
    local targetPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not targetPlayer then cb(false) return end
    
    local targetIdentifier = targetPlayer.PlayerData.citizenid
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    
    MySQL.insert('INSERT INTO rx_player_notes (player_identifier, player_name, note, created_by, created_by_name) VALUES (?, ?, ?, ?, ?)',
        {targetIdentifier, targetName, note, staffIdentifier, staffName}, function(noteId)
        if noteId then
            local noteData = {
                id = noteId,
                player_identifier = targetIdentifier,
                player_name = targetName,
                note = note,
                created_by = staffIdentifier,
                created_by_name = staffName,
                created_at = os.time()
            }
            
            if Config.Discord.events.noteAdded then
                SendDiscordLog(
                    '📝 Note Added',
                    string.format('**Player:** %s\n**Added by:** %s\n**Note:** %s', targetName, staffName, note),
                    Config.Discord.colors.noteAdded
                )
            end
            
            cb(true, noteData)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:deleteNote', function(source, cb, noteId)
    if not HasPermission(source, 'addNotes') then cb(false) return end
    
    MySQL.query('DELETE FROM rx_player_notes WHERE id = ?', {noteId}, function(affectedRows)
        cb(affectedRows > 0)
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getPlayerNotes', function(source, cb, playerId)
    if not HasPermission(source, 'viewNotes') then cb({}) return end
    
    local targetPlayer = QBCore.Functions.GetPlayer(playerId)
    if not targetPlayer then cb({}) return end
    
    local targetIdentifier = targetPlayer.PlayerData.citizenid
    
    MySQL.query('SELECT * FROM rx_player_notes WHERE player_identifier = ? ORDER BY created_at DESC', 
        {targetIdentifier}, function(result)
        cb(result or {})
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:searchPlayers', function(source, cb, query)
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
        if Player then
            local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            if string.find(string.lower(name), string.lower(query)) or string.find(tostring(playerId), query) then
                table.insert(players, {
                    id = playerId,
                    name = name,
                    citizenid = Player.PlayerData.citizenid
                })
            end
        end
    end
    cb(players)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getStaffStats', function(source, cb)
    if not HasPermission(source, 'viewStats') then cb({}) return end
    
    MySQL.query('SELECT * FROM rx_staff_stats ORDER BY tickets_closed DESC, average_rating DESC LIMIT 20', {}, function(result)
        cb(result or {})
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getStaffMessages', function(source, cb, limit)
    if not HasPermission(source, 'staffChat') then cb({}) return end
    
    MySQL.query('SELECT * FROM rx_staff_chat ORDER BY created_at DESC LIMIT ?', {limit}, function(result)
        cb(result or {})
    end)
end)

-- Server Events
RegisterNetEvent('rx_reports:server:executeAction', function(ticketId, action, targetId)
    local source = source
    
    if action.permission and not HasPermission(source, action.permission) then
        return
    end
    
    local staffIdentifier = GetPlayerIdentifier(source)
    local staffName = GetPlayerName(source)
    
    -- Log action
    MySQL.insert('INSERT INTO rx_ticket_actions (ticket_id, action_id, action_label, staff_identifier, staff_name, target_identifier, target_name) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {ticketId, action.id, action.label, staffIdentifier, staffName, targetId and GetPlayerIdentifier(targetId) or nil, targetId and GetPlayerName(targetId) or nil})
    
    -- Execute action
    if action.id == 'teleport_to_player' then
        if targetId then
            local targetPed = GetPlayerPed(targetId)
            local coords = GetEntityCoords(targetPed)
            TriggerClientEvent('rx_reports:client:teleportToPlayer', source, coords)
        end
    elseif action.id == 'bring_player' then
        if targetId then
            local staffPed = GetPlayerPed(source)
            local coords = GetEntityCoords(staffPed)
            SetEntityCoords(GetPlayerPed(targetId), coords.x, coords.y, coords.z)
            TriggerClientEvent('rx_reports:client:bringPlayer', source, targetId)
        end
    elseif action.id == 'freeze_player' then
        if targetId then
            TriggerClientEvent('rx_reports:client:freezePlayer', targetId, true)
        end
    elseif action.id == 'screenshot' then
        if targetId and Config.Screenshot.enabled then
            TriggerClientEvent('rx_reports:client:takeScreenshot', targetId)
        end
    elseif action.id == 'warn_player' then
        if targetId then
            -- Integrate with your warning system here
            -- Example: exports['warn_system']:WarnPlayer(targetId, reason)
        end
    elseif action.id == 'spectate' then
        if targetId then
            -- Integrate with your admin spectate system here
        end
    elseif action.id == 'check_inventory' then
        if targetId then
            -- Integrate with your inventory system here
            -- Example: TriggerClientEvent('inventory:client:OpenInventory', source, targetId)
        end
    end
end)

RegisterNetEvent('rx_reports:server:sendStaffMessage', function(message, isBroadcast)
    local source = source
    
    if not HasPermission(source, 'staffChat') then return end
    
    local identifier = GetPlayerIdentifier(source)
    local senderName = GetPlayerName(source)
    
    MySQL.insert('INSERT INTO rx_staff_chat (sender_identifier, sender_name, message, is_broadcast) VALUES (?, ?, ?, ?)',
        {identifier, senderName, message, isBroadcast and 1 or 0}, function(messageId)
        if messageId then
            local messageData = {
                id = messageId,
                sender_identifier = identifier,
                sender_name = senderName,
                message = message,
                is_broadcast = isBroadcast,
                created_at = os.time()
            }
            
            -- Broadcast to all staff
            for _, player in pairs(QBCore.Functions.GetPlayers()) do
                if HasPermission(player, 'staffChat') then
                    TriggerClientEvent('rx_reports:client:staffMessage', player, messageData)
                end
            end
        end
    end)
end)

RegisterNetEvent('rx_reports:server:screenshotUploaded', function(url)
    local source = source
    -- Handle screenshot URL - could store in ticket actions or send to Discord
    print('Screenshot uploaded: ' .. url)
end)

-- Auto-close old tickets
CreateThread(function()
    if Config.AutoCloseTicketsAfter > 0 then
        while true do
            Wait(3600000) -- Check every hour
            
            local hours = Config.AutoCloseTicketsAfter
            MySQL.update('UPDATE rx_tickets SET status = ?, closed_at = NOW() WHERE status != ? AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)',
                {'closed', 'closed', hours})
        end
    end
end)

-- Exports
exports('CreateTicket', function(formId, reporterId, reportedId, formData, priority)
    local reporter = QBCore.Functions.GetPlayer(reporterId)
    if not reporter then return false end
    
    local ticketNumber = GenerateTicketNumber()
    local reporterIdentifier = reporter.PlayerData.citizenid
    local reporterName = reporter.PlayerData.charinfo.firstname .. ' ' .. reporter.PlayerData.charinfo.lastname
    
    local reportedIdentifier = nil
    local reportedName = nil
    
    if reportedId then
        local reported = QBCore.Functions.GetPlayer(reportedId)
        if reported then
            reportedIdentifier = reported.PlayerData.citizenid
            reportedName = reported.PlayerData.charinfo.firstname .. ' ' .. reported.PlayerData.charinfo.lastname
        end
    end
    
    MySQL.insert('INSERT INTO rx_tickets (ticket_number, form_id, reporter_identifier, reporter_name, reported_identifier, reported_name, priority, status, form_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {ticketNumber, formId, reporterIdentifier, reporterName, reportedIdentifier, reportedName, priority or 'medium', 'open', json.encode(formData)},
        function(ticketId)
            return ticketId ~= nil
        end)
end)

exports('AddNote', function(playerId, note, staffId)
    local player = QBCore.Functions.GetPlayer(playerId)
    local staff = QBCore.Functions.GetPlayer(staffId)
    
    if not player or not staff then return false end
    
    local playerIdentifier = player.PlayerData.citizenid
    local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    local staffIdentifier = staff.PlayerData.citizenid
    local staffName = staff.PlayerData.charinfo.firstname .. ' ' .. staff.PlayerData.charinfo.lastname
    
    MySQL.insert('INSERT INTO rx_player_notes (player_identifier, player_name, note, created_by, created_by_name) VALUES (?, ?, ?, ?, ?)',
        {playerIdentifier, playerName, note, staffIdentifier, staffName},
        function(noteId)
            return noteId ~= nil
        end)
end)

exports('BlockPlayer', function(playerId, reason, duration, staffId)
    local player = QBCore.Functions.GetPlayer(playerId)
    local staff = QBCore.Functions.GetPlayer(staffId)
    
    if not player or not staff then return false end
    
    local playerIdentifier = player.PlayerData.citizenid
    local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    local staffIdentifier = staff.PlayerData.citizenid
    local staffName = staff.PlayerData.charinfo.firstname .. ' ' .. staff.PlayerData.charinfo.lastname
    local isPermanent = duration <= 0 and 1 or 0
    local expiresAt = isPermanent and nil or os.time() + (duration * 24 * 60 * 60)
    
    MySQL.insert('INSERT INTO rx_player_blocks (player_identifier, player_name, reason, blocked_by, blocked_by_name, duration_days, is_permanent, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))',
        {playerIdentifier, playerName, reason, staffIdentifier, staffName, duration, isPermanent, expiresAt},
        function(blockId)
            return blockId ~= nil
        end)
end)

print('^2[RX Reports]^7 Resource loaded successfully!')