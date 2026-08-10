/**
 * 深色玻璃拟态主题常量
 * 统一颜色/尺寸/模糊风格,避免在多个组件中重复定义
 * 支持深色/浅色模式切换
 */

export class AppTheme {
  // ==================== 主题状态 ====================
  static currentTheme: string = AppStorage.get<string>('themeMode') || 'dark';

  static init(): void {
    if (!AppStorage.has('themeMode')) {
      AppStorage.set('themeMode', 'light');
    }
  }

  static get isDark(): boolean {
    return AppStorage.get<string>('themeMode') !== 'light';
  }

  // ==================== 背景层 (深色) ====================
  static readonly DARK_BG_GRADIENT_TOP: string = '#000000';
  static readonly DARK_BG_GRADIENT_BOTTOM: string = '#000000';
  static readonly DARK_BG_OVERLAY: string = 'rgba(0,0,0,0.6)';

  // ==================== 背景层 (浅色) ====================
  static readonly LIGHT_BG_GRADIENT_TOP: string = '#FFFFFF';
  static readonly LIGHT_BG_GRADIENT_BOTTOM: string = '#FFFFFF';
  static readonly LIGHT_BG_OVERLAY: string = 'rgba(0,0,0,0.30)';

  // ==================== 玻璃表面 (深色) ====================
  static readonly DARK_SURFACE_GLASS: string = 'rgba(255,255,255,0.06)';
  static readonly DARK_SURFACE_GLASS_STRONG: string = 'rgba(255,255,255,0.10)';
  static readonly DARK_SURFACE_GLASS_WEAK: string = 'rgba(255,255,255,0.04)';
  static readonly DARK_BORDER_GLASS: string = 'rgba(255,255,255,0.12)';
  static readonly DARK_BORDER_GLASS_STRONG: string = 'rgba(255,255,255,0.20)';

  // ==================== 玻璃表面 (浅色) ====================
  static readonly LIGHT_SURFACE_GLASS: string = '#F5F5FA';
  static readonly LIGHT_SURFACE_GLASS_STRONG: string = '#EDEEF5';
  static readonly LIGHT_SURFACE_GLASS_WEAK: string = '#F9F9FC';
  static readonly LIGHT_BORDER_GLASS: string = 'rgba(0,0,0,0.08)';
  static readonly LIGHT_BORDER_GLASS_STRONG: string = 'rgba(0,0,0,0.12)';

  // ==================== 文字 (深色) ====================
  static readonly DARK_TEXT_PRIMARY: string = '#F5F5FA';
  static readonly DARK_TEXT_SECONDARY: string = '#9A9AB0';
  static readonly DARK_TEXT_TERTIARY: string = '#7A7A90';

  // ==================== 文字 (浅色) ====================
  static readonly LIGHT_TEXT_PRIMARY: string = '#1A1A2E';
  static readonly LIGHT_TEXT_SECONDARY: string = '#3C3C54';
  static readonly LIGHT_TEXT_TERTIARY: string = '#54546A';

  // ==================== 动态颜色 (根据 isDark 切换) ====================
  static get BG_GRADIENT_TOP(): string { return AppTheme.isDark ? AppTheme.DARK_BG_GRADIENT_TOP : AppTheme.LIGHT_BG_GRADIENT_TOP; }
  static get BG_GRADIENT_BOTTOM(): string { return AppTheme.isDark ? AppTheme.DARK_BG_GRADIENT_BOTTOM : AppTheme.LIGHT_BG_GRADIENT_BOTTOM; }
  static get BG_OVERLAY(): string { return AppTheme.isDark ? AppTheme.DARK_BG_OVERLAY : AppTheme.LIGHT_BG_OVERLAY; }
  static get SURFACE_GLASS(): string { return AppTheme.isDark ? AppTheme.DARK_SURFACE_GLASS : AppTheme.LIGHT_SURFACE_GLASS; }
  static get SURFACE_GLASS_STRONG(): string { return AppTheme.isDark ? AppTheme.DARK_SURFACE_GLASS_STRONG : AppTheme.LIGHT_SURFACE_GLASS_STRONG; }
  static get SURFACE_GLASS_WEAK(): string { return AppTheme.isDark ? AppTheme.DARK_SURFACE_GLASS_WEAK : AppTheme.LIGHT_SURFACE_GLASS_WEAK; }
  static get BORDER_GLASS(): string { return AppTheme.isDark ? AppTheme.DARK_BORDER_GLASS : AppTheme.LIGHT_BORDER_GLASS; }
  static get BORDER_GLASS_STRONG(): string { return AppTheme.isDark ? AppTheme.DARK_BORDER_GLASS_STRONG : AppTheme.LIGHT_BORDER_GLASS_STRONG; }
  static get TEXT_PRIMARY(): string { return AppTheme.isDark ? AppTheme.DARK_TEXT_PRIMARY : AppTheme.LIGHT_TEXT_PRIMARY; }
  static get TEXT_SECONDARY(): string { return AppTheme.isDark ? AppTheme.DARK_TEXT_SECONDARY : AppTheme.LIGHT_TEXT_SECONDARY; }
  static get TEXT_TERTIARY(): string { return AppTheme.isDark ? AppTheme.DARK_TEXT_TERTIARY : AppTheme.LIGHT_TEXT_TERTIARY; }

