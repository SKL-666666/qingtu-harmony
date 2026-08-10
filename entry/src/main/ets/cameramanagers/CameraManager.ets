/*
 * Camera capability management class.
 */

import { camera } from '@kit.CameraKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { OutputManager, CreateOutputConfig } from './OutputManager';

const TAG = 'CameraManager';

/**
 * Camera capability management class, manages various configurations and output streams of the camera.
 */
export class CameraManager {
  public session?: camera.PhotoSession | camera.VideoSession;
  private cameraManager?: camera.CameraManager;
  private cameraInput?: camera.CameraInput;
  private outputManagers: OutputManager[] = [];

  constructor(context: Context, outputManagers: OutputManager[]) {
    try {
      this.cameraManager = camera.getCameraManager(context);
      this.outputManagers = outputManagers;
      this.addCameraStatusListener();
    } catch (exception) {
      Logger.error(TAG, `constructor failed, code is ${exception.code}, message is ${exception.message}`);
    }
  }

  addCameraStatusListener(): void {
    this.cameraManager?.on('cameraStatus', (err: BusinessError, statusInfo: camera.CameraStatusInfo) => {
      if (err && err.message) {
        Logger.error(TAG, 'cameraStatus with errorMessage = ' + err.message);
        return;
      }
      Logger.info(TAG, `cameraStatusInfo: camera is ${statusInfo.camera.cameraId}, status is ${statusInfo.status}`);
    });
  }

  getCameraManager(): camera.CameraManager | undefined {
    return this.cameraManager;
  }

