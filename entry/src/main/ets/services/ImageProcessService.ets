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

import { image } from '@kit.ImageKit';
import { imageSuperResolution, visionBase } from '@kit.CoreVisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ProcessResult, ProgressInfo } from '../common/types/ImageTypes';
import { ErrorCode, ImageConstants } from '../common/constants/ImageConstants';
import { ErrorUtils } from '../common/utils/ErrorUtils';
import { LogUtils, PerformanceMonitor } from '../common/utils/LogUtils';

/**
 * 可处理检查结果
 */
interface CanProcessResult {
  canProcess: boolean;
  reason: string;
}

/**
 * 图像处理服务 - 基于 Core Vision Kit 图像超分能力
 * 参考: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-vision-image-super-resolution
 *
 * 关键事实(基于官方文档):
 * 1. imageSuperResolution 从 API 26 (HarmonyOS 26.0.0) 起支持,属 @kit.CoreVisionKit
 * 2. 调用链路: ImageSRAnalyzer.create() -> process() -> destroy()
 * 3. 固定放大 4 倍(输出宽高均为输入的 4 倍),无质量档位/倍率参数
 * 4. 无 [512,2000] 分辨率约束,也无需 DMA 内存类型(普通 PixelMap 即可)
 * 5. process 仅支持单张图片,批量需自行循环调用
 * 6. 失败抛异常,错误码统一为 1018700001 (Service exception)
 */
export class ImageProcessService {
  private static instance: ImageProcessService;
  private analyzer: imageSuperResolution.ImageSRAnalyzer | null = null;
  private initPromise: Promise<void> | null = null;
  private cancelFlag: boolean = false;

  private constructor() {}

  public static getInstance(): ImageProcessService {
    if (!ImageProcessService.instance) {
      ImageProcessService.instance = new ImageProcessService();
    }
    return ImageProcessService.instance;
  }

  /**
   * 初始化超分分析器 - 必须在使用前调用
   * 幂等且并发安全: 重复调用不会重复创建实例
   */
  public async initializeEnvironment(): Promise<void> {
    if (this.analyzer !== null) {
      return;
    }
    if (this.initPromise !== null) {
      await this.initPromise;
      return;
    }
    this.initPromise = this.doInitialize();
    try {
      await this.initPromise;
    } finally {
      this.initPromise = null;
    }
  }

  private async doInitialize(): Promise<void> {
    try {
      LogUtils.info('开始创建 ImageSRAnalyzer...');
      const analyzer: imageSuperResolution.ImageSRAnalyzer =
        await imageSuperResolution.ImageSRAnalyzer.create();
      if (analyzer === null || analyzer === undefined) {
        throw new Error('ImageSRAnalyzer.create() 返回空');
      }
      this.analyzer = analyzer;
      LogUtils.info('ImageSRAnalyzer 创建成功');
    } catch (e) {
      const code: number = (e as BusinessError)?.code ?? -1;
      const err: Error = e instanceof Error ? e : new Error(String(e));
      LogUtils.error('超分服务初始化失败 [code=' + code + ']: ' + err.message);
      if (code === 1018700001) {
        throw new Error('超分服务异常,请确认设备支持图像超分能力(HarmonyOS 26.0.0+)');
      }
      throw err;
    }
  }

  /**
   * 释放超分分析器
   */
  public async deinitializeEnvironment(): Promise<void> {
    const analyzer: imageSuperResolution.ImageSRAnalyzer | null = this.analyzer;
    this.analyzer = null;
    if (analyzer === null) {
      return;
    }
    try {
      await analyzer.destroy();
      LogUtils.info('ImageSRAnalyzer 已释放');
    } catch (e) {
      LogUtils.warn('释放 ImageSRAnalyzer 失败: ' + String(e));
    }
  }

  /**
   * 服务是否已就绪
   */
  public isReady(): boolean {
    return this.analyzer !== null;
  }

