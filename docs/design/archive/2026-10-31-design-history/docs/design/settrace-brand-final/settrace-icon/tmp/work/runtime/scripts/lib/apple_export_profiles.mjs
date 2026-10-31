export const APPLE_EXPORT_SCALE = 1;

export const APPLE_APPEARANCE_RENDITIONS = Object.freeze([
  Object.freeze({ name: "Default" }),
  Object.freeze({ name: "Dark" }),
  Object.freeze({ name: "TintedLight", tintColor: "0.25", tintStrength: "0.75" }),
  Object.freeze({ name: "TintedDark", tintColor: "0.25", tintStrength: "0.75" }),
  Object.freeze({ name: "ClearLight" }),
  Object.freeze({ name: "ClearDark" }),
]);

export const APPLE_EXPORT_PROFILES = Object.freeze([
  Object.freeze({ platform: "iOS", width: 1024, height: 1024, renditions: APPLE_APPEARANCE_RENDITIONS }),
  Object.freeze({ platform: "macOS", width: 1024, height: 1024, renditions: APPLE_APPEARANCE_RENDITIONS }),
  Object.freeze({ platform: "watchOS", width: 1088, height: 1088, renditions: Object.freeze([Object.freeze({ name: "Default" })]) }),
]);

export function appleExportProfilesForTargets(targetPlatforms) {
  const requested = new Set(targetPlatforms.map((platform) => (platform === "iPadOS" ? "iOS" : platform)));
  return APPLE_EXPORT_PROFILES.filter((profile) => requested.has(profile.platform));
}
