/**
 * Target Blitz - Main Game Script
 * A fast-paced reaction game with progressive difficulty
 * Features: Local storage, leaderboard, statistics, and visual effects
 */

// Game Configuration
const GAME_CONFIG = {
    duration: 60, // seconds
    targetTypes: {
        standard: { points: 10, color: '#4ECDC4', probability: 0.7 },
        bonus: { points: 25, color: '#FFD700', probability: 0.2 },
        bomb: { points: -20, color: '#FF4757', probability: 0.1 }
    },
    difficulty: {
        levels: 15,
        targetSize: { start: 80, end: 40 },
        targetSpeed: { start: 2, end: 8 },
        spawnInterval: { start: 2500, end: 1000 },
        targetLifetime: { start: 3000, end: 1500 }
    },
    combo: {
        maxMultiplier: 5,
        timeout: 2000 // milliseconds
    }
};

// Game State
let gameState = {
    status: 'menu', // menu, playing, paused, gameOver
    score: 0,
    level: 1,
    combo: 0,
    maxCombo: 0,
    timeLeft: GAME_CONFIG.duration,
    targetsHit: 0,
    totalClicks: 0,
    accuracy: 0,
    gameStartTime: null,
    lastHitTime: null,
    activeTargets: [],
    gameLoop: null,
    timerInterval: null
};

// Player Statistics
let playerStats = {
    gamesPlayed: 0,
    highScore: 0,
    totalTargets: 0,
    bestCombo: 0,
    totalScore: 0,
    playTime: 0,
    scoreHistory: []
};

// Leaderboard Data
let leaderboard = {
    today: [],
    week: [],
    alltime: []
};

// Game Settings
let gameSettings = {
    soundEffects: true,
    backgroundMusic: true,
    particleEffects: true
};

// DOM Elements - with fallback to prevent errors
const elements = {
    // Navigation
    navTabs: document.querySelectorAll('.nav-tab'),
    soundToggle: document.getElementById('soundToggle'),
    settingsBtn: document.getElementById('settingsBtn'),
    
    // Hero Section
    heroSection: document.getElementById('heroSection'),
    startGameBtn: document.getElementById('startGameBtn'),
    
    // Game Section
    gameSection: document.getElementById('gameSection'),
    currentScore: document.getElementById('currentScore'),
    gameTimer: document.getElementById('gameTimer'),
    comboMultiplier: document.getElementById('comboMultiplier'),
    currentLevel: document.getElementById('currentLevel'),
    pauseBtn: document.getElementById('pauseBtn'),
    restartBtn: document.getElementById('restartBtn'),
    gameArea: document.getElementById('gameArea'),
    gameCanvas: document.getElementById('gameCanvas'),
    gameOverlay: document.getElementById('gameOverlay'),
    pauseOverlay: document.getElementById('pauseOverlay'),
    gameOverOverlay: document.getElementById('gameOverOverlay'),
    resumeBtn: document.getElementById('resumeBtn'),
    playAgainBtn: document.getElementById('playAgainBtn'),
    submitScoreBtn: document.getElementById('submitScoreBtn'),
    finalScore: document.getElementById('finalScore'),
    levelProgress: document.getElementById('levelProgress'),
    accuracyProgress: document.getElementById('accuracyProgress'),
    
    // Leaderboard Section
    leaderboardSection: document.getElementById('leaderboardSection'),
    leaderboardList: document.getElementById('leaderboardList'),
    personalBest: document.querySelector('.best-score-value'),
    
    // Statistics Section
    statsSection: document.getElementById('statsSection'),
    gamesPlayed: document.getElementById('gamesPlayed'),
    highScore: document.getElementById('highScore'),
    totalTargets: document.getElementById('totalTargets'),
    bestCombo: document.getElementById('bestCombo'),
    averageScore: document.getElementById('averageScore'),
    playTime: document.getElementById('playTime'),
    statsChart: document.getElementById('statsChart'),
    
    // Modals
    scoreModal: document.getElementById('scoreModal'),
    settingsModal: document.getElementById('settingsModal'),
    modalScore: document.getElementById('modalScore'),
    playerName: document.getElementById('playerName'),
    cancelSubmit: document.getElementById('cancelSubmit'),
    confirmSubmit: document.getElementById('confirmSubmit'),
    closeSettings: document.getElementById('closeSettings'),
    
    // Settings
    soundEffectsToggle: document.getElementById('soundEffects'),
    backgroundMusicToggle: document.getElementById('backgroundMusic'),
    particleEffectsToggle: document.getElementById('particleEffects'),
    
    // Particle Canvas
    particleCanvas: document.getElementById('particleCanvas')
};

