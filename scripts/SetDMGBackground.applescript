-- SPDX-License-Identifier: GPL-3.0-only

on run argv
	set diskName to item 1 of argv
	set mountDir to item 2 of argv
	set backgroundFileName to item 3 of argv
	set backgroundAlias to (POSIX file (mountDir & "/.background/" & backgroundFileName) as alias)

	tell application "Finder"
		tell disk diskName
			open
			set opts to the icon view options of container window
			set background picture of opts to backgroundAlias
			set position of item "SpaceShift.app" to {200, 190}
			set position of item "Applications" to {600, 190}
			close
			open
			delay 2
			set opts to the icon view options of container window
			set background picture of opts to backgroundAlias
			set position of item "SpaceShift.app" to {200, 190}
			set position of item "Applications" to {600, 190}
			delay 2
		end tell
	end tell
end run
