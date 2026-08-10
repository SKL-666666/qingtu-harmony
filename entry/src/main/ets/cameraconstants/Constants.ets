/*
 * Camera entry module constants.
 */

import { Permissions } from '@kit.AbilityKit';

class CameraEntryConstant {
  public static readonly RATIO_PHOTO: number = 4 / 3;
  public static readonly RATIO_VIDEO: number = 16 / 9;
  public static readonly PERMISSIONS: Permissions[] = [
    'ohos.permission.CAMERA',
    'ohos.permission.ACCELEROMETER'
  ];
}

export default CameraEntryConstant;