// Validate elements exist
function validateElements() {
    const missing = [];
    Object.entries(elements).forEach(([key, element]) => {
        if (!element && key !== 'particleCanvas') {
            missing.push(key);
        }
    });
    
    if (missing.length > 0) {
        console.error('Missing elements:', missing);
        return false;
    }
    return true;
}

// Canvas and Context
let canvas, ctx;
let particleCanvas, particleCtx;

// Load game data from localStorage
function loadGameData() {
    const savedStats = localStorage.getItem('targetBlitzStats');
    const savedLeaderboard = localStorage.getItem('targetBlitzLeaderboard');
    const savedSettings = localStorage.getItem('targetBlitzSettings');
    
    if (savedStats) {
        playerStats = { ...playerStats, ...JSON.parse(savedStats) };
    }
    
    if (savedLeaderboard) {
        leaderboard = { ...leaderboard, ...JSON.parse(savedLeaderboard) };
    }
    
    if (savedSettings) {
        gameSettings = { ...gameSettings, ...JSON.parse(savedSettings) };
        updateSettingsUI();
    }
}

// Save game data to localStorage
function saveGameData() {
    localStorage.setItem('targetBlitzStats', JSON.stringify(playerStats));
    localStorage.setItem('targetBlitzLeaderboard', JSON.stringify(leaderboard));
    localStorage.setItem('targetBlitzSettings', JSON.stringify(gameSettings));
}

// Initialize the game
function initGame() {
    console.log('Initializing Target Blitz game...');
    
    // Validate elements exist
    if (!validateElements()) {
        console.error('Cannot initialize game - missing required elements');
        return;
    }
    
    console.log('All DOM elements found successfully');
    
    loadGameData();
    setupCanvas();
    setupEventListeners();
    updateStatsDisplay();
    updateLeaderboard();
    createHeroBackground();
    
    // Initialize audio context (for future sound effects)
    initAudio();
    
    // Ensure canvas is ready
    setTimeout(() => {
        resizeCanvas();
        // Force a redraw
        if (ctx) {
            ctx.fillStyle = '#f8f9fa';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        }
    }, 100);
    
    console.log('Game initialization complete');
}

// Setup canvas elements
function setupCanvas() {
    // Main game canvas
    canvas = elements.gameCanvas;
    ctx = canvas.getContext('2d');
    
    // Particle canvas
    particleCanvas = elements.particleCanvas;
    particleCtx = particleCanvas.getContext('2d');
    
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);
}

// Resize canvas to fit container
function resizeCanvas() {
    // Force canvas to match container size
    const container = canvas.parentElement;
    const rect = container.getBoundingClientRect();
    
    canvas.width = rect.width;
    canvas.height = rect.height;
    
    particleCanvas.width = rect.width;
    particleCanvas.height = rect.height;
}

// Setup event listeners
function setupEventListeners() {
    console.log('Setting up event listeners...');
    
    // Navigation
    elements.navTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            console.log('Nav tab clicked:', tab.dataset.tab);
            switchTab(tab.dataset.tab);
        });
    });
    
    // Hero section
    elements.startGameBtn.addEventListener('click', () => {
        console.log('Start game button clicked');
        startGame();
    });
    
    // Game controls
    elements.pauseBtn.addEventListener('click', () => {
        console.log('Pause button clicked');
        togglePause();
    });
    
    elements.restartBtn.addEventListener('click', () => {
        console.log('Restart button clicked');
        restartGame();
    });
    
    elements.resumeBtn.addEventListener('click', () => {
        console.log('Resume button clicked');
        resumeGame();
    });
    
    elements.playAgainBtn.addEventListener('click', () => {
        console.log('Play again button clicked');
        startGame();
    });
    
    elements.submitScoreBtn.addEventListener('click', () => {
        console.log('Submit score button clicked');
        showScoreModal();
    });
    
    // Canvas interactions
    canvas.addEventListener('click', handleCanvasClick);
    canvas.addEventListener('touchstart', handleTouchStart, { passive: false });
    
    // Modal controls
    elements.cancelSubmit.addEventListener('click', () => {
        console.log('Cancel button clicked');
        hideScoreModal();
    });
    
    elements.confirmSubmit.addEventListener('click', () => {
        console.log('Confirm submit button clicked');
        submitScore();
    });
    
    elements.closeSettings.addEventListener('click', () => {
        console.log('Close settings button clicked');
        hideSettingsModal();
    });
    
    elements.settingsBtn.addEventListener('click', () => {
        console.log('Settings button clicked');
        showSettingsModal();
    });
    
    // Settings toggles
    elements.soundEffectsToggle.addEventListener('change', updateSettings);
    elements.backgroundMusicToggle.addEventListener('change', updateSettings);
    elements.particleEffectsToggle.addEventListener('change', updateSettings);
    
    // Sound toggle
    elements.soundToggle.addEventListener('click', () => {
        console.log('Sound toggle clicked');
        toggleSound();
    });
    
    // Keyboard controls
    document.addEventListener('keydown', handleKeyPress);
    
    // Prevent context menu on canvas
    canvas.addEventListener('contextmenu', e => e.preventDefault());
    
    console.log('Event listeners setup complete');
}

