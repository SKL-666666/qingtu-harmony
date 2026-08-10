/*
 * Level indicator component.
 */

import { curves, display } from '@kit.ArkUI';
import { sensor } from '@kit.SensorServiceKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';

const ANGLE_DIFFERENCE: number = 3;
const TAG = 'LevelIndicator';

/**
 * Universal Camera Preview Level Component.
 */
@Component
export struct LevelIndicator {
  @Prop acc: sensor.AccelerometerResponse;

  getRotate(): number {
    let displayDefault: display.Display | null = null;
    try {
      displayDefault = display.getDefaultDisplaySync();
    } catch (exception) {
      Logger.error(TAG, `getDefaultDisplaySync failed, code is ${exception.code}, message is ${exception.message}`);
    }
    const rotation = (displayDefault?.rotation ?? 0) * 90;
    if (rotation === 90 || rotation === 270) {
      return -Math.atan2(-this.acc.y, this.acc.x) * (180 / Math.PI);
    }
    return -Math.atan2(-this.acc.x, this.acc.y) * (180 / Math.PI);
  }

  isAlign(): boolean {
    return Math.abs(this.getRotate()) - 0 <= ANGLE_DIFFERENCE ||
      Math.abs(Math.abs(this.getRotate()) - 90) <= ANGLE_DIFFERENCE;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Line({
        width: 200,
        height: 1
      })
        .stroke(Color.White)
        .endPoint([200, 0])
        .strokeDashArray([3, this.isAlign() ? 0 : 3])
        .opacity(this.isAlign() ? 1 : 0.5)
        .rotate({ angle: this.getRotate(), centerX: '50%', centerY: '50%' })
        .animation({
          curve: curves.springMotion(0.6, 0.8),
          iterations: 1,
          playMode: PlayMode.Normal
        })
      Circle()
        .width(48)
        .height(48)
        .stroke(Color.White)
        .fill(Color.Transparent)
        .opacity(this.isAlign() ? 1 : 0.5)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
