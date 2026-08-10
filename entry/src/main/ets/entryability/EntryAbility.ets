/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, ConfigurationConstant, EnvironmentCallback, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../common/constants/Theme';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private envCallbackId: number = -1;

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    try {
      // 从系统获取初始颜色模式
      this.syncSystemColorMode();
      // 注册环境变化回调,监听系统深浅色切换
      this.registerColorModeListener();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'AppTheme.init error: %{public}s', JSON.stringify(e) ?? '');
    }
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    // 注销环境回调
    if (this.envCallbackId >= 0) {
      this.context.getApplicationContext().off('environment', this.envCallbackId);
    }
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  /**
   * 从系统配置读取初始颜色模式并同步到 AppStorage
   */
  private syncSystemColorMode(): void {
    const colorMode: ConfigurationConstant.ColorMode = this.context.config.colorMode ??
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    const themeValue: string = (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) ? 'dark' : 'light';
    AppStorage.setOrCreate('themeMode', themeValue);
    AppTheme.init();
    hilog.info(DOMAIN, TAG, 'System colorMode: %{public}d → themeMode: %{public}s', colorMode, themeValue);
  }

  /**
   * 注册系统环境变化监听,深浅色切换时实时更新 UI
   */
  private registerColorModeListener(): void {
    const envCallback: EnvironmentCallback = {
      onConfigurationUpdated: (config) => {
        const colorMode: ConfigurationConstant.ColorMode = config.colorMode ??
          ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
        const themeValue: string = (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) ? 'dark' : 'light';
        AppStorage.set('themeMode', themeValue);
        hilog.info(DOMAIN, TAG, 'ColorMode changed: %{public}d → %{public}s', colorMode, themeValue);
      },
      onMemoryLevel: (_level) => { }
    };
    this.envCallbackId = this.context.getApplicationContext().on('environment', envCallback);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
