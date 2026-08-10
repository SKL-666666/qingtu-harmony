/**
 * Universal Camera Preview Grid Component.
 */
@Component
export struct GridLine {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop cols: number = 3;
  @Prop rows: number = 3;
  @Prop strokeStyle: string | number | CanvasGradient | CanvasPattern = Color.White;
  @Prop lineWidth: number = 1;

  draw(): void {
    const ctx = this.context;
    ctx.strokeStyle = this.strokeStyle;
    ctx.lineWidth = this.lineWidth;
    const height = this.context.height;
    const width = this.context.width;
    for (let i = 1; i < this.cols; i++) {
      const x = (width / this.cols) * i;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }
    for (let i = 1; i < this.rows; i++) {
      const y = (height / this.rows) * i;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .onReady(() => this.draw())
  }
}