// Switch between game sections
function switchTab(tabName) {
    // Update nav tabs
    elements.navTabs.forEach(tab => {
        tab.classList.toggle('active', tab.dataset.tab === tabName);
    });
    
    // Hide all sections
    elements.heroSection.style.display = 'none';
    elements.gameSection.style.display = 'none';
    elements.leaderboardSection.style.display = 'none';
    elements.statsSection.style.display = 'none';
    
    // Show selected section
    switch (tabName) {
        case 'game':
            elements.heroSection.style.display = 'flex';
            break;
        case 'leaderboard':
            elements.leaderboardSection.style.display = 'block';
            updateLeaderboard();
            break;
        case 'stats':
            elements.statsSection.style.display = 'block';
            updateStatsChart();
            break;
    }
}

// Start a new game
function startGame() {
    // Reset game state
    gameState = {
        status: 'playing',
        score: 0,
        level: 1,
        combo: 0,
        maxCombo: 0,
        timeLeft: GAME_CONFIG.duration,
        targetsHit: 0,
        totalClicks: 0,
        accuracy: 0,
        gameStartTime: Date.now(),
        lastHitTime: null,
        activeTargets: [],
        gameLoop: null,
        timerInterval: null
    };
    
    // Hide hero section and show game section instantly
    elements.heroSection.style.display = 'none';
    elements.gameSection.style.display = 'block';
    
    // Ensure canvas is properly sized
    resizeCanvas();
    
    // Update UI
    updateGameUI();
    hideGameOverlay();
    
    // Start game loop
    gameState.gameLoop = requestAnimationFrame(gameLoop);
    gameState.timerInterval = setInterval(updateTimer, 1000);
    
    // Spawn first target immediately
    setTimeout(() => {
        spawnTarget();
    }, 100);
}

// Main game loop
function gameLoop() {
    if (gameState.status !== 'playing') return;
    
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Update and draw targets
    updateTargets();
    drawTargets();
    
    // Update particles
    updateParticles();
    
    // Continue loop
    gameState.gameLoop = requestAnimationFrame(gameLoop);
}

// Update targets
function updateTargets() {
    const currentTime = Date.now();
    
    gameState.activeTargets = gameState.activeTargets.filter(target => {
        // Update position
        target.x += target.vx;
        target.y += target.vy;
        
        // Bounce off walls
        if (target.x <= target.radius || target.x >= canvas.width - target.radius) {
            target.vx *= -1;
        }
        if (target.y <= target.radius || target.y >= canvas.height - target.radius) {
            target.vy *= -1;
        }
        
        // Check lifetime
        if (currentTime - target.created > target.lifetime) {
            // Target expired
            if (target.type === 'bomb') {
                // Bombs don't penalize when they expire
            } else {
                // Missed target
                gameState.combo = 0;
            }
            return false;
        }
        
        return true;
    });
    
    // Spawn new targets if there are too few
    if (gameState.activeTargets.length < 3 && Math.random() < 0.1) {
        spawnTarget();
    }
}

// Draw targets on canvas
function drawTargets() {
    gameState.activeTargets.forEach(target => {
        ctx.save();
        
        // Draw target based on type
        switch (target.type) {
            case 'standard':
                drawStandardTarget(target);
                break;
            case 'bonus':
                drawBonusTarget(target);
                break;
            case 'bomb':
                drawBombTarget(target);
                break;
        }
        
        ctx.restore();
    });
}

// Draw standard circular target
function drawStandardTarget(target) {
    const gradient = ctx.createRadialGradient(
        target.x, target.y, 0,
        target.x, target.y, target.radius
    );
    gradient.addColorStop(0, '#FFFFFF');
    gradient.addColorStop(1, target.color);
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(target.x, target.y, target.radius, 0, Math.PI * 2);
    ctx.fill();
    
    // Draw rings
    ctx.strokeStyle = target.color;
    ctx.lineWidth = 2;
    for (let i = 1; i <= 3; i++) {
        ctx.beginPath();
        ctx.arc(target.x, target.y, target.radius * (i / 3), 0, Math.PI * 2);
        ctx.stroke();
    }
    
    // Center dot
    ctx.fillStyle = target.color;
    ctx.beginPath();
    ctx.arc(target.x, target.y, 4, 0, Math.PI * 2);
    ctx.fill();
}