  // ==================== 强调色 (深浅共用) ====================
  static readonly ACCENT_GRADIENT_START: string = '#4A56D4';
  static readonly ACCENT_GRADIENT_END: string = '#5748DC';
  static readonly ACCENT_PRIMARY: string = '#4A56D4';
  static readonly ACCENT_SUCCESS: string = '#3DDC84';
  static readonly ACCENT_ERROR: string = '#CC4040';
  static readonly ACCENT_WARNING: string = '#FFB340';

  // ==================== 尺寸 ====================
  static readonly RADIUS_CARD: number = 20;
  static readonly RADIUS_BUTTON: number = 24;
  static readonly RADIUS_SMALL: number = 12;
  static readonly RADIUS_THUMB: number = 14;
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly BUTTON_HEIGHT_SMALL: number = 36;
  static readonly THUMBNAIL_SIZE: number = 120;
  static readonly THUMBNAIL_BADGE_SIZE: number = 14;
  static readonly PADDING_BASE: number = 16;
  static readonly PADDING_CARD: number = 20;
  static readonly PADDING_SMALL: number = 12;

  // ==================== 模糊风格 ====================
  static readonly BLUR_THICK: BlurStyle = BlurStyle.COMPONENT_THICK;
  static readonly BLUR_REGULAR: BlurStyle = BlurStyle.COMPONENT_REGULAR;

  // ==================== 相机专用 ====================
  static readonly DARK_CAMERA_BAR: string = 'rgba(0,0,0,0.55)';
  static readonly LIGHT_CAMERA_BAR: string = 'rgba(0,0,0,0.06)';
  static get CAMERA_BAR(): string { return AppTheme.isDark ? AppTheme.DARK_CAMERA_BAR : AppTheme.LIGHT_CAMERA_BAR; }

  // ==================== 强调表面 (浅色模式下浅紫,深色下暗透) ====================
  static readonly LIGHT_ACCENT_SURFACE: string = '#D6DAF7';
  static readonly DARK_ACCENT_SURFACE: string = 'rgba(74,86,212,0.12)';
  static get ACCENT_SURFACE(): string { return AppTheme.isDark ? AppTheme.DARK_ACCENT_SURFACE : AppTheme.LIGHT_ACCENT_SURFACE; }

  // ==================== 空态卡片表面 (比 SURFACE_GLASS 更明显的灰色) ====================
  static readonly LIGHT_SURFACE_CARD_EMPTY: string = '#D8D8E1';
  static readonly DARK_SURFACE_CARD_EMPTY: string = 'rgba(255,255,255,0.04)';
  static get SURFACE_CARD_EMPTY(): string { return AppTheme.isDark ? AppTheme.DARK_SURFACE_CARD_EMPTY : AppTheme.LIGHT_SURFACE_CARD_EMPTY; }

  // ==================== 阴影 ====================
  static readonly SHADOW_CARD: ShadowOptions = {
    radius: 16,
    color: 'rgba(0,0,0,0.30)',
    offsetX: 0,
    offsetY: 4
  };
  static readonly SHADOW_CARD_LIGHT: ShadowOptions = {
    radius: 12,
    color: 'rgba(0,0,0,0.06)',
    offsetX: 0,
    offsetY: 2
  };
  static readonly SHADOW_BUTTON: ShadowOptions = {
    radius: 12,
    color: 'rgba(74,86,212,0.30)',
    offsetX: 0,
    offsetY: 4
  };

  // ==================== 渐变工具 ====================
  /**
   * 主按钮渐变配置
   */
  public static getAccentGradient(angle: number = 135): LinearGradientOptions {
    const result: LinearGradientOptions = {
      angle: angle,
      colors: [
        [AppTheme.ACCENT_GRADIENT_START, 0.0],
        [AppTheme.ACCENT_GRADIENT_END, 1.0]
      ]
    };
    return result;
  }

  /**
   * 卡片阴影 (深浅色自动切换)
   */
  public static getCardShadow(): ShadowOptions {
    return AppTheme.isDark ? AppTheme.SHADOW_CARD : AppTheme.SHADOW_CARD_LIGHT;
  }

  /**
   * 背景渐变配置 (动态深浅色)
   */
  public static getBackgroundGradient(angle: number = 180): LinearGradientOptions {
    const result: LinearGradientOptions = {
      angle: angle,
      colors: [
        [AppTheme.BG_GRADIENT_TOP, 0.0],
        [AppTheme.BG_GRADIENT_BOTTOM, 1.0]
      ]
    };
    return result;
  }

  /**
   * 禁用态渐变 - 单色玻璃
   */
  public static getDisabledGradient(): LinearGradientOptions {
    const result: LinearGradientOptions = {
      angle: 0,
      colors: [
        [AppTheme.SURFACE_GLASS, 0.0],
        [AppTheme.SURFACE_GLASS, 1.0]
      ]
    };
    return result;
  }

  /**
   * 无阴影配置 - 用于禁用态
   */
  public static getNoShadow(): ShadowOptions {
    const result: ShadowOptions = {
      radius: 0,
      color: Color.Transparent,
      offsetX: 0,
      offsetY: 0
    };
    return result;
  }
}

/**
 * 缩略图状态徽标颜色
 */
export enum ThumbnailStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  DONE = 'done',
  ERROR = 'error'
}
