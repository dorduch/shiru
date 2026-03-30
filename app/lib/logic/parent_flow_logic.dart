String routeWithNext(String path, String nextLocation) {
  return Uri(path: path, queryParameters: {'next': nextLocation}).toString();
}

bool isParentAreaLocation(String location) {
  final path = Uri.parse(location).path;
  return path.startsWith('/parent');
}

bool shouldResetParentAuth({
  required String currentLocation,
  required String nextLocation,
}) {
  return isParentAreaLocation(currentLocation) &&
      !isParentAreaLocation(nextLocation);
}

String? protectAdultRoute({
  required bool isAuthenticated,
  required String nextLocation,
}) {
  if (!isAuthenticated) {
    return routeWithNext('/parent-access', nextLocation);
  }

  return null;
}

String resolveParentAccessDestination({
  required bool isAuthenticated,
  required bool hasVerifiedAdult,
  required String nextLocation,
}) {
  if (isAuthenticated) {
    return nextLocation;
  }

  if (hasVerifiedAdult) {
    return '/pin';
  }

  return '/age-check';
}
