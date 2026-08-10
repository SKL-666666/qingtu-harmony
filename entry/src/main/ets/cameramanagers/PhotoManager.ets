/*
 * Photo output stream management class.
 */

import { camera } from '@kit.CameraKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { sensor } from '@kit.SensorServiceKit';
import { Decimal } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { colorSpaceManager } from '@kit.ArkGraphics2D';
import { geoLocationManager } from '@kit.LocationKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { OutputManager, CreateOutputConfig } from './OutputManager';
import CameraConstant from '../cameraconstants/CameraConstants';

const TAG_LOG = 'PhotoManager';

/**
 * Photo output stream management class, responsible for managing the creation,
 * configuration, and release of the output stream
 */
export class PhotoManager implements OutputManager {
  public output?: camera.PhotoOutput;
  public isActive: boolean = true;
  public context: Context;
  public location: geoLocationManager.Location | null = null;
  private callback: (pixelMap: image.PixelMap, url: string) => void = () => {};
  constructor(context: Context, isActive = true) {
    this.context = context;
    this.isActive = isActive;
  }

  setIsActive(isActive: boolean): void {
    this.isActive = isActive;
  }

  setCallback(callback: (pixelMap: image.PixelMap, url: string) => void): void {
    this.callback = callback;
  }

  async createOutput(config: CreateOutputConfig): Promise<camera.PhotoOutput | undefined> {
    let cameraPhotoOutput = this.createPhotoOutput(config.cameraManager, config.device, config.profile);
    if (cameraPhotoOutput) {
      this.output = cameraPhotoOutput;
      this.setPhotoOutputCallback();
    }
    return cameraPhotoOutput;
  }

  public createPhotoOutput(cameraManager: camera.CameraManager | undefined, cameraDevice: camera.CameraDevice,
    profile: camera.Profile): camera.PhotoOutput | undefined {
    let cameraPhotoOutput: camera.PhotoOutput | undefined;
    const cameraOutputCapability =
      cameraManager?.getSupportedOutputCapability(cameraDevice, camera.SceneMode.NORMAL_PHOTO);
    let photoProfilesArray: camera.Profile[] | undefined = cameraOutputCapability?.photoProfiles;
    if (photoProfilesArray?.length) {
      try {
        const displayRatio = profile.size.width / profile.size.height;
        // 选择与预览比例匹配的、分辨率最高的照片 Profile(提高照片清晰度)
        const photoProfile = photoProfilesArray
          .filter(pf => {
            const pfDisplayRatio = pf.size.width / pf.size.height;
            return Math.abs(pfDisplayRatio - displayRatio) <= CameraConstant.PROFILE_DIFFERENCE &&
              pf.format === camera.CameraFormat.CAMERA_FORMAT_JPEG;
          })
          .sort((a, b) => b.size.width - a.size.width)[0];
        if (!photoProfile) {
          Logger.error(TAG_LOG, 'Failed to get photo profile');
          return undefined;
        }
        Logger.info(TAG_LOG, `photoProfile selected: ${photoProfile.size.width}x${photoProfile.size.height}`);
        cameraPhotoOutput = cameraManager?.createPhotoOutput(photoProfile);
      } catch (error) {
        Logger.error(TAG_LOG, `Failed to createPhotoOutput. Error: ${JSON.stringify(error)}`);
      }
    }
    this.output = cameraPhotoOutput;
    return cameraPhotoOutput;
  }

  async mediaLibSavePhoto(photoAsset: photoAccessHelper.PhotoAsset,
    phAccessHelper: photoAccessHelper.PhotoAccessHelper): Promise<void> {
    try {
      let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
        new photoAccessHelper.MediaAssetChangeRequest(photoAsset);
      assetChangeRequest.saveCameraPhoto();
      await phAccessHelper.applyChanges(assetChangeRequest).catch((err: BusinessError) => {
        Logger.error(TAG_LOG, `applyChanges failed, code is ${err.code}, message is ${err.message}`);
      });
      phAccessHelper.release().catch((err: BusinessError) => {
        Logger.error(TAG_LOG, `phAccessHelper.release failed, code is ${err.code}, message is ${err.message}`);
      });
    } catch (error) {
      Logger.error(TAG_LOG, `apply saveCameraPhoto failed with error: ${error.code}, ${error.message}`);
    }
  }

