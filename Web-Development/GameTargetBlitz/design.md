# Target Blitz - Visual Design Document

## Design Philosophy

### Color Palette
- **Primary Colors**: Vibrant coral (#FF6B6B), electric blue (#4ECDC4), sunny yellow (#FFE66D)
- **Secondary Colors**: Soft mint (#95E1D3), warm peach (#FFA07A), lavender (#DDA0DD)
- **Neutral Colors**: Pure white (#FFFFFF), charcoal gray (#2C3E50), light gray (#F8F9FA)
- **Accent Colors**: Gold (#FFD700) for bonuses, red (#FF4757) for warnings/danger

### Typography
- **Display Font**: "Fredoka One" - playful, rounded sans-serif for headings and game title
- **Body Font**: "Nunito" - clean, friendly sans-serif for UI text and scores
- **Monospace Font**: "JetBrains Mono" - for score displays and timers

### Visual Language
- **Rounded Design**: All buttons, cards, and interactive elements use 12px-20px border radius
- **Soft Shadows**: Subtle drop shadows (0 4px 12px rgba(0,0,0,0.1)) for depth
- **Gradient Accents**: Subtle gradients on buttons and important elements
- **Playful Icons**: Custom rounded icons with soft edges and bright colors
- **Breathing Animations**: Gentle scale animations on interactive elements

## Visual Effects & Animations

### Core Libraries Used
- **Anime.js**: Smooth button animations, score counters, target movements
- **p5.js**: Particle systems for explosions, confetti effects, background animations
- **Matter.js**: Physics-based target movements and collision detection
- **ECharts.js**: Beautiful animated leaderboard and statistics charts

### Animation Effects
- **Button Hover**: Gentle scale up (1.05x) with soft shadow increase
- **Target Hit**: Explosion particles with color burst and screen shake
- **Score Update**: Number counting animation with bounce effect
- **Combo Multiplier**: Growing text with pulsing glow effect
- **Level Progress**: Smooth progress bar fill with color transition
- **Confetti**: Burst of colorful particles on achievements
- **Background**: Subtle floating particles for ambient movement

### Header Effect
- **Animated Background**: Floating geometric shapes in brand colors
- **Gradient Overlay**: Soft aurora-like gradient flow behind game title
- **Particle System**: Gentle floating dots that respond to mouse movement

## Layout & Styling

### Game Interface
- **Clean Layout**: Centered game area with minimal distractions
- **Responsive Grid**: Flexible layout that adapts to all screen sizes
- **Card Design**: Game stats and leaderboard displayed in rounded cards
- **Color Coding**: Different target types use distinct, recognizable colors
- **Visual Hierarchy**: Important elements (score, timer) are larger and more prominent

### Interactive Elements
- **Primary Buttons**: Coral background with white text, rounded corners, hover lift effect
- **Secondary Buttons**: Outlined style with brand color borders
- **Game Targets**: Circular design with bright gradients and subtle glow effects
- **Score Display**: Large, bold numbers with counting animations
- **Progress Bars**: Rounded bars with gradient fills and smooth animations

### Mobile Optimization
- **Touch Targets**: Minimum 44px touch areas for all interactive elements
- **Simplified UI**: Reduced visual clutter on smaller screens
- **Optimized Animations**: Reduced particle effects for better performance
- **Gesture Support**: Touch-friendly controls with haptic-like visual feedback

## User Experience Design

### Game Flow
1. **Landing**: Animated title with floating particles and prominent start button
2. **Game Play**: Clean interface focusing on targets with minimal UI distractions
3. **Feedback**: Immediate visual and audio feedback for all interactions
4. **Results**: Celebratory animations for high scores with confetti effects
5. **Replay**: Easy restart with improved challenge and motivation

### Accessibility
- **High Contrast**: 4.5:1 minimum contrast ratio for all text
- **Clear Visual Hierarchy**: Important information stands out clearly
- **Color Independence**: Information not conveyed by color alone
- **Large Touch Targets**: Easy interaction for all users
- **Reduced Motion**: Option to disable animations for sensitive users
