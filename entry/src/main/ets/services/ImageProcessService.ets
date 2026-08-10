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

import { image, videoProcessingEngine } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ProcessResult, ProgressInfo } from '../common/types/ImageTypes';
import { ErrorCode, ImageConstants } from '../common/constants/ImageConstants';
import { ErrorUtils } from '../common/utils/ErrorUtils';
import { LogUtils, PerformanceMonitor } from '../common/utils/LogUtils';

/**
 * 分辨率校验结果
 */
interface ValidationResult {
  valid: boolean;
  reason: string;
}

/**
 * 可处理检查结果
 */
interface CanProcessResult {
  canProcess: boolean;
  reason: string;
}

/**
 * 目标尺寸
 */
interface TargetSize {
  width: number;
  height: number;
}

/**
 * 图像处理服务 - 严格遵循官方规范
 * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/image-processing-arkts
 *
 * 关键事实(基于官方文档):
 * 1. videoProcessingEngine API 从 API 18 (HarmonyOS 5.1.0) 起支持
 * 2. HIGH 档位输入/输出宽高均须在 [512, 2000]
 * 3. 必须先调用 initializeEnvironment(),再 create(),再 enhanceDetail()
 * 4. create() 失败返回 null,必须判空
 * 5. enhanceDetail 有两个重载: (source, width, height, level) 和 (source, scale, level)
 * 6. 失败会抛异常(错误码 801/29200001-29200009),不会 silent 返回原图
 */
export class ImageProcessService {
  private static instance: ImageProcessService;
  private isInitialized: boolean = false;
  private cancelFlag: boolean = false;

  private constructor() {}

  public static getInstance(): ImageProcessService {
    if (!ImageProcessService.instance) {
      ImageProcessService.instance = new ImageProcessService();
    }
    return ImageProcessService.instance;
  }

