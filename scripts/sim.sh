#!/bin/zsh
# Boot the iPhone 15 Pro Max (iOS 17.0) simulator and show its window.
ID=F2F076B6-2668-4F42-8E61-321F9D870AE3
xcrun simctl boot "$ID" 2>/dev/null   # already-booted is fine
open -a Simulator --args -CurrentDeviceUDID "$ID"
