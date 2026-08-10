import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppTheme } from '../common/constants/Theme';
import { FileService } from '../services/FileService';
import { LogUtils } from '../common/utils/LogUtils';

/** 压缩结果 */
interface CompressedResult {
  pixelMap: image.PixelMap;
  byteLength: number;
  data: ArrayBuffer;
}

/** 压缩常量 */
class CompressionConstants {
  static readonly PICTURE_QUALITY_MAX: number = 100;
  static readonly DICHOTOMY_ACCURACY: number = 10;
  static readonly REDUCE_SCALE: number = 0.4;
  static readonly BYTE_CONVERSION: number = 1024;
}

/**
 * 图片压缩页面 Tab 组件
 * 移植自 image-compression-master,适配深色主题+选图+保存到图库
 * 核心算法: 二分法查找最优质量 + 缩放逼近目标大小
 */
@Component
export struct CompressionTab {
  @StorageLink('themeMode') themeMode: string = 'dark';
  @State private hasImage: boolean = false;
  @State private originalPixelMap: image.PixelMap | undefined = undefined;
  @State private compressedPixelMap: image.PixelMap | undefined = undefined;
  @State private originalSize: string = '';
  @State private compressedSize: string = '';
  @State private originalBytes: number = 0;
  @State private compressedBytes: number = 0;
  @State private maxTargetKB: number = 500;
  @State private inputText: string = '500';
  @State private isCompressing: boolean = false;
  @State private isSaved: boolean = false;
  private fileService: FileService = FileService.getInstance();
  /** 缓存 UIAbility 上下文,避免 getContext(this) 在 SaveButton onClick 中返回错误对象 */
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

  /**
   * 选择图片并解码
   */
  private async handleSelectImage(): Promise<void> {
    try {
      const imageInfo = await this.fileService.selectImageFromGallery();
      if (!imageInfo || !imageInfo.pixelMap) {
        return;
      }

      // 释放旧资源
      this.releaseResources();

      this.originalPixelMap = imageInfo.pixelMap;
      this.originalBytes = await this.getPixelMapBytes(imageInfo.pixelMap);
      this.originalSize = (this.originalBytes / CompressionConstants.BYTE_CONVERSION).toFixed(1) + ' KB';
      this.hasImage = true;
      this.compressedPixelMap = undefined;
      this.compressedSize = '';
      this.isSaved = false;
      LogUtils.info('压缩: 已选择图片, 原始大小 ' + this.originalSize);
    } catch (error) {
      LogUtils.error('压缩: 选图失败', error instanceof Error ? error : new Error(String(error)));
    }
  }

  /**
   * 获取 PixelMap 的字节大小 (通过 packToData 为 JPEG)
   */
  private async getPixelMapBytes(pixelMap: image.PixelMap): Promise<number> {
    try {
      const packer = image.createImagePacker();
      const opts: image.PackingOption = { format: 'image/jpeg', quality: 100 };
      const data: ArrayBuffer = await packer.packToData(pixelMap, opts);
      packer.release();
      return data.byteLength;
    } catch (e) {
      return 0;
    }
  }

  /**
   * 压缩图片 - 二分法查找最优质量
   * DMA PixelMap 的 cloneSync() 结果可能无效,改用 pack/unpack 转换为非 DMA PixelMap
   */
  private async compressImage(): Promise<void> {
    if (!this.originalPixelMap) {
      return;
    }

    const targetKB: number = this.maxTargetKB;
    const targetBytes: number = targetKB * CompressionConstants.BYTE_CONVERSION;

    if (targetBytes >= this.originalBytes) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '目标大小已大于原图,无需压缩',
          duration: 2000
        });
      } catch (_e) { /* ignore */ }
      return;
    }

    this.isCompressing = true;
    let workingMap: image.PixelMap | undefined;

    try {
      // DMA PixelMap 的 cloneSync() 可能返回无效 PixelMap
      // 通过 pack/unpack 转换为非 DMA PixelMap (RGBA_8888)
      const conversionPacker = image.createImagePacker();
      const conversionOpts: image.PackingOption = { format: 'image/jpeg', quality: 100 };
      const conversionData: ArrayBuffer = await conversionPacker.packToData(this.originalPixelMap!, conversionOpts);
      conversionPacker.release();
      const conversionSource = image.createImageSource(conversionData);
      workingMap = await conversionSource.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      conversionSource.release();

      // 先尝试质量压缩
      let result: CompressedResult = await this.compressWithQuality(workingMap, targetBytes);

      // 如果质量压缩到 0 仍超出目标,则缩放
      if (result.byteLength > targetBytes) {
        result = await this.compressWithScaling(workingMap, targetBytes);
      }

      this.compressedPixelMap = result.pixelMap;
      this.compressedBytes = result.byteLength;
      this.compressedSize = (result.byteLength / CompressionConstants.BYTE_CONVERSION).toFixed(1) + ' KB';
      this.isSaved = false;

      const ratio: string = ((1 - result.byteLength / this.originalBytes) * 100).toFixed(1);
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '压缩完成,减少 ' + ratio + '%',
          duration: 2000
        });
      } catch (_e) { /* ignore */ }
      LogUtils.info('压缩完成: ' + this.compressedSize + ' (减少 ' + ratio + '%)');
    } catch (error) {
      LogUtils.error('压缩失败', error instanceof Error ? error : new Error(String(error)));
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '压缩失败',
          duration: 3000
        });
      } catch (_e) { /* ignore */ }
    } finally {
      this.isCompressing = false;
      // 释放临时 workingMap (避免内存泄漏)
      if (workingMap) {
        try { workingMap.release(); } catch (_e) { /* ignore */ }
      }
    }
  }

  /**
   * 二分法质量压缩
   */
  private async compressWithQuality(pixelMap: image.PixelMap, targetBytes: number): Promise<CompressedResult> {
    const packer = image.createImagePacker();
    const packingArray: number[] = [];
    for (let i = 0; i <= CompressionConstants.PICTURE_QUALITY_MAX; i += CompressionConstants.DICHOTOMY_ACCURACY) {
      packingArray.push(i);
    }

    let bestQuality: number = 0;
    let bestData: ArrayBuffer = new ArrayBuffer(0);

    // 先用最低质量压缩
    const lowOpts: image.PackingOption = { format: 'image/jpeg', quality: 0 };
    try {
      bestData = await packer.packToData(pixelMap, lowOpts);
    } catch (_e) {
      // packToData may throw, fall through to use low quality result below
    }

    if (bestData.byteLength <= targetBytes) {
      // 二分法查找最高可用质量
      let left: number = 0;
      let right: number = packingArray.length - 1;
      while (left <= right) {
        const mid: number = Math.floor((left + right) / 2);
        const quality: number = packingArray[mid];
        const opts: image.PackingOption = { format: 'image/jpeg', quality: quality };
        try {
          const data: ArrayBuffer = await packer.packToData(pixelMap, opts);
          if (data.byteLength <= targetBytes) {
            bestData = data;
            left = mid + 1;
          } else {
            right = mid - 1;
          }
        } catch (_e) {
          right = mid - 1;
        }
      }
    }

    packer.release();

    // 用最佳质量重新解码为 PixelMap
    const imageSource = image.createImageSource(bestData);
    const decodedMap: image.PixelMap = await imageSource.createPixelMap();
    imageSource.release();

    return {
      pixelMap: decodedMap,
      byteLength: bestData.byteLength,
      data: bestData
    };
  }

  /**
   * 缩放压缩 - 质量降到0仍不够时缩小尺寸
   * 修复: pixelMap.scale() 是相对当前尺寸累加的,需用 prevScale 跟踪已应用的缩放比
   */
  private async compressWithScaling(pixelMap: image.PixelMap, targetBytes: number): Promise<CompressedResult> {
    let scale: number = 1;
    let prevScale: number = 1;
    let lastData: ArrayBuffer = new ArrayBuffer(0);
    const packer = image.createImagePacker();

    while (scale > 0) {
      scale = scale - CompressionConstants.REDUCE_SCALE;
      if (scale <= 0) {
        scale = 0.1;
      }
      // scale() 是相对缩放,用 scale/prevScale 转换为绝对缩放
      await pixelMap.scale(scale / prevScale, scale / prevScale);
      prevScale = scale;
      const opts: image.PackingOption = { format: 'image/jpeg', quality: 0 };
      try {
        lastData = await packer.packToData(pixelMap, opts);
      } catch (_e) {
        break;
      }
      if (lastData.byteLength <= targetBytes) {
        break;
      }
      if (scale <= 0.1) {
        break;
      }
    }

    packer.release();

    const imageSource = image.createImageSource(lastData);
    const decodedMap: image.PixelMap = await imageSource.createPixelMap();
    imageSource.release();

    return {
      pixelMap: decodedMap,
      byteLength: lastData.byteLength,
      data: lastData
    };
  }

  /**
   * 保存压缩后图片到图库
   * 完全模仿超分功能的保存逻辑:
   * 1. 将结果 PixelMap 通过 packPixelMapToData 打包为 ArrayBuffer
   * 2. 通过 saveToGallery 保存到系统图库
   */
  private async handleSave(): Promise<void> {
    if (!this.compressedPixelMap) {
      LogUtils.warn('handleSave: compressedPixelMap 为空');
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '没有可保存的数据', duration: 2000
        });
      } catch (_e) { /* ignore */ }
      return;
    }
    try {
      const imageData: ArrayBuffer = await this.fileService.packPixelMapToData(this.compressedPixelMap);
      LogUtils.info('压缩保存: 数据打包完成,大小: ' + imageData.byteLength + ' bytes');
      const saveUri: string = await this.fileService.saveToGallery(this.context, imageData);
      this.isSaved = true;
      LogUtils.info('压缩保存成功: ' + saveUri);
      this.getUIContext().getPromptAction().showToast({
        message: '已保存到图库', duration: 2000
      });
    } catch (e) {
      const err: Error = e instanceof Error ? e : new Error(String(e));
      LogUtils.error('压缩保存失败', err);
      LogUtils.error('压缩保存失败详情: ' + JSON.stringify(e));
      try {
        this.getUIContext().getPromptAction().showToast({
          message: '保存失败: ' + err.message, duration: 5000
        });
      } catch (_e) { /* ignore */ }
    }
  }

  private releaseResources(): void {
    if (this.originalPixelMap) {
      try {
        this.originalPixelMap.release();
      } catch (e) {
        // ignore
      }
    }
    if (this.compressedPixelMap && this.compressedPixelMap !== this.originalPixelMap) {
      try {
        this.compressedPixelMap.release();
      } catch (e) {
        // ignore
      }
    }
  }

  aboutToDisappear(): void {
    this.releaseResources();
  }

  build() {
    Column({ space: 0 }) {
      // 顶部标题
      Row() {
        Text('图片压缩')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16, top: 4 })
      .alignItems(VerticalAlign.Center)

      if (!this.hasImage) {
        // 空态: 选择图片
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.checkered_magnifyingglass'))
            .fontSize(56)
            .fontColor([AppTheme.TEXT_TERTIARY])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)

          Text('选择图片开始压缩')
            .fontSize(16)
            .fontColor(AppTheme.TEXT_SECONDARY)

          Button('选择图片')
            .width(200)
            .height(AppTheme.BUTTON_HEIGHT)
            .fontSize(15)
            .fontColor(AppTheme.TEXT_PRIMARY)
            .backgroundColor(AppTheme.ACCENT_SURFACE)
            .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
            .borderRadius(AppTheme.RADIUS_BUTTON)
            .onClick(() => this.handleSelectImage())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // 压缩主内容区 — Scroll 使用 layoutWeight(1) 填满剩余空间
        Scroll() {
          Column({ space: 16 }) {
            // 原图预览
            Column({ space: 8 }) {
              Text('原图')
                .fontSize(14)
                .fontColor(AppTheme.TEXT_SECONDARY)
                .width('100%')
              Image(this.originalPixelMap)
                .width('100%')
                .aspectRatio(1)
                .objectFit(ImageFit.Contain)
                .borderRadius(AppTheme.RADIUS_THUMB)
                .backgroundColor('#000000')
              Text(this.originalSize)
                .fontSize(13)
                .fontColor(AppTheme.TEXT_TERTIARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 目标大小输入
            Row({ space: 12 }) {
              Text('目标大小')
                .fontSize(14)
                .fontColor(AppTheme.TEXT_PRIMARY)
              TextInput({ text: this.inputText })
                .type(InputType.Number)
                .width(120)
                .height(40)
                .fontSize(14)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .backgroundColor(AppTheme.SURFACE_GLASS)
                .borderRadius(AppTheme.RADIUS_SMALL)
                .onChange((value: string) => {
                  this.inputText = value;
                  this.maxTargetKB = Number(value);
                })
              Text('KB')
                .fontSize(14)
                .fontColor(AppTheme.TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 压缩按钮
            Button(this.isCompressing ? '压缩中...' : '开始压缩')
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .fontSize(15)
              .fontColor(this.isCompressing ? AppTheme.TEXT_TERTIARY : AppTheme.TEXT_PRIMARY)
              .backgroundColor(this.isCompressing ? AppTheme.SURFACE_GLASS : AppTheme.ACCENT_SURFACE)
              .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
              .borderRadius(AppTheme.RADIUS_BUTTON)
              .enabled(!this.isCompressing)
              .onClick(() => this.compressImage())

            // 压缩结果
            if (this.compressedPixelMap) {
              Divider().color(AppTheme.BORDER_GLASS)

              Column({ space: 8 }) {
                Text('压缩后')
                  .fontSize(14)
                  .fontColor(AppTheme.TEXT_SECONDARY)
                  .width('100%')
                Image(this.compressedPixelMap)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Contain)
                  .borderRadius(AppTheme.RADIUS_THUMB)
                  .backgroundColor('#000000')

                Row() {
                  Text(this.compressedSize)
                    .fontSize(13)
                    .fontColor(AppTheme.ACCENT_SUCCESS)
                  if (this.originalBytes > 0 && this.compressedBytes > 0) {
                    Text('  (减少 ' + ((1 - this.compressedBytes / this.originalBytes) * 100).toFixed(1) + '%)')
                      .fontSize(12)
                      .fontColor(AppTheme.TEXT_TERTIARY)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            // 重新选择按钮
            Button('重新选择图片')
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT_SMALL)
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .backgroundColor(AppTheme.SURFACE_GLASS)
              .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
              .borderRadius(AppTheme.BUTTON_HEIGHT_SMALL / 2)
              .onClick(() => this.handleSelectImage())

            // 底部留白(与 Index.ets 一致,确保按钮上方有间隙)
            Column().height(8)
          }
          .padding({ left: 16, right: 16, top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      // 底部固定保存按钮 (与 Index.ets 超分页面的 Column 流布局一致)
      // layoutWeight(1) 的 Scroll 占满剩余空间,此 Column 固定在底部
      // padding bottom: 80 确保按钮在 barOverlap(true) 的 Tab 栏上方
      if (this.hasImage) {
        Column({ space: 8 }) {
          if (this.compressedPixelMap && !this.isSaved) {
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
                LogUtils.info('压缩保存 SaveButton 点击: result=' + JSON.stringify(result));
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  LogUtils.info('压缩保存: 授权成功,开始保存');
                  this.handleSave();
                } else {
                  const errMsg: string = error?.message ?? String(result);
                  LogUtils.error('压缩保存授权失败: ' + errMsg,
                    error instanceof Error ? error : new Error(errMsg));
                  try {
                    this.getUIContext().getPromptAction().showToast({
                      message: '保存授权失败: ' + errMsg, duration: 5000
                    });
                  } catch (_e) { /* ignore */ }
                }
              })
          } else if (this.isSaved) {
            Button('已保存到图库')
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .fontSize(15)
              .fontColor(AppTheme.ACCENT_SUCCESS)
              .backgroundColor(AppTheme.SURFACE_GLASS)
              .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
              .borderRadius(AppTheme.RADIUS_BUTTON)
              .enabled(false)
          } else if (this.isCompressing) {
            Button('压缩中...')
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .fontSize(15)
              .fontColor(AppTheme.TEXT_TERTIARY)
              .backgroundColor(AppTheme.SURFACE_GLASS)
              .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
              .borderRadius(AppTheme.RADIUS_BUTTON)
              .enabled(false)
          } else {
            Button('保存至图库')
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .fontSize(15)
              .fontColor(AppTheme.TEXT_TERTIARY)
              .backgroundColor(AppTheme.SURFACE_GLASS)
              .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
              .borderRadius(AppTheme.RADIUS_BUTTON)
              .enabled(false)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 80 })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient(AppTheme.getBackgroundGradient(180))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
