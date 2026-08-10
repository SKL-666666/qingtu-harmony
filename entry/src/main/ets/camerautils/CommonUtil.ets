/*
 * Common utility functions for camera.
 */

import { camera } from '@kit.CameraKit';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraLogger as Logger } from './CameraLogger';

const FACE_BOX_LINE_RATIO: number = 0.3;

export interface LinePoint {
  start: camera.Point,
  increment: camera.Point
}

export interface SimplePoint {
  x: number;
  y: number;
}

export function limitNumberInRange(src: number, range: number[]): number {
  if (range.length < 2) {
    return src;
  }
  if (src < range[0]) {
    return range[0];
  }
  if (src > range[1]) {
    return range[1];
  }
  return src;
}

export function findRangeIndex(target: number, arr: number[]): number {
  if (arr.length === 0) {
    return -1;
  }
  if (target >= arr[arr.length - 1]) {
    return arr.length - 1;
  }
  return [...arr].sort((a, b) => a - b).findIndex((n, i) => {
    return target >= n && target < arr[i + 1];
  });
}

export function toFixed(num: number, digit: number): string {
  const scale = 10 ** digit;
  return (Math.floor(num * scale) / scale).toFixed(digit);
}

export function getClampedChildPosition(childSize: Size, parentSize: Size, point: SimplePoint): Edges {
  let left = point.x - childSize.width / 2;
  let top = point.y - childSize.height / 2;
  if (left < 0) {
    left = 0;
  }
  if (left + childSize.width > parentSize.width) {
    left = parentSize.width - childSize.width;
  }
  if (top < 0) {
    top = 0;
  }
  if (top + childSize.height > parentSize.height) {
    top = parentSize.height - childSize.height;
  }
  return { left, top };
}

export function calFaceBoxLinePoint(faceBoxRect: camera.Rect): LinePoint[] {
  let lineLength: number = Math.min(faceBoxRect.width, faceBoxRect.height) * FACE_BOX_LINE_RATIO;
  let linePoints: LinePoint[] = [];

  let startPoints: camera.Point[] = [
    { x: faceBoxRect.topLeftX, y: faceBoxRect.topLeftY },
    { x: faceBoxRect.topLeftX + faceBoxRect.width, y: faceBoxRect.topLeftY },
    { x: faceBoxRect.topLeftX, y: faceBoxRect.topLeftY + faceBoxRect.height },
    { x: faceBoxRect.topLeftX + faceBoxRect.width, y: faceBoxRect.topLeftY + faceBoxRect.height }];

  startPoints.forEach((startPoint: camera.Point) => {
    let horizontalLine: LinePoint = {
      start: startPoint,
      increment: { x: startPoint.x > faceBoxRect.topLeftX ? -lineLength : lineLength, y: 0 }
    };

    let verticalLine: LinePoint = {
      start: startPoint,
      increment: { x: 0, y: startPoint.y > faceBoxRect.topLeftY ? -lineLength : lineLength }
    };

    linePoints.push(horizontalLine, verticalLine);
  });
  return linePoints;
}

export function showToast(
  curUIContext: UIContext,
  message: ResourceStr = '',
  duration = 2000,
  alignment = Alignment.Top,
  offset: Offset = { dx: 0, dy: 300 }
): void {
  curUIContext.getPromptAction().openToast({
    message,
    duration,
    alignment,
    offset
  }).catch((err: BusinessError) => {
    Logger.error('showToast', `showToast failed, code is ${err.code}, message is ${err.message}`);
  });
}

export function calCameraPoint(eventX: number, eventY: number, width: number, height: number): camera.Point {
  let displayDefault: display.Display | null = null;
  try {
    displayDefault = display.getDefaultDisplaySync();
  } catch (exception) {
    Logger.error('calCameraPoint', `calCameraPoint failed, code is ${exception.code}, message is ${exception.message}`);
  }
  const displayRotation = (displayDefault?.rotation ?? 0) * 90;
  if (displayRotation === 0) {
    return { x: eventY / height, y: 1 - eventX / width };
  }
  if (displayRotation === 90) {
    return { x: 1 - eventX / width, y: 1 - eventY / height };
  }
  if (displayRotation === 180) {
    return { x: 1 - eventY / height, y: eventX / width };
  }
  return { x: eventX / width, y: eventY / height };
}