  /**
   * 初始化环境 - 必须在使用前调用
   * 官方链路: initializeEnvironment() → create() → enhanceDetail()
   */
  public async initializeEnvironment(): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    try {
      LogUtils.info('开始初始化 videoProcessingEngine 环境...');
      await videoProcessingEngine.initializeEnvironment();
      this.isInitialized = true;
      LogUtils.info('VideoProcessingEngine 环境初始化成功');
    } catch (e) {
      const err: Error = e instanceof Error ? e : new Error(String(e));
      const code: number = (e as BusinessError)?.code ?? -1;
      LogUtils.error('环境初始化失败 [code=' + code + ']: ' + err.message);
      if (code === 801) {
        throw new Error('设备不支持超分能力(API 18+ / HarmonyOS 5.1.0+)');
      }
      throw err;
    }
  }

  /**
   * 反初始化环境 - 释放资源
   */
  public deinitializeEnvironment(): void {
    if (!this.isInitialized) {
      return;
    }
    try {
      videoProcessingEngine.deinitializeEnvironment();
      this.isInitialized = false;
      LogUtils.info('VideoProcessingEngine 环境已释放');
    } catch (_e) {
      LogUtils.warn('环境释放失败: ' + String(_e));
    }
  }

  /**
   * 检查分辨率是否满足 HIGH 档位约束 [512, 2000]
   * 官方约束: HIGH 档位清晰度增强场景,输入/输出宽高均须在 [512, 2000]
   */
  public validateHighResolution(width: number, height: number): ValidationResult {
    if (width < ImageConstants.MIN_DIM_HIGH) {
      const result: ValidationResult = { valid: false, reason: '宽度 ' + width + ' < ' + ImageConstants.MIN_DIM_HIGH + ',不满足 HIGH 档位下限' };
      return result;
    }
    if (height < ImageConstants.MIN_DIM_HIGH) {
      const result: ValidationResult = { valid: false, reason: '高度 ' + height + ' < ' + ImageConstants.MIN_DIM_HIGH + ',不满足 HIGH 档位下限' };
      return result;
    }
    if (width > ImageConstants.MAX_DIM_HIGH) {
      const result: ValidationResult = { valid: false, reason: '宽度 ' + width + ' > ' + ImageConstants.MAX_DIM_HIGH + ',不满足 HIGH 档位上限' };
      return result;
    }
    if (height > ImageConstants.MAX_DIM_HIGH) {
      const result: ValidationResult = { valid: false, reason: '高度 ' + height + ' > ' + ImageConstants.MAX_DIM_HIGH + ',不满足 HIGH 档位上限' };
      return result;
    }
    const ok: ValidationResult = { valid: true, reason: '' };
    return ok;
  }

  /**
   * 检查是否可处理 - 检查 HIGH 档位约束 [512, 2000]
   * 大图在加载时已通过 DecodingOptions.size 缩小到 2000 以内
   * 这里只检查最终解码后的尺寸是否满足约束
   */
  public canProcess(sourcePixelMap: image.PixelMap | undefined): CanProcessResult {
    if (!sourcePixelMap) {
      const fail: CanProcessResult = { canProcess: false, reason: 'PixelMap 为空' };
      return fail;
    }
    try {
      const imageInfo: image.ImageInfo = sourcePixelMap.getImageInfoSync();
      const width: number = imageInfo.size.width;
      const height: number = imageInfo.size.height;
      const check: ValidationResult = this.validateHighResolution(width, height);
      if (!check.valid) {
        const fail: CanProcessResult = { canProcess: false, reason: check.reason };
        return fail;
      }
      const ok: CanProcessResult = { canProcess: true, reason: '' };
      return ok;
    } catch (e) {
      const err: Error = e instanceof Error ? e : new Error(String(e));
      LogUtils.error('检查图片信息失败', err);
      const fail: CanProcessResult = { canProcess: false, reason: '读取图片信息失败: ' + err.message };
      return fail;
    }
  }

  /**
   * 异步图像增强处理 - 单次 HIGH 超分
   *
   * 严格遵循官方规范:
   * 1. 校验输入分辨率必须在 [512, 2000] 范围内,不符合直接拒绝
   * 2. 调用 initializeEnvironment() 确保环境已初始化
   * 3. 调用 create() 并检查返回是否为 null
   * 4. 调用 enhanceDetail() 并捕获错误码
   * 5. 校验输出 PixelMap 尺寸是否等于目标尺寸
   *
   * 不做预处理缩小,不符合要求的图片直接拒绝
   */
  public async enhanceDetailAsync(
    sourcePixelMap: image.PixelMap,
    _qualityLevel: number,
    zoomRatio: number = 2.0,
    progressCallback?: (progress: ProgressInfo) => void
  ): Promise<ProcessResult> {
    PerformanceMonitor.startTimer('enhanceDetail');
    this.cancelFlag = false;

    try {
      // 步骤1: 读取原图尺寸
      const imageInfo: image.ImageInfo = sourcePixelMap.getImageInfoSync();
      const sourceWidth: number = imageInfo.size.width;
      const sourceHeight: number = imageInfo.size.height;

      LogUtils.info('超分输入: ' + sourceWidth + 'x' + sourceHeight + ', zoomRatio=' + zoomRatio);

      // 步骤2: 严格校验输入分辨率(不缩小,直接拒绝)
      const inputCheck: ValidationResult = this.validateHighResolution(sourceWidth, sourceHeight);
      if (!inputCheck.valid) {
        LogUtils.error('超分拒绝: 输入' + inputCheck.reason);
        return {
          success: false,
          error: ErrorUtils.createError(ErrorCode.INVALID_PARAMETER, '分辨率不符合 HIGH 档位要求: ' + inputCheck.reason)
        };
      }

      // 步骤3: 计算放大目标尺寸(2x,约束在 [512, 2000])
      const targetSize: TargetSize = this.calculateTargetSize(sourceWidth, sourceHeight, zoomRatio);
      const finalWidth: number = targetSize.width;
      const finalHeight: number = targetSize.height;

      // 校验输出分辨率也在 [512, 2000]
      const outputCheck: ValidationResult = this.validateHighResolution(finalWidth, finalHeight);
      if (!outputCheck.valid) {
        LogUtils.error('超分拒绝: 输出' + outputCheck.reason);
        return {
          success: false,
          error: ErrorUtils.createError(ErrorCode.INVALID_PARAMETER, '输出分辨率不符合 HIGH 档位要求: ' + outputCheck.reason)
        };
      }

      LogUtils.info('超分计划: ' + sourceWidth + 'x' + sourceHeight + ' -> ' + finalWidth + 'x' + finalHeight);

      // 步骤4: 确保环境已初始化
      if (!this.isInitialized) {
        LogUtils.info('环境未初始化,先初始化...');
        await this.initializeEnvironment();
      }

      // 进度阶段1: 准备 (0-10%)
      this.updateProgress(progressCallback, 5, '初始化处理器', true);
      await this.delay(50);

      if (this.cancelFlag) {
        return this.createCancelledResult();
      }

      // 步骤5: 创建处理器 (create() 失败返回 null,必须判空)
      this.updateProgress(progressCallback, 10, '创建处理器', true);
      LogUtils.info('调用 videoProcessingEngine.create()...');
      const imageProcessor: videoProcessingEngine.ImageProcessor | null = videoProcessingEngine.create();

      if (imageProcessor === null || imageProcessor === undefined) {
        LogUtils.error('create() 返回 null,实例数可能超上限(29200003)或环境未初始化(29200006)');
        return {
          success: false,
          error: ErrorUtils.createError(ErrorCode.IMAGE_PROCESS_ERROR, '创建处理器失败(create 返回 null)')
        };
      }

      LogUtils.info('create() 成功,开始调用 enhanceDetail(HIGH)...');

      // 步骤6: 调用 enhanceDetail (HIGH 档位)
      const highLevel: videoProcessingEngine.QualityLevel = videoProcessingEngine.QualityLevel.HIGH;

      // 单次 HIGH 超分 (10-90%)
      let currentProgress: number = 10;
      const progressInterval = setInterval(() => {
        if (currentProgress < 85 && !this.cancelFlag) {
          currentProgress += 5;
          this.updateProgress(progressCallback, currentProgress, '正在增强图像(HIGH)...', true);
        }
      }, 300);

      try {
        const result: image.PixelMap = await imageProcessor.enhanceDetail(
          sourcePixelMap, finalWidth, finalHeight, highLevel);
        clearInterval(progressInterval);

        if (this.cancelFlag) {
          if (result) {
            result.release();
          }
          return this.createCancelledResult();
        }

        // 步骤7: 校验输出 - 确认真的处理了
        const resultInfo: image.ImageInfo = result.getImageInfoSync();
        const resultWidth: number = resultInfo.size.width;
        const resultHeight: number = resultInfo.size.height;

        LogUtils.info('enhanceDetail 返回: ' + resultWidth + 'x' + resultHeight + ' (期望: ' + finalWidth + 'x' + finalHeight + ')');

        if (resultWidth !== finalWidth || resultHeight !== finalHeight) {
          LogUtils.warn('警告: 输出尺寸与期望不一致,但仍返回结果');
        }

        const duration: number = PerformanceMonitor.endTimer('enhanceDetail');
        LogUtils.info('超分完成, 耗时: ' + duration + 'ms');

        this.updateProgress(progressCallback, 100, '处理完成', false);

        const processResult: ProcessResult = {
          success: true,
          pixelMap: result,
          width: resultWidth,
          height: resultHeight,
          duration: duration
        };
        return processResult;
      } catch (e) {
        clearInterval(progressInterval);
        const businessError: BusinessError = e as BusinessError;
        const code: number = businessError?.code ?? -1;
        const msg: string = businessError?.message ?? String(e);
        LogUtils.error('enhanceDetail 调用失败 [code=' + code + ']: ' + msg);

        let userMsg: string;
        if (code === 801) {
          userMsg = '设备不支持超分能力(需 HarmonyOS 5.1.0+)';
        } else if (code === 29200009) {
          userMsg = '参数无效(分辨率越界或档位错误)';
        } else if (code === 29200006) {
          userMsg = '操作不被允许(未初始化)';
        } else if (code === 29200002) {
          userMsg = 'GPU 环境初始化失败';
        } else if (code === 29200007) {
          userMsg = '内存不足';
        } else {
          userMsg = '超分失败[' + code + ']: ' + msg;
        }

        return {
          success: false,
          error: ErrorUtils.createError(ErrorCode.IMAGE_PROCESS_ERROR, userMsg)
        };
      }

    } catch (error) {
      PerformanceMonitor.endTimer('enhanceDetail');
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('超分异常', err);

      return {
        success: false,
        error: ErrorUtils.createError(ErrorCode.IMAGE_PROCESS_ERROR, err.message)
      };
    }
  }

  /**
   * 计算 2x 放大目标尺寸,约束在 [512, 2000]
   * 如果 2x 放大后超过 2000,则输出 = 2000(不放大,只增强)
   */
  private calculateTargetSize(width: number, height: number, zoomRatio: number): TargetSize {
    const MAX_HIGH: number = ImageConstants.MAX_DIM_HIGH; // 2000
    const MIN_HIGH: number = ImageConstants.MIN_DIM_HIGH; // 512

    let targetW: number = Math.floor(width * zoomRatio);
    let targetH: number = Math.floor(height * zoomRatio);

    // 如果放大后超过 2000,缩到 2000
    const maxSide: number = Math.max(targetW, targetH);
    if (maxSide > MAX_HIGH) {
      const ratio: number = MAX_HIGH / maxSide;
      targetW = Math.floor(targetW * ratio);
      targetH = Math.floor(targetH * ratio);
    }

    // 硬约束
    if (targetW > MAX_HIGH) targetW = MAX_HIGH;
    if (targetH > MAX_HIGH) targetH = MAX_HIGH;
    if (targetW < MIN_HIGH) targetW = MIN_HIGH;
    if (targetH < MIN_HIGH) targetH = MIN_HIGH;

    LogUtils.info('目标尺寸: ' + width + 'x' + height + ' * ' + zoomRatio + ' -> ' + targetW + 'x' + targetH);
    const result: TargetSize = { width: targetW, height: targetH };
    return result;
  }

  /**
   * 更新进度回调
   */
  private updateProgress(
    callback: ((progress: ProgressInfo) => void) | undefined,
    progress: number,
    stage: string,
    cancellable: boolean
  ): void {
    if (callback) {
      const info: ProgressInfo = {
        progress: progress,
        stage: stage,
        isCancellable: cancellable
      };
      callback(info);
    }
  }

  /**
   * 创建取消结果
   */
  private createCancelledResult(): ProcessResult {
    return {
      success: false,
      error: ErrorUtils.createError(ErrorCode.UNKNOWN_ERROR, '用户取消操作')
    };
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  /**
   * 取消处理
   */
  public cancelProcess(): void {
    this.cancelFlag = true;
    LogUtils.info('用户取消超分处理');
  }

  /**
   * 单图重试处理 - 简化版,无进度模拟
   */
  public async enhanceDetailSingle(
    sourcePixelMap: image.PixelMap,
    qualityLevel: number,
    zoomRatio: number = ImageConstants.DEFAULT_ZOOM_RATIO
  ): Promise<ProcessResult> {
    return this.enhanceDetailAsync(sourcePixelMap, qualityLevel, zoomRatio);
  }

  /**
   * 释放 PixelMap 资源
   */
  public releasePixelMap(pixelMap: image.PixelMap | undefined): void {
    if (pixelMap) {
      try {
        pixelMap.release();
      } catch (e) {
        LogUtils.warn('释放 PixelMap 失败: ' + String(e));
      }
    }
  }
}
