local QBCore = exports['qb-core']:GetCoreObject()

-- Helper Functions
local function GenerateTicketNumber()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local number = 'TK-'
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        number = number .. string.sub(chars, rand, rand)
    end
    return number
end

local function GetPlayerIdentifier(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.citizenid or nil
end

local function GetPlayerName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return Player and Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname or 'Unknown'
end

local function GetPlayerByIdentifier(identifier)
    return QBCore.Functions.GetPlayerByCitizenId(identifier)
end

local function HasPermission(source, permission)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local permissionList = Config.Permissions[permission]
    if not permissionList then return false end
    
    for _, role in ipairs(permissionList) do
        if Player.PlayerData.job.name == role then
            return true
        end
    end
    
    return false
end

local function SendDiscordLog(title, description, color, fields)
    if not Config.Discord.enabled or not Config.Discord.webhookURL or Config.Discord.webhookURL == '' then
        return
    end
    
    local embed = {
        {
            ['title'] = title,
            ['description'] = description,
            ['color'] = color,
            ['fields'] = fields or {},
            ['footer'] = {
                ['text'] = 'RX Reports System',
            },
            ['timestamp'] = os.date('!%Y-%m-%dT%H:%M:%S')
        }
    }
    
    PerformHttpRequest(Config.Discord.webhookURL, function(err, text, headers) end, 'POST', json.encode({
        username = Config.Discord.botName,
        avatar_url = Config.Discord.botAvatar,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function UpdateStaffStats(identifier, action, value)
    MySQL.query('SELECT * FROM rx_staff_stats WHERE staff_identifier = ?', {identifier}, function(result)
        if result and result[1] then
            local stats = result[1]
            
            if action == 'claim' then
                MySQL.update('UPDATE rx_staff_stats SET tickets_claimed = tickets_claimed + 1, last_active = NOW() WHERE staff_identifier = ?', {identifier})
            elseif action == 'close' then
                MySQL.update('UPDATE rx_staff_stats SET tickets_closed = tickets_closed + 1, last_active = NOW() WHERE staff_identifier = ?', {identifier})
            elseif action == 'rating' then
                local newTotal = stats.total_rating + value
                local newCount = stats.rating_count + 1
                local newAvg = newTotal / newCount
                MySQL.update('UPDATE rx_staff_stats SET total_rating = ?, rating_count = ?, average_rating = ?, last_active = NOW() WHERE staff_identifier = ?', 
                    {newTotal, newCount, newAvg, identifier})
            elseif action == 'response_time' then
                local newTotal = stats.total_response_time + value
                local newCount = stats.response_count + 1
                local newAvg = newTotal / newCount
                MySQL.update('UPDATE rx_staff_stats SET total_response_time = ?, response_count = ?, average_response_time = ?, last_active = NOW() WHERE staff_identifier = ?', 
                    {newTotal, newCount, newAvg, identifier})
            end
        else
            MySQL.insert('INSERT INTO rx_staff_stats (staff_identifier, staff_name, last_active) VALUES (?, ?, NOW())', 
                {identifier, GetPlayerName(GetPlayerByIdentifier(identifier).PlayerData.source)})
        end
    end)
end

-- Callbacks
QBCore.Functions.CreateCallback('rx_reports:server:isBlocked', function(source, cb)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then cb(false) return end
    
    MySQL.query('SELECT * FROM rx_player_blocks WHERE player_identifier = ? AND is_active = 1 AND (is_permanent = 1 OR expires_at > NOW())', 
        {identifier}, function(result)
        if result and result[1] then
            cb(true, result[1])
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:createTicket', function(source, cb, data)
    local identifier = GetPlayerIdentifier(source)
    local playerName = GetPlayerName(source)
    
    if not identifier then 
        cb(false)
        return 
    end
    
    -- Check if blocked
    MySQL.query('SELECT * FROM rx_player_blocks WHERE player_identifier = ? AND is_active = 1 AND (is_permanent = 1 OR expires_at > NOW())', 
        {identifier}, function(blockResult)
        if blockResult and blockResult[1] then
            cb(false)
            return
        end
        
        -- Check open ticket limit
        MySQL.query('SELECT COUNT(*) as count FROM rx_tickets WHERE reporter_identifier = ? AND status != ?', 
            {identifier, 'closed'}, function(countResult)
            if countResult and countResult[1] and countResult[1].count >= Config.MaxOpenTicketsPerPlayer then
                cb(false)
                return
            end
            
            -- Create ticket
            local ticketNumber = GenerateTicketNumber()
            local formData = json.encode(data.formData)
            local reportedIdentifier = data.reportedPlayer and GetPlayerIdentifier(data.reportedPlayer) or nil
            local reportedName = data.reportedPlayer and GetPlayerName(data.reportedPlayer) or nil
            
            MySQL.insert('INSERT INTO rx_tickets (ticket_number, form_id, reporter_identifier, reporter_name, reported_identifier, reported_name, priority, status, form_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                {ticketNumber, data.formId, identifier, playerName, reportedIdentifier, reportedName, data.priority or 'medium', 'open', formData},
                function(ticketId)
                    if ticketId then
                        local ticketData = {
                            id = ticketId,
                            ticket_number = ticketNumber,
                            form_id = data.formId,
                            reporter_identifier = identifier,
                            reporter_name = playerName,
                            reported_identifier = reportedIdentifier,
                            reported_name = reportedName,
                            priority = data.priority or 'medium',
                            status = 'open',
                            form_data = data.formData,
                            created_at = os.time()
                        }
                        
                        -- Notify all staff
                        for _, player in pairs(QBCore.Functions.GetPlayers()) do
                            if HasPermission(player, 'viewReports') then
                                TriggerClientEvent('rx_reports:client:newTicket', player, ticketData)
                            end
                        end
                        
                        -- Discord log
                        if Config.Discord.events.ticketCreated then
                            local formConfig = nil
                            for _, form in ipairs(Config.Forms) do
                                if form.id == data.formId then
                                    formConfig = form
                                    break
                                end
                            end
                            
                            SendDiscordLog(
                                '📋 New Ticket Created',
                                string.format('**Ticket:** %s\n**Reporter:** %s\n**Type:** %s\n**Priority:** %s', 
                                    ticketNumber, playerName, formConfig and formConfig.name or data.formId, data.priority or 'medium'),
                                Config.Discord.colors.ticketCreated,
                                {
                                    {name = 'Ticket ID', value = ticketNumber, inline = true},
                                    {name = 'Reporter', value = playerName, inline = true},
                                    {name = 'Priority', value = data.priority or 'medium', inline = true}
                                }
                            )
                        end
                        
                        cb(true, ticketData)
                    else
                        cb(false)
                    end
                end)
        end)
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getPlayerTickets', function(source, cb)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then cb({}) return end
    
    MySQL.query('SELECT t.*, COUNT(m.id) as message_count FROM rx_tickets t LEFT JOIN rx_ticket_messages m ON t.id = m.ticket_id WHERE t.reporter_identifier = ? GROUP BY t.id ORDER BY t.created_at DESC', 
        {identifier}, function(result)
        if result then
            for i, ticket in ipairs(result) do
                result[i].form_data = json.decode(ticket.form_data)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getAllTickets', function(source, cb)
    if not HasPermission(source, 'viewReports') then cb({}) return end
    
    MySQL.query('SELECT t.*, COUNT(m.id) as message_count FROM rx_tickets t LEFT JOIN rx_ticket_messages m ON t.id = m.ticket_id GROUP BY t.id ORDER BY t.created_at DESC LIMIT 100', 
        {}, function(result)
        if result then
            for i, ticket in ipairs(result) do
                result[i].form_data = json.decode(ticket.form_data)
            end
            cb(result)
        else
            cb({})
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:getTicketDetails', function(source, cb, ticketId)
    MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(ticketResult)
        if ticketResult and ticketResult[1] then
            local ticket = ticketResult[1]
            ticket.form_data = json.decode(ticket.form_data)
            
            -- Get messages
            MySQL.query('SELECT * FROM rx_ticket_messages WHERE ticket_id = ? ORDER BY created_at ASC', {ticketId}, function(messages)
                ticket.messages = messages or {}
                
                -- Get actions
                MySQL.query('SELECT * FROM rx_ticket_actions WHERE ticket_id = ? ORDER BY created_at DESC', {ticketId}, function(actions)
                    ticket.actions = actions or {}
                    cb(ticket)
                end)
            end)
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:claimTicket', function(source, cb, ticketId)
    if not HasPermission(source, 'claimReports') then cb(false) return end
    
    local identifier = GetPlayerIdentifier(source)
    local staffName = GetPlayerName(source)
    
    MySQL.update('UPDATE rx_tickets SET status = ?, claimed_by = ?, claimed_by_name = ?, claimed_at = NOW() WHERE id = ? AND status = ?', 
        {'claimed', identifier, staffName, ticketId, 'open'}, function(affectedRows)
        if affectedRows > 0 then
            UpdateStaffStats(identifier, 'claim')
            
            -- Get ticket data
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(result)
                if result and result[1] then
                    local ticket = result[1]
                    ticket.form_data = json.decode(ticket.form_data)
                    
                    -- Notify reporter
                    local reporterPlayer = GetPlayerByIdentifier(ticket.reporter_identifier)
                    if reporterPlayer then
                        TriggerClientEvent('rx_reports:client:ticketUpdated', reporterPlayer.PlayerData.source, ticket)
                    end
                    
                    -- Notify all staff
                    for _, player in pairs(QBCore.Functions.GetPlayers()) do
                        if HasPermission(player, 'viewReports') then
                            TriggerClientEvent('rx_reports:client:ticketUpdated', player, ticket)
                        end
                    end
                    
                    -- Add system message
                    MySQL.insert('INSERT INTO rx_ticket_messages (ticket_id, sender_identifier, sender_name, sender_type, message) VALUES (?, ?, ?, ?, ?)',
                        {ticketId, 'system', 'System', 'system', string.format('%s claimed this ticket', staffName)})
                    
                    -- Discord log
                    if Config.Discord.events.ticketClaimed then
                        SendDiscordLog(
                            '👤 Ticket Claimed',
                            string.format('**Ticket:** %s\n**Claimed by:** %s', ticket.ticket_number, staffName),
                            Config.Discord.colors.ticketClaimed,
                            {
                                {name = 'Staff Member', value = staffName, inline = true},
                                {name = 'Ticket', value = ticket.ticket_number, inline = true}
                            }
                        )
                    end
                end
            end)
            
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:unclaimTicket', function(source, cb, ticketId)
    if not HasPermission(source, 'claimReports') then cb(false) return end
    
    local identifier = GetPlayerIdentifier(source)
    
    MySQL.update('UPDATE rx_tickets SET status = ?, claimed_by = NULL, claimed_by_name = NULL, claimed_at = NULL WHERE id = ? AND claimed_by = ?', 
        {'open', ticketId, identifier}, function(affectedRows)
        if affectedRows > 0 then
            -- Get ticket data and notify
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(result)
                if result and result[1] then
                    local ticket = result[1]
                    ticket.form_data = json.decode(ticket.form_data)
                    
                    for _, player in pairs(QBCore.Functions.GetPlayers()) do
                        if HasPermission(player, 'viewReports') then
                            TriggerClientEvent('rx_reports:client:ticketUpdated', player, ticket)
                        end
                    end
                end
            end)
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:closeTicket', function(source, cb, ticketId, reason)
    if not HasPermission(source, 'closeReports') then cb(false) return end
    
    local identifier = GetPlayerIdentifier(source)
    local staffName = GetPlayerName(source)
    
    MySQL.update('UPDATE rx_tickets SET status = ?, closed_at = NOW() WHERE id = ?', 
        {'closed', ticketId}, function(affectedRows)
        if affectedRows > 0 then
            -- Get ticket data
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(result)
                if result and result[1] then
                    local ticket = result[1]
                    ticket.form_data = json.decode(ticket.form_data)
                    
                    -- Update stats if claimed by this staff
                    if ticket.claimed_by == identifier then
                        UpdateStaffStats(identifier, 'close')
                        
                        -- Calculate response time
                        if ticket.claimed_at then
                            local responseTime = os.time() - ticket.claimed_at
                            UpdateStaffStats(identifier, 'response_time', responseTime)
                        end
                    end
                    
                    -- Notify reporter
                    local reporterPlayer = GetPlayerByIdentifier(ticket.reporter_identifier)
                    if reporterPlayer then
                        TriggerClientEvent('rx_reports:client:ticketUpdated', reporterPlayer.PlayerData.source, ticket)
                    end
                    
                    -- Notify all staff
                    for _, player in pairs(QBCore.Functions.GetPlayers()) do
                        if HasPermission(player, 'viewReports') then
                            TriggerClientEvent('rx_reports:client:ticketUpdated', player, ticket)
                        end
                    end
                    
                    -- Add system message
                    local closeMsg = reason and string.format('%s closed this ticket. Reason: %s', staffName, reason) or string.format('%s closed this ticket', staffName)
                    MySQL.insert('INSERT INTO rx_ticket_messages (ticket_id, sender_identifier, sender_name, sender_type, message) VALUES (?, ?, ?, ?, ?)',
                        {ticketId, 'system', 'System', 'system', closeMsg})
                    
                    -- Discord log
                    if Config.Discord.events.ticketClosed then
                        SendDiscordLog(
                            '✅ Ticket Closed',
                            string.format('**Ticket:** %s\n**Closed by:** %s\n**Reason:** %s', ticket.ticket_number, staffName, reason or 'None'),
                            Config.Discord.colors.ticketClosed,
                            {
                                {name = 'Staff Member', value = staffName, inline = true},
                                {name = 'Ticket', value = ticket.ticket_number, inline = true}
                            }
                        )
                    end
                end
            end)
            
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:reopenTicket', function(source, cb, ticketId)
    if not HasPermission(source, 'closeReports') then cb(false) return end
    
    MySQL.update('UPDATE rx_tickets SET status = ?, closed_at = NULL WHERE id = ?', 
        {'reopened', ticketId}, function(affectedRows)
        if affectedRows > 0 then
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(result)
                if result and result[1] then
                    local ticket = result[1]
                    ticket.form_data = json.decode(ticket.form_data)
                    
                    for _, player in pairs(QBCore.Functions.GetPlayers()) do
                        if HasPermission(player, 'viewReports') then
                            TriggerClientEvent('rx_reports:client:ticketUpdated', player, ticket)
                        end
                    end
                    
                    if Config.Discord.events.ticketReopened then
                        SendDiscordLog(
                            '🔄 Ticket Reopened',
                            string.format('**Ticket:** %s', ticket.ticket_number),
                            Config.Discord.colors.ticketReopened
                        )
                    end
                end
            end)
            cb(true)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:sendMessage', function(source, cb, ticketId, message, isQuickResponse)
    local identifier = GetPlayerIdentifier(source)
    local senderName = GetPlayerName(source)
    local senderType = HasPermission(source, 'viewReports') and 'staff' or 'player'
    
    MySQL.insert('INSERT INTO rx_ticket_messages (ticket_id, sender_identifier, sender_name, sender_type, message, is_quick_response) VALUES (?, ?, ?, ?, ?, ?)',
        {ticketId, identifier, senderName, senderType, message, isQuickResponse and 1 or 0}, function(messageId)
        if messageId then
            local messageData = {
                id = messageId,
                ticket_id = ticketId,
                sender_identifier = identifier,
                sender_name = senderName,
                sender_type = senderType,
                message = message,
                is_quick_response = isQuickResponse,
                created_at = os.time()
            }
            
            -- Get ticket data
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(ticketResult)
                if ticketResult and ticketResult[1] then
                    local ticket = ticketResult[1]
                    
                    -- Notify reporter
                    if senderType == 'staff' then
                        local reporterPlayer = GetPlayerByIdentifier(ticket.reporter_identifier)
                        if reporterPlayer then
                            TriggerClientEvent('rx_reports:client:newMessage', reporterPlayer.PlayerData.source, ticketId, messageData)
                        end
                    end
                    
                    -- Notify staff
                    if senderType == 'player' then
                        for _, player in pairs(QBCore.Functions.GetPlayers()) do
                            if HasPermission(player, 'viewReports') then
                                TriggerClientEvent('rx_reports:client:newMessage', player, ticketId, messageData)
                            end
                        end
                    end
                end
            end)
            
            cb(true, messageData)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('rx_reports:server:rateTicket', function(source, cb, ticketId, rating, comment)
    local identifier = GetPlayerIdentifier(source)
    
    MySQL.update('UPDATE rx_tickets SET rating = ?, rating_comment = ? WHERE id = ? AND reporter_identifier = ?', 
        {rating, comment, ticketId, identifier}, function(affectedRows)
        if affectedRows > 0 then
            -- Get ticket to update staff stats
            MySQL.query('SELECT * FROM rx_tickets WHERE id = ?', {ticketId}, function(result)
                if result and result[1] and result[1].claimed_by then
                    UpdateStaffStats(result[1].claimed_by, 'rating', rating)
                end
            end)
            cb(true)
        else
            cb(false)
        end
    end)
end)-- Continue server.lua

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