// Draw bonus star target
function drawBonusTarget(target) {
    ctx.fillStyle = target.color;
    ctx.strokeStyle = '#FFA500';
    ctx.lineWidth = 2;
    
    // Draw star
    drawStar(target.x, target.y, target.radius, 5);
    
    // Add glow effect
    ctx.shadowColor = target.color;
    ctx.shadowBlur = 10;
    ctx.fill();
    ctx.shadowBlur = 0;
}

// Draw bomb target
function drawBombTarget(target) {
    // Red circle
    const gradient = ctx.createRadialGradient(
        target.x, target.y, 0,
        target.x, target.y, target.radius
    );
    gradient.addColorStop(0, '#FF6B6B');
    gradient.addColorStop(1, target.color);
    
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(target.x, target.y, target.radius, 0, Math.PI * 2);
    ctx.fill();
    
    // Draw X
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    
    const size = target.radius * 0.6;
    ctx.beginPath();
    ctx.moveTo(target.x - size, target.y - size);
    ctx.lineTo(target.x + size, target.y + size);
    ctx.moveTo(target.x + size, target.y - size);
    ctx.lineTo(target.x - size, target.y + size);
    ctx.stroke();
}

// Draw star shape
function drawStar(x, y, radius, points) {
    const outerRadius = radius;
    const innerRadius = radius * 0.4;
    
    ctx.beginPath();
    for (let i = 0; i < points * 2; i++) {
        const angle = (i * Math.PI) / points;
        const r = i % 2 === 0 ? outerRadius : innerRadius;
        const px = x + Math.cos(angle) * r;
        const py = y + Math.sin(angle) * r;
        
        if (i === 0) {
            ctx.moveTo(px, py);
        } else {
            ctx.lineTo(px, py);
        }
    }
    ctx.closePath();
}

// Spawn a new target
function spawnTarget() {
    const level = gameState.level;
    const difficulty = GAME_CONFIG.difficulty;
    
    // Calculate target properties based on level
    const sizeProgress = Math.min((level - 1) / (difficulty.levels - 1), 1);
    const speedProgress = Math.min((level - 1) / (difficulty.levels - 1), 1);
    
    const radius = difficulty.targetSize.start - 
                   (difficulty.targetSize.start - difficulty.targetSize.end) * sizeProgress;
    const speed = difficulty.targetSpeed.start + 
                  (difficulty.targetSpeed.end - difficulty.targetSpeed.start) * speedProgress;
    const lifetime = difficulty.targetLifetime.start - 
                     (difficulty.targetLifetime.start - difficulty.targetLifetime.end) * speedProgress;
    
    // Determine target type
    const rand = Math.random();
    let targetType = 'standard';
    let cumulativeProbability = 0;
    
    for (const [type, config] of Object.entries(GAME_CONFIG.targetTypes)) {
        cumulativeProbability += config.probability;
        if (rand <= cumulativeProbability) {
            targetType = type;
            break;
        }
    }
    
    // Create target
    const target = {
        x: radius + Math.random() * (canvas.width - radius * 2),
        y: radius + Math.random() * (canvas.height - radius * 2),
        vx: (Math.random() - 0.5) * speed,
        vy: (Math.random() - 0.5) * speed,
        radius: radius,
        type: targetType,
        color: GAME_CONFIG.targetTypes[targetType].color,
        created: Date.now(),
        lifetime: lifetime
    };
    
    gameState.activeTargets.push(target);
}

// Handle canvas click
function handleCanvasClick(event) {
    if (gameState.status !== 'playing') return;
    
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    
    processClick(x, y);
}

// Handle touch events
function handleTouchStart(event) {
    event.preventDefault();
    if (gameState.status !== 'playing') return;
    
    const rect = canvas.getBoundingClientRect();
    const touch = event.touches[0];
    const x = touch.clientX - rect.left;
    const y = touch.clientY - rect.top;
    
    processClick(x, y);
}

// Process click/touch on targets
function processClick(x, y) {
    gameState.totalClicks++;
    let hitTarget = false;
    
    // Check each target
    gameState.activeTargets = gameState.activeTargets.filter(target => {
        const distance = Math.sqrt(
            Math.pow(x - target.x, 2) + Math.pow(y - target.y, 2)
        );
        
        if (distance <= target.radius) {
            // Hit!
            hitTarget = true;
            handleTargetHit(target);
            return false; // Remove target
        }
        return true; // Keep target
    });
    
    if (!hitTarget) {
        // Miss - reset combo
        gameState.combo = 0;
        createMissEffect(x, y);
    }
    
    updateGameUI();
}

