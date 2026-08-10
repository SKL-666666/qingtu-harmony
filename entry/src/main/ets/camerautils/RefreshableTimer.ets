/*
 * Refreshable timer utility.
 */

class RefreshableTimer {
  private timerId?: number;
  private readonly timeout: number;
  private callback: () => void;
  private isActive: boolean = false;

  constructor(callback: () => void, timeout: number) {
    this.callback = callback;
    this.timeout = timeout;
  }

  start(): void {
    clearTimeout(this.timerId);
    this.timerId = setTimeout(() => {
      this.callback();
      this.isActive = false;
    }, this.timeout);
    this.isActive = true;
  }

  clear(): void {
    clearTimeout(this.timerId);
    this.timerId = undefined;
    this.isActive = false;
  }

  refresh(): void {
    this.clear();
    this.start();
  }

  isRunning(): boolean {
    return this.isActive;
  }
}

export default RefreshableTimer;
