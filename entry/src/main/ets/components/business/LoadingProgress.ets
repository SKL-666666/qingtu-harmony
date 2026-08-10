import { ProgressInfo } from '../../common/types/ImageTypes';
import { AppTheme } from '../../common/constants/Theme';

const PROGRESS_SIZE: number = 100;

const INITIAL_PROGRESS: ProgressInfo = {
  progress: 0,
  stage: '准备中',
  isCancellable: true
};

/**
 * 进度覆盖层 - 玻璃拟态深色风格
 */
@Component
export struct ProgressOverlay {
  @Prop progressInfo: ProgressInfo = INITIAL_PROGRESS;
  onCancel?: () => void;

  build() {
    Stack() {
      // 全屏背景遮罩 + 毛玻璃
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.BG_OVERLAY)
        .backgroundBlurStyle(AppTheme.BLUR_THICK)

      // 玻璃卡片
      Column({ space: 16 }) {
        // 进度环 - 单环,带轨道色
        Progress({
          value: this.progressInfo.progress,
          total: 100,
          type: ProgressType.Ring
        })
          .width(PROGRESS_SIZE)
          .height(PROGRESS_SIZE)
          .color(AppTheme.ACCENT_PRIMARY)
          .backgroundColor(AppTheme.SURFACE_GLASS_STRONG)
          .margin({ bottom: 8 })

        // 百分比
        Text(this.progressInfo.progress + '%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)

        // 当前阶段
        Text(this.progressInfo.stage)
          .fontSize(14)
          .fontColor(AppTheme.TEXT_SECONDARY)

        // 线性进度条
        Progress({
          value: this.progressInfo.progress,
          total: 100,
          type: ProgressType.Linear
        })
          .width('70%')
          .height(3)
          .color(AppTheme.ACCENT_PRIMARY)
          .backgroundColor(AppTheme.SURFACE_GLASS_STRONG)
          .borderRadius(2)
          .margin({ top: 4 })

        // 取消按钮
        if (this.progressInfo.isCancellable && this.onCancel) {
          Button('取消处理')
            .width('60%')
            .height(AppTheme.BUTTON_HEIGHT_SMALL)
            .fontSize(14)
            .fontColor(AppTheme.TEXT_SECONDARY)
            .backgroundColor(AppTheme.SURFACE_GLASS)
            .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
            .borderRadius(AppTheme.BUTTON_HEIGHT_SMALL / 2)
            .margin({ top: 12 })
            .onClick(() => {
              if (this.onCancel) {
                this.onCancel();
              }
            })
        }
      }
      .padding(AppTheme.PADDING_CARD)
      .width('70%')
      .borderRadius(AppTheme.RADIUS_CARD)
      .backgroundColor(AppTheme.SURFACE_GLASS)
      .backgroundBlurStyle(AppTheme.BLUR_THICK)
      .border({ width: 0.5, color: AppTheme.BORDER_GLASS })
      .shadow(AppTheme.getCardShadow())
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}
