import { bundleManager } from '@kit.AbilityKit';
import { AppTheme } from '../common/constants/Theme';

/**
 * 关于页面 Tab 组件
 * 介绍应用信息 + 设置入口
 * 深色玻璃拟态风格,沉浸式适配状态栏与底部导航
 */
@Component
export struct AboutTab {
  @State private versionName: string = '1.0.2';
  @State private appName: string = '清图';

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.versionName = info.versionName;
    } catch (e) {
      // 读取失败保留默认值
    }
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('关于')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16, top: 4 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 24 }) {
          // ===== 应用信息卡片 =====
          Column({ space: 12 }) {
            // 应用图标
            Stack() {
              SymbolGlyph($r('sys.symbol.wand_and_stars'))
                .fontSize(56)
                .fontColor([AppTheme.ACCENT_PRIMARY])
                .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            }
            .width(96)
            .height(96)
            .borderRadius(24)
            .backgroundColor(AppTheme.SURFACE_GLASS)
            .border({ width: 0.5, color: AppTheme.BORDER_GLASS })

            Text(this.appName)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT_PRIMARY)

            Text('v' + this.versionName)
              .fontSize(13)
              .fontColor(AppTheme.TEXT_TERTIARY)

            Text('基于 HarmonyOS 图像处理引擎\n超分增强 / 智能压缩 / 原生相机 / 图库保存')
              .fontSize(13)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
              .lineHeight(20)
          }
          .width('100%')
          .padding({ top: 24, bottom: 24, left: 16, right: 16 })
          .alignItems(HorizontalAlign.Center)
          .borderRadius(AppTheme.RADIUS_CARD)
          .backgroundColor(AppTheme.SURFACE_GLASS)
          .border({ width: 0.5, color: AppTheme.BORDER_GLASS })

          // ===== 功能介绍 =====
          Column({ space: 0 }) {
            Text('功能特性')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT_SECONDARY)
              .margin({ bottom: 12 })

            this.buildFeatureItem('超分增强', 'HIGH 档位 2x 放大,输出上限 2000px')
            this.buildFeatureItem('智能压缩', '二分法质量压缩 + 缩放逼近目标大小')
            this.buildFeatureItem('原生相机', '无AI介入，真实自然 · 系统平滑变焦')
            this.buildFeatureItem('对比预览', '滑动分割线查看超分前后效果')
            this.buildFeatureItem('图库保存', '安全组件授权,批量保存到系统相册')
          }
          .width('100%')
          .padding(16)
          .borderRadius(AppTheme.RADIUS_CARD)
          .backgroundColor(AppTheme.SURFACE_GLASS)
          .border({ width: 0.5, color: AppTheme.BORDER_GLASS })

          // ===== 底部留白 (避开悬浮导航栏) =====
          Column().height(80)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .linearGradient(AppTheme.getBackgroundGradient(180))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildFeatureItem(title: string, desc: string) {
    Row({ space: 8 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(AppTheme.ACCENT_PRIMARY)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(14)
          .fontColor(AppTheme.TEXT_PRIMARY)
        Text(desc)
          .fontSize(12)
          .fontColor(AppTheme.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }
}