// Handle target hit
function handleTargetHit(target) {
    const points = GAME_CONFIG.targetTypes[target.type].points;
    const currentTime = Date.now();
    
    if (target.type === 'bomb') {
        // Bomb hit - penalty and screen shake
        gameState.score = Math.max(0, gameState.score + points);
        gameState.combo = 0;
        createExplosionEffect(target.x, target.y, '#FF4757');
        shakeScreen();
        playSound('bomb');
    } else {
        // Regular target hit
        gameState.targetsHit++;
        
        // Update combo
        if (gameState.lastHitTime && currentTime - gameState.lastHitTime < GAME_CONFIG.combo.timeout) {
            gameState.combo = Math.min(gameState.combo + 1, GAME_CONFIG.combo.maxMultiplier);
        } else {
            gameState.combo = 1;
        }
        
        gameState.lastHitTime = currentTime;
        gameState.maxCombo = Math.max(gameState.maxCombo, gameState.combo);
        
        // Calculate score with combo multiplier
        const comboBonus = gameState.combo > 1 ? Math.floor(points * 0.5 * (gameState.combo - 1)) : 0;
        const totalPoints = points + comboBonus;
        gameState.score += totalPoints;
        
        // Create hit effect
        createHitEffect(target.x, target.y, totalPoints);
        createExplosionEffect(target.x, target.y, target.color);
        playSound('hit');
        
        // Check for level up
        checkLevelUp();
    }
}

// Check if player should level up
function checkLevelUp() {
    const newLevel = Math.floor(gameState.score / 100) + 1;
    if (newLevel > gameState.level && newLevel <= GAME_CONFIG.difficulty.levels) {
        gameState.level = newLevel;
        createLevelUpEffect();
        playSound('levelup');
    }
}

// Update game timer
function updateTimer() {
    if (gameState.status !== 'playing') return;
    
    gameState.timeLeft--;
    
    if (gameState.timeLeft <= 0) {
        endGame();
    } else {
        updateGameUI();
    }
}

// End the game
function endGame() {
    gameState.status = 'gameOver';
    
    // Clear intervals
    if (gameState.timerInterval) {
        clearInterval(gameState.timerInterval);
    }
    
    if (gameState.gameLoop) {
        cancelAnimationFrame(gameState.gameLoop);
    }
    
    // Calculate final stats
    gameState.accuracy = gameState.totalClicks > 0 ? 
        Math.round((gameState.targetsHit / gameState.totalClicks) * 100) : 0;
    
    // Update player stats
    playerStats.gamesPlayed++;
    playerStats.totalScore += gameState.score;
    playerStats.totalTargets += gameState.targetsHit;
    playerStats.bestCombo = Math.max(playerStats.bestCombo, gameState.maxCombo);
    playerStats.highScore = Math.max(playerStats.highScore, gameState.score);
    
    const gameTime = Math.round((Date.now() - gameState.gameStartTime) / 1000);
    playerStats.playTime += gameTime;
    
    // Add to score history
    playerStats.scoreHistory.push({
        score: gameState.score,
        date: new Date().toISOString(),
        level: gameState.level,
        accuracy: gameState.accuracy
    });
    
    // Keep only last 50 scores
    if (playerStats.scoreHistory.length > 50) {
        playerStats.scoreHistory = playerStats.scoreHistory.slice(-50);
    }
    
    // Save data
    saveGameData();
    
    // Show game over screen
    elements.finalScore.textContent = gameState.score;
    showGameOverlay('gameOver');
    
    // Update displays
    updateStatsDisplay();
    
    // Check for high score
    if (gameState.score === playerStats.highScore && gameState.score > 0) {
        setTimeout(() => showScoreModal(), 1000);
    }
    
    playSound('gameover');
}

// Toggle pause
function togglePause() {
    if (gameState.status === 'playing') {
        pauseGame();
    } else if (gameState.status === 'paused') {
        resumeGame();
    }
}

// Pause the game
function pauseGame() {
    gameState.status = 'paused';
    
    if (gameState.gameLoop) {
        cancelAnimationFrame(gameState.gameLoop);
    }
    
    if (gameState.timerInterval) {
        clearInterval(gameState.timerInterval);
    }
    
    showGameOverlay('pause');
}

// Resume the game
function resumeGame() {
    gameState.status = 'playing';
    
    gameState.gameLoop = requestAnimationFrame(gameLoop);
    gameState.timerInterval = setInterval(updateTimer, 1000);
    
    hideGameOverlay();
}

// Restart the game
function restartGame() {
    if (gameState.status === 'playing' || gameState.status === 'paused') {
        endGame();
    }
    startGame();
}

// Show game overlay
function showGameOverlay(type) {
    elements.gameOverlay.classList.add('active');
    
    if (type === 'pause') {
        elements.pauseOverlay.style.display = 'block';
        elements.gameOverOverlay.style.display = 'none';
    } else if (type === 'gameOver') {
        elements.pauseOverlay.style.display = 'none';
        elements.gameOverOverlay.style.display = 'block';
    }
}

