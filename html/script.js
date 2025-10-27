// RX Reports - NUI Script
let currentView = null;
let currentTicketId = null;
let selectedRating = 0;
let appData = {
    userType: 'player', // 'player' or 'staff'
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
    // Close button
    document.getElementById('closeBtn').addEventListener('click', closeUI);
    
    // Theme toggle
    document.getElementById('themeToggle').addEventListener('click', toggleTheme);
    
    // Submit report button
    document.getElementById('submitReportBtn').addEventListener('click', submitReport);
    
    // Send message buttons
    document.getElementById('sendTicketMessage').addEventListener('click', sendTicketMessage);
    document.getElementById('sendStaffMessage').addEventListener('click', sendStaffMessage);
    
    // Rating stars
    document.querySelectorAll('.rating-stars i').forEach(star => {
        star.addEventListener('click', function() {
            selectedRating = parseInt(this.dataset.rating);
            updateRatingStars();
        });
    });
    
    // Submit rating
    document.getElementById('submitRatingBtn').addEventListener('click', submitRating);
    
    // Add note
    document.getElementById('addNoteBtn').addEventListener('click', () => openModal('addNoteModal'));
    document.getElementById('submitNoteBtn').addEventListener('click', submitNote);
    
    // Block player
    document.getElementById('confirmBlockBtn').addEventListener('click', confirmBlockPlayer);
    
    // Refresh tickets
    document.getElementById('refreshTickets').addEventListener('click', refreshAllTickets);
    
    // Search and filters
    document.getElementById('myReportsSearch').addEventListener('input', filterMyTickets);
    document.getElementById('myReportsStatusFilter').addEventListener('change', filterMyTickets);
    document.getElementById('staffSearch').addEventListener('input', filterStaffTickets);
    document.getElementById('staffStatusFilter').addEventListener('change', filterStaffTickets);
    document.getElementById('staffPriorityFilter').addEventListener('change', filterStaffTickets);
    
    // Chat inputs enter key
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
        addNavItem('fa-clipboard-check', 'All Tickets', 'staffDashboardView', appData.allTickets.filter(t => t.status !== 'closed').length);
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
        if (item.textContent.includes(document.querySelector(`#${viewId} h2`)?.textContent || '')) {
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
    
    // Build form fields
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
    
    // Build priority select
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
    
    // Store current form
    document.getElementById('reportForm').dataset.formId = form.id;
}

// Submit Report
function submitReport() {
    const form = document.getElementById('reportForm');
    const formId = form.dataset.formId;
    const formData = {};
    
    // Collect form data
    form.querySelectorAll('[name]').forEach(field => {
        formData[field.name] = field.value;
    });
    
    const priority = document.getElementById('prioritySelect').value;
    
    // Validate required fields
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
    
    // Send to client
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
    
    // Apply filters
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
            <span><i class="fas fa-clock"></i> ${formatDate(ticket