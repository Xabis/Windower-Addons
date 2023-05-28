# Open Sesame (modified)
Automatically open doors for the ultra lazy.

This is a modified addon. See the original work here: https://github.com/z16/Addons

# Salvage extensions
Enhancements include:
- Support for all menu prompt doors inside Salvage. Take caution as opening these doors lock in your path.
- Fast skip for the nyzul isle staging doors.
- Instant warp for the portal pad inside nyzul isle leading to BRII only.
- Instant warp for portal pads inside BRII, on the common farming route only.
- Automatic instance reservation for assault and salvage II

Auto mode must be enabled to enable these features:
> os auto

# Auto Instance Reservation Warning
Instance reservation is tested with BRII ONLY.

DO NOT APPROACH DOOR WITHOUT ENTRY KEYITEMS AND DO NOT LEAVE ONCE RESERVATION BEGINS.

If you need to enter salvage I, you must turn auto mode off and enter normally.

# About door skip and portals
Only specific portals are supported.

This is because the game stores warp coordinates client-side and sends it to the server as a request. Sending the confirmation menu option packet alone is not enough.

Due to this, a list of coordinates must be known ahead of time based on the specific zone and menu that is being interacted with.

If you wish to support additional warps that are not supported in this mod, you will need to capture the coordinate data and add it to the configuration manually.

Currently supported warps:
- Nyzul staging north entrance
- Nyzul staging north exit
- Nyzul staging south entrance
- Nyzul staging south exit
- Nyzul portal A to E
- Nyzul portal to A (Bhaflau Remnent)
- BRII F1 to F2
- BRII F2 NE to F3
- BRII F3 WEST to F4
- BRII F4 to F5
