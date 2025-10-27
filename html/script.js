// RX Reports - Complete NUI Script
let currentView = null;
let currentTicketId = null;
let selectedRating = 0;
let appData = {
    userType: 'player',
    forms: [],
    priorities: [],
    myTickets: [],
    allTickets: [],
    onlinePlayers: [],
    actions: [],
    quickResponses: [],
    permissions: {},
    stats: []
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    setupKeyBindings();
});

// Setup Event Listeners
function setupEventListeners() {
    document.getElementById('closeBtn').addEventListener('click', closeUI);
    document.getElementById('themeToggle').addEventListener('click', toggleTheme);
    document.getElementById('submitReportBtn').addEventListener('click', submitReport);
    document.getElementById('sendTicketMessage').addEventListener('click', sendTicketMessage);
    document.getElementById('sendStaffMessage').addEventListener('click', sendStaffMessage);
    
    document.querySelectorAll('.rating-stars i').forEach(star => {
        star.addEventListener('click', function() {
            selectedRating = parseInt(this.dataset.rating);
            updateRatingStars();
        });
    });
    
    document.getElementById('submitRatingBtn').addEventListener('click', submitRating);
    document.getElementById('addNoteBtn').addEventListener('click', () => openModal('addNoteModal'));
    document.getElementById('submitNoteBtn').addEventListener('click', submitNote);
    document.getElementById('confirmBlockBtn').addEventListener('click', confirmBlockPlayer);
    document.getElementById('refreshTickets').addEventListener('click', refreshAllTickets);
    
    document.getElementById('myReportsSearch').addEventListener('input', filterMyTickets);
    document.getElementById('myReportsStatusFilter').addEventListener('change', filterMyTickets);
    document.getElementById('staffSearch').addEventListener('input', filterStaffTickets);
    document.getElementById('staffStatusFilter').addEventListener('change', filterStaffTickets);
    document.getElementById('staffPriorityFilter').addEventListener('change', filterStaffTickets);
    
    document.getElementById('ticketChatInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendTicketMessage();
        }
    });
    
    document.getElementById('staffChatInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            sendStaffMessage();
        }
    });
}

// Setup Key Bindings
function setupKeyBindings() {
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (document.querySelector('.modal:not(.hidden)')) {
                closeAllModals();
            } else {
                closeUI();
            }
        }
    });
}

// NUI Message Handler
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.action) {
        case 'openUI':
            openUI(data.type, data.data);
            break;
        case 'closeUI':
            closeUI();
            break;
        case 'ticketUpdated':
            handleTicketUpdate(data.ticket);
            break;
        case 'newMessage':
            handleNewMessage(data.ticketId, data.message);
            break;
        case 'newTicket':
            handleNewTicket(data.ticket);
            break;
        case 'newStaffMessage':
            handleNewStaffMessage(data.message);
            break;
    }
});

// Open UI
function openUI(type, data) {
    appData.userType = type;
    
    if (data.forms) appData.forms = data.forms;
    if (data.priorities) appData.priorities = data.priorities;
    if (data.myTickets) appData.myTickets = data.myTickets;
    if (data.tickets) appData.allTickets = data.tickets;
    if (data.onlinePlayers) appData.onlinePlayers = data.onlinePlayers;
    if (data.actions) appData.actions = data.actions;
    if (data.quickResponses) appData.quickResponses = data.quickResponses;
    if (data.permissions) appData.permissions = data.permissions;
    if (data.stats) appData.stats = data.stats;
    
    buildNavigation();
    
    if (type === 'player') {
        showView('submitReportView');
        renderFormCategories();
        renderMyTickets();
    } else {
        showView('staffDashboardView');
        renderStaffDashboard();
    }
    
    document.getElementById('app').classList.remove('hidden');
}

