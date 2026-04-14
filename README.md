# TriKing

Play the game <a href="https://pragyaangaur.github.io/TriKing/">here</a>.  
It looks simple… until it really, really isn’t.

## Overview
TriKing is a high-speed, tile-matching puzzle game with pseudo-triominos engineered for cross-platform play (Desktop and Mobile Web). Built entirely from scratch, this repository contains the core game engine, state management logic, and UI rendering pipeline. The system has been compiled to WebAssembly (WASM) and is currently deployed as a live web application. 

This repository focuses on the software architecture of the game, specifically the implementation of the grid-based collision physics, advanced scoring algorithms, and the unified input handler for touch and keyboard interfaces.

## Core Systems

### 1. The Game Engine & State Machine

**What it does:**
Manages the core gameplay loop, piece generation, and transitions between game states without triggering logic race conditions.

**Core Idea:**
Decoupling the visual rendering of the blocks from the underlying mathematical grid array, while strictly controlling execution flow.

**Approach:**
* Implementation of a strict State Machine (`MENU`, `PLAYING`, `GAMEOVER`, `PAUSED`).
* Virtual 8x18 matrix for discrete collision detection and boundary locking.
* "7-Bag" randomizer algorithm to ensure fair distribution of the 6 distinct pieces (Kings and Hooks).

**How it Works:**
The engine updates a virtual 2D array every tick. Visuals are only drawn based on the current state of this array. Timers and input listeners check the current `game_state` before executing, preventing bugs like pieces falling while paused or game-over sounds looping.

**Stack:** Godot 4 (GDScript)

---

### 2. Advanced Scoring & Progressive Difficulty

**What it does:**
Calculates dynamic score yields based on player performance, factoring in combos, multi-line clears, and complex positional rotations.

**Core Idea:**
Rewarding advanced mechanical skill and spatial reasoning rather than simple survival time.

**Approach:**
* Tracking consecutive line clears to build a Combo multiplier.
* Detecting "Tri-Spins" by calculating if a piece was rotated into a locked coordinate where up, left, and right translations are mathematically blocked.
* Progressive temporal scaling using the formula: $T_{fall} = \max(0.1, 1.0 - (L - 1) \times 0.1)$ where $L$ is the current level.

**How it Works:**
When a piece locks, the engine scans the grid for saturated rows. If cleared, it calculates base points mapped to the number of rows, multiplies it by the current level, and applies massive bonus multipliers if the lock was registered as a "Tri-Spin" or part of a combo chain. Gravity speed is then dynamically recalculated based on the new level threshold.

**Key Result:**
A mathematically rigorous difficulty curve that scales cleanly down to a maximum drop interval of 0.1 seconds.

---

### 3. Unified Cross-Platform Input Handler

**What it does:**
Translates raw hardware inputs (mouse clicks, keyboard strokes, touchscreen interactions) into a unified set of game actions.

**Core Idea:**
Providing a native, zero-friction control scheme regardless of whether the user is on an iOS touchscreen or a macOS keyboard.

**Approach:**
* Vector math to calculate touch coordinates and swipe lengths.
* Boolean threshold checks to differentiate a "tap" from a "swipe".
* Echo-event handling for hardware keyboards to allow continuous soft-dropping.

**How it Works:**
The input listener intercepts `InputEventScreenTouch`. If the displacement vector between the initial touch and the release exceeds the predefined `SWIPE_THRESHOLD`, it calculates the dominant axis (X or Y) to determine movement or hard drops. If the vector is below the threshold, it registers as a rotational tap. 

**Stack:** HTML5 / WebAssembly Export