// Hide game overlay
function hideGameOverlay() {
    elements.gameOverlay.classList.remove('active');
}

// Update game UI
function updateGameUI() {
    elements.currentScore.textContent = gameState.score;
    elements.gameTimer.textContent = gameState.timeLeft;
    elements.comboMultiplier.textContent = `${gameState.combo}x`;
    elements.currentLevel.textContent = gameState.level;
    
    // Update progress bars
    const levelProgress = ((gameState.score % 100) / 100) * 100;
    elements.levelProgress.style.width = `${levelProgress}%`;
    
    const accuracyProgress = gameState.accuracy;
    elements.accuracyProgress.style.width = `${accuracyProgress}%`;
    
    // Animate score changes
    animateScoreUpdate(elements.currentScore);
}

// Animate score updates
function animateScoreUpdate(element) {
    anime({
        targets: element,
        scale: [1, 1.1, 1],
        duration: 300,
        easing: 'easeOutElastic(1, .8)'
    });
}

// Create hit effect
function createHitEffect(x, y, points) {
    if (!gameSettings.particleEffects) return;
    
    // Create floating score text
    const scoreText = document.createElement('div');
    scoreText.className = 'hit-score';
    scoreText.textContent = `+${points}`;
    scoreText.style.cssText = `
        position: absolute;
        left: ${x}px;
        top: ${y}px;
        color: #4ECDC4;
        font-weight: bold;
        font-size: 1.2rem;
        pointer-events: none;
        z-index: 1000;
    `;
    
    elements.gameArea.appendChild(scoreText);
    
    anime({
        targets: scoreText,
        translateY: -50,
        opacity: [1, 0],
        scale: [1, 1.5],
        duration: 1000,
        easing: 'easeOutQuart',
        complete: () => scoreText.remove()
    });
}

// Create miss effect
function createMissEffect(x, y) {
    if (!gameSettings.particleEffects) return;
    
    // Create small red X
    const missMarker = document.createElement('div');
    missMarker.textContent = '✗';
    missMarker.style.cssText = `
        position: absolute;
        left: ${x}px;
        top: ${y}px;
        color: #FF4757;
        font-size: 1.5rem;
        pointer-events: none;
        z-index: 1000;
    `;
    
    elements.gameArea.appendChild(missMarker);
    
    anime({
        targets: missMarker,
        scale: [0.5, 1.2, 0],
        opacity: [0, 1, 0],
        duration: 800,
        easing: 'easeOutQuart',
        complete: () => missMarker.remove()
    });
}

// Create explosion effect
function createExplosionEffect(x, y, color) {
    if (!gameSettings.particleEffects) return;
    
    // Create multiple particles
    for (let i = 0; i < 12; i++) {
        createParticle(x, y, color);
    }
}

// Create individual particle
function createParticle(x, y, color) {
    const particle = {
        x: x,
        y: y,
        vx: (Math.random() - 0.5) * 10,
        vy: (Math.random() - 0.5) * 10,
        life: 1.0,
        decay: 0.02,
        color: color,
        size: Math.random() * 8 + 4
    };
    
    particles.push(particle);
}

// Particle system
let particles = [];

// Update particles
function updateParticles() {
    particleCtx.clearRect(0, 0, particleCanvas.width, particleCanvas.height);
    
    particles = particles.filter(particle => {
        // Update position
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.vy += 0.3; // gravity
        
        // Update life
        particle.life -= particle.decay;
        
        // Draw particle
        if (particle.life > 0) {
            particleCtx.save();
            particleCtx.globalAlpha = particle.life;
            particleCtx.fillStyle = particle.color;
            particleCtx.beginPath();
            particleCtx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
            particleCtx.fill();
            particleCtx.restore();
            
            return true;
        }
        
        return false;
    });
}

// Screen shake effect
function shakeScreen() {
    anime({
        targets: elements.gameArea,
        translateX: [0, -5, 5, -5, 5, 0],
        duration: 500,
        easing: 'easeOutQuart'
    });
}

// Level up effect
function createLevelUpEffect() {
    // Create celebration particles
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    
    for (let i = 0; i < 20; i++) {
        setTimeout(() => {
            createParticle(
                centerX + (Math.random() - 0.5) * 200,
                centerY + (Math.random() - 0.5) * 200,
                '#FFD700'
            );
        }, i * 50);
    }
}

// Show score submission modal
function showScoreModal() {
    elements.modalScore.textContent = gameState.score;
    elements.scoreModal.classList.add('active');
    elements.playerName.focus();
}

// Hide score modal
function hideScoreModal() {
    elements.scoreModal.classList.remove('active');
    elements.playerName.value = '';
}