// Close UI
function closeUI() {
    document.getElementById('app').classList.add('hidden');
    closeAllModals();
    
    fetch('https://rx_reports/closeUI', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// Build Navigation
function buildNavigation() {
    const nav = document.getElementById('sidebarNav');
    nav.innerHTML = '';
    
    if (appData.userType === 'player') {
        addNavItem('fa-plus-circle', 'Submit Report', 'submitReportView');
        addNavItem('fa-list-alt', 'My Reports', 'myReportsView', appData.myTickets.filter(t => t.status !== 'closed').length);
    } else {
        addNavItem('fa-th-large', 'Dashboard', 'staffDashboardView');
        const openTickets = appData.allTickets.filter(t => t.status !== 'closed').length;
        addNavItem('fa-clipboard-check', 'All Tickets', 'staffDashboardView', openTickets);
        if (appData.permissions.notes) {
            addNavItem('fa-sticky-note', 'Player Notes', 'playerNotesView');
        }
        if (appData.permissions.viewStats) {
            addNavItem('fa-chart-bar', 'Statistics', 'statisticsView');
        }
        if (appData.permissions.staffChat) {
            addNavItem('fa-comments', 'Staff Chat', 'staffChatView');
        }
    }
}

function addNavItem(icon, label, viewId, badge) {
    const nav = document.getElementById('sidebarNav');
    const item = document.createElement('div');
    item.className = 'nav-item';
    item.innerHTML = `
        <i class="fas ${icon}"></i>
        <span>${label}</span>
        ${badge ? `<span class="badge">${badge}</span>` : ''}
    `;
    item.onclick = () => showView(viewId);
    nav.appendChild(item);
}

// Show View
function showView(viewId) {
    document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    
    const view = document.getElementById(viewId);
    if (view) {
        view.classList.remove('hidden');
        currentView = viewId;
    }
    
    document.querySelectorAll('.nav-item').forEach(item => {
        const viewHeader = document.querySelector(`#${viewId} h2`);
        if (viewHeader && item.textContent.includes(viewHeader.textContent)) {
            item.classList.add('active');
        }
    });
}

// Render Form Categories
function renderFormCategories() {
    const container = document.getElementById('formCategories');
    container.innerHTML = '';
    
    appData.forms.forEach(form => {
        const card = document.createElement('div');
        card.className = 'form-card';
        card.innerHTML = `
            <div class="icon"><i class="fas ${form.icon}"></i></div>
            <h3>${form.name}</h3>
            <p>${form.description}</p>
        `;
        card.onclick = () => openReportForm(form);
        container.appendChild(card);
    });
}

// Open Report Form
function openReportForm(form) {
    document.getElementById('formTitle').textContent = form.name;
    
    const fieldsContainer = document.getElementById('formFields');
    fieldsContainer.innerHTML = '';
    
    form.fields.forEach(field => {
        const fieldDiv = document.createElement('div');
        fieldDiv.className = 'form-group';
        
        let fieldHTML = `<label>${field.label}${field.required ? ' *' : ''}</label>`;
        
        switch (field.type) {
            case 'text':
                fieldHTML += `<input type="text" class="form-control" name="${field.name}" placeholder="${field.placeholder || ''}" ${field.required ? 'required' : ''}>`;
                break;
            case 'textarea':
                fieldHTML += `<textarea class="form-control" name="${field.name}" placeholder="${field.placeholder || ''}" ${field.required ? 'required' : ''}></textarea>`;
                break;
            case 'select':
                fieldHTML += `<select class="form-control" name="${field.name}" ${field.required ? 'required' : ''}>
                    <option value="">Select...</option>
                    ${field.options.map(opt => `<option value="${opt.value}">${opt.label}</option>`).join('')}
                </select>`;
                break;
            case 'player_select':
                fieldHTML += `<select class="form-control" name="${field.name}" ${field.required ? 'required' : ''}>
                    <option value="">Select player...</option>
                    ${appData.onlinePlayers.map(p => `<option value="${p.id}">${p.name} (ID: ${p.id})</option>`).join('')}
                </select>`;
                break;
        }
        
        fieldDiv.innerHTML = fieldHTML;
        fieldsContainer.appendChild(fieldDiv);
    });
    
    const prioritySelect = document.getElementById('prioritySelect');
    prioritySelect.innerHTML = '';
    appData.priorities.forEach(priority => {
        const option = document.createElement('option');
        option.value = priority.id;
        option.textContent = priority.label;
        if (priority.id === form.defaultPriority) {
            option.selected = true;
        }
        prioritySelect.appendChild(option);
    });
    
    openModal('reportFormModal');
    document.getElementById('reportForm').dataset.formId = form.id;
}

// Submit Report
function submitReport() {
    const form = document.getElementById('reportForm');
    const formId = form.dataset.formId;
    const formData = {};
    
    form.querySelectorAll('[name]').forEach(field => {
        formData[field.name] = field.value;
    });
    
    const priority = document.getElementById('prioritySelect').value;
    
    let valid = true;
    form.querySelectorAll('[required]').forEach(field => {
        if (!field.value.trim()) {
            field.style.borderColor = 'var(--danger)';
            valid = false;
        } else {
            field.style.borderColor = '';
        }
    });
    
    if (!valid) {
        showToast('Error', 'Please fill in all required fields', 'error');
        return;
    }
    
    fetch('https://rx_reports/createTicket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            formId: formId,
            formData: formData,
            priority: priority
        })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            closeModal('reportFormModal');
            form.reset();
            showToast('Success', 'Your report has been submitted', 'success');
            refreshMyTickets();
        } else {
            showToast('Error', 'Failed to submit report', 'error');
        }
    });
}

