export interface MapPoint {
  latitude: number;
  longitude: number;
}

export function validMapPoint(point: MapPoint): boolean {
  return Number.isFinite(point.latitude) && Number.isFinite(point.longitude) &&
    Math.abs(point.latitude) <= 90 && Math.abs(point.longitude) <= 180;
}

export function inverseMapPoint(target: MapPoint, forward: (point: MapPoint) => MapPoint): MapPoint {
  if (!validMapPoint(target)) throw new Error('Invalid map coordinate');
  let estimate: MapPoint = { latitude: target.latitude, longitude: target.longitude };
  for (let iteration = 0; iteration < 8; iteration++) {
    const projected = forward(estimate);
    if (!validMapPoint(projected)) throw new Error('Invalid coordinate conversion');
    const latitudeError = projected.latitude - target.latitude;
    const longitudeError = projected.longitude - target.longitude;
    if (Math.max(Math.abs(latitudeError), Math.abs(longitudeError)) < 0.000001) return estimate;
    estimate = { latitude: estimate.latitude - latitudeError, longitude: estimate.longitude - longitudeError };
    if (!validMapPoint(estimate)) break;
  }
  throw new Error('Coordinate conversion did not converge');
}