// Submit score to leaderboard
function submitScore() {
    const playerName = elements.playerName.value.trim() || 'Anonymous';
    
    const scoreEntry = {
        name: playerName,
        score: gameState.score,
        level: gameState.level,
        accuracy: gameState.accuracy,
        date: new Date().toISOString()
    };
    
    // Add to all-time leaderboard
    leaderboard.alltime.push(scoreEntry);
    leaderboard.alltime.sort((a, b) => b.score - a.score);
    leaderboard.alltime = leaderboard.alltime.slice(0, 10); // Keep top 10
    
    // Add to weekly leaderboard
    leaderboard.week.push(scoreEntry);
    leaderboard.week.sort((a, b) => b.score - a.score);
    leaderboard.week = leaderboard.week.slice(0, 10);
    
    // Add to daily leaderboard
    leaderboard.today.push(scoreEntry);
    leaderboard.today.sort((a, b) => b.score - a.score);
    leaderboard.today = leaderboard.today.slice(0, 10);
    
    // Save and update
    saveGameData();
    updateLeaderboard();
    hideScoreModal();
    
    // Show success message
    showNotification('Score submitted successfully!');
}

// Show settings modal
function showSettingsModal() {
    updateSettingsUI();
    elements.settingsModal.classList.add('active');
}

// Hide settings modal
function hideSettingsModal() {
    elements.settingsModal.classList.remove('active');
}

// Update settings UI
function updateSettingsUI() {
    elements.soundEffectsToggle.checked = gameSettings.soundEffects;
    elements.backgroundMusicToggle.checked = gameSettings.backgroundMusic;
    elements.particleEffectsToggle.checked = gameSettings.particleEffects;
    
    elements.soundToggle.textContent = gameSettings.soundEffects ? '🔊' : '🔇';
}

// Update settings
function updateSettings() {
    gameSettings.soundEffects = elements.soundEffectsToggle.checked;
    gameSettings.backgroundMusic = elements.backgroundMusicToggle.checked;
    gameSettings.particleEffects = elements.particleEffectsToggle.checked;
    
    updateSettingsUI();
    saveGameData();
}

// Toggle sound
function toggleSound() {
    gameSettings.soundEffects = !gameSettings.soundEffects;
    updateSettingsUI();
    saveGameData();
}

// Handle keyboard input
function handleKeyPress(event) {
    switch (event.code) {
        case 'Space':
            if (gameState.status === 'menu') {
                event.preventDefault();
                startGame();
            } else if (gameState.status === 'gameOver') {
                event.preventDefault();
                startGame();
            } else if (gameState.status === 'playing') {
                event.preventDefault();
                pauseGame();
            } else if (gameState.status === 'paused') {
                event.preventDefault();
                resumeGame();
            }
            break;
        case 'Escape':
            if (gameState.status === 'playing') {
                pauseGame();
            } else if (gameState.status === 'paused') {
                resumeGame();
            }
            break;
        case 'Enter':
            if (elements.scoreModal.classList.contains('active')) {
                submitScore();
            }
            break;
    }
}

// Update statistics display
function updateStatsDisplay() {
    elements.gamesPlayed.textContent = playerStats.gamesPlayed;
    elements.highScore.textContent = playerStats.highScore;
    elements.totalTargets.textContent = playerStats.totalTargets;
    elements.bestCombo.textContent = playerStats.bestCombo;
    elements.averageScore.textContent = playerStats.gamesPlayed > 0 ? 
        Math.round(playerStats.totalScore / playerStats.gamesPlayed) : 0;
    elements.playTime.textContent = `${Math.round(playerStats.playTime / 3600)}h`;
    
    elements.personalBest.textContent = playerStats.highScore;
}

// Update leaderboard display
function updateLeaderboard() {
    const leaderboardData = leaderboard.alltime; // Default to all-time
    
    elements.leaderboardList.innerHTML = '';
    
    leaderboardData.forEach((entry, index) => {
        const entryElement = document.createElement('div');
        entryElement.className = 'leaderboard-entry';
        entryElement.innerHTML = `
            <div class="leaderboard-rank">#${index + 1}</div>
            <div class="leaderboard-name">${entry.name}</div>
            <div class="leaderboard-score">${entry.score}</div>
        `;
        
        elements.leaderboardList.appendChild(entryElement);
    });
    
    if (leaderboardData.length === 0) {
        elements.leaderboardList.innerHTML = '<p style="text-align: center; color: #6C757D; padding: 2rem;">No scores yet. Be the first to play!</p>';
    }
}

