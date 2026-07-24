# Universal Search App

Native SwiftUI port of the universal-search travel prototype (iPhone 16/17 Pro).

Result data comes from two selectable pipelines: Narrative + mock, and Gen-UI.

Build:
```
xcodebuild -project "Universal Search App.xcodeproj" -scheme "Universal Search App" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```