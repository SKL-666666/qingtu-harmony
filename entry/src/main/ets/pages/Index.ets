import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppTheme } from '../common/constants/Theme';
import { ProcessState, ProgressInfo, ImageInfo, ProcessResult } from '../common/types/ImageTypes';
import { ErrorUtils } from '../common/utils/ErrorUtils';
import { LogUtils } from '../common/utils/LogUtils';
import { ImageProcessService } from '../services/ImageProcessService';
import { FileService } from '../services/FileService';
import { ProgressOverlay } from '../components/business/LoadingProgress';
import { ImageCompareViewer, ImageCompareInfo } from '../components/business/ImageCompareViewer';
import { AboutTab } from './AboutPage';
import { CompressionTab } from './CompressionPage';
import { CameraTab } from './CameraPage';
import { HdsTabs, HdsTabsController, hdsMaterial, DividerMode } from '@kit.UIDesignKit';

/**
 * 图片处理状态
 * @Observed 装饰:属性变化可被 @ObjectLink 子组件监听,触发 UI 刷新
 */
@Observed
class ImageProcessStatus {
  originalInfo: ImageInfo | null = null;
  resultPixelMap: image.PixelMap | undefined = undefined;
  imageData: ArrayBuffer | null = null;
  isProcessed: boolean = false;
  isProcessing: boolean = false;
  isSaved: boolean = false;
  error: string | null = null;
  enhancedWidth: number = 0;
  enhancedHeight: number = 0;
  durationMs: number = 0;
}

/**
 * 图片卡片子组件
 * @ObjectLink 监听 ImageProcessStatus 属性变化,自动刷新 UI
 * 卡片宽度自适应 Grid 列宽,缩略图用 aspectRatio(1) 保持正方形
 * 单击图片弹出菜单:预览(已增强)/删除
 */
@Component
struct ImageCard {
  @ObjectLink status: ImageProcessStatus;
  @Prop index: number;
  @Prop progressValue: number;
  onRetry: (status: ImageProcessStatus) => void = () => {};
  onRemove: (status: ImageProcessStatus) => void = () => {};
  onOpenCompare: (status: ImageProcessStatus) => void = () => {};
  onSave: (status: ImageProcessStatus) => void = () => {};
  onShowActions: (index: number) => void = () => {};

