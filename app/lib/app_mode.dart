enum AppMode { free, paid }

/// Temporary app-wide monetization switch until real entitlements exist.
const appMode = AppMode.paid;

bool get isPaidApp => appMode == AppMode.paid;
