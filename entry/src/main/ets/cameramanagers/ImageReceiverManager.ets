/*
 * Image receiver management class for dual-stream preview.
 */

import { image } from '@kit.ImageKit';
import { camera } from '@kit.CameraKit';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { OutputManager, CreateOutputConfig } from './OutputManager';
import CameraConstant from '../cameraconstants/CameraConstants';

const TAG = 'ImageReceiverManager';

/**
 * Dual-stream preview output - image receiver management class, responsible for the creation,
 * configuration, and release of this output stream.
 *
 * Uses JPEG format; frames are decoded to RGBA PixelMap for GL rendering.
 */
export class ImageReceiverManager implements OutputManager {
  public output?: camera.PreviewOutput;
  public isActive: boolean = true;
  public callback: (px: image.PixelMap) => void;
  private position: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;

  constructor(cb: (px: image.PixelMap) => void) {
    this.callback = cb;
  }

  async createOutput(config: CreateOutputConfig): Promise<camera.PreviewOutput | undefined> {
    const cameraOutputCap = config.cameraManager?.getSupportedOutputCapability(config.device, config.sceneMode);
    const displayRatio = config.profile.size.width / config.profile.size.height;
    const profileWidth = config.profile.size.width;
    const previewProfile = cameraOutputCap?.previewProfiles
      .sort((a, b) => Math.abs(a.size.width - profileWidth) - Math.abs(b.size.width - profileWidth))
      .find(pf => {
        const pfDisplayRatio = pf.size.width / pf.size.height;
        return pf.format === config.profile.format &&
          Math.abs(pfDisplayRatio - displayRatio) <= CameraConstant.PROFILE_DIFFERENCE;
      });
    if (!previewProfile) {
      Logger.error(TAG, 'Failed to get preview profile');
      return undefined;
    }
    const surfaceId = await this.init(config.profile.size);
    try {
      this.output = config.cameraManager?.createPreviewOutput(previewProfile, surfaceId);
    } catch (exception) {
      Logger.error(TAG, `createPreviewOutput failed, code is ${exception.code}, message is ${exception.message}`);
    }
    this.position = config.device.cameraPosition;
    return this.output;
  }

  async release(): Promise<void> {
    try {
      await this.output?.release();
    } catch (exception) {
      Logger.error(TAG, `release failed, code is ${exception.code}, message is ${exception.message}`);
    }
    this.output = undefined;
  }

  async init(size: Size, format: image.ImageFormat = image.ImageFormat.JPEG, capacity: number = 8): Promise<string> {
    const receiver = image.createImageReceiver(size, format, capacity);
    const surfaceId = await receiver.getReceivingSurfaceId();
    this.onImageArrival(receiver);
    return surfaceId;
  }

  onImageArrival(receiver: image.ImageReceiver): void {
    receiver.on('imageArrival', () => {
      Logger.info(TAG, 'imageArrival');
      receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
        if (err || nextImage === undefined) {
          nextImage?.release();
          Logger.error(TAG, 'readNextImage failed');
          return;
        }
        nextImage.getComponent(image.ComponentType.JPEG, async (errJ: BusinessError, imgComponent: image.Component) => {
          if (errJ || !imgComponent?.byteBuffer) {
            Logger.error(TAG, 'get JPEG component failed');
            nextImage.release();
            return;
          }
          try {
            const pixelMap: image.PixelMap = await this.getPixelMap(imgComponent,
              nextImage.size.width, nextImage.size.height);
            // Apply rotation for correct orientation
            const finalPx = await this.rotatePixelMap(pixelMap);
            this.callback(finalPx);
          } catch (e) {
            Logger.error(TAG, 'decode pixelmap failed');
          }
          nextImage.release();
        });
      });
    });
  }

  private async getPixelMap(imgComponent: image.Component, width: number, height: number): Promise<image.PixelMap> {
    const imageSource: image.ImageSource = image.createImageSource(imgComponent.byteBuffer);
    const pixelMap = await imageSource.createPixelMap({
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      desiredSize: { width: width, height: height },
      desiredRegion: { size: { width: width, height: height }, x: 0, y: 0 },
    });
    imageSource.release();
    return pixelMap;
  }

  private async rotatePixelMap(px: image.PixelMap): Promise<image.PixelMap> {
    try {
      const displayDefault = display.getDefaultDisplaySync();
      const displayRotation = (displayDefault?.rotation ?? 0) * camera.ImageRotation.ROTATION_90;
      const rotation = this.output?.getPreviewRotation(displayRotation) || 0;
      if (rotation === 90 || rotation === 270 || rotation === 180) {
        px.rotate(rotation);
      }
      if (this.position === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        px.flip(true, false);
      }
    } catch (e) {
      Logger.error(TAG, `rotatePixelMap error: ${JSON.stringify(e)}`);
    }
    return px;
  }
}