  async mediaLibRequestBuffer(photoAsset: photoAccessHelper.PhotoAsset, context: Context,
    callback: (pixelMap: image.PixelMap, url: string) => void): Promise<void> {
    class MediaDataHandler implements photoAccessHelper.MediaAssetDataHandler<ArrayBuffer> {
      onDataPrepared(data: ArrayBuffer): void {
        if (data === undefined) {
          Logger.error(TAG_LOG, 'Error occurred when preparing data');
          return;
        }
        let imageSource = image.createImageSource(data);
        imageSource.createPixelMap().then((pixelMap: image.PixelMap) => {
          callback(pixelMap, photoAsset.uri);
        }).catch((err: BusinessError) => {
          Logger.error(TAG_LOG, `createPixelMap err:${err.code}`);
        });
      }
    }

    let requestOptions: photoAccessHelper.RequestOptions = {
      deliveryMode: photoAccessHelper.DeliveryMode.FAST_MODE,
    };
    const handler = new MediaDataHandler();
    try {
      await photoAccessHelper.MediaAssetManager.requestImageData(context, photoAsset, requestOptions, handler);
    } catch (exception) {
      Logger.error(TAG_LOG, `requestImageData failed, code is ${exception.code}, message is ${exception.message}`);
    }
  }

  public setPhotoOutputCbDouble(cameraPhotoOutput: camera.PhotoOutput): void {
    cameraPhotoOutput.on('photoAssetAvailable',
      async (_err: BusinessError, photoAsset: photoAccessHelper.PhotoAsset): Promise<void> => {
        let accessHelper: photoAccessHelper.PhotoAccessHelper =
          photoAccessHelper.getPhotoAccessHelper(this.context);
        this.mediaLibSavePhoto(photoAsset, accessHelper);
        this.mediaLibRequestBuffer(photoAsset, this.context, this.callback);
      });
  }

  setPhotoOutputCallback(): void {
    if (!this.output) {
      return;
    }
    this.setPhotoOutputCbDouble(this.output);
  }

  preparePhoto(session: camera.Session, zoomRatio?: number, flashMode?: camera.FlashMode,
    focusMode?: camera.FocusMode): void {
    const photoSession = session as camera.PhotoSession;
    this.setPhotoFlash(photoSession, flashMode);
    this.setPhotoFocus(photoSession, focusMode);
    this.setPhotoZoomRatio(photoSession, zoomRatio || 0);
  }

  setColorSpaceBeforeCommitConfig(session: camera.PhotoSession, isHdr: boolean): void {
    let colorSpace: colorSpaceManager.ColorSpace =
      isHdr ? colorSpaceManager.ColorSpace.DISPLAY_P3 : colorSpaceManager.ColorSpace.SRGB;
    let colorSpaces: colorSpaceManager.ColorSpace[] = [];
    try {
      colorSpaces = session.getSupportedColorSpaces();
    } catch (error) {
      Logger.error(TAG_LOG, `The getSupportedColorSpaces call failed. Error code: ${error.code}`);
    }
    if (!colorSpaces.includes(colorSpace)) {
      Logger.info(TAG_LOG, `colorSpace: ${colorSpace} is not support`);
      return;
    }
    try {
      Logger.info(TAG_LOG, `setColorSpace: ${colorSpace}`);
      session.setColorSpace(colorSpace);
    } catch (exception) {
      Logger.error(TAG_LOG, `setColorSpace failed, code is ${exception.code}, message is ${exception.message}`);
    }
    try {
      let activeColorSpace: colorSpaceManager.ColorSpace = session.getActiveColorSpace();
      Logger.info(TAG_LOG, `activeColorSpace: ${activeColorSpace}`);
    } catch (error) {
      Logger.error(TAG_LOG, `getActiveColorSpace Faild: ${error.message}`);
    }
  }

  public checkFlash(photoSession: camera.PhotoSession, flashMode?: camera.FlashMode): boolean {
    let flashModeStatus: boolean = false;
    try {
      if (photoSession.hasFlash()) {
        flashModeStatus = photoSession.isFlashModeSupported(flashMode || camera.FlashMode.FLASH_MODE_CLOSE);
      }
    } catch (exception) {
      Logger.error(TAG_LOG, `checkFlash failed, code is ${exception.code}, message is ${exception.message}`);
    }
    return flashModeStatus;
  }

