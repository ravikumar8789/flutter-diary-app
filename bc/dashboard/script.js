// Supabase configuration - UPDATE THESE!
const SUPABASE_URL = 'https://foqoterfgxoiwoxvuxqi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvcW90ZXJmZ3hvaXdveHZ1eHFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkyMTYzNDksImV4cCI6MjA3NDc5MjM0OX0.GqWC7AOMMvxJwnUvJk7-YaSzxrQ1rPu7uxeHXBV4tkk';

// Initialize Supabase client
supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// State
let currentIssues = [];
let selectedIssueId = null;
let currentFilter = 'all';
let searchTerm = '';

// Load issues on page load
document.addEventListener('DOMContentLoaded', () => {
    loadIssues();
    
    // Event listeners
    document.getElementById('priorityFilter').addEventListener('change', (e) => {
        currentFilter = e.target.value;
        filterAndRenderIssues();
    });
    
    document.getElementById('searchInput').addEventListener('input', (e) => {
        searchTerm = e.target.value.toLowerCase();
        filterAndRenderIssues();
    });
    
    document.getElementById('refreshBtn').addEventListener('click', loadIssues);
    
    // Delete button listener
    document.getElementById('deleteBtn').addEventListener('click', showDeleteConfirmation);
});

async function loadIssues() {
    try {
        const { data, error } = await supabase
            .from('issues_tracking')
            .select('*')
            .order('issue_date', { ascending: false });
        
        if (error) throw error;
        
        currentIssues = data || [];
        document.getElementById('issueCount').textContent = `${currentIssues.length} issues`;
        filterAndRenderIssues();
        
    } catch (error) {
        console.error('Error loading issues:', error);
        alert('Error loading issues. Check console for details.');
    }
}

function filterAndRenderIssues() {
    let filtered = currentIssues;
    
    // Apply priority filter
    if (currentFilter !== 'all') {
        filtered = filtered.filter(issue => issue.priority === currentFilter);
    }
    
    // Apply search
    if (searchTerm) {
        filtered = filtered.filter(issue => 
            issue.title?.toLowerCase().includes(searchTerm) ||
            issue.description?.toLowerCase().includes(searchTerm) ||
            issue.feature?.toLowerCase().includes(searchTerm)
        );
    }
    
    renderIssuesList(filtered);
    
    // If selected issue is not in filtered list, clear details
    if (selectedIssueId && !filtered.find(i => i.id === selectedIssueId)) {
        selectedIssueId = null;
        renderIssueDetails(null);
    }
}

function renderIssuesList(issues) {
    const issuesList = document.getElementById('issuesList');
    
    if (issues.length === 0) {
        issuesList.innerHTML = '<div class="no-selection">No issues found</div>';
        return;
    }
    
    issuesList.innerHTML = issues.map(issue => `
        <div class="issue-card ${selectedIssueId === issue.id ? 'selected' : ''}" 
             onclick="selectIssue('${issue.id}')">
            <div class="issue-card-header">
                <span class="issue-title">${escapeHtml(issue.title || 'Untitled')}</span>
                <span class="priority-badge priority-${issue.priority || 'Low'}">
                    ${issue.priority || 'Low'}
                </span>
            </div>
            <div class="issue-meta">
                <span class="issue-feature">${escapeHtml(issue.feature || 'General')}</span>
                <span class="issue-date">📅 ${formatDate(issue.issue_date)}</span>
            </div>
        </div>
    `).join('');
}

function selectIssue(issueId) {
    selectedIssueId = issueId;
    const issue = currentIssues.find(i => i.id === issueId);
    renderIssueDetails(issue);
    filterAndRenderIssues(); // Re-render to update selected state
    
    // Show delete button
    document.getElementById('deleteContainer').style.display = 'block';
}