// Update statistics chart
function updateStatsChart() {
    if (!elements.statsChart || playerStats.scoreHistory.length === 0) return;
    
    const chart = echarts.init(elements.statsChart);
    
    const option = {
        title: {
            text: 'Score History',
            left: 'center',
            textStyle: {
                color: '#2C3E50',
                fontSize: 16,
                fontWeight: 'bold'
            }
        },
        tooltip: {
            trigger: 'axis',
            formatter: function(params) {
                const data = params[0];
                return `Game ${data.dataIndex + 1}<br/>Score: ${data.value}`;
            }
        },
        xAxis: {
            type: 'category',
            data: playerStats.scoreHistory.map((_, index) => `Game ${index + 1}`),
            axisLabel: {
                color: '#6C757D'
            }
        },
        yAxis: {
            type: 'value',
            axisLabel: {
                color: '#6C757D'
            }
        },
        series: [{
            data: playerStats.scoreHistory.map(entry => entry.score),
            type: 'line',
            smooth: true,
            lineStyle: {
                color: '#FF6B6B',
                width: 3
            },
            itemStyle: {
                color: '#4ECDC4'
            },
            areaStyle: {
                color: {
                    type: 'linear',
                    x: 0,
                    y: 0,
                    x2: 0,
                    y2: 1,
                    colorStops: [{
                        offset: 0, color: 'rgba(255, 107, 107, 0.3)'
                    }, {
                        offset: 1, color: 'rgba(255, 107, 107, 0.1)'
                    }]
                }
            }
        }]
    };
    
    chart.setOption(option);
    
    // Resize chart on window resize
    window.addEventListener('resize', () => {
        chart.resize();
    });
}

// Create hero background animation
function createHeroBackground() {
    const heroBackground = elements.heroBackground;
    if (!heroBackground) return;
    
    // Create floating particles
    for (let i = 0; i < 20; i++) {
        const particle = document.createElement('div');
        particle.style.cssText = `
            position: absolute;
            width: ${Math.random() * 20 + 10}px;
            height: ${Math.random() * 20 + 10}px;
            background: rgba(255, 107, 107, ${Math.random() * 0.3});
            border-radius: 50%;
            left: ${Math.random() * 100}%;
            top: ${Math.random() * 100}%;
            animation: float ${Math.random() * 10 + 10}s infinite linear;
        `;
        
        heroBackground.appendChild(particle);
    }
}

// Show notification
function showNotification(message) {
    const notification = document.createElement('div');
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 100px;
        right: 20px;
        background: #4ECDC4;
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        z-index: 3000;
        font-weight: 600;
    `;
    
    document.body.appendChild(notification);
    
    anime({
        targets: notification,
        translateX: [300, 0],
        opacity: [0, 1],
        duration: 300,
        easing: 'easeOutQuart'
    });
    
    setTimeout(() => {
        anime({
            targets: notification,
            translateX: [0, 300],
            opacity: [1, 0],
            duration: 300,
            easing: 'easeInQuart',
            complete: () => notification.remove()
        });
    }, 3000);
}

// Audio system (placeholder for future implementation)
function initAudio() {
    // Initialize Web Audio API for sound effects
    try {
        window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    } catch (e) {
        console.log('Web Audio API not supported');
    }
}

// Play sound effect
function playSound(type) {
    if (!gameSettings.soundEffects || !window.audioContext) return;
    
    // Create simple tones for different game events
    const frequencies = {
        hit: 800,
        bomb: 200,
        levelup: 1000,
        gameover: 300
    };
    
    const frequency = frequencies[type] || 440;
    
    try {
        const oscillator = window.audioContext.createOscillator();
        const gainNode = window.audioContext.createGain();
        
        oscillator.connect(gainNode);
        gainNode.connect(window.audioContext.destination);
        
        oscillator.frequency.value = frequency;
        oscillator.type = 'sine';
        
        gainNode.gain.setValueAtTime(0.1, window.audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, window.audioContext.currentTime + 0.2);
        
        oscillator.start(window.audioContext.currentTime);
        oscillator.stop(window.audioContext.currentTime + 0.2);
    } catch (e) {
        console.log('Error playing sound:', e);
    }
}

// CSS animations for floating particles
const style = document.createElement('style');
style.textContent = `
    @keyframes float {
        0% { transform: translateY(100vh) rotate(0deg); opacity: 0; }
        10% { opacity: 1; }
        90% { opacity: 1; }
        100% { transform: translateY(-100px) rotate(360deg); opacity: 0; }
    }
    
    .hit-score {
        font-family: 'JetBrains Mono', monospace;
        font-weight: bold;
        text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
    }
`;
document.head.appendChild(style);

// Initialize the game when DOM is loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initGame);
} else {
    // DOM is already loaded
    initGame();
}

// Fallback initialization
window.addEventListener('load', () => {
    console.log('Window loaded - game should be ready');
});

// Export for potential module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { initGame, startGame, gameState, playerStats };
}