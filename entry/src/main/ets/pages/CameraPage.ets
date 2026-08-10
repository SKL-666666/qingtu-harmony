// CameraPage - 原生相机预览（已移除调色板/滤镜功能）

import { sensor } from '@kit.SensorServiceKit';
import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import RefreshableTimer from '../camerautils/RefreshableTimer';
import SettingButtonsView from '../cameraviews/SettingButtonsView';
import { OperateButtonsView } from '../cameraviews/OperateButtonsView';
import { PreviewScreenView } from '../cameraviews/PreviewScreenView';
import { FuncButtonView } from '../cameraviews/FuncButtomView';
import ZoomButtonsView from '../cameraviews/ZoomButtonsView';
import PreviewViewModel, { CameraMode } from '../cameramodels/PreviewViewModel';
import { AppTheme } from '../common/constants/Theme';

const TAG = 'CameraPage';

@Component
export struct CameraTab {
  @StorageLink('themeMode') themeMode: string = 'dark';
  @Prop @Watch('onActiveChange') isActive: boolean = true;
  @State previewVM: PreviewViewModel = new PreviewViewModel(this.getUIContext());
  @State capturedImage: image.PixelMap | undefined = undefined;
  @State capturedImageUrl: string = '';
  private context: Context = this.getUIContext().getHostContext()!;
  private applicationContext = this.context.getApplicationContext();
  private windowClass?: window.Window;
  private isCameraRunning: boolean = false;

  onActiveChange(): void {
    if (this.isActive) {
      this.startCamera();
    } else {
      this.stopCamera();
    }
  }

  async startCamera(): Promise<void> {
    if (this.previewVM.isSleeping || this.isCameraRunning) {
      return;
    }
    try {
      await this.previewVM.cameraManagerStart();
      this.previewVM.syncButtonSettings();
      this.isCameraRunning = true;
      Logger.info(TAG, 'Camera started (tab active)');
    } catch (e) {
      Logger.error(TAG, 'startCamera failed');
    }
  }

  stopCamera(): void {
    if (!this.isCameraRunning) {
      return;
    }
    this.previewVM.openPreviewBlur();
    this.previewVM.cameraManagerRelease();
    this.isCameraRunning = false;
    Logger.info(TAG, 'Camera stopped (tab inactive)');
  }

  async aboutToAppear(): Promise<void> {
    this.addGravityEventListener();
    this.initSleepTimer();
    this.registerApplicationStateChange();
    this.addOrientationChangeEventListener();
    try {
      this.windowClass = (this.context as common.UIAbilityContext).windowStage.getMainWindowSync();
    } catch (exception) {
      Logger.error(TAG, 'getMainWindowSync failed');
    }
    try {
      display.on('foldStatusChange', () => { this.onFoldStatusChange(); });
    } catch (exception) {
      Logger.error(TAG, 'onFoldStatusChange failed');
    }
    this.previewVM.cameraMode = CameraMode.PHOTO;
    // 仅在 Tab 可见时启动相机
    if (this.isActive) {
      await this.startCamera();
    }
  }

  aboutToDisappear(): void {
    sensor.off(sensor.SensorId.GRAVITY);
    this.previewVM.sleepTimer?.clear();
    this.applicationContext.off('applicationStateChange');
    this.removeOrientationChangeEventListener();
    this.stopCamera();
  }

  addGravityEventListener(): void {
    try {
      sensor.on(sensor.SensorId.GRAVITY, (data) => {
        this.previewVM.acc = data;
      }, { interval: 100 * 1000 * 1000 });
    } catch (exception) {
      Logger.error(TAG, 'addGravityEventListener failed');
    }
  }

  initSleepTimer(): void {
    this.previewVM.sleepTimer = new RefreshableTimer(() => {
      this.previewVM.isSleeping = true;
      this.stopCamera();
    }, 30 * 1000);
    this.previewVM.sleepTimer.start();
    const observer = this.getUIContext().getUIObserver();
    observer.on('willClick', () => { this.previewVM.sleepTimer?.refresh(); });
  }

  registerApplicationStateChange(): void {
    this.applicationContext.on('applicationStateChange', {
      onApplicationForeground: async () => {
        this.addGravityEventListener();
        // 仅在相机 Tab 可见时恢复相机
        if (this.isActive) {
          await this.startCamera();
        }
      },
      onApplicationBackground: () => {
        sensor.off(sensor.SensorId.GRAVITY);
        this.stopCamera();
      }
    });
  }

  addOrientationChangeEventListener(): void {
    this.windowClass?.on('windowSizeChange', () => { this.previewVM.setPreviewSize(); });
  }

  removeOrientationChangeEventListener(): void {
    this.windowClass?.off('windowSizeChange');
  }

  async onFoldStatusChange(): Promise<void> {
    this.stopCamera();
    if (this.isActive) {
      await this.startCamera();
    }
  }

  private onPhotoCaptured(px: image.PixelMap, url: string): void {
    this.capturedImageUrl = url;
    this.capturedImage = px;
  }

  @Builder
  wakeupMask() {
    Column() {
      Text($r('app.string.wakeup_text')).fontColor(AppTheme.TEXT_PRIMARY).opacity(0.6)
    }
    .width('100%').height('100%').backgroundColor(AppTheme.BG_GRADIENT_TOP)
    .justifyContent(FlexAlign.Center)
    .onClick(async () => {
      this.previewVM.isSleeping = false;
      this.previewVM.sleepTimer?.refresh();
      await this.startCamera();
    })
  }

  build() {
    Stack() {
      // 底层: 相机全屏预览,向上偏移55px让预览框更靠上
      Column() {
        PreviewScreenView({ previewVM: this.previewVM })
      }
      .margin({ top: -165 })

      // 顶部: 设置按钮 (闪光灯/帧率/延时等)
      Column() {
        SettingButtonsView({ previewVM: this.previewVM })
      }
      .position({ top: 0 })
      .width('100%')

      // 右上: 功能按钮 (网格/水平仪/双预览)
      Column() {
        FuncButtonView({ previewVM: this.previewVM })
      }
      .position({ top: 90, right: 10 })

      // 变焦按钮毛玻璃背景长条 (压暗,左右居中)
      Column() {
        Row()
          .width(160)
          .height(40)
          .borderRadius(20)
          .backgroundColor(AppTheme.CAMERA_BAR)
          .border({ width: 1, color: AppTheme.BORDER_GLASS })
          .backdropBlur(AppTheme.BLUR_THICK)
      }
      .position({ bottom: 180 })
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 变焦按钮,居中,拍照按钮上方
      Column() {
        ZoomButtonsView({ previewVM: this.previewVM })
      }
      .position({ bottom: 184 })
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 底部: 拍照/录像按钮,居中
      if (!this.previewVM.photoRemainder) {
        Column() {
          OperateButtonsView({
            previewVM: this.previewVM,
            onCaptureComplete: (pixelMap: image.PixelMap, url: string) => {
              this.onPhotoCaptured(pixelMap, url);
            }
          });
        }
        .position({ bottom: 90 })
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      // 顶层: 休眠遮罩
      if (this.previewVM.isSleeping) { this.wakeupMask(); }
    }
    .width('100%')
    .height('100%')
    .linearGradient(AppTheme.getBackgroundGradient(180))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
