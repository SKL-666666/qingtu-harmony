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

/**
 * 图像增强质量级别枚举
 */
export enum QualityLevel {
  NONE = 0,
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3
}

/**
 * 图像处理状态枚举
 */
export enum ProcessState {
  IDLE = 'idle',
  PROCESSING = 'processing',
  SUCCESS = 'success',
  ERROR = 'error'
}

/**
 * 图片来源类型枚举
 */
export enum ImageSourceType {
  GALLERY = 'gallery',
  CAMERA = 'camera'
}

/**
 * 图像信息接口
 */
export interface ImageInfo {
  width: number;
  height: number;
  uri: string;
  pixelMap?: image.PixelMap;
  sourceType?: ImageSourceType;
}

/**
 * 处理结果接口
 */
export interface ProcessResult {
  success: boolean;
  pixelMap?: image.PixelMap;
  width?: number;
  height?: number;
  error?: AppError;
  duration?: number;
}

/**
 * 应用错误接口
 */
export interface AppError {
  code: number;
  message: string;
  details?: string;
  timestamp: number;
}

/**
 * 进度信息接口
 */
export interface ProgressInfo {
  progress: number;  // 0-100
  stage: string;     // 处理阶段描述
  isCancellable: boolean;
}