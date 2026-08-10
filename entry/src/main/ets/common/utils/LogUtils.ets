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

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ImageConstants } from '../constants/ImageConstants';

/**
 * 日志参数类型
 */
export type LogArg = string | number | boolean | Object;

/**
 * 日志工具类
 */
export class LogUtils {
  /**
   * 调试日志
   */
  public static debug(message: string, ...args: LogArg[]): void {
    const formatted: string = LogUtils.formatMessage(message, args);
    hilog.debug(
      ImageConstants.LOG_DOMAIN,
      ImageConstants.LOG_TAG,
      '%{public}s',
      formatted
    );
  }

  /**
   * 信息日志
   */
  public static info(message: string, ...args: LogArg[]): void {
    const formatted: string = LogUtils.formatMessage(message, args);
    hilog.info(
      ImageConstants.LOG_DOMAIN,
      ImageConstants.LOG_TAG,
      '%{public}s',
      formatted
    );
  }

  /**
   * 警告日志
   */
  public static warn(message: string, ...args: LogArg[]): void {
    const formatted: string = LogUtils.formatMessage(message, args);
    hilog.warn(
      ImageConstants.LOG_DOMAIN,
      ImageConstants.LOG_TAG,
      '%{public}s',
      formatted
    );
  }

  /**
   * 错误日志 - 接受Error
   */
  public static error(message: string, error?: Error): void {
    let fullMessage: string = message;
    if (error !== undefined) {
      fullMessage = message + ' | ' + error.message;
    }
    hilog.error(
      ImageConstants.LOG_DOMAIN,
      ImageConstants.LOG_TAG,
      '%{public}s',
      fullMessage
    );
  }

  /**
   * 性能日志
   */
  public static performance(operation: string, duration: number): void {
    const msg: string = operation + ' 耗时: ' + duration + ' ms';
    hilog.info(
      ImageConstants.LOG_DOMAIN,
      ImageConstants.PERFORMANCE_TAG,
      '%{public}s',
      msg
    );
  }

  /**
   * 格式化消息 - 静态工具方法
   */
  private static formatMessage(message: string, args: LogArg[]): string {
    if (args.length === 0) {
      return message;
    }
    let result: string = message;
    for (let i = 0; i < args.length; i++) {
      const arg: LogArg = args[i];
      result = result + ' | arg' + i + ': ' + LogUtils.toString(arg);
    }
    return result;
  }

  /**
   * 将参数转为字符串 - 静态工具方法
   */
  private static toString(arg: LogArg): string {
    if (typeof arg === 'string') {
      return arg;
    }
    if (typeof arg === 'number' || typeof arg === 'boolean') {
      return String(arg);
    }
    try {
      return JSON.stringify(arg);
    } catch (e) {
      return '[Object]';
    }
  }
}

/**
 * 性能监控类
 */
export class PerformanceMonitor {
  private static timers: Map<string, number> = new Map();

  /**
   * 开始计时
   */
  public static startTimer(name: string): void {
    PerformanceMonitor.timers.set(name, Date.now());
    LogUtils.debug('开始: ' + name);
  }

  /**
   * 结束计时
   */
  public static endTimer(name: string): number {
    const startTime: number = PerformanceMonitor.timers.get(name) ?? 0;
    if (startTime > 0) {
      const duration: number = Date.now() - startTime;
      LogUtils.performance(name, duration);
      PerformanceMonitor.timers.delete(name);
      return duration;
    }
    return 0;
  }

  /**
   * 清除所有计时器
   */
  public static clearAll(): void {
    PerformanceMonitor.timers.clear();
  }
}