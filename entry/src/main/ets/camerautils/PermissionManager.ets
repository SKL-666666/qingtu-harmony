/*
 * Permission manager utility.
 */

import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { CameraLogger as Logger } from './CameraLogger';

const TAG = 'PermissionManager';

class PermissionManager {
  private static atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

  static async request(permissions: Permissions[], context: Context): Promise<void> {
    try {
      const data = await PermissionManager.atManager.requestPermissionsFromUser(context, permissions);
      const grantStatus: number[] = data.authResults;
      const deniedPermissions = permissions.filter((_, i) => grantStatus[i] !== 0);
      for (const permission of deniedPermissions) {
        const secondGrantStatus = await PermissionManager.atManager.requestPermissionOnSetting(context, [permission]);
        if (secondGrantStatus[0] !== 0) {
          Logger.error(TAG, 'permission denied');
          throw new Error('permission denied');
        }
      }
    } catch (exception) {
      Logger.error(TAG, `request failed, code is ${exception.code}, message is ${exception.message}`);
      throw new Error('permission failed');
    }
  }
}

export default PermissionManager;