// Render My Tickets
function renderMyTickets() {
    const container = document.getElementById('myReportsList');
    container.innerHTML = '';
    
    let tickets = appData.myTickets;
    
    const search = document.getElementById('myReportsSearch').value.toLowerCase();
    const statusFilter = document.getElementById('myReportsStatusFilter').value;
    
    if (search) {
        tickets = tickets.filter(t => 
            t.ticket_number.toLowerCase().includes(search) ||
            t.form_id.toLowerCase().includes(search)
        );
    }
    
    if (statusFilter) {
        tickets = tickets.filter(t => t.status === statusFilter);
    }
    
    if (tickets.length === 0) {
        container.innerHTML = '<div class="text-center" style="padding: 40px; color: var(--text-muted);">No reports found</div>';
        return;
    }
    
    tickets.forEach(ticket => {
        const card = createTicketCard(ticket);
        container.appendChild(card);
    });
}

// Create Ticket Card
function createTicketCard(ticket) {
    const div = document.createElement('div');
    div.className = `ticket-card priority-${ticket.priority}`;
    div.innerHTML = `
        <div class="ticket-header">
            <span class="ticket-number">#${ticket.ticket_number}</span>
            <div class="ticket-badges">
                <span class="badge priority priority-${ticket.priority}">${ticket.priority}</span>
                <span class="badge status-${ticket.status}">${ticket.status}</span>
            </div>
        </div>
        <div class="ticket-body">
            <h4>${getFormName(ticket.form_id)}</h4>
            <p>${getTicketDescription(ticket)}</p>
        </div>
        <div class="ticket-footer">
            <span><i class="fas fa-clock"></i> ${formatDate(ticket.created_at)}</span>
            <span><i class="fas fa-comments"></i> ${ticket.message_count || 0} messages</span>
        </div>
    `;
    div.onclick = () => openTicketDetails(ticket.id);
    return div;
}

// Render Staff Dashboard
function renderStaffDashboard() {
    renderDashboardStats();
    renderStaffTickets();
}

function renderDashboardStats() {
    const container = document.getElementById('dashboardStats');
    container.innerHTML = '';
    
    const openTickets = appData.allTickets.filter(t => t.status === 'open').length;
    const claimedTickets = appData.allTickets.filter(t => t.status === 'claimed').length;
    const closedToday = appData.allTickets.filter(t => {
        if (!t.closed_at) return false;
        const today = new Date().toDateString();
        return new Date(t.closed_at).toDateString() === today;
    }).length;
    
    const stats = [
        { label: 'Open Tickets', value: openTickets, icon: 'fa-inbox' },
        { label: 'Claimed', value: claimedTickets, icon: 'fa-hand-paper' },
        { label: 'Closed Today', value: closedToday, icon: 'fa-check-circle' },
        { label: 'Total Tickets', value: appData.allTickets.length, icon: 'fa-clipboard-list' }
    ];
    
    stats.forEach(stat => {
        const card = document.createElement('div');
        card.className = 'stat-card';
        card.innerHTML = `
            <div class="label">${stat.label}</div>
            <div class="value">${stat.value}</div>
            <i class="fas ${stat.icon} icon"></i>
        `;
        container.appendChild(card);
    });
}

