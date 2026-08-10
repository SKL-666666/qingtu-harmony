/*
 * Camera logger utility (merged from commons module).
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

export class CameraLogger {
  private static readonly DOMAIN: number = 0xFF00;
  private static readonly TAG: string = 'com.example.customcamera';
  private static readonly PREFIX: string = '[camera-log]';

  public static debug(logTag: string, messageFormat: string, ...args: Object[]): void {
    hilog.debug(CameraLogger.DOMAIN, CameraLogger.TAG, `${CameraLogger.PREFIX} ${logTag}: ${messageFormat}`, args);
  }

  public static info(logTag: string, messageFormat: string, ...args: Object[]): void {
    hilog.info(CameraLogger.DOMAIN, CameraLogger.TAG, `${CameraLogger.PREFIX} ${logTag}: ${messageFormat}`, args);
  }

  public static warn(logTag: string, messageFormat: string, ...args: Object[]): void {
    hilog.warn(CameraLogger.DOMAIN, CameraLogger.TAG, `${CameraLogger.PREFIX} ${logTag}: ${messageFormat}`, args);
  }

  public static error(logTag: string, messageFormat: string, ...args: Object[]): void {
    hilog.error(CameraLogger.DOMAIN, CameraLogger.TAG, `${CameraLogger.PREFIX} ${logTag}: ${messageFormat}`, args);
  }

  public static fatal(logTag: string, messageFormat: string, ...args: Object[]): void {
    hilog.fatal(CameraLogger.DOMAIN, CameraLogger.TAG, `${CameraLogger.PREFIX} ${logTag}: ${messageFormat}`, args);
  }

  private constructor() {
  }
}
