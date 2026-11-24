export function viewportMetrics(layoutHeight, viewport, focused) {
  const zoomed = (viewport?.scale || 1) > 1.05;
  const height = zoomed ? layoutHeight : Math.min(layoutHeight, viewport?.height || layoutHeight);
  const offset = zoomed ? 0 : Math.max(0, layoutHeight - height - (viewport?.offsetTop || 0));
  return {height, offset: focused && offset > 120 ? offset : 0};
}
export function trackViewport(win = window, doc = document) {
  const update = () => {
    const focused = !!doc.activeElement?.matches('input,textarea,[contenteditable=true]');
    const metrics = viewportMetrics(win.innerHeight, win.visualViewport, focused);
    doc.documentElement.style.setProperty('--visible-height', metrics.height + 'px');
    doc.documentElement.style.setProperty('--keyboard-offset', metrics.offset + 'px');
    doc.documentElement.classList.toggle('keyboard-open', metrics.offset > 0);
  };
  win.visualViewport?.addEventListener('resize', update);
  win.visualViewport?.addEventListener('scroll', update);
  win.addEventListener('resize', update);
  doc.addEventListener('focusin', update);
  doc.addEventListener('focusout', () => win.requestAnimationFrame(update));
  update();
}
