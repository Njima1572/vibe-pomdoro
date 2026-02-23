/**
 * Pomodoro Timer — Web Dashboard Application
 * Real-time synchronized with the macOS app via WebSocket
 */

// ============================================
// Configuration
// ============================================

const WS_PORT = '{{WS_PORT}}' !== '{{' + 'WS_PORT}}' ? '{{WS_PORT}}' : '8095';
const WS_HOST = window.location.hostname || 'localhost';
const WS_URL = `ws://${WS_HOST}:${WS_PORT}`;

// ============================================
// Phase Colors
// ============================================

const PHASE_COLORS = {
    idle: {
        primary: '#636e72',
        glow: 'rgba(99, 110, 114, 0.2)',
        gradient: ['#636e72', '#74808a'],
        emoji: '🍅',
        name: 'Ready',
        subtitle: 'Press play to start'
    },
    work: {
        primary: '#ff6b6b',
        glow: 'rgba(255, 107, 107, 0.3)',
        gradient: ['#ff6b6b', '#ee5a24'],
        emoji: '🔥',
        name: 'Focus',
        subtitle: 'Stay focused'
    },
    short_break: {
        primary: '#4ecdc4',
        glow: 'rgba(78, 205, 196, 0.3)',
        gradient: ['#4ecdc4', '#44bd9e'],
        emoji: '☕',
        name: 'Short Break',
        subtitle: 'Take a breather'
    },
    long_break: {
        primary: '#6c5ce7',
        glow: 'rgba(108, 92, 231, 0.3)',
        gradient: ['#6c5ce7', '#a29bfe'],
        emoji: '🌿',
        name: 'Long Break',
        subtitle: 'Relax and recharge'
    }
};

// Map from snake_case (from Swift) to our keys
const PHASE_MAP = {
    'idle': 'idle',
    'work': 'work',
    'shortBreak': 'short_break',
    'short_break': 'short_break',
    'longBreak': 'long_break',
    'long_break': 'long_break'
};

// ============================================
// State
// ============================================

let state = {
    phase: 'idle',
    remaining_seconds: 1500,
    total_seconds: 1500,
    is_running: false,
    completed_pomodoros: 0,
    pomodoros_until_long_break: 4
};

let config = {
    work_duration: 1500,
    short_break_duration: 300,
    long_break_duration: 900,
    pomodoros_until_long_break: 4,
    auto_start_breaks: true,
    auto_start_pomodoros: false,
    play_sound_alert: true,
    show_notification_alert: true,
    show_full_screen_alert: true,
    global_shortcuts_enabled: true
};

let ws = null;
let reconnectTimer = null;
let localTimer = null;

// ============================================
// DOM Elements
// ============================================

const $ = id => document.getElementById(id);

const elements = {
    connectionStatus: $('connectionStatus'),
    phaseEmoji: $('phaseEmoji'),
    phaseName: $('phaseName'),
    phaseBadge: $('phaseBadge'),
    timerTime: $('timerTime'),
    timerSubtitle: $('timerSubtitle'),
    ringProgress: $('ringProgress'),
    gradientStop1: $('gradientStop1'),
    gradientStop2: $('gradientStop2'),
    playPauseBtn: $('playPauseBtn'),
    resetBtn: $('resetBtn'),
    skipBtn: $('skipBtn'),
    iconPlay: $('iconPlay'),
    iconPause: $('iconPause'),
    sessionDots: $('sessionDots'),
    sessionLabel: $('sessionLabel'),
    settingsToggle: $('settingsToggle'),
    settingsPanel: $('settingsPanel'),
    settingsClose: $('settingsClose'),
    applySettings: $('applySettings'),
    // Settings inputs
    workDuration: $('workDuration'),
    shortBreakDuration: $('shortBreakDuration'),
    longBreakDuration: $('longBreakDuration'),
    pomodorosUntilLongBreak: $('pomodorosUntilLongBreak'),
    autoStartBreaks: $('autoStartBreaks'),
    autoStartPomodoros: $('autoStartPomodoros'),
    playSoundAlert: $('playSoundAlert'),
    showNotificationAlert: $('showNotificationAlert'),
    showFullScreenAlert: $('showFullScreenAlert'),
    globalShortcutsEnabled: $('globalShortcutsEnabled'),
    // Settings values
    workDurationValue: $('workDurationValue'),
    shortBreakValue: $('shortBreakValue'),
    longBreakValue: $('longBreakValue'),
    pomodorosValue: $('pomodorosValue')
};