  build() {
    Column({ space: 6 }) {
      // 缩略图 + 覆盖层 - 宽度自适应,正方形
      Stack() {
        Image(this.status.originalInfo?.pixelMap)
          .width('100%')
          .aspectRatio(1)
          .objectFit(ImageFit.Cover)
          .borderRadius(AppTheme.RADIUS_THUMB)
          .onClick(() => {
            console.info('ImageCard clicked, index: ' + this.index + ', isProcessed: ' + this.status.isProcessed);
            this.onShowActions(this.index);
          })

        if (this.status.isProcessing) {
          Column()
            .width('100%')
            .aspectRatio(1)
            .borderRadius(AppTheme.RADIUS_THUMB)
            .backgroundColor('rgba(0,0,0,0.55)')

          Progress({
            value: this.progressValue,
            total: 100,
            type: ProgressType.Ring
          })
            .width(36)
            .height(36)
            .color(AppTheme.ACCENT_PRIMARY)
        }

        if (this.status.isSaved) {
          Stack() {
            Text('✓')
              .fontSize(13)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor(AppTheme.ACCENT_SUCCESS)
          .border({ width: 1.5, color: 'rgba(0,0,0,0.4)' })
          .markAnchor({ x: '100%', y: '100%' })
          .position({ x: '100%', y: '100%' })
          .offset({ x: -8, y: -8 })
        }
      }
      .width('100%')
      .aspectRatio(1)

      // 状态文本
      if (this.status.isProcessing) {
        Text('处理中')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .maxLines(1)
      } else if (this.status.isSaved) {
        Text('已保存')
          .fontSize(11)
          .fontColor(AppTheme.ACCENT_SUCCESS)
          .maxLines(1)
      } else if (this.status.error) {
        Text('失败')
          .fontSize(11)
          .fontColor(AppTheme.ACCENT_ERROR)
          .maxLines(1)
      } else if (this.status.isProcessed) {
        Text('已增强')
          .fontSize(11)
          .fontColor(AppTheme.ACCENT_PRIMARY)
          .maxLines(1)
      } else {
        Text('待处理')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_TERTIARY)
          .maxLines(1)
      }

      // 尺寸信息
      if (this.status.isProcessed) {
        Text(this.status.enhancedWidth + '×' + this.status.enhancedHeight)
          .fontSize(9)
          .fontColor(AppTheme.TEXT_TERTIARY)
          .maxLines(1)
      } else if (this.status.originalInfo) {
        Text(this.status.originalInfo.width + '×' + this.status.originalInfo.height)
          .fontSize(9)
          .fontColor(AppTheme.TEXT_TERTIARY)
          .maxLines(1)
      }

      // 重试按钮 (仅失败时显示)
      if (this.status.error && !this.status.isProcessing) {
        Button('重试')
          .width('100%')
          .height(26)
          .fontSize(11)
          .fontColor(AppTheme.ACCENT_ERROR)
          .backgroundColor(AppTheme.SURFACE_GLASS)
          .border({ width: 0.5, color: AppTheme.ACCENT_ERROR })
          .borderRadius(13)
          .onClick(() => this.onRetry(this.status))
      }

      // 保存按钮 - SaveButton 安全组件(仅已增强且未保存时显示)
      // 只用安全控件支持的属性: width/height/fontSize/fontColor/backgroundColor/borderRadius
      // 不用 linearGradient/shadow/fontWeight(会导致授权失败)
      if (this.status.isProcessed && !this.status.isSaved && !this.status.isProcessing) {
        SaveButton({
          icon: SaveIconStyle.FULL_FILLED,
          text: SaveDescription.SAVE,
          buttonType: ButtonType.Normal
        })
          .width('100%')
          .height(26)
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.ACCENT_PRIMARY)
          .borderRadius(13)
          .onClick((_event: ClickEvent, result: SaveButtonOnClickResult, _error?: BusinessError) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              this.onSave(this.status);
            }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 主页面 - 多图片批量超分辨率增强
 * 深色玻璃拟态风格
 */
@Entry
@Component
struct Index {
  @StorageLink('themeMode') themeMode: string = 'dark';
  @State private processState: ProcessState = ProcessState.IDLE;
  @State private imageList: ImageProcessStatus[] = [];
  @State private progressInfo: ProgressInfo = {
    progress: 0,
    stage: '准备中',
    isCancellable: true
  };
  @State private showHelpDialog: boolean = false;
  @State private showCompareViewer: boolean = false;
  @State private compareIndex: number = -1;
  // 未保存的已处理图片数量 (响应式,手动更新)
  @State private unsavedCount: number = 0;
  // 自定义操作弹窗
  @State private showActionDialog: boolean = false;
  @State private actionDialogIndex: number = -1;
  @State private currentTab: number = 0;

  private imageProcessService: ImageProcessService = ImageProcessService.getInstance();
  private fileService: FileService = FileService.getInstance();
  // 缓存 UIAbilityContext,避免 getContext(this) 在异步回调中失效
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    await this.initializeServices();
  }

  aboutToDisappear(): void {
    void this.cleanupAllResources();
  }

  // ==================== 服务初始化 ====================
  private async initializeServices(): Promise<void> {
    try {
      await this.imageProcessService.initializeEnvironment();
      LogUtils.info('应用初始化完成');
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('初始化失败', err);
      ErrorUtils.showStringErrorToast(this.getUIContext(), '初始化失败');
    }
  }

  private async cleanupAllResources(): Promise<void> {
    for (const status of this.imageList) {
      if (status.originalInfo?.pixelMap) {
        this.imageProcessService.releasePixelMap(status.originalInfo.pixelMap);
      }
      if (status.resultPixelMap) {
        this.imageProcessService.releasePixelMap(status.resultPixelMap);
      }
    }
    await this.imageProcessService.deinitializeEnvironment();
  }

  // ==================== 图片选择/管理 ====================
  private async handleSelectImages(): Promise<void> {
    try {
      const images: ImageInfo[] = await this.fileService.selectMultipleImagesFromGallery();
      if (images.length > 0) {
        await this.cleanupAllResources();
        this.imageList = [];

        // 新 API (imageSuperResolution) 无分辨率约束,仅过滤 PixelMap 无效的图片
        const validImages: ImageInfo[] = [];
        let invalidCount: number = 0;
        for (const img of images) {
          if (img.pixelMap && this.imageProcessService.canProcess(img.pixelMap).canProcess) {
            validImages.push(img);
          } else {
            invalidCount++;
            if (img.pixelMap) {
              // 无效图片释放 PixelMap
              this.imageProcessService.releasePixelMap(img.pixelMap);
            }
          }
        }

        for (const img of validImages) {
          const status: ImageProcessStatus = new ImageProcessStatus();
          status.originalInfo = img;
          this.imageList.push(status);
        }

        LogUtils.info('选择了 ' + images.length + ' 张图片,合格 ' + validImages.length + ' 张');

        if (invalidCount > 0) {
          ErrorUtils.showStringErrorToast(
            this.getUIContext(), '已跳过 ' + invalidCount + ' 张无法读取的图片'
          );
        }

        if (validImages.length > 0) {
          this.processState = ProcessState.IDLE;
        }
      }
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('选择图片失败', err);
      ErrorUtils.showErrorToast(this.getUIContext(), err);
    }
  }

  private handleRemoveImage(status: ImageProcessStatus): void {
    const index: number = this.imageList.indexOf(status);
    if (index < 0) {
      return;
    }
    if (status.originalInfo?.pixelMap) {
      this.imageProcessService.releasePixelMap(status.originalInfo.pixelMap);
    }
    if (status.resultPixelMap) {
      this.imageProcessService.releasePixelMap(status.resultPixelMap);
    }
    this.imageList.splice(index, 1);
    LogUtils.info('移除了第 ' + (index + 1) + ' 张图片');
  }

  private async handleClearAll(): Promise<void> {
    await this.cleanupAllResources();
    this.imageList = [];
    this.processState = ProcessState.IDLE;
    this.progressInfo = { progress: 0, stage: '准备中', isCancellable: true };
    LogUtils.info('已清除所有图片');
  }

  // ==================== 批量处理 ====================
  private async handleProcessAllImages(): Promise<void> {
    if (this.imageList.length === 0) {
      return;
    }

    const validCount: number = this.imageList.filter(
      (s: ImageProcessStatus) => s.originalInfo?.pixelMap
    ).length;

    if (validCount === 0) {
      ErrorUtils.showStringErrorToast(this.getUIContext(), '没有可处理的图片');
      return;
    }

    // 处理能力提示：底部 toast 提醒
    try {
      this.getUIContext().getPromptAction().showToast({
        message: '提示：超分将把图片放大 4 倍（最长边上限 4096 像素）',
        duration: 3000
      });
    } catch (error) {
      // 忽略 toast 错误
    }

    this.processState = ProcessState.PROCESSING;
    this.progressInfo = { progress: 0, stage: '准备中', isCancellable: true };
    let processedCount: number = 0;

    for (let i = 0; i < this.imageList.length; i++) {
      const status: ImageProcessStatus = this.imageList[i];
      if (!status.originalInfo?.pixelMap) {
        continue;
      }

      status.isProcessing = true;
      status.error = null;

      try {
        const result: ProcessResult = await this.imageProcessService.enhanceDetailAsync(
          status.originalInfo.pixelMap,
          (progress: ProgressInfo) => {
            const totalProgress: number = Math.floor(
              ((processedCount * 100) + progress.progress) / validCount
            );
            this.progressInfo = {
              progress: totalProgress,
              stage: '处理第 ' + (i + 1) + '/' + validCount + ' 张',
              isCancellable: true
            };
          }
        );

        if (result.success && result.pixelMap) {
          status.resultPixelMap = result.pixelMap;
          status.enhancedWidth = result.width ?? 0;
          status.enhancedHeight = result.height ?? 0;
          status.durationMs = result.duration ?? 0;
          status.imageData = await this.fileService.packPixelMapToData(result.pixelMap);
          status.isProcessed = true;
          status.isProcessing = false;
          processedCount++;
          this.updateUnsavedCount();
          LogUtils.info('第 ' + (i + 1) + ' 张处理成功');
        } else {
          // 优先显示 details(具体错误原因),其次 message
          status.error = result.error?.details ?? result.error?.message ?? '处理失败';
          status.isProcessing = false;
          LogUtils.error('第 ' + (i + 1) + ' 张超分失败: ' + status.error,
            new Error(status.error));
        }
      } catch (error) {
        const err: Error = error instanceof Error ? error : new Error(String(error));
        status.error = err.message;
        status.isProcessing = false;
        LogUtils.error('第 ' + (i + 1) + ' 张处理失败', err);
      }
    }

    this.processState = ProcessState.SUCCESS;
    this.progressInfo = { progress: 100, stage: '处理完成', isCancellable: false };
    LogUtils.info('批量处理完成: ' + processedCount + '/' + validCount + ' 张成功');
  }

  // ==================== 单图重试 ====================
  private async handleRetryImage(status: ImageProcessStatus): Promise<void> {
    const index: number = this.imageList.indexOf(status);
    if (index < 0 || !status.originalInfo?.pixelMap) {
      return;
    }

    status.isProcessing = true;
    status.error = null;

    try {
      const result: ProcessResult = await this.imageProcessService.enhanceDetailSingle(
        status.originalInfo.pixelMap
      );

      if (result.success && result.pixelMap) {
        if (status.resultPixelMap) {
          this.imageProcessService.releasePixelMap(status.resultPixelMap);
        }
        status.resultPixelMap = result.pixelMap;
        status.enhancedWidth = result.width ?? 0;
        status.enhancedHeight = result.height ?? 0;
        status.durationMs = result.duration ?? 0;
        status.imageData = await this.fileService.packPixelMapToData(result.pixelMap);
        status.isProcessed = true;
        status.isProcessing = false;
        this.updateUnsavedCount();
        this.getUIContext().getPromptAction().showToast({
          message: '重试成功', duration: 2000
        });
      } else {
        status.error = result.error?.details ?? result.error?.message ?? '重试失败';
        status.isProcessing = false;
        this.getUIContext().getPromptAction().showToast({
          message: status.error, duration: 5000
        });
      }
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      status.error = err.message;
      status.isProcessing = false;
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '重试失败: ' + err.message, duration: 5000
        });
      } catch (_e) { /* ignore */ }
    }
  }

  // ==================== 保存 (通过系统保存对话框 showAssetsCreationDialog) ====================
  // 无需 SaveButton 安全组件,无需权限声明,系统弹窗让用户确认保存

  // ==================== 对比预览 ====================
  private handleOpenCompare(status: ImageProcessStatus): void {
    if (!status.isProcessed) {
      return;
    }
    const index: number = this.imageList.indexOf(status);
    if (index < 0) {
      return;
    }
    this.compareIndex = index;
    this.showCompareViewer = true;
  }

  private handleCloseCompare(): void {
    this.showCompareViewer = false;
    this.compareIndex = -1;
  }

  // ==================== 其他控制 ====================
  private handleCancelProcess(): void {
    this.imageProcessService.cancelProcess();
    this.processState = ProcessState.IDLE;

    for (const status of this.imageList) {
      if (status.isProcessing) {
        status.isProcessing = false;
        status.error = null;
      }
    }
  }

  private getProcessedCount(): number {
    return this.imageList.filter((s: ImageProcessStatus) => s.isProcessed).length;
  }

  /**
   * 构造缩略图长按菜单项 - 已迁移至 ImageCard 组件
   */

  // ==================== UI Builder ====================
  @Builder
  private buildHeader() {
    Row({ space: 8 }) {
      Text('清图')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .layoutWeight(1)

      // 帮助按钮
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.questionmark_circle'))
          .fontSize(16)
          .fontColor([AppTheme.TEXT_SECONDARY])
      }
      .width(32)
      .height(32)
      .backgroundColor(AppTheme.SURFACE_GLASS)
      .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
      .onClick(() => { this.showHelpDialog = true; })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16, top: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildImageGrid() {
    if (this.imageList.length > 0) {
      Grid() {
        ForEach(this.imageList, (status: ImageProcessStatus, index: number) => {
          GridItem() {
            ImageCard({
              status: status,
              index: index,
              progressValue: this.progressInfo.progress,
              onRetry: (s: ImageProcessStatus) => this.handleRetryImage(s),
              onRemove: (s: ImageProcessStatus) => this.handleRemoveImage(s),
              onOpenCompare: (s: ImageProcessStatus) => this.handleOpenCompare(s),
              onSave: (s: ImageProcessStatus) => this.handleSaveSingle(s),
              onShowActions: (idx: number) => {
                this.actionDialogIndex = idx;
                this.showActionDialog = true;
              }
            })
          }
        }, (status: ImageProcessStatus, index: number) => index + '_' + (status.originalInfo?.uri ?? '') + '_' + status.isProcessed + '_' + status.isSaved + '_' + status.isProcessing + '_' + (status.error ?? ''))
      }
      .columnsTemplate('repeat(3, 1fr)')
      .rowsGap(16)
      .columnsGap(12)
      .padding({ top: 8, bottom: 8 })
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    } else {
      // 空态卡片 - 居中引导选择图片
      Column({ space: 8 }) {
        Text('＋')
          .fontSize(32)
          .fontColor(AppTheme.TEXT_TERTIARY)
        Text('选择图片')
          .fontSize(14)
          .fontColor(AppTheme.TEXT_TERTIARY)
        Text('最多 9 张 · 4x 超分增强')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_TERTIARY)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(AppTheme.RADIUS_CARD)
      .backgroundColor(AppTheme.SURFACE_CARD_EMPTY)
      .backgroundBlurStyle(AppTheme.BLUR_REGULAR)
      .border({ width: 1, color: AppTheme.BORDER_GLASS, style: BorderStyle.Dashed })
      .onClick(() => this.handleSelectImages())
    }
  }

  @Builder
  private buildProcessButton() {
    Button(this.imageList.length === 0 ? '批量增强' :
      (this.processState === ProcessState.PROCESSING ? '处理中...' :
        '批量增强 (' + this.imageList.length + '张)'))
      .width('100%')
      .height(AppTheme.BUTTON_HEIGHT)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .borderRadius(AppTheme.RADIUS_BUTTON)
      .backgroundColor(
        this.processState === ProcessState.PROCESSING
          ? AppTheme.SURFACE_GLASS
          : (this.imageList.length > 0 ? AppTheme.ACCENT_PRIMARY : AppTheme.ACCENT_SURFACE)
      )
      .fontColor(
        this.processState === ProcessState.PROCESSING
          ? AppTheme.TEXT_TERTIARY
          : (this.imageList.length > 0 ? Color.White : AppTheme.TEXT_PRIMARY)
      )
      .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
      .enabled(this.imageList.length > 0 && this.processState !== ProcessState.PROCESSING)
      .onClick(() => this.handleProcessAllImages())
  }

  @Builder
  private buildClearButton() {
    Button('清除全部')
      .width('100%')
      .height(AppTheme.BUTTON_HEIGHT_SMALL)
      .fontSize(13)
      .fontColor(
        this.imageList.length > 0 && this.processState !== ProcessState.PROCESSING
          ? AppTheme.TEXT_SECONDARY : AppTheme.TEXT_TERTIARY
      )
      .backgroundColor(AppTheme.SURFACE_GLASS)
      .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
      .borderRadius(AppTheme.BUTTON_HEIGHT_SMALL / 2)
      .enabled(this.imageList.length > 0 && this.processState !== ProcessState.PROCESSING)
      .onClick(() => { void this.handleClearAll(); })
  }

  /**
   * 全部保存按钮 - SaveButton 安全组件
   * 只用安全控件支持的属性: width/height/fontSize/fontColor/backgroundColor/borderRadius
   * 不用 linearGradient/shadow/fontWeight(会导致授权失败)
   */
  @Builder
  private buildSaveAllButton() {
    if (this.unsavedCount > 0 && this.processState !== ProcessState.PROCESSING) {
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_TO_GALLERY,
        buttonType: ButtonType.Normal
      })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.ACCENT_PRIMARY)
        .borderRadius(AppTheme.RADIUS_BUTTON)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult, error?: BusinessError) => {
          LogUtils.info('全部保存 SaveButton 点击: result=' + result);
          if (result === SaveButtonOnClickResult.SUCCESS) {
            LogUtils.info('SaveButton 授权成功,开始全部保存...');
            this.handleSaveAll();
          } else {
            const errMsg: string = error?.message ?? String(result);
            LogUtils.error('SaveButton 授权失败: ' + errMsg, error instanceof Error ? error : new Error(errMsg));
            ErrorUtils.showStringErrorToast(this.getUIContext(), '保存授权失败: ' + errMsg);
          }
        })
    } else {
      // 禁用占位 - 保持按钮区域固定高度
      Button('全部保存至图库')
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .fontSize(15)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .backgroundColor(AppTheme.ACCENT_SURFACE)
        .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
        .borderRadius(AppTheme.RADIUS_BUTTON)
        .enabled(false)
    }
  }

  // 保存单张图片到图库 - 由卡片上的 SaveButton 授权后调用
  // SaveButton 每次点击只授权一次保存,用户需逐张点击卡片上的保存按钮
  private async handleSaveSingle(status: ImageProcessStatus): Promise<void> {
    if (!status.isProcessed || status.isSaved || !status.imageData) {
      return;
    }

    try {
      LogUtils.info('保存图片,数据大小: ' + status.imageData.byteLength + ' bytes');
      const saveUri: string = await this.fileService.saveToGallery(this.context, status.imageData);
      status.isSaved = true;
      status.imageData = null;
      this.updateUnsavedCount();
      LogUtils.info('已保存: ' + saveUri);
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '已保存到图库', duration: 2000
        });
      } catch (_e) { /* ignore */ }
    } catch (e) {
      const err: Error = e instanceof Error ? e : new Error(String(e));
      LogUtils.error('保存失败', err);
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '保存失败: ' + err.message, duration: 5000
        });
      } catch (_e) { /* ignore */ }
    }
  }

  /**
   * 全部保存 - 由底部 SaveButton 授权后调用
   * 在 SaveButton 授权窗口内(API20+ 为 1 分钟),循环调用 saveToGallery
   * 复用与单张保存完全相同的逻辑(createAsset + fileIo.writeSync)
   */
  private async handleSaveAll(): Promise<void> {
    let successCount: number = 0;
    let failCount: number = 0;
    let firstErrorMsg: string = '';
    const savedIndices: number[] = [];

    try {
      const unsavedCount: number = this.imageList.filter(
        (s: ImageProcessStatus) => s.isProcessed && !s.isSaved && s.imageData
      ).length;
      LogUtils.info('开始全部保存,待保存数量: ' + unsavedCount);

      if (unsavedCount === 0) {
        return;
      }

      for (let i = 0; i < this.imageList.length; i++) {
        const status: ImageProcessStatus = this.imageList[i];
        if (status.isProcessed && !status.isSaved && status.imageData) {
          try {
            const dataToSave: ArrayBuffer = status.imageData;
            LogUtils.info('保存第 ' + (i + 1) + ' 张,数据大小: ' + dataToSave.byteLength + ' bytes');
            const saveUri: string = await this.fileService.saveToGallery(this.context, dataToSave);
            savedIndices.push(i);
            successCount++;
            LogUtils.info('第 ' + (i + 1) + ' 张已保存: ' + saveUri);
          } catch (e) {
            failCount++;
            const errMsg: string = e instanceof Error ? e.message : String(e);
            if (firstErrorMsg.length === 0) {
              firstErrorMsg = errMsg;
            }
            LogUtils.error('第 ' + (i + 1) + ' 张保存失败: ' + errMsg,
              e instanceof Error ? e : new Error(errMsg));
          }
        }
      }

      // 保存完成后统一更新状态
      for (const idx of savedIndices) {
        this.imageList[idx].isSaved = true;
        this.imageList[idx].imageData = null;
      }
      this.updateUnsavedCount();

      const promptAction = this.getUIContext().getPromptAction();
      if (failCount === 0) {
        promptAction.showToast({
          message: '已保存 ' + successCount + ' 张到图库',
          duration: 2000
        });
      } else if (successCount > 0) {
        promptAction.showToast({
          message: '保存: ' + successCount + '张成功, ' + failCount + '张失败\n' + firstErrorMsg,
          duration: 5000
        });
      } else {
        promptAction.showToast({
          message: '保存失败: ' + firstErrorMsg,
          duration: 5000
        });
      }
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('全部保存异常', err);
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '保存失败: ' + err.message,
          duration: 5000
        });
      } catch (e) {
        // 忽略 toast 错误
      }
    }
  }

  /**
   * 更新未保存计数 (手动触发 UI 刷新)
   */
  private updateUnsavedCount(): void {
    let count: number = 0;
    for (let i = 0; i < this.imageList.length; i++) {
      if (this.imageList[i].isProcessed && !this.imageList[i].isSaved) {
        count++;
      }
    }
    this.unsavedCount = count;
  }

  @Builder
  private buildHelpDialog() {
    if (this.showHelpDialog) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(AppTheme.BG_OVERLAY)
          .backgroundBlurStyle(AppTheme.BLUR_THICK)
          .onClick(() => { this.showHelpDialog = false; })

        // 玻璃卡片
        Column({ space: 16 }) {
          Text('使用说明')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT_PRIMARY)

          Column({ space: 8 }) {
            Text('本应用支持批量图片超分辨率增强,基于官方 Core Vision Kit 图像超分能力。')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('使用流程')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_PRIMARY)
            Text('1. 点击「选择图片」选择多张图片(最多 9 张)')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
            Text('2. 点击「批量增强」开始超分处理')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
            Text('3. 点击已处理缩略图查看前后对比')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
            Text('4. 点击底部「保存至图库」按钮存入系统相册')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Text('超分原理')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_PRIMARY)
            Text('• 基于 Core Vision Kit 图像超分重建细节')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
            Text('• 固定放大 4 倍,输出最长边上限 4096 像素')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
            Text('• 超大图会先缩小到 1024 像素再超分')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)

          Text('使用系统安全组件「保存至图库」按钮,点击即授权保存到系统相册,无需申请权限。')
            .fontSize(12)
            .fontColor(AppTheme.TEXT_TERTIARY)

          Button('关闭')
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .fontSize(15)
            .borderRadius(AppTheme.RADIUS_BUTTON)
            .linearGradient(AppTheme.getAccentGradient(135))
            .fontColor(AppTheme.TEXT_PRIMARY)
            .margin({ top: 4 })
            .onClick(() => { this.showHelpDialog = false; })
        }
        .padding(AppTheme.PADDING_CARD)
        .width('85%')
        .borderRadius(AppTheme.RADIUS_CARD)
        .backgroundColor(AppTheme.SURFACE_GLASS)
        .backgroundBlurStyle(AppTheme.BLUR_THICK)
        .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
        .shadow(AppTheme.getCardShadow())
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
  }

  private getCompareOriginalPixelMap(): image.PixelMap | undefined {
    if (this.compareIndex < 0 || this.compareIndex >= this.imageList.length) {
      return undefined;
    }
    return this.imageList[this.compareIndex].originalInfo?.pixelMap;
  }

  private getCompareEnhancedPixelMap(): image.PixelMap | undefined {
    if (this.compareIndex < 0 || this.compareIndex >= this.imageList.length) {
      return undefined;
    }
    return this.imageList[this.compareIndex].resultPixelMap;
  }

  private getCompareInfo(): ImageCompareInfo {
    const empty: ImageCompareInfo = {
      originalWidth: 0,
      originalHeight: 0,
      enhancedWidth: 0,
      enhancedHeight: 0,
      durationMs: 0
    };
    if (this.compareIndex < 0 || this.compareIndex >= this.imageList.length) {
      return empty;
    }
    const status: ImageProcessStatus = this.imageList[this.compareIndex];
    const info: ImageCompareInfo = {
      originalWidth: status.originalInfo?.width ?? 0,
      originalHeight: status.originalInfo?.height ?? 0,
      enhancedWidth: status.enhancedWidth,
      enhancedHeight: status.enhancedHeight,
      durationMs: status.durationMs
    };
    return info;
  }

  @Builder
  private buildCompareViewer() {
    if (this.showCompareViewer && this.compareIndex >= 0) {
      ImageCompareViewer({
        originalPixelMap: this.getCompareOriginalPixelMap(),
        enhancedPixelMap: this.getCompareEnhancedPixelMap(),
        enhancedInfo: this.getCompareInfo(),
        onClose: () => this.handleCloseCompare()
      })
    }
  }

  private getActionStatus(): ImageProcessStatus | undefined {
    if (this.actionDialogIndex < 0 || this.actionDialogIndex >= this.imageList.length) {
      return undefined;
    }
    return this.imageList[this.actionDialogIndex];
  }

  @Builder
  private buildActionDialog() {
    if (this.showActionDialog) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.55)')
          .onClick(() => {
            this.showActionDialog = false;
            this.actionDialogIndex = -1;
          })

        Column({ space: 16 }) {
          Text(this.getActionStatus()?.isProcessed ? '选择操作' : '确认删除?')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)
            .width('100%')

          Row({ space: 12 }) {
            if (this.getActionStatus()?.isProcessed) {
              Button('对比')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor(AppTheme.ACCENT_PRIMARY)
                .borderRadius(10)
                .onClick(() => {
                  const status = this.getActionStatus();
                  this.showActionDialog = false;
                  this.actionDialogIndex = -1;
                  if (status) {
                    this.handleOpenCompare(status);
                  }
                })
            }
            Button('删除')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor(AppTheme.ACCENT_ERROR)
              .borderRadius(10)
              .onClick(() => {
                const status = this.getActionStatus();
                this.showActionDialog = false;
                this.actionDialogIndex = -1;
                if (status) {
                  this.handleRemoveImage(status);
                }
              })
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .backgroundColor(AppTheme.SURFACE_GLASS)
              .borderRadius(10)
              .onClick(() => {
                this.showActionDialog = false;
                this.actionDialogIndex = -1;
              })
          }
          .width('100%')
        }
        .padding(24)
        .width('75%')
        .borderRadius(20)
        .backgroundColor(AppTheme.SURFACE_GLASS_STRONG)
        .backgroundBlurStyle(AppTheme.BLUR_THICK)
        .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
  }

  private hdsController: HdsTabsController = new HdsTabsController();

  // 底部导航栏 (图标 + 小字号文字)
  @Builder
  private buildTabLabel(icon: Resource, text: string) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([AppTheme.TEXT_PRIMARY])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)

      Text(text)
        .fontSize(11)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .margin({ top: 2 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        HdsTabs({ controller: this.hdsController }) {
          TabContent() {
            // ===== Tab 1: 超分增强 =====
            Column() {
              this.buildHeader()

              Column({ space: 12 }) {
                this.buildImageGrid()

                if (this.imageList.length > 0) {
                  Text('已选择 ' + this.imageList.length + ' 张 · 已处理 ' + this.getProcessedCount() + ' 张')
                    .fontSize(12)
                    .fontColor(AppTheme.TEXT_SECONDARY)
                    .width('100%')
                    .padding({ left: 4, right: 4 })
                }

                this.buildProcessButton()
              }
              .padding({ left: 16, right: 16, top: 8 })
              .layoutWeight(1)
              .width('100%')

              Column({ space: 8 }) {
                this.buildSaveAllButton()
                this.buildClearButton()
              }
              .padding({ left: 16, right: 16, top: 4, bottom: 80 })
              .width('100%')
            }
            .width('100%')
            .height('100%')
            .linearGradient(AppTheme.getBackgroundGradient(180))
          }
          .tabBar(this.buildTabLabel($r('sys.symbol.ohos_photo'), '超分'))

          TabContent() {
            // ===== Tab 2: 压缩 =====
            CompressionTab()
          }
          .tabBar(this.buildTabLabel($r('sys.symbol.checkered_magnifyingglass'), '压缩'))

          TabContent() {
            // ===== Tab 3: 相机 =====
            CameraTab({ isActive: this.currentTab === 2 })
          }
          .tabBar(this.buildTabLabel($r('sys.symbol.camera'), '相机'))

          TabContent() {
            // ===== Tab 4: 关于 =====
            AboutTab()
          }
          .tabBar(this.buildTabLabel($r('sys.symbol.info_circle'), '关于'))
        }
        .barPosition(BarPosition.End)
        .vertical(false)
        .scrollable(false)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // 去掉分割线
        .divider({ mode: DividerMode.NONE })
        // 沉浸光感 - 底部悬浮导航栏
        // 通过 systemMaterialEffect 配置 IMMERSIVE 材质实现
        .barFloatingStyle({
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          },
          lightColor: '#33FFFFFF',
          barOpacity: 1
        })
        .width('100%')
        .height('100%')
        .onChange((index: number) => {
          this.currentTab = index;
        })
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 全屏覆盖层
      if (this.processState === ProcessState.PROCESSING) {
        ProgressOverlay({
          progressInfo: this.progressInfo,
          onCancel: () => this.handleCancelProcess()
        })
      }
      this.buildCompareViewer()
      this.buildHelpDialog()
      this.buildActionDialog()
    }
    .width('100%')
    .height('100%')
  }
}

