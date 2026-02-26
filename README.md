RotationHelper v0.3 – Summary

Version 0.3 introduces major usability improvements and a basic spell prediction system for Marksmanship Hunter (WotLK 3.3.5a).

🔧 New Features

1. Settings Menu Added

Integrated into the Interface Options panel.

Lock/Unlock option to enable or disable frame movement.

Visibility mode dropdown:

Always On

Combat or Target

Hidden

Adjustable Spell Prediction Count slider (1–4 upcoming abilities).

2. Spell Prediction System

Displays the next recommended abilities based on MM Hunter priority logic:

Kill Shot (execute)

Serpent Sting (maintenance)

Chimera Shot

Aimed Shot

Arcane Shot

Steady Shot (filler)

Simulates short GCD offsets to predict upcoming spells.

Prevents duplicate spell recommendations in the prediction chain (except Steady Shot).

Prediction count is configurable via settings.

3. Smart Visibility Modes

Frame visibility can now be controlled:

Always visible

Only in combat or with a valid target

Completely hidden

4. Utility Indicators

Aspect reminder (shows active Aspect or warning glow if missing).

Hunter's Mark tracker (desaturates if already applied).

Kill Command off-GCD flash indicator.

Basic range check (main icon tint turns red if out of range).

⚙️ Quality of Life

Frame locking toggle via checkbox or /hh slash command.

Automatically hides if player is not a Hunter.

Stops updating during casting/channeling to avoid flicker.
