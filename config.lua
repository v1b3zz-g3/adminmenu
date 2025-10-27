Config = {}

-- General Settings
Config.Framework = 'qb-core' -- or 'esx'
Config.DefaultLanguage = 'en'
Config.NotificationDuration = 5000
Config.MaxOpenTicketsPerPlayer = 3
Config.AutoCloseTicketsAfter = 48 -- hours (0 to disable)
Config.RequireReportedPlayer = false -- false allows reports without a specific player

-- Commands
Config.Commands = {
    playerReport = 'report',
    staffDashboard = 'staffreports',
    adminPanel = 'adminreports'
}

-- Permissions
Config.Permissions = {
    viewReports = {'admin', 'mod', 'god'},
    claimReports = {'admin', 'mod', 'god'},
    closeReports = {'admin', 'mod', 'god'},
    deleteReports = {'admin','god'},
    blockPlayers = {'admin', 'mod','god'},
    viewNotes = {'admin', 'mod', 'god'},
    addNotes = {'admin', 'mod', 'god'},
    viewStats = {'admin', 'mod','god'},
    staffChat = {'admin', 'mod', 'god'},
    teleportActions = {'admin', 'mod','god'},
    freezeActions = {'admin', 'mod','god'},
    warnActions = {'admin', 'mod', 'god'}
}

-- Report Priorities
Config.Priorities = {
    {
        id = 'low',
        label = 'Low',
        color = '#4CAF50',
        icon = 'fa-circle-info',
        weight = 1
    },
    {
        id = 'medium',
        label = 'Medium',
        color = '#FFC107',
        icon = 'fa-triangle-exclamation',
        weight = 2
    },
    {
        id = 'high',
        label = 'High',
        color = '#FF9800',
        icon = 'fa-exclamation',
        weight = 3
    },
    {
        id = 'critical',
        label = 'Critical',
        color = '#F44336',
        icon = 'fa-circle-exclamation',
        weight = 4
    }
}

-- Report Categories/Forms
Config.Forms = {
    {
        id = 'player_report',
        name = 'Player Report',
        description = 'Report another player for rule violations',
        icon = 'fa-user-slash',
        requiresTarget = true,
        defaultPriority = 'medium',
        fields = {
            {
                name = 'reported_player',
                label = 'Reported Player ID',
                type = 'player_select',
                required = true,
                placeholder = 'Select player...'
            },
            {
                name = 'reason',
                label = 'Violation Type',
                type = 'select',
                required = true,
                options = {
                    {value = 'rdm', label = 'Random Deathmatch (RDM)'},
                    {value = 'vdm', label = 'Vehicle Deathmatch (VDM)'},
                    {value = 'exploiting', label = 'Exploiting/Cheating'},
                    {value = 'metagaming', label = 'Metagaming'},
                    {value = 'failrp', label = 'Fail RP'},
                    {value = 'nlr', label = 'New Life Rule (NLR)'},
                    {value = 'toxicity', label = 'Toxicity/Harassment'},
                    {value = 'powergaming', label = 'Power Gaming'},
                    {value = 'other', label = 'Other'}
                }
            },
            {
                name = 'description',
                label = 'Detailed Description',
                type = 'textarea',
                required = true,
                placeholder = 'Provide as much detail as possible...',
                minLength = 20,
                maxLength = 1000
            },
            {
                name = 'evidence',
                label = 'Evidence Links (Optional)',
                type = 'text',
                required = false,
                placeholder = 'YouTube, Streamable, Medal.tv links...'
            }
        }
    },
    {
        id = 'bug_report',
        name = 'Bug Report',
        description = 'Report a technical issue or bug',
        icon = 'fa-bug',
        requiresTarget = false,
        defaultPriority = 'low',
        fields = {
            {
                name = 'bug_category',
                label = 'Bug Category',
                type = 'select',
                required = true,
                options = {
                    {value = 'vehicle', label = 'Vehicle Issue'},
                    {value = 'job', label = 'Job Script'},
                    {value = 'inventory', label = 'Inventory'},
                    {value = 'housing', label = 'Housing/Property'},
                    {value = 'interaction', label = 'Interaction/Menu'},
                    {value = 'performance', label = 'Performance/FPS'},
                    {value = 'other', label = 'Other'}
                }
            },
            {
                name = 'description',
                label = 'Bug Description',
                type = 'textarea',
                required = true,
                placeholder = 'Describe the bug and steps to reproduce...',
                minLength = 20
            },
            {
                name = 'reproduction',
                label = 'Steps to Reproduce',
                type = 'textarea',
                required = false,
                placeholder = '1. Go to...\n2. Click on...\n3. See error'
            }
        }
    },
    {
        id = 'help_request',
        name = 'Help Request',
        description = 'Request assistance from staff',
        icon = 'fa-hands-helping',
        requiresTarget = false,
        defaultPriority = 'low',
        fields = {
            {
                name = 'help_type',
                label = 'Help Type',
                type = 'select',
                required = true,
                options = {
                    {value = 'stuck', label = 'Stuck/Trapped'},
                    {value = 'lost_items', label = 'Lost Items'},
                    {value = 'question', label = 'General Question'},
                    {value = 'guidance', label = 'Need Guidance'},
                    {value = 'other', label = 'Other'}
                }
            },
            {
                name = 'description',
                label = 'How can we help?',
                type = 'textarea',
                required = true,
                placeholder = 'Explain your situation...',
                minLength = 10
            }
        }
    },
    {
        id = 'compensation',
        name = 'Compensation Request',
        description = 'Request compensation for lost items/money',
        icon = 'fa-hand-holding-dollar',
        requiresTarget = false,
        defaultPriority = 'medium',
        fields = {
            {
                name = 'loss_type',
                label = 'Loss Type',
                type = 'select',
                required = true,
                options = {
                    {value = 'money', label = 'Money'},
                    {value = 'items', label = 'Items'},
                    {value = 'vehicle', label = 'Vehicle'},
                    {value = 'property', label = 'Property'},
                    {value = 'other', label = 'Other'}
                }
            },
            {
                name = 'amount',
                label = 'Estimated Value',
                type = 'text',
                required = true,
                placeholder = 'e.g., $50,000 or specific item names'
            },
            {
                name = 'description',
                label = 'What happened?',
                type = 'textarea',
                required = true,
                placeholder = 'Explain how you lost the items/money...',
                minLength = 30
            },
            {
                name = 'evidence',
                label = 'Evidence (Required)',
                type = 'text',
                required = true,
                placeholder = 'Video/screenshot evidence links'
            }
        }
    }
}