  public setPhotoFlash(photoSession: camera.PhotoSession, flashMode?: camera.FlashMode): void {
    try {
      if (this.checkFlash(photoSession, flashMode)) {
        photoSession.setFlashMode(flashMode || camera.FlashMode.FLASH_MODE_CLOSE);
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to hasFlash. Error: ${JSON.stringify(error)}`);
    }
  }

  public setPhotoFocus(photoSession: camera.PhotoSession, focusMode?: camera.FocusMode): void {
    const defaultMode = camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO;
    try {
      let focusModeStatus: boolean = photoSession.isFocusModeSupported(focusMode || defaultMode);
      if (focusModeStatus) {
        photoSession.setFocusMode(focusMode || defaultMode);
      }
    } catch (error) {
      Logger.error(TAG_LOG,
        `Failed to check whether the focus mode is supported. Error: ${JSON.stringify(error)}`);
    }
  }

  public setFocusPoint(photoSession: camera.PhotoSession, focusPoint: camera.Point): void {
    try {
      photoSession.setFocusPoint(focusPoint);
    } catch (error) {
      Logger.error(TAG_LOG, `The setFocusPoint call failed. Error code: ${error.code}`);
    }
  }

  public setPhotoZoomRatio(photoSession: camera.PhotoSession, zoomRatio?: number): void {
    let photoZoomRatio = 0;
    if (!zoomRatio) {
      try {
        let zoomRatioRange: number[] = photoSession.getZoomRatioRange();
        if (zoomRatioRange?.length) {
          photoZoomRatio = zoomRatioRange[0];
        }
      } catch (error) {
        Logger.error(TAG_LOG, `Failed to get the zoom ratio range. Error: ${JSON.stringify(error)}`);
      }
    }
    try {
      photoSession.setZoomRatio(zoomRatio || photoZoomRatio);
    } catch (exception) {
      Logger.error(TAG_LOG, `setZoomRatio failed, code is ${exception.code}, message is ${exception.message}`);
    }
  }

  getSupportedColorSpaces(session: camera.PhotoSession): colorSpaceManager.ColorSpace[] {
    let colorSpaces: colorSpaceManager.ColorSpace[] = [];
    try {
      colorSpaces = session.getSupportedColorSpaces();
    } catch (error) {
      Logger.error(TAG_LOG, `The getSupportedColorSpaces call failed. Error code: ${error.code}`);
    }
    return colorSpaces;
  }

  getPhotoRotation(photoOutput: camera.PhotoOutput, deviceDegree: number): camera.ImageRotation {
    let photoRotation: camera.ImageRotation = camera.ImageRotation.ROTATION_0;
    try {
      photoRotation = photoOutput.getPhotoRotation(deviceDegree);
    } catch (error) {
      Logger.error(TAG_LOG, `The photoOutput.getPhotoRotation call failed. Error code: ${error.code}`);
    }
    return photoRotation;
  }

  public async capture(isFront: boolean): Promise<void> {
    if (!this.output) {
      Logger.error(TAG_LOG, 'Failed to capture the photo due to photo output undefined');
      return;
    }
    const degree = await this.getPhotoDegree();
    const rotation = this.getPhotoRotation(this.output, degree);
    let settings: camera.PhotoCaptureSetting = {
      quality: camera.QualityLevel.QUALITY_LEVEL_HIGH,
      rotation,
      mirror: isFront
    };
    this.output.capture(settings, (err: BusinessError) => {
      if (err) {
        Logger.error(TAG_LOG, `Failed to capture the photo. Error: ${JSON.stringify(err)}`);
        return;
      }
      Logger.info(TAG_LOG, 'Callback invoked to indicate the photo capture request success.');
    });
  }

  private calculateDeviceDegree(x: number, y: number, z: number): number {
    let deviceDegree: number = 0;
    if ((x * x + y * y) * 3 < z * z) {
      return deviceDegree;
    } else {
      try {
        let sd: Decimal = Decimal.atan2(y, -x);
        let sc: Decimal = Decimal.round(Number(sd) / Math.PI * 180);
        deviceDegree = 90 - Number(sc);
        deviceDegree = deviceDegree >= 0 ? deviceDegree % 360 : deviceDegree % 360 + 360;
      } catch (exception) {
        Logger.error(TAG_LOG,
          `calculateDeviceDegree failed, code is ${exception.code}, message is ${exception.message}`);
      }
    }
    return deviceDegree;
  }

  private getPhotoDegree(): Promise<number> {
    const promise: Promise<number> = new Promise(resolve => {
      try {
        sensor.once(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
          let degree = this.calculateDeviceDegree(data.x, data.y, data.z);
          resolve(degree);
        });
      } catch (exception) {
        Logger.error(TAG_LOG, `getPhotoDegree failed, code is ${exception.code}, message is ${exception.message}`);
        resolve(0);
      }
    });
    return promise;
  }

  public isMovingPhotoSupported(photoOutput: camera.PhotoOutput): boolean {
    let isSupported: boolean = false;
    try {
      isSupported = photoOutput.isMovingPhotoSupported();
    } catch (error) {
      Logger.error(TAG_LOG, `The isMovingPhotoSupported call failed. Error code: ${error.code}`);
    }
    return isSupported;
  }

  public enableMovingPhoto(enabled: boolean): void {
    try {
      this.output?.enableMovingPhoto(enabled);
    } catch (error) {
      Logger.error(TAG_LOG, `The enableMovingPhoto call failed. Error code: ${error.code}`);
    }
  }

  async release(): Promise<void> {
    this.output?.off('photoAssetAvailable');
    try {
      await this.output?.release();
    } catch (exception) {
      Logger.error(TAG_LOG, `release failed, code is ${exception.code}, message is ${exception.message}`);
    }
    this.output = undefined;
  }
}
