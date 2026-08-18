on run argv
    set volumeName to item 1 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set pathbar visible of container window to false
            set sidebar width of container window to 0
            set bounds of container window to {120, 120, 780, 520}

            set viewOptions to icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 112
            set text size of viewOptions to 13
            set background picture of viewOptions to file ".background:background.png"

            set position of item "SpaceShift.app" to {170, 210}
            set position of item "Applications" to {490, 210}

            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