function renderStaffTickets() {
    const tbody = document.getElementById('ticketsTableBody');
    tbody.innerHTML = '';
    
    let tickets = appData.allTickets;
    
    const search = document.getElementById('staffSearch').value.toLowerCase();
    const statusFilter = document.getElementById('staffStatusFilter').value;
    const priorityFilter = document.getElementById('staffPriorityFilter').value;
    
    if (search) {
        tickets = tickets.filter(t => 
            t.ticket_number.toLowerCase().includes(search) ||
            t.reporter_name.toLowerCase().includes(search)
        );
    }
    
    if (statusFilter) tickets = tickets.filter(t => t.status === statusFilter);
    if (priorityFilter) tickets = tickets.filter(t => t.priority === priorityFilter);
    
    tickets.forEach(ticket => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>#${ticket.ticket_number}</td>
            <td><span class="badge priority priority-${ticket.priority}">${ticket.priority}</span></td>
            <td>${ticket.reporter_name}</td>
            <td>${getFormName(ticket.form_id)}</td>
            <td><span class="badge status-${ticket.status}">${ticket.status}</span></td>
            <td>${ticket.claimed_by_name || '-'}</td>
            <td>${formatDate(ticket.created_at)}</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="openTicketDetails(${ticket.id})">View</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Open Ticket Details
function openTicketDetails(ticketId) {
    fetch('https://rx_reports/getTicketDetails', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId: ticketId })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            currentTicketId = ticketId;
            displayTicketDetails(data.ticket);
            openModal('ticketDetailsModal');
        }
    });
}

function displayTicketDetails(ticket) {
    document.getElementById('ticketDetailsTitle').textContent = getFormName(ticket.form_id);
    document.getElementById('ticketDetailsNumber').textContent = `#${ticket.ticket_number}`;
    
    const infoContent = document.getElementById('ticketInfoContent');
    const formData = JSON.parse(ticket.form_data);
    
    infoContent.innerHTML = `
        <div class="info-item">
            <span class="label">Status:</span>
            <span class="value"><span class="badge status-${ticket.status}">${ticket.status}</span></span>
        </div>
        <div class="info-item">
            <span class="label">Priority:</span>
            <span class="value"><span class="badge priority priority-${ticket.priority}">${ticket.priority}</span></span>
        </div>
        <div class="info-item">
            <span class="label">Reporter:</span>
            <span class="value">${ticket.reporter_name}</span>
        </div>
        ${ticket.reported_name ? `
        <div class="info-item">
            <span class="label">Reported:</span>
            <span class="value">${ticket.reported_name}</span>
        </div>` : ''}
        <div class="info-item">
            <span class="label">Created:</span>
            <span class="value">${formatDate(ticket.created_at)}</span>
        </div>
        ${ticket.claimed_by_name ? `
        <div class="info-item">
            <span class="label">Claimed By:</span>
            <span class="value">${ticket.claimed_by_name}</span>
        </div>` : ''}
    `;
    
    // Render action buttons if staff
    if (appData.userType === 'staff') {
        const actionsContainer = document.getElementById('ticketActionsButtons');
        actionsContainer.innerHTML = '';
        
        appData.actions.forEach(action => {
            if (action.requiresOnline && !ticket.reported_identifier) return;
            if (action.permission && !appData.permissions[action.permission.replace('Actions', '')]) return;
            
            const btn = document.createElement('button');
            btn.className = 'action-btn';
            btn.innerHTML = `<i class="fas ${action.icon}"></i> ${action.label}`;
            btn.onclick = () => executeAction(ticket.id, action, ticket.reported_identifier);
            actionsContainer.appendChild(btn);
        });
    }
    
    // Render messages
    renderTicketMessages(ticket.messages || []);
    
    // Render quick responses
    if (appData.userType === 'staff') {
        const quickContainer = document.getElementById('quickResponsesContainer');
        quickContainer.innerHTML = '';
        appData.quickResponses.forEach(qr => {
            const btn = document.createElement('button');
            btn.className = 'quick-response-btn';
            btn.textContent = qr.label;
            btn.onclick = () => {
                document.getElementById('ticketChatInput').value = qr.message;
            };
            quickContainer.appendChild(btn);
        });
    }
    
    // Render footer buttons
    renderTicketFooter(ticket);
}