  /**
   * 检查图片是否可处理
   * 新 API 无分辨率约束,仅校验 PixelMap 有效性与尺寸合理性
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
      if (width < ImageConstants.MIN_INPUT_DIM || height < ImageConstants.MIN_INPUT_DIM) {
        const fail: CanProcessResult = {
          canProcess: false,
          reason: '图片尺寸 ' + width + 'x' + height + ' 过小'
        };
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
   * 异步图像超分处理 - 固定 4 倍放大
   *
   * 流程:
   * 1. 确保 ImageSRAnalyzer 已创建
   * 2. 构造 visionBase.Request(单张 PixelMap)
   * 3. 调用 analyzer.process() 获取 4 倍放大结果
   * 4. 校验返回 PixelMap 有效性
   *
   * 注意: process 不可中断,取消操作只能等其返回后丢弃结果
   */
  public async enhanceDetailAsync(
    sourcePixelMap: image.PixelMap,
    progressCallback?: (progress: ProgressInfo) => void
  ): Promise<ProcessResult> {
    PerformanceMonitor.startTimer('enhanceDetail');
    this.cancelFlag = false;

    try {
      // 步骤1: 确保分析器已就绪
      if (this.analyzer === null) {
        this.updateProgress(progressCallback, 5, '初始化超分服务', true);
        await this.initializeEnvironment();
      }
      const analyzer: imageSuperResolution.ImageSRAnalyzer | null = this.analyzer;
      if (analyzer === null) {
        return {
          success: false,
          error: ErrorUtils.createError(ErrorCode.IMAGE_PROCESS_ERROR, '超分服务未初始化')
        };
      }

      if (this.cancelFlag) {
        return this.createCancelledResult();
      }

      // 步骤2: 记录输入尺寸(4 倍放大由 API 内部完成)
      const sourceInfo: image.ImageInfo = sourcePixelMap.getImageInfoSync();
      const sourceWidth: number = sourceInfo.size.width;
      const sourceHeight: number = sourceInfo.size.height;
      LogUtils.info('超分输入: ' + sourceWidth + 'x' + sourceHeight
        + ', 预期输出: ' + (sourceWidth * ImageConstants.SR_SCALE) + 'x'
        + (sourceHeight * ImageConstants.SR_SCALE));

      this.updateProgress(progressCallback, 15, '正在超分处理...', true);

      // 步骤3: 调用超分 (官方无真实进度回调,以下为 UX 假进度)
      let currentProgress: number = 15;
      const progressInterval = setInterval(() => {
        if (currentProgress < 85 && !this.cancelFlag) {
          currentProgress += 5;
          this.updateProgress(progressCallback, currentProgress, '正在超分处理...', true);
        }
      }, 300);

      try {
        const imageData: visionBase.ImageData = { pixelMap: sourcePixelMap };
        const request: visionBase.Request = { inputData: imageData };
        const response: imageSuperResolution.ISPResponse = await analyzer.process(request);
        clearInterval(progressInterval);

        if (this.cancelFlag) {
          if (response.pixelMap) {
            this.releasePixelMap(response.pixelMap);
          }
          return this.createCancelledResult();
        }

        if (response.pixelMap === null || response.pixelMap === undefined) {
          LogUtils.error('process() 返回空 PixelMap');
          return {
            success: false,
            error: ErrorUtils.createError(ErrorCode.IMAGE_PROCESS_ERROR, '超分返回空图片')
          };
        }

        // 步骤4: 记录输出尺寸
        const resultInfo: image.ImageInfo = response.pixelMap.getImageInfoSync();
        const resultWidth: number = resultInfo.size.width;
        const resultHeight: number = resultInfo.size.height;
        const duration: number = PerformanceMonitor.endTimer('enhanceDetail');

        LogUtils.info('超分完成: ' + resultWidth + 'x' + resultHeight
          + ' (期望 ' + (sourceWidth * ImageConstants.SR_SCALE) + 'x'
          + (sourceHeight * ImageConstants.SR_SCALE) + '), 耗时: ' + duration + 'ms');
        this.updateProgress(progressCallback, 100, '处理完成', false);

        const processResult: ProcessResult = {
          success: true,
          pixelMap: response.pixelMap,
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
        LogUtils.error('超分调用失败 [code=' + code + ']: ' + msg);

        let userMsg: string;
        if (code === 1018700001) {
          userMsg = '超分服务异常,请确认设备支持该能力(HarmonyOS 26.0.0+)';
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
   * 单图处理 - 与 enhanceDetailAsync 等价(保持调用方兼容)
   */
  public async enhanceDetailSingle(
    sourcePixelMap: image.PixelMap
  ): Promise<ProcessResult> {
    return this.enhanceDetailAsync(sourcePixelMap);
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
   * 取消处理
   * 注意: analyzer.process 不可中断,此标志仅用于返回后丢弃结果
   */
  public cancelProcess(): void {
    this.cancelFlag = true;
    LogUtils.info('用户取消超分处理');
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
