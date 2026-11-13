# BACKROOMS: LOST TOGETHER

A low-poly, mobile-first cooperative horror exploration prototype built with Godot 4.3.

## Current implementation
- Procedurally assembled yellow-room test arena.
- First-person keyboard/mouse and basic two-finger mobile movement/look input.
- ENet host/join interface on UDP 2456 for same-Wi-Fi/hotspot testing.
- Player spawn and position replication prototype.
- Three collectible power fuses and a simple server-controlled watcher pursuit.
- Android export preset.

## LAN testing
1. Connect phones to the same Wi-Fi/hotspot.
2. Host taps HOST GAME and shares the host phone's local IPv4 address.
3. Joiner enters that address and taps JOIN.
4. UDP port 2456 must be reachable on the local network.

## Important status
This is an early playable systems prototype, not a finished game. Multiplayer replication, Android touch usability, reconnect handling, mission completion, audio, additional levels, and real-device performance need implementation and testing. No APK is available until a successful Android export workflow has run. Practical player capacity depends on device/network testing.