// ============================================
// WebSocket Connection
// ============================================

function connectWebSocket() {
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
        return;
    }

    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
        console.log('✅ WebSocket connected');
        updateConnectionStatus('connected');
        clearInterval(reconnectTimer);
        // Request current state
        ws.send(JSON.stringify({ action: 'getState' }));
    };

    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleServerMessage(data);
        } catch (e) {
            console.warn('Failed to parse message:', e);
        }
    };

    ws.onclose = () => {
        console.log('🔌 WebSocket disconnected');
        updateConnectionStatus('disconnected');
        scheduleReconnect();
    };

    ws.onerror = (error) => {
        console.error('❌ WebSocket error:', error);
        updateConnectionStatus('disconnected');
    };
}

function scheduleReconnect() {
    clearInterval(reconnectTimer);
    reconnectTimer = setInterval(() => {
        console.log('🔄 Attempting reconnect...');
        connectWebSocket();
    }, 3000);
}

function sendAction(action, payload = {}) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action, ...payload }));
    }
}

function updateConnectionStatus(status) {
    const el = elements.connectionStatus;
    el.className = 'connection-status ' + status;
    el.querySelector('.status-text').textContent =
        status === 'connected' ? 'Connected' :
            status === 'disconnected' ? 'Disconnected' : 'Connecting...';
}

// ============================================
// Message Handling
// ============================================

function handleServerMessage(data) {
    if (data.type === 'state' && data.state) {
        updateState(data.state);
        if (data.config) {
            updateConfig(data.config);
        }
    }
}

function updateState(newState) {
    const prevPhase = state.phase;

    state = {
        phase: PHASE_MAP[newState.phase] || newState.phase || 'idle',
        remaining_seconds: newState.remaining_seconds ?? newState.remainingSeconds ?? 0,
        total_seconds: newState.total_seconds ?? newState.totalSeconds ?? 1,
        is_running: newState.is_running ?? newState.isRunning ?? false,
        completed_pomodoros: newState.completed_pomodoros ?? newState.completedPomodoros ?? 0,
        pomodoros_until_long_break: newState.pomodoros_until_long_break ?? newState.pomodorosUntilLongBreak ?? 4
    };

    const phaseChanged = prevPhase !== state.phase;
    renderState(phaseChanged);

    // Start/stop local countdown for smooth animation
    clearInterval(localTimer);
    if (state.is_running) {
        localTimer = setInterval(localTick, 1000);
    }
}

function updateConfig(newConfig) {
    config = {
        work_duration: newConfig.work_duration ?? newConfig.workDuration ?? 1500,
        short_break_duration: newConfig.short_break_duration ?? newConfig.shortBreakDuration ?? 300,
        long_break_duration: newConfig.long_break_duration ?? newConfig.longBreakDuration ?? 900,
        pomodoros_until_long_break: newConfig.pomodoros_until_long_break ?? newConfig.pomodorosUntilLongBreak ?? 4,
        auto_start_breaks: newConfig.auto_start_breaks ?? newConfig.autoStartBreaks ?? true,
        auto_start_pomodoros: newConfig.auto_start_pomodoros ?? newConfig.autoStartPomodoros ?? false,
        play_sound_alert: newConfig.play_sound_alert ?? newConfig.playSoundAlert ?? true,
        show_notification_alert: newConfig.show_notification_alert ?? newConfig.showNotificationAlert ?? true,
        show_full_screen_alert: newConfig.show_full_screen_alert ?? newConfig.showFullScreenAlert ?? true,
        global_shortcuts_enabled: newConfig.global_shortcuts_enabled ?? newConfig.globalShortcutsEnabled ?? true
    };

    // Update settings UI
    elements.workDuration.value = config.work_duration / 60;
    elements.shortBreakDuration.value = config.short_break_duration / 60;
    elements.longBreakDuration.value = config.long_break_duration / 60;
    elements.pomodorosUntilLongBreak.value = config.pomodoros_until_long_break;
    elements.autoStartBreaks.checked = config.auto_start_breaks;
    elements.autoStartPomodoros.checked = config.auto_start_pomodoros;
    elements.playSoundAlert.checked = config.play_sound_alert;
    elements.showNotificationAlert.checked = config.show_notification_alert;
    elements.showFullScreenAlert.checked = config.show_full_screen_alert;
    elements.globalShortcutsEnabled.checked = config.global_shortcuts_enabled;
    updateSettingsValues();
}