function renderIssueDetails(issue) {
    const detailsDiv = document.getElementById('issueDetails');
    
    if (!issue) {
        detailsDiv.innerHTML = `
            <div class="no-selection">
                <p>👈 Select an issue to view details</p>
            </div>
        `;
        // Hide delete button when no issue selected
        document.getElementById('deleteContainer').style.display = 'none';
        return;
    }
    
    // Format steps as list if it's an array
    const steps = issue.steps_taken || [];
    const stepsHtml = steps.length > 0 ? `
        <div class="detail-item">
            <div class="detail-label">Steps Taken</div>
            <ul class="steps-list">
                ${steps.map((step, index) => `
                    <li class="step-item">
                        <span class="step-number">${index + 1}</span>
                        <span class="step-text">${escapeHtml(step)}</span>
                    </li>
                `).join('')}
            </ul>
        </div>
    ` : '';
    
    detailsDiv.innerHTML = `
        <div class="detail-item">
            <div class="detail-label">Title</div>
            <div class="detail-value">${escapeHtml(issue.title || 'Untitled')}</div>
        </div>
        
        <div class="detail-item">
            <div class="detail-label">Feature</div>
            <div class="detail-value">${escapeHtml(issue.feature || 'General')}</div>
        </div>
        
        <div class="detail-item">
            <div class="detail-label">Priority</div>
            <div class="detail-value">
                <span class="priority-badge priority-${issue.priority || 'Low'}">
                    ${issue.priority || 'Low'}
                </span>
            </div>
        </div>
        
        <div class="detail-item">
            <div class="detail-label">Issue Date</div>
            <div class="detail-value">${formatDate(issue.issue_date)}</div>
        </div>
        
        <div class="detail-item">
            <div class="detail-label">Description</div>
            <div class="detail-value">${escapeHtml(issue.description || 'No description')}</div>
        </div>
        
        <div class="detail-item">
            <div class="detail-label">Root Cause</div>
            <div class="detail-value">${escapeHtml(issue.root_cause || 'Not specified')}</div>
        </div>
        
        ${stepsHtml}
        
        <div class="detail-item">
            <div class="detail-label">Resolution Date</div>
            <div class="detail-value">${formatDate(issue.resolution_date) || 'Not resolved'}</div>
        </div>
    `;
}

// Show delete confirmation modal
function showDeleteConfirmation() {
    if (!selectedIssueId) return;
    
    const issue = currentIssues.find(i => i.id === selectedIssueId);
    
    // Create modal
    const modalOverlay = document.createElement('div');
    modalOverlay.className = 'modal-overlay';
    modalOverlay.innerHTML = `
        <div class="modal-content">
            <h3>Delete Issue</h3>
            <p>Are you sure you want to delete "${escapeHtml(issue.title)}"?</p>
            <p style="font-size: 13px; color: #e53e3e;">This action cannot be undone.</p>
            <div class="modal-buttons">
                <button class="modal-cancel">Cancel</button>
                <button class="modal-confirm">Delete</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modalOverlay);
    
    // Handle cancel
    modalOverlay.querySelector('.modal-cancel').addEventListener('click', () => {
        modalOverlay.remove();
    });
    
    // Handle confirm delete
    modalOverlay.querySelector('.modal-confirm').addEventListener('click', async () => {
        await deleteIssue(selectedIssueId);
        modalOverlay.remove();
    });
    
    // Close on overlay click
    modalOverlay.addEventListener('click', (e) => {
        if (e.target === modalOverlay) {
            modalOverlay.remove();
        }
    });
}

// Delete issue function
async function deleteIssue(issueId) {
    try {
        const { error } = await supabase
            .from('issues_tracking')
            .delete()
            .eq('id', issueId);
        
        if (error) throw error;
        
        // Remove from local array
        currentIssues = currentIssues.filter(i => i.id !== issueId);
        
        // Clear selection
        selectedIssueId = null;
        
        // Refresh UI
        document.getElementById('issueCount').textContent = `${currentIssues.length} issues`;
        filterAndRenderIssues();
        renderIssueDetails(null);
        
        // Show success message (optional)
        alert('Issue deleted successfully!');
        
    } catch (error) {
        console.error('Error deleting issue:', error);
        alert('Error deleting issue. Check console for details.');
    }
}

// Helper function to escape HTML
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Helper function to format date
function formatDate(dateString) {
    if (!dateString) return 'Not set';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric' 
    });
}