/*
 * Window utility functions.
 */

import { display, window } from '@kit.ArkUI';
import { CameraLogger as Logger } from './CameraLogger';

const TAG = 'WindowUtil';

class WindowUtil {
  static async enterImmersive(window: window.Window): Promise<void> {
    try {
      await window.setWindowLayoutFullScreen(true);
      await window.setWindowSystemBarEnable([]);
    } catch (exception) {
      Logger.error(TAG, 'Failed to enter immersive. Cause:', JSON.stringify(exception));
    }
  }

  static getMaxDisplaySize(ratio: number): Size {
    let defaultDisplay: display.Display | null = null;
    try {
      defaultDisplay = display.getDefaultDisplaySync();
    } catch (exception) {
      Logger.error(TAG, `getDefaultDisplaySync failed, code is ${exception.code}, message is ${exception.message}`);
    }
    const windowWidth: number = defaultDisplay?.width ?? 0;
    const windowHeight: number = defaultDisplay?.height ?? 0;
    const rotation = (defaultDisplay?.rotation ?? 0) * 90;
    if (rotation === 90 || rotation === 270) {
      ratio = 1 / ratio;
    }
    const calculatedHeight = windowWidth * ratio;
    if (calculatedHeight <= windowHeight) {
      return {
        width: windowWidth,
        height: calculatedHeight
      };
    } else {
      return {
        width: windowHeight / ratio,
        height: windowHeight
      };
    }
  }

  static getWindowRatio(): number {
    try {
      const defaultDisplay: display.Display = display.getDefaultDisplaySync();
      return defaultDisplay.height / defaultDisplay.width;
    } catch (exception) {
      Logger.error(TAG, `getWindowRatio failed, code is ${exception.code}, message is ${exception.message}`);
      return 0;
    }
  }
}

export default WindowUtil;
