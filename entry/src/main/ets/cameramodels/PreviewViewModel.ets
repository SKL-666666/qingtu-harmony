/*
 * Preview view model.
 */

import { curves, display } from '@kit.ArkUI';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { sensor } from '@kit.SensorServiceKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { ImageReceiverManager } from '../cameramanagers/ImageReceiverManager';
import { MetadataManager } from '../cameramanagers/MetadataManager';
import { PhotoManager } from '../cameramanagers/PhotoManager';
import { PreviewManager } from '../cameramanagers/PreviewManager';
import { VideoManager } from '../cameramanagers/VideoManager';
import WindowUtil from '../camerautils/WindowUtil';
import CameraEntryConstant from '../cameraconstants/Constants';
import { CameraManagerModel } from './CameraManagerModel';
import RefreshableTimer from '../camerautils/RefreshableTimer';

export enum CameraMode {
  PHOTO,
  VIDEO
}

const TAG = 'PreviewViewModel';

/**
 * States and methods related to preview.
 */
@Observed
class PreviewViewModel {
  public isFront: boolean = false;
  public cameraMode: CameraMode = CameraMode.PHOTO;
  public xComponentController: XComponentController = new XComponentController();
  public surfaceId: string = '';
  public previewSize: Size = WindowUtil.getMaxDisplaySize(CameraEntryConstant.RATIO_PHOTO);
  public rates?: number[] = [];
  public currentRate: number = 0;
  public blurRadius: number = 0;
  public blurRotation: RotateOptions = { y: 0.5, angle: 0 };
  public faceBoundingBoxArr: camera.Rect[] = [];
  public acc: sensor.AccelerometerResponse = { x: 0, y: 0, z: 0 } as sensor.AccelerometerResponse;

  public isDelayTakePhoto: boolean = false;
  public photoDelayTime: number = 0;
  public photoRemainder: number = 0;

  public isStabilizationEnabled: boolean = false;
  public zoomRange: number[] = [];
  public zooms: number[] = [1, 3.5, 10];
  public currentZoom: number = 1;

  public isGridLineVisible: boolean = false;
  public isLevelIndicatorVisible: boolean = false;
  public isLivePhoto: boolean = false;
  public isPreviewImageVisible: boolean = false;
  public previewImage: PixelMap | ResourceStr = '';
  public isSleeping: boolean = false;
  public sleepTimer: RefreshableTimer | undefined = undefined;
  public frameCount: number = 0;
  public onFrameCallback: ((px: image.PixelMap) => void) | null = null;

  public getProfile: (cameraOrientation: number) => camera.Profile = cameraOrientation => {
    const displaySize: Size = WindowUtil.getMaxDisplaySize(this.getPreviewRatio());
    let displayDefault: display.Display | null = null;
    try {
      displayDefault = display.getDefaultDisplaySync();
    } catch (exception) {
      Logger.error(TAG, `getDefaultDisplaySync failed, code is ${exception.code}, message is ${exception.message}`);
    }
    const displayRotation = (displayDefault?.rotation ?? 0) * 90;
    const isRevert = (cameraOrientation + displayRotation) % 180 !== 0;
    return {
      format: camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP,
      size: {
        height: isRevert ? displaySize.width : displaySize.height,
        width: isRevert ? displaySize.height : displaySize.width
      }
    };
  };

  private context: Context | undefined;
  private uiContext: UIContext;
  private cameraManagerModel: CameraManagerModel;

  constructor(uiContext: UIContext) {
    this.uiContext = uiContext;
    let context = this.uiContext.getHostContext()!;
    this.context = context;

    let previewManager = new PreviewManager(() => {
      this.closePreviewBlur();
    });
    let photoManager = new PhotoManager(this.context, true);
    let videoManager = new VideoManager(this.context);
    let imageReceiverManager = new ImageReceiverManager(px => {
      this.onImageReceiver(px);
    });
    let metadataManager = new MetadataManager(faceBoxArr => {
      this.onMetadataObjectsAvailable(faceBoxArr);
    });
    this.cameraManagerModel = new CameraManagerModel(context, previewManager,
      photoManager, videoManager, imageReceiverManager, metadataManager);
  }

  onPreviewStart(): void {
    this.closePreviewBlur();
  }

  async onImageReceiver(pixelMap: image.PixelMap): Promise<void> {
    // 释放上一帧的 PixelMap,避免每帧泄漏
    if (this.previewImage !== null && typeof this.previewImage !== 'string') {
      try {
        (this.previewImage as image.PixelMap).release();
      } catch (_e) { /* ignore */ }
    }
    this.previewImage = pixelMap;
    this.frameCount++;
    if (this.onFrameCallback) {
      this.onFrameCallback(pixelMap);
    }
  }

  onMetadataObjectsAvailable(faceBoxArr: camera.Rect[]): void {
    faceBoxArr.forEach((value) => {
      value.topLeftX *= this.getPreviewWidth();
      value.topLeftY *= this.getPreviewHeight();
      value.width *= this.getPreviewWidth();
      value.height *= this.getPreviewHeight();
    });
    this.faceBoundingBoxArr = faceBoxArr;
  }

  async cameraManagerStart(): Promise<void> {
    let cameraPosition = this.getCameraPosition();
    let sceneMode = this.getSceneMode();
    await this.cameraManagerModel.cameraManager.start(this.surfaceId, cameraPosition, sceneMode, this.getProfile,
      this.isStabilizationEnabled);
  }

  /**
   * 切换滤镜模式 - 控制是否创建 XComponent 的 PreviewOutput
   * - 滤镜激活: PreviewManager.isActive=false, 只用 ImageReceiver 接收帧
   * - 原图模式: PreviewManager.isActive=true, 两个 output 都创建
   */
  async switchFilterMode(isFilterActive: boolean): Promise<void> {
    this.cameraManagerModel.previewManager.isActive = !isFilterActive;
    await this.cameraManagerStart();
  }

  async cameraManagerRelease(): Promise<void> {
    await this.cameraManagerModel.cameraManager.release();
    // 释放残留的预览帧 PixelMap
    if (this.previewImage !== null && typeof this.previewImage !== 'string') {
      try {
        (this.previewImage as image.PixelMap).release();
      } catch (_e) { /* ignore */ }
    }
    this.previewImage = '';
  }

  getCameraZoomRange(): number[] {
    return this.cameraManagerModel.cameraManager.getZoomRange();
  }

  setCameraZoomRatio(): void {
    this.cameraManagerModel.cameraManager.setZoomRatio(this.currentZoom);
  }

  setCameraFocusMode(focusMode: camera.FocusMode): void {
    this.cameraManagerModel.cameraManager.setFocusMode(focusMode);
  }

  setCameraExposureMode(exposureMode: camera.ExposureMode): void {
    this.cameraManagerModel.cameraManager.setExposureMode(exposureMode);
  }

  setCameraFocusPoint(cameraPoint: camera.Point): void {
    this.cameraManagerModel.cameraManager.setFocusPoint(cameraPoint);
  }

  setCameraMeteringPoint(cameraPoint: camera.Point): void {
    this.cameraManagerModel.cameraManager.setMeteringPoint(cameraPoint);
  }

  setCameraFlashMode(mode: camera.FlashMode): void {
    this.cameraManagerModel.cameraManager.setFlashMode(mode);
  }

  setCameraSmoothZoom(zoom: number): void {
    this.cameraManagerModel.cameraManager.setSmoothZoom(zoom);
  }

  syncButtonSettings(): void {
    this.cameraManagerModel.previewManager.setFrameRate(this.currentRate, this.currentRate);
    this.cameraManagerModel.photoManager.enableMovingPhoto(this.isLivePhoto);
    this.cameraManagerModel.photoManager.setPhotoOutputCallback();
    this.currentZoom = 1;
    this.faceBoundingBoxArr.length = 0;
  }

  isPreviewManagerExist(): boolean {
    if (this.cameraManagerModel.previewManager) {
      return true;
    }
    return false;
  }

  setPhotoIsActive(): void {
    this.cameraManagerModel.photoManager.setIsActive(this.isPhotoMode() ? true : false);
  }

  setVideoIsActive(): void {
    this.cameraManagerModel.videoManager.setIsActive(this.isPhotoMode() ? false : true);
  }

  setPhotoCallback(cb: (pixelMap: image.PixelMap, url: string) => void): void {
    this.cameraManagerModel.photoManager.setCallback(cb);
  }