function renderTicketMessages(messages) {
    const container = document.getElementById('ticketChatMessages');
    container.innerHTML = '';
    
    messages.forEach(msg => {
        const div = document.createElement('div');
        div.className = `chat-message ${msg.sender_type === 'staff' ? 'staff' : 'own'}`;
        div.innerHTML = `
            <div class="chat-avatar">${msg.sender_name.charAt(0).toUpperCase()}</div>
            <div class="message-content">
                <div class="message-header">
                    <span class="message-sender">${msg.sender_name}</span>
                    <span class="message-time">${formatDate(msg.created_at)}</span>
                </div>
                <div class="message-bubble">${msg.message}</div>
            </div>
        `;
        container.appendChild(div);
    });
    
    container.scrollTop = container.scrollHeight;
    document.getElementById('messageCount').textContent = `${messages.length} messages`;
}

function renderTicketFooter(ticket) {
    const footer = document.getElementById('ticketDetailsFooter');
    footer.innerHTML = '';
    
    if (appData.userType === 'staff') {
        if (ticket.status === 'open' && appData.permissions.claim) {
            const claimBtn = document.createElement('button');
            claimBtn.className = 'btn btn-primary';
            claimBtn.innerHTML = '<i class="fas fa-hand-paper"></i> Claim Ticket';
            claimBtn.onclick = () => claimTicket(ticket.id);
            footer.appendChild(claimBtn);
        }
        
        if (ticket.status === 'claimed' && appData.permissions.claim) {
            const unclaimBtn = document.createElement('button');
            unclaimBtn.className = 'btn btn-secondary';
            unclaimBtn.textContent = 'Unclaim';
            unclaimBtn.onclick = () => unclaimTicket(ticket.id);
            footer.appendChild(unclaimBtn);
        }
        
        if (ticket.status !== 'closed' && appData.permissions.close) {
            const closeBtn = document.createElement('button');
            closeBtn.className = 'btn btn-success';
            closeBtn.innerHTML = '<i class="fas fa-check"></i> Close Ticket';
            closeBtn.onclick = () => closeTicket(ticket.id);
            footer.appendChild(closeBtn);
        }
    }
}

// Ticket Actions
function claimTicket(ticketId) {
    fetch('https://rx_reports/claimTicket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            refreshAllTickets();
            closeModal('ticketDetailsModal');
        }
    });
}

function unclaimTicket(ticketId) {
    fetch('https://rx_reports/unclaimTicket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            refreshAllTickets();
            closeModal('ticketDetailsModal');
        }
    });
}

function closeTicket(ticketId) {
    fetch('https://rx_reports/closeTicket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId, reason: 'Resolved' })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            refreshAllTickets();
            closeModal('ticketDetailsModal');
            if (appData.userType === 'player') {
                openModal('ratingModal');
            }
        }
    });
}

function sendTicketMessage() {
    const input = document.getElementById('ticketChatInput');
    const message = input.value.trim();
    
    if (!message || !currentTicketId) return;
    
    fetch('https://rx_reports/sendMessage', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId: currentTicketId, message })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            input.value = '';
            // Message will be added via event
        }
    });
}

function executeAction(ticketId, action, targetId) {
    fetch('https://rx_reports/executeAction', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId, action, targetId })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            showToast('Success', `Action "${action.label}" executed`, 'success');
        }
    });
}

// Helper Functions
function getFormName(formId) {
    const form = appData.forms.find(f => f.id === formId);
    return form ? form.name : formId;
}

function getTicketDescription(ticket) {
    const formData = JSON.parse(ticket.form_data);
    return formData.description || formData.bug_category || formData.help_type || 'No description';
}

function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleString();
}

function toggleTheme() {
    const body = document.body;
    const currentTheme = body.getAttribute('data-theme') || 'dark';
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    body.setAttribute('data-theme', newTheme);
}

function openModal(modalId) {
    document.getElementById(modalId).classList.remove('hidden');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.add('hidden');
}

function closeAllModals() {
    document.querySelectorAll('.modal').forEach(modal => {
        modal.classList.add('hidden');
    });
}

function showToast(title, message, type) {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    const icons = {
        success: 'fa-check-circle',
        error: 'fa-times-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };
    
    toast.innerHTML = `
        <i class="fas ${icons[type]} toast-icon"></i>
        <div class="toast-content">
            <div class="toast-title">${title}</div>
            <div class="toast-message">${message}</div>
        </div>
    `;
    
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 5000);
}

