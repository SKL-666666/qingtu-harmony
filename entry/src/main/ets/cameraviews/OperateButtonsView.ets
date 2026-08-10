/*
 * Operate buttons view - photo capture, video start/stop, camera switch.
 */

import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AVRecorderState } from '../cameramanagers/VideoManager';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import PreviewViewModel from '../cameramodels/PreviewViewModel';
import { inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import { AppTheme } from '../common/constants/Theme';

const TAG = 'OperateButtonsView';

/**
 * Shooting operation button components, including taking photos, starting, pausing,
 * and stopping video recording, as well as switching cameras.
 */
@Component
export struct OperateButtonsView {
  @State thumbnail: image.PixelMap | string = '';
  @State thumbnailUrl: string = '';
  @ObjectLink previewVM: PreviewViewModel;
  @StorageLink('captureClick') captureClickFlag: number = 0;
  private photoDelayTimer: number = 0;
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  // 拍照完成回调(由 CameraPage 设置,用于应用滤镜等后处理)
  onCaptureComplete: (pixelMap: image.PixelMap, url: string) => void = () => {};
  private setThumbnail: (pixelMap: image.PixelMap, url: string) => void = (pixelMap: image.PixelMap, url: string) => {
    this.thumbnail = pixelMap;
    this.thumbnailUrl = url;
    this.onCaptureComplete(pixelMap, url);
  };
  private volumeUpCallBackFunc: (event: KeyEvent) => void = () => {};
  private volumeDownCallBackFunc: (event: KeyEvent) => void = () => {};

  aboutToAppear(): void {
    this.previewVM.setPhotoCallback(this.setThumbnail);
    this.previewVM.setVideoCallback(this.setThumbnail);
    this.setVolumeKeyCallback();
  }

  aboutToDisappear(): void {
    try {
      inputConsumer.off('keyPressed');
    } catch (error) {
      Logger.error(TAG, `inputConsumer off keyPressed failed, code is ${error.code}, message is ${error.message}`);
    }
  }

  setVolumeKeyCallback(): void {
    let volumeUpOptions: inputConsumer.KeyPressedConfig = {
      key: KeyCode.KEYCODE_VOLUME_UP,
      action: 1,
      isRepeat: false
    };

    let volumeDownOptions: inputConsumer.KeyPressedConfig = {
      key: KeyCode.KEYCODE_VOLUME_DOWN,
      action: 1,
      isRepeat: false
    };

    this.volumeUpCallBackFunc = (event: KeyEvent): void => {
      Logger.info(TAG, 'KEYCODE_VOLUME_UP' + JSON.stringify(event));
      if (event.keys.length > 1) {
        return;
      }
      this.volumeKeyPressedFunc();
    };

    this.volumeDownCallBackFunc = (event: KeyEvent): void => {
      Logger.info(TAG, 'KEYCODE_VOLUME_DOWN' + JSON.stringify(event));
      if (event.keys.length > 1) {
        return;
      }
      this.volumeKeyPressedFunc();
    };

    try {
      inputConsumer.on('keyPressed', volumeUpOptions, this.volumeUpCallBackFunc);
      inputConsumer.on('keyPressed', volumeDownOptions, this.volumeDownCallBackFunc);
    } catch (error) {
      Logger.error(TAG, `inputConsumer on keyPressed failed, code is ${error.code}, message is ${error.message}`);
    }
  }

  async volumeKeyPressedFunc(): Promise<void> {
    if (this.previewVM.isSleeping) {
      this.previewVM.isSleeping = false;
      this.previewVM.sleepTimer?.refresh();
      await this.previewVM.cameraManagerStart();
      this.previewVM.syncButtonSettings();
      return;
    }

    if (this.previewVM.isPhotoMode()) {
     this.takePhoto();
    }
    else {
      if (this.previewVM.isVideoRecording()) {
        this.stopRecord();
      } else {
        this.previewVM.videoStart();
      }
    }
  }

  takePhoto(): void {
    if (this.previewVM.photoDelayTime) {
      this.previewVM.isDelayTakePhoto = true;
      this.previewVM.photoRemainder = this.previewVM.photoDelayTime;
      this.photoDelayTimer = setInterval(() => {
        this.previewVM.photoRemainder--;
        if (this.previewVM.photoRemainder === 0) {
          this.previewVM.photoCapture();
          this.captureClickFlag++;
          this.previewVM.isDelayTakePhoto = false;
          clearInterval(this.photoDelayTimer);
        }
      }, 1000);
    } else {
      this.previewVM.photoCapture();
      this.captureClickFlag++;
    }
  }

  async stopRecord(): Promise<void> {
    if (this.previewVM.checkVideoState(AVRecorderState.STARTED) ||
    this.previewVM.checkVideoState(AVRecorderState.PAUSED)) {
      await this.previewVM.videoStop();
      await this.previewVM.cameraManagerRelease();
      await this.previewVM.cameraManagerStart();
      this.previewVM.syncButtonSettings();
    }
  }

  @Builder
  photoButton() {
    Column() {
      Column()
        .width(48)
        .height(48)
        .borderRadius('50%')
        .border({
          color: AppTheme.TEXT_PRIMARY,
          width: 24
        })
    }
    .width(64)
    .height(64)
    .borderRadius('50%')
    .border({
      color: AppTheme.TEXT_PRIMARY,
      width: 1
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.takePhoto();
    })
  }

  @Builder
  videoStartButton() {
    Column() {
      Column()
        .width(52)
        .height(52)
        .backgroundColor(Color.Red)
        .borderRadius('50%')
        .border({
          color: AppTheme.TEXT_PRIMARY,
          width: 8
        })
    }
    .width(64)
    .height(64)
    .borderRadius('50%')
    .border({
      color: AppTheme.TEXT_PRIMARY,
      width: 1
    })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.previewVM.videoStart();
    })
  }

  @Builder
  videoStopButton() {
    Column() {
      Column()
        .width(28)
        .height(28)
        .borderRadius(10)
        .backgroundColor(Color.Red)
    }
    .width(64)
    .height(64)
    .borderRadius('50%')
    .border({
      color: AppTheme.TEXT_PRIMARY,
      width: 1
    })
    .justifyContent(FlexAlign.Center)
    .onClick(async () => {
      this.stopRecord();
    })
  }

  @Builder
  videoPauseButton() {
    SymbolGlyph($r('sys.symbol.pause'))
      .fontColor([AppTheme.TEXT_PRIMARY])
      .fontSize(22)
      .fontWeight(FontWeight.Bolder)
      .padding(11)
      .borderWidth(1)
      .borderColor(AppTheme.TEXT_PRIMARY)
      .borderRadius('50%')
      .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
      .onClick(async () => {
        this.previewVM.videoPause();
      })
  }

  @Builder
  videoResumeButton() {
    SymbolGlyph($r('sys.symbol.play'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([AppTheme.TEXT_PRIMARY])
      .fontSize(22)
      .padding(11)
      .borderWidth(1)
      .borderColor(AppTheme.TEXT_PRIMARY)
      .borderRadius('50%')
      .onClick(async () => {
        this.previewVM.videoResume();
      })
  }

  @Builder
  thumbnailButton() {
    Image(this.thumbnail)
      .width(48)
      .height(48)
      .borderRadius('50%')
      .borderWidth(this.thumbnail ? 1 : 0)
      .borderColor(AppTheme.TEXT_PRIMARY)
      .clip(true)
      .onClick(() => {
        if (this.thumbnailUrl) {
          this.context.startAbility({
            parameters: { uri: this.thumbnailUrl },
            action: 'ohos.want.action.viewData',
            bundleName: 'com.huawei.hmos.photos',
            abilityName: 'com.huawei.hmos.photos.MainAbility'
          }).catch((err: BusinessError) => {
            Logger.error(TAG, `showToast failed, code is ${err.code}, message is ${err.message}`);
          });
        }
      })
  }

  @Builder
  delayTakePhotoCancelButton() {
    SymbolGlyph($r('sys.symbol.pause'))
      .fontColor([AppTheme.TEXT_PRIMARY])
      .fontSize(22)
      .fontWeight(FontWeight.Bolder)
      .padding(11)
      .borderWidth(1)
      .borderColor(AppTheme.TEXT_PRIMARY)
      .borderRadius('50%')
      .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
      .onClick(async () => {
        this.previewVM.isDelayTakePhoto = false;
        clearInterval(this.photoDelayTimer);
        this.previewVM.photoRemainder = 0;
      })
  }

  @Builder
  toggleCameraPositionButton() {
    Image($r('app.media.toggle_position'))
      .width(48)
      .height(48)
      .colorFilter([
        0, 0, 0, AppTheme.isDark ? 0.961 : 0.102, 0,
        0, 0, 0, AppTheme.isDark ? 0.961 : 0.102, 0,
        0, 0, 0, AppTheme.isDark ? 0.980 : 0.180, 0,
        0, 0, 0, 1, 0
      ])
      .onClick(async () => {
        this.previewVM.openPreviewBlur();
        this.previewVM.rotatePreviewBlur();
        this.previewVM.isFront = !this.previewVM.isFront;
        await this.previewVM.cameraManagerRelease();
        await this.previewVM.cameraManagerStart();
        this.previewVM.syncButtonSettings();
      })
  }

  build() {
    Row() {
      this.thumbnailButton();
      if (this.previewVM.isPhotoMode()) {
        this.photoButton();
      } else {
        if (this.previewVM.isVideoRecording()) {
          this.videoStopButton();
        } else {
          this.videoStartButton();
        }
      }
      if (!this.previewVM.isVideoRecording()) {
        this.toggleCameraPositionButton();
      }
      if (this.previewVM.isVideoMode() && this.previewVM.checkVideoState(AVRecorderState.STARTED)) {
        this.videoPauseButton();
      } else if (this.previewVM.isVideoMode() && this.previewVM.checkVideoState(AVRecorderState.PAUSED)) {
        this.videoResumeButton();
      }
    }
    .justifyContent(FlexAlign.SpaceAround)
    .width('90%')
  }
}