-- Quick Responses (Canned Messages)
Config.QuickResponses = {
    {
        label = 'Under Investigation',
        message = 'Thank you for your report. We are currently investigating this matter and will update you shortly.'
    },
    {
        label = 'Need More Info',
        message = 'We need additional information to process your report. Can you please provide more details or evidence?'
    },
    {
        label = 'Resolved',
        message = 'This issue has been resolved. Thank you for bringing this to our attention.'
    },
    {
        label = 'No Evidence',
        message = 'We are unable to proceed without sufficient evidence. Please provide video/screenshot proof if possible.'
    },
    {
        label = 'Action Taken',
        message = 'Appropriate action has been taken against the reported player. Thank you for your report.'
    },
    {
        label = 'Invalid Report',
        message = 'This report does not contain a valid rule violation. Please review server rules before submitting.'
    }
}

-- Staff Actions
Config.Actions = {
    {
        id = 'teleport_to_player',
        label = 'Teleport to Player',
        icon = 'fa-location-arrow',
        permission = 'teleportActions',
        requiresOnline = true,
        cooldown = 0
    },
    {
        id = 'bring_player',
        label = 'Bring Player',
        icon = 'fa-hand-pointer',
        permission = 'teleportActions',
        requiresOnline = true,
        cooldown = 0
    },
    {
        id = 'freeze_player',
        label = 'Freeze Player',
        icon = 'fa-snowflake',
        permission = 'freezeActions',
        requiresOnline = true,
        cooldown = 0
    },
    {
        id = 'screenshot',
        label = 'Take Screenshot',
        icon = 'fa-camera',
        permission = 'viewReports',
        requiresOnline = true,
        cooldown = 30
    },
    {
        id = 'warn_player',
        label = 'Warn Player',
        icon = 'fa-triangle-exclamation',
        permission = 'warnActions',
        requiresOnline = false,
        cooldown = 0
    },
    {
        id = 'spectate',
        label = 'Spectate Player',
        icon = 'fa-eye',
        permission = 'viewReports',
        requiresOnline = true,
        cooldown = 0
    },
    {
        id = 'check_inventory',
        label = 'Check Inventory',
        icon = 'fa-box-open',
        permission = 'viewReports',
        requiresOnline = true,
        cooldown = 0
    }
}

-- Discord Webhooks
Config.Discord = {
    enabled = true,
    webhookURL = '', -- Add your webhook URL here
    botName = 'RX Reports',
    botAvatar = 'https://i.imgur.com/4M34hi2.png',
    events = {
        ticketCreated = true,
        ticketClaimed = true,
        ticketClosed = true,
        ticketReopened = true,
        playerBlocked = true,
        playerUnblocked = true,
        noteAdded = true
    },
    colors = {
        ticketCreated = 3447003, -- Blue
        ticketClaimed = 15844367, -- Gold
        ticketClosed = 5763719, -- Green
        ticketReopened = 15105570, -- Orange
        playerBlocked = 15158332, -- Red
        playerUnblocked = 10181046, -- Purple
        noteAdded = 9807270 -- Gray
    }
}

-- Rating System
Config.Rating = {
    enabled = true,
    required = false, -- Force player to rate before closing
    options = {
        {value = 1, label = 'Very Poor', icon = '😢'},
        {value = 2, label = 'Poor', icon = '😞'},
        {value = 3, label = 'Average', icon = '😐'},
        {value = 4, label = 'Good', icon = '😊'},
        {value = 5, label = 'Excellent', icon = '😍'}
    }
}

-- Block System
Config.BlockSystem = {
    enabled = true,
    maxBlockDuration = 30, -- days
    reasons = {
        'Spam Reports',
        'False Reports',
        'Abuse of System',
        'Toxic Behavior',
        'Other'
    }
}

-- Notifications
Config.Notifications = {
    ticketCreated = {
        title = 'Report Submitted',
        message = 'Your report has been submitted successfully.',
        type = 'success'
    },
    ticketClaimed = {
        title = 'Report Claimed',
        message = 'A staff member is now handling your report.',
        type = 'info'
    },
    ticketClosed = {
        title = 'Report Closed',
        message = 'Your report has been closed.',
        type = 'success'
    },
    newMessage = {
        title = 'New Message',
        message = 'You have received a new message on your report.',
        type = 'info'
    },
    staffNewTicket = {
        title = 'New Report',
        message = 'A new report has been submitted.',
        type = 'warning'
    }
}

-- Screenshot Settings
Config.Screenshot = {
    enabled = true,
    webhook = '', -- Separate webhook for screenshots
    format = 'png',
    quality = 0.92,
    encoding = 'webp'
}

-- UI Settings
Config.UI = {
    defaultTheme = 'dark', -- 'dark' or 'light'
    accentColor = '#6366f1',
    animations = true,
    soundEffects = false,
    showStaffAvatars = true,
    dateFormat = 'MM/DD/YYYY',
    timeFormat = '12h' -- '12h' or '24h'
}