  setVideoCallback(cb: (pixelMap: image.PixelMap, url: string) => void): void {
    this.cameraManagerModel.videoManager.setVideoCallback(cb);
  }

  async photoCapture(): Promise<void> {
    this.cameraManagerModel.photoManager.capture(this.isFront);
  }

  async videoStart(): Promise<void> {
    this.cameraManagerModel.videoManager.start(this.isFront);
  }

  async videoPause(): Promise<void> {
    this.cameraManagerModel.videoManager.pause();
  }

  async videoResume(): Promise<void> {
    this.cameraManagerModel.videoManager.resume();
  }

  async videoStop(): Promise<void> {
    await this.cameraManagerModel.videoManager.stop();
  }

  isVideoRecording(): boolean {
    return this.cameraManagerModel.videoManager.isRecording();
  }

  checkVideoState(state: media.AVRecorderState): boolean {
    return this.cameraManagerModel.videoManager.state === state;
  }

  getPreviewSupportedFrameRates(): camera.FrameRateRange[] | undefined {
    return this.cameraManagerModel.previewManager.getSupportedFrameRates();
  }

  setPreviewFrameRate(minRate: number, maxRate: number): void {
    this.cameraManagerModel.previewManager.setFrameRate(minRate, maxRate);
  }

  enableMovingPhoto(): void {
    this.cameraManagerModel.photoManager.enableMovingPhoto(this.isLivePhoto);
  }

  getCameraPosition(): camera.CameraPosition {
    return this.isFront
      ? camera.CameraPosition.CAMERA_POSITION_FRONT
      : camera.CameraPosition.CAMERA_POSITION_BACK;
  }

  getPreviewRatio(): number {
    return this.cameraMode === CameraMode.PHOTO
      ? CameraEntryConstant.RATIO_PHOTO
      : CameraEntryConstant.RATIO_VIDEO;
  }

  getSceneMode(): camera.SceneMode {
    return this.cameraMode === CameraMode.PHOTO
      ? camera.SceneMode.NORMAL_PHOTO
      : camera.SceneMode.NORMAL_VIDEO;
  }

  setPreviewSize(): void {
    const displaySize: Size = WindowUtil.getMaxDisplaySize(this.getPreviewRatio());
    this.previewSize = displaySize;
    this.xComponentController.setXComponentSurfaceRect({
      surfaceWidth: displaySize.width,
      surfaceHeight: displaySize.height
    });
  }

  getPreviewTop(): number {
    const previewRatio = this.getPreviewRatio();
    return WindowUtil.getWindowRatio() > previewRatio ? 85 : 0;
  }

  getPreviewWidth(): number {
    return this.uiContext.px2vp(this.previewSize.width);
  }

  getPreviewHeight(): number {
    return this.uiContext.px2vp(this.previewSize.height);
  }

  isPhotoMode(): boolean {
    return this.cameraMode === CameraMode.PHOTO;
  }

  isVideoMode(): boolean {
    return this.cameraMode === CameraMode.VIDEO;
  }

  isCurrentCameraMode(mode: CameraMode): boolean {
    return this.cameraMode === mode;
  }

  openPreviewBlur(): void {
    animateToImmediately({
      duration: 200,
      curve: Curve.Friction
    }, () => {
      this.blurRadius = 150;
    });
  }

  rotatePreviewBlur(): void {
    animateToImmediately({
      delay: 50,
      duration: 200,
      curve: curves.cubicBezierCurve(0.2, 0, 0.83, 1),
      onFinish: () => {
        this.rotatePreviewBlurSecond();
      }
    }, () => {
      this.blurRotation = { y: 0.5, angle: 90 };
    });
  }

  rotatePreviewBlurSecond(): void {
    this.blurRotation = { y: 0.5, angle: 270 };
    animateToImmediately({
      duration: 200,
      curve: curves.cubicBezierCurve(0.17, 0, 0.2, 1),
      onFinish: () => {
        this.blurRotation = { y: 0.5, angle: 0 };
      }
    }, () => {
      this.blurRotation = { y: 0.5, angle: 360 };
    });
  }

  closePreviewBlur(): void {
    animateToImmediately({
      duration: 200,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.blurRadius = 0;
    });
  }
}

export default PreviewViewModel;
