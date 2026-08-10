import { image } from '@kit.ImageKit';
import { AppTheme } from '../../common/constants/Theme';

const SLIDER_MIN: number = 0.02;
const SLIDER_MAX: number = 0.98;
const SLIDER_DEFAULT: number = 0.5;
const DIVIDER_WIDTH: number = 2;
const DIVIDER_HANDLE_SIZE: number = 36;
const SCALE_MIN: number = 0.5;
const SCALE_MAX: number = 5.0;
const SCALE_DEFAULT: number = 1.0;
const DEFAULT_CONTAINER_WIDTH: number = 360;

/**
 * 增强信息 - 用于对比预览显示
 */
export interface ImageCompareInfo {
  originalWidth: number;
  originalHeight: number;
  enhancedWidth: number;
  enhancedHeight: number;
  durationMs: number;
}

/**
 * 前后对比预览组件 - 滑动分割式
 *
 * 方案: clipped container
 * - 底层: 增强后图 (全宽全高,始终完全显示)
 * - 上层: 原图放在一个 clip(true) 的容器中,容器宽度 = 分割线位置 × 容器宽度
 *   原图 Image 用固定像素宽度(=容器宽度),与底层增强图位置完全一致
 *   Stack 用 alignContent=TopStart,确保 clip 容器左对齐,内部 Image 也左对齐
 * - 分割线 + 手柄浮动在最上层
 *
 * 效果: 左侧显示原图,右侧显示增强图,拖动分割线改变原图可见区域
 */
@Component
export struct ImageCompareViewer {
  originalPixelMap: image.PixelMap | undefined = undefined;
  enhancedPixelMap: image.PixelMap | undefined = undefined;
  enhancedInfo: ImageCompareInfo | undefined = undefined;
  onClose: () => void = () => {};

  @State sliderPosition: number = SLIDER_DEFAULT;
  @State containerWidth: number = DEFAULT_CONTAINER_WIDTH;
  @State containerHeight: number = 640;
  @State imageScale: number = SCALE_DEFAULT;

  private startSliderPosition: number = SLIDER_DEFAULT;
  private startScale: number = SCALE_DEFAULT;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ===== 底层: 增强后图 (全宽全高,始终完全显示) =====
      Image(this.enhancedPixelMap)
        .objectFit(ImageFit.Contain)
        .width('100%')
        .height('100%')
        .scale({ x: this.imageScale, y: this.imageScale })

      // ===== 上层: 原图 clip 容器 =====
      // 宽度 = 分割线位置 × 容器宽度,clip 裁剪超出部分
      // 内部 Image 用固定像素宽度 = containerWidth,与底层增强图完全对齐
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.originalPixelMap)
          .objectFit(ImageFit.Contain)
          .width(this.containerWidth)
          .height(this.containerHeight)
          .scale({ x: this.imageScale, y: this.imageScale })
      }
      .width(this.containerWidth * this.sliderPosition)
      .height('100%')
      .clip(true)

      // ===== 分割线 (竖线) =====
      Column()
        .width(DIVIDER_WIDTH)
        .height('100%')
        .backgroundColor(AppTheme.TEXT_PRIMARY)
        .opacity(0.9)
        .position({
          x: this.containerWidth * this.sliderPosition - DIVIDER_WIDTH / 2,
          y: 0
        })

      // ===== 拖动手柄 (圆形,垂直居中) =====
      Stack() {
        Text('⟷')
          .fontSize(14)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Bold)
      }
      .width(DIVIDER_HANDLE_SIZE)
      .height(DIVIDER_HANDLE_SIZE)
      .borderRadius(DIVIDER_HANDLE_SIZE / 2)
      .backgroundColor(AppTheme.SURFACE_GLASS_STRONG)
      .border({ width: 1, color: AppTheme.BORDER_GLASS_STRONG })
      .position({
        x: this.containerWidth * this.sliderPosition - DIVIDER_HANDLE_SIZE / 2,
        y: this.containerHeight / 2 - DIVIDER_HANDLE_SIZE / 2
      })
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.startSliderPosition = this.sliderPosition;
          })
          .onActionUpdate((e: GestureEvent) => {
            if (this.containerWidth <= 0) {
              return;
            }
            let newPos: number = this.startSliderPosition + e.offsetX / this.containerWidth;
            if (newPos < SLIDER_MIN) {
              newPos = SLIDER_MIN;
            }
            if (newPos > SLIDER_MAX) {
              newPos = SLIDER_MAX;
            }
            this.sliderPosition = newPos;
          })
      )

      // ===== 顶部关闭按钮 (浮动) =====
      Row() {
        Button('关闭')
          .fontSize(14)
          .fontColor(AppTheme.TEXT_SECONDARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onClose())
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .justifyContent(FlexAlign.Start)

      // ===== 底部信息栏 (浮动) =====
      Column({ space: 8 }) {
        Row({ space: 16 }) {
          Column({ space: 2 }) {
            Text('原图')
              .fontSize(11)
              .fontColor(AppTheme.TEXT_TERTIARY)
            if (this.enhancedInfo) {
              Text(this.enhancedInfo.originalWidth + '×' + this.enhancedInfo.originalHeight)
                .fontSize(12)
                .fontColor(AppTheme.TEXT_SECONDARY)
            }
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text('增强后')
              .fontSize(11)
              .fontColor(AppTheme.ACCENT_PRIMARY)
            if (this.enhancedInfo) {
              Text(this.enhancedInfo.enhancedWidth + '×' + this.enhancedInfo.enhancedHeight)
                .fontSize(12)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
          }
          .alignItems(HorizontalAlign.Start)

          if (this.enhancedInfo && this.enhancedInfo.durationMs > 0) {
            Column({ space: 2 }) {
              Text('耗时')
                .fontSize(11)
                .fontColor(AppTheme.TEXT_TERTIARY)
              Text(this.enhancedInfo.durationMs + 'ms')
                .fontSize(12)
                .fontColor(AppTheme.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Start)
          }
        }
        .justifyContent(FlexAlign.Center)

        Text('拖动分割线对比 · 双指缩放 · 双击复位')
          .fontSize(11)
          .fontColor(AppTheme.TEXT_TERTIARY)
      }
      .width('100%')
      .padding({ top: 12, bottom: 24, left: 16, right: 16 })
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(AppTheme.SURFACE_GLASS_STRONG)
      .position({ x: 0, y: '100%' })
      .markAnchor({ x: 0, y: '100%' })
      .offset({ y: 3000 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BG_GRADIENT_TOP)
    .onAreaChange((_old: Area, newArea: Area) => {
      const w: number = Number(newArea.width);
      const h: number = Number(newArea.height);
      if (w > 0) {
        this.containerWidth = w;
      }
      if (h > 0) {
        this.containerHeight = h;
      }
    })
    .gesture(
      PinchGesture({ fingers: 2 })
        .onActionStart(() => {
          this.startScale = this.imageScale;
        })
        .onActionUpdate((e: GestureEvent) => {
          let newScale: number = this.startScale * e.scale;
          if (newScale < SCALE_MIN) {
            newScale = SCALE_MIN;
          }
          if (newScale > SCALE_MAX) {
            newScale = SCALE_MAX;
          }
          this.imageScale = newScale;
        })
    )
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          this.getUIContext().animateTo({ duration: 200 }, () => {
            this.sliderPosition = SLIDER_DEFAULT;
            this.imageScale = SCALE_DEFAULT;
          });
        })
    )
  }
}