// ============================================
// Local Timer (for smooth countdown between WS updates)
// ============================================

function localTick() {
    if (state.remaining_seconds > 0) {
        state.remaining_seconds--;
        renderTimer();
        renderProgress();
    } else {
        clearInterval(localTimer);
    }
}

// ============================================
// Rendering
// ============================================

function renderState(phaseChanged = false) {
    renderPhase(phaseChanged);
    renderTimer();
    renderProgress();
    renderControls();
    renderSessions();
    updatePageTitle();
}

function renderPhase(phaseChanged) {
    const phaseKey = state.phase;
    const phaseInfo = PHASE_COLORS[phaseKey] || PHASE_COLORS.idle;

    // Update CSS custom properties
    document.documentElement.style.setProperty('--phase-color', phaseInfo.primary);
    document.documentElement.style.setProperty('--phase-glow', phaseInfo.glow);

    // Update gradient
    elements.gradientStop1.style.stopColor = phaseInfo.gradient[0];
    elements.gradientStop2.style.stopColor = phaseInfo.gradient[1];

    // Update phase indicator
    elements.phaseEmoji.textContent = phaseInfo.emoji;
    elements.phaseName.textContent = phaseInfo.name;

    if (phaseChanged) {
        elements.phaseEmoji.style.animation = 'none';
        elements.phaseEmoji.offsetHeight; // Trigger reflow
        elements.phaseEmoji.style.animation = 'bounceIn 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55)';
    }

    // Status badge
    if (state.phase !== 'idle') {
        elements.phaseBadge.textContent = state.is_running ? 'RUNNING' : 'PAUSED';
        elements.phaseBadge.classList.add('visible');
    } else {
        elements.phaseBadge.classList.remove('visible');
    }

    // Subtitle
    if (state.phase === 'idle') {
        elements.timerSubtitle.textContent = phaseInfo.subtitle;
    } else {
        elements.timerSubtitle.textContent = state.is_running ? phaseInfo.subtitle : 'Paused';
    }
}

function renderTimer() {
    const minutes = Math.floor(state.remaining_seconds / 60);
    const seconds = state.remaining_seconds % 60;
    const timeStr = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    elements.timerTime.textContent = timeStr;

    if (state.is_running) {
        elements.timerTime.classList.add('running');
    } else {
        elements.timerTime.classList.remove('running');
    }
}

function renderProgress() {
    const circumference = 2 * Math.PI * 88; // r=88 from SVG
    const progress = state.total_seconds > 0
        ? 1.0 - (state.remaining_seconds / state.total_seconds)
        : 0;
    const offset = circumference * (1 - progress);
    elements.ringProgress.style.strokeDashoffset = offset;
}

function renderControls() {
    // Play/Pause icon
    if (state.is_running) {
        elements.iconPlay.style.display = 'none';
        elements.iconPause.style.display = 'block';
        elements.playPauseBtn.title = 'Pause';
    } else {
        elements.iconPlay.style.display = 'block';
        elements.iconPause.style.display = 'none';
        elements.playPauseBtn.title = state.phase === 'idle' ? 'Start' : 'Resume';
    }

    // Disable reset/skip when idle
    elements.resetBtn.disabled = state.phase === 'idle';
    elements.skipBtn.disabled = state.phase === 'idle';
}