  async start(
    xComponentSurfaceId: string,
    cameraPosition: camera.CameraPosition,
    sceneMode: camera.SceneMode,
    getProfile: (cameraOrientation: number) => camera.Profile,
    isStabilizationEnabled: boolean
  ): Promise<void> {
    try {
      // 释放旧 session,避免重复创建导致冲突
      if (this.session) {
        try {
          await this.session.stop();
        } catch (e) {
          // ignore
        }
      }
      const device = this.getCameraDevice(cameraPosition);
      if (!device) {
        return;
      }
      this.cameraInput = this.cameraManager?.createCameraInput(device);
      await this.cameraInput?.open();
      const session = this.cameraManager?.createSession(sceneMode);
      session?.beginConfig();
      session?.addInput(this.cameraInput);
      const config: CreateOutputConfig = {
        cameraManager: this.cameraManager,
        device,
        sceneMode,
        profile: getProfile(device.cameraOrientation),
        surfaceId: xComponentSurfaceId
      };
      for (const outputManager of this.outputManagers) {
        if (outputManager.isActive) {
          const output = await outputManager.createOutput(config);
          session?.addOutput(output);
        }
      }
      await session?.commitConfig();
      if (sceneMode === camera.SceneMode.NORMAL_VIDEO && session) {
        this.setVideoStabilizationMode(isStabilizationEnabled, session as camera.VideoSession);
      }
      await session?.start();
      this.session = session as (camera.PhotoSession | camera.VideoSession);
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      this.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_CONTINUOUS_AUTO);
    } catch (e) {
      Logger.error(TAG, `Failed to start camera session. Cause ${JSON.stringify(e)}`);
    }
  }

  async refreshOutput(oldOutput: camera.CameraOutput, newOutput: camera.CameraOutput): Promise<void> {
    try {
      await this.session?.stop();
      this.session?.beginConfig();
      this.session?.removeOutput(oldOutput);
      this.session?.addOutput(newOutput);
      await this.session?.commitConfig();
      await this.session?.start();
    } catch (exception) {
      Logger.error(TAG, `refreshOutput failed, code is ${exception.code}, message is ${exception.message}`);
    }
  }

  async release(): Promise<void> {
    try {
      await this.session?.stop();
      for (const outputManager of this.outputManagers) {
        if (outputManager.isActive) {
          await outputManager.release();
        }
      }
      await this.cameraInput?.close();
      await this.session?.release();
    } catch (exception) {
      Logger.error(TAG, `release failed, code is ${exception.code}, message is ${exception.message}`);
    }
  }

  getCameraDevice(cameraPosition: camera.CameraPosition): camera.CameraDevice | undefined {
    const cameraDevices = this.cameraManager?.getSupportedCameras();
    if (!cameraDevices) {
      Logger.error(TAG, `Failed to get camera device. cameraPosition: ${cameraPosition}}`);
      return undefined;
    }
    const device = cameraDevices?.find(device => device.cameraPosition === cameraPosition) || cameraDevices[0];
    if (!device) {
      Logger.error(TAG, `Failed to get camera device. cameraPosition: ${cameraPosition}}`);
    }
    return device;
  }

  getZoomRange(): number[] {
    try {
      return this.session!.getZoomRatioRange();
    } catch (exception) {
      Logger.error(TAG, `getZoomRange failed, code is ${exception.code}, message is ${exception.message}`);
      return [];
    }
  }

  setFocusMode(focusMode: camera.FocusMode): void {
    try {
      const isSupported = this.session?.isFocusModeSupported(focusMode);
      if (!isSupported) {
        Logger.error(TAG, `setFocusMode error: focus mode ${focusMode} is not supported`);
        return;
      }
      this.session?.setFocusMode(focusMode);
    } catch (e) {
      Logger.error(TAG, 'setFocusMode error ' + JSON.stringify(e));
    }
  }

  setFocusPoint(point: camera.Point): void {
    try {
      this.session?.setFocusPoint(point);
    } catch (e) {
      Logger.error(TAG, 'setFocusPoint error ' + JSON.stringify(e));
    }
  }

  setExposureMode(exposureMode: camera.ExposureMode): void {
    try {
      const isSupported = this.session?.isExposureModeSupported(exposureMode);
      if (!isSupported) {
        Logger.error(TAG, `setExposureMode error: focus mode ${exposureMode} is not supported`);
        return;
      }
      this.session?.setExposureMode(exposureMode);
    } catch (e) {
      Logger.error(TAG, 'setExposureMode error ' + JSON.stringify(e));
    }
  }

  setMeteringPoint(point: camera.Point): void {
    try {
      this.session?.setMeteringPoint(point);
    } catch (e) {
      Logger.error(TAG, 'setMeteringPoint error ' + JSON.stringify(e));
    }
  }

  setZoomRatio(zoom: number): void {
    try {
      this.session?.setZoomRatio(zoom);
    } catch (e) {
      Logger.error(TAG, 'setZoomRatio error ' + JSON.stringify(e));
    }
  }

  setSmoothZoom(zoom: number): void {
    try {
      this.session?.setSmoothZoom(zoom);
    } catch (e) {
      Logger.error(TAG, 'setSmoothZoom error ' + JSON.stringify(e));
    }
  }

  setFlashMode(flashMode: camera.FlashMode): void {
    try {
      const isSupported = this.session?.isFlashModeSupported(flashMode);
      if (!isSupported) {
        Logger.error(TAG, `setFlashMode error: flash mode ${flashMode} is not supported`);
        return;
      }
      this.session?.setFlashMode(flashMode);
    } catch (e) {
      Logger.error(TAG, 'setFlashMode error ' + JSON.stringify(e));
    }
  }

  setVideoStabilizationMode(isStabilizationEnabled: boolean, session: camera.VideoSession): void {
    try {
      let mode = isStabilizationEnabled ? camera.VideoStabilizationMode.AUTO : camera.VideoStabilizationMode.OFF;
      const isSupported: boolean = session.isVideoStabilizationModeSupported(mode);
      if (isSupported) {
        session.setVideoStabilizationMode(mode);
      } else {
        Logger.error(TAG, 'stabilizationMode is not supported: ' + JSON.stringify(mode));
      }
    } catch (e) {
      Logger.error(TAG, 'setVideoStabilizationMode error ' + JSON.stringify(e));
    }
  }
}
