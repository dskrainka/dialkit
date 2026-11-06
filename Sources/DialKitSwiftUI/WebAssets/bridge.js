/* Native adapter for the upstream, unmodified DialKit vanilla editor. */
(() => {
  const post = body => window.webkit.messageHandlers.dialkit.postMessage(body);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 1;
  const context = canvas.getContext('2d', { willReadFrequently: true });
  let kit, root, stop;

  function colors(config, values, prefix = '', result = {}) {
    for (const [key, control] of Object.entries(config)) {
      const path = prefix ? `${prefix}.${key}` : key;
      if (control?.type === 'color' && CSS.supports('color', values[key])) {
        context.clearRect(0, 0, 1, 1);
        context.fillStyle = values[key];
        context.fillRect(0, 0, 1, 1);
        result[path] = Array.from(context.getImageData(0, 0, 1, 1).data, n => n / 255);
      } else if (control && typeof control === 'object' && !Array.isArray(control) && !control.type) {
        colors(control, values[key] || {}, path, result);
      }
    }
    return result;
  }

  window.DialKitNative = {
    initialize(encoded) {
      stop?.(); kit?.destroy(); root?.destroy();
      const bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
      const payload = JSON.parse(new TextDecoder().decode(bytes));
      const order = [...payload.order, ...Object.keys(payload.config).filter(key => !payload.order.includes(key))];
      payload.config = Object.fromEntries(order.map(key => [key, payload.config[key]]));
      kit = DialKit.createDialKit(payload.name, payload.config, {
        id: payload.id,
        onAction: path => post({ type: 'action', path }),
      });
      kit.setValues(payload.values);
      root = DialKit.createDialRoot({ target: document.getElementById('editor'), mode: 'inline', versions: 'menu' });
      stop = kit.subscribe(values => post({ type: 'values', values, colors: colors(payload.config, values) }));
    },
    // Explicit bridge API also supports integration tests and custom hosts.
    setValue(path, value) { kit.setValue(path, value); },
    getValues() { return kit.getValues(); },
    reset() { kit.resetValues(); },
  };

  // The existing Copy button exports a SwiftUI-specific source handoff.
  Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
    writeText: async () => post({ type: 'copy' }),
  } });
  window.addEventListener('error', event => post({ type: 'error', message: event.message }));
  window.addEventListener('unhandledrejection', event => post({ type: 'error', message: String(event.reason) }));
  post({ type: 'ready' });
})();
