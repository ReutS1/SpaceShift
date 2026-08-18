import CoreGraphics
import Foundation

let needle = CommandLine.arguments.dropFirst().first ?? "SpaceShift"
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for window in windows {
    guard window[kCGWindowOwnerName as String] as? String == "Finder",
          let title = window[kCGWindowName as String] as? String,
          title.localizedCaseInsensitiveContains(needle),
          let number = window[kCGWindowNumber as String] as? Int else { continue }
    print(number)
    exit(0)
}
exit(2)