function renderSessions() {
    const total = state.pomodoros_until_long_break;
    const completed = state.completed_pomodoros % total;

    // Build dots
    let dotsHtml = '';
    for (let i = 0; i < total; i++) {
        const isCompleted = i < completed;
        dotsHtml += `<div class="session-dot${isCompleted ? ' completed' : ''}"></div>`;
    }
    elements.sessionDots.innerHTML = dotsHtml;

    // Label
    const totalCompleted = state.completed_pomodoros;
    elements.sessionLabel.textContent = `${totalCompleted} session${totalCompleted !== 1 ? 's' : ''} completed`;
}

function updatePageTitle() {
    if (state.phase === 'idle') {
        document.title = 'Pomodoro Timer';
    } else {
        const minutes = Math.floor(state.remaining_seconds / 60);
        const seconds = state.remaining_seconds % 60;
        const timeStr = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
        const phaseInfo = PHASE_COLORS[state.phase] || PHASE_COLORS.idle;
        document.title = `${timeStr} — ${phaseInfo.name}`;
    }
}

// ============================================
// Settings
// ============================================

function updateSettingsValues() {
    elements.workDurationValue.textContent = `${elements.workDuration.value} min`;
    elements.shortBreakValue.textContent = `${elements.shortBreakDuration.value} min`;
    elements.longBreakValue.textContent = `${elements.longBreakDuration.value} min`;
    elements.pomodorosValue.textContent = elements.pomodorosUntilLongBreak.value;
}

function applySettings() {
    const newConfig = {
        work_duration: parseInt(elements.workDuration.value) * 60,
        short_break_duration: parseInt(elements.shortBreakDuration.value) * 60,
        long_break_duration: parseInt(elements.longBreakDuration.value) * 60,
        pomodoros_until_long_break: parseInt(elements.pomodorosUntilLongBreak.value),
        auto_start_breaks: elements.autoStartBreaks.checked,
        auto_start_pomodoros: elements.autoStartPomodoros.checked,
        play_sound_alert: elements.playSoundAlert.checked,
        show_notification_alert: elements.showNotificationAlert.checked,
        show_full_screen_alert: elements.showFullScreenAlert.checked,
        global_shortcuts_enabled: elements.globalShortcutsEnabled.checked
    };

    sendAction('updateSettings', { settings: newConfig });
    elements.settingsPanel.classList.remove('open');
}

// ============================================
// Event Listeners
// ============================================

function setupEventListeners() {
    // Timer controls
    elements.playPauseBtn.addEventListener('click', () => {
        sendAction('toggle');
    });

    elements.resetBtn.addEventListener('click', () => {
        sendAction('reset');
    });

    elements.skipBtn.addEventListener('click', () => {
        sendAction('skip');
    });

    // Settings
    elements.settingsToggle.addEventListener('click', () => {
        elements.settingsPanel.classList.toggle('open');
    });

    elements.settingsClose.addEventListener('click', () => {
        elements.settingsPanel.classList.remove('open');
    });

    elements.applySettings.addEventListener('click', applySettings);

    // Settings range inputs
    elements.workDuration.addEventListener('input', updateSettingsValues);
    elements.shortBreakDuration.addEventListener('input', updateSettingsValues);
    elements.longBreakDuration.addEventListener('input', updateSettingsValues);
    elements.pomodorosUntilLongBreak.addEventListener('input', updateSettingsValues);

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
        if (e.target.tagName === 'INPUT') return;

        switch (e.code) {
            case 'Space':
                e.preventDefault();
                sendAction('toggle');
                break;
            case 'KeyR':
                sendAction('reset');
                break;
            case 'KeyS':
                sendAction('skip');
                break;
            case 'Escape':
                elements.settingsPanel.classList.remove('open');
                break;
        }
    });
}

// ============================================
// Initialization
// ============================================

function init() {
    console.log('🍅 Pomodoro Web Dashboard initializing...');
    setupEventListeners();
    renderState();
    connectWebSocket();
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