function submitRating() {
    if (selectedRating === 0) {
        showToast('Error', 'Please select a rating', 'error');
        return;
    }
    
    const comment = document.getElementById('ratingComment').value;
    
    fetch('https://rx_reports/rateTicket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticketId: currentTicketId, rating: selectedRating, comment })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            closeModal('ratingModal');
            selectedRating = 0;
            updateRatingStars();
        }
    });
}

function updateRatingStars() {
    document.querySelectorAll('.rating-stars i').forEach((star, index) => {
        if (index < selectedRating) {
            star.classList.add('active');
        } else {
            star.classList.remove('active');
        }
    });
}

function submitNote() {
    const playerId = document.getElementById('notePlayerId').value;
    const note = document.getElementById('noteContent').value.trim();
    
    if (!playerId || !note) {
        showToast('Error', 'Please fill in all fields', 'error');
        return;
    }
    
    fetch('https://rx_reports/addNote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId, note })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            closeModal('addNoteModal');
            document.getElementById('notePlayerId').value = '';
            document.getElementById('noteContent').value = '';
        }
    });
}

function confirmBlockPlayer() {
    const reason = document.getElementById('blockReason').value;
    const duration = parseInt(document.getElementById('blockDuration').value);
    
    if (!reason) {
        showToast('Error', 'Please select a reason', 'error');
        return;
    }
    
    fetch('https://rx_reports/blockPlayer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId: currentTicketId, reason, duration })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            closeModal('blockPlayerModal');
        }
    });
}

function sendStaffMessage() {
    const input = document.getElementById('staffChatInput');
    const message = input.value.trim();
    
    if (!message) return;
    
    fetch('https://rx_reports/sendStaffMessage', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            input.value = '';
        }
    });
}

function refreshMyTickets() {
    fetch('https://rx_reports/getMyTickets', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        if (data.tickets) {
            appData.myTickets = data.tickets;
            renderMyTickets();
        }
    });
}

function refreshAllTickets() {
    fetch('https://rx_reports/getAllTickets', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            appData.allTickets = data.tickets;
            renderStaffDashboard();
        }
    });
}

function filterMyTickets() {
    renderMyTickets();
}

function filterStaffTickets() {
    renderStaffTickets();
}

// Event Handlers
function handleTicketUpdate(ticket) {
    if (appData.userType === 'player') {
        const index = appData.myTickets.findIndex(t => t.id === ticket.id);
        if (index !== -1) {
            appData.myTickets[index] = ticket;
            renderMyTickets();
        }
    } else {
        const index = appData.allTickets.findIndex(t => t.id === ticket.id);
        if (index !== -1) {
            appData.allTickets[index] = ticket;
            renderStaffDashboard();
        }
    }
    
    if (currentTicketId === ticket.id) {
        displayTicketDetails(ticket);
    }
}

function handleNewMessage(ticketId, message) {
    if (currentTicketId === ticketId) {
        const container = document.getElementById('ticketChatMessages');
        const div = document.createElement('div');
        div.className = `chat-message ${message.sender_type === 'staff' ? 'staff' : 'own'}`;
        div.innerHTML = `
            <div class="chat-avatar">${message.sender_name.charAt(0).toUpperCase()}</div>
            <div class="message-content">
                <div class="message-header">
                    <span class="message-sender">${message.sender_name}</span>
                    <span class="message-time">${formatDate(message.created_at)}</span>
                </div>
                <div class="message-bubble">${message.message}</div>
            </div>
        `;
        container.appendChild(div);
        container.scrollTop = container.scrollHeight;
        
        const currentCount = parseInt(document.getElementById('messageCount').textContent);
        document.getElementById('messageCount').textContent = `${currentCount + 1} messages`;
    }
}

function handleNewTicket(ticket) {
    if (appData.userType === 'staff') {
        appData.allTickets.unshift(ticket);
        renderStaffDashboard();
        buildNavigation();
    }
}

function handleNewStaffMessage(message) {
    const container = document.getElementById('staffChatMessages');
    if (!container) return;
    
    const div = document.createElement('div');
    div.className = 'chat-message';
    div.innerHTML = `
        <div class="chat-avatar">${message.sender_name.charAt(0).toUpperCase()}</div>
        <div class="message-content">
            <div class="message-header">
                <span class="message-sender">${message.sender_name}</span>
                <span class="message-time">${formatDate(message.created_at)}</span>
            </div>
            <div class="message-bubble">${message.message}</div>
        </div>
    `;
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
}