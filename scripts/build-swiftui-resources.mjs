import { copyFile, mkdir } from 'node:fs/promises';
const destination = new URL('../Sources/DialKitSwiftUI/WebAssets/', import.meta.url);
await mkdir(destination, { recursive: true });
await copyFile(new URL('../dist/vanilla/browser.global.js', import.meta.url), new URL('dialkit.js', destination));
await copyFile(new URL('../dist/vanilla/styles.css', import.meta.url), new URL('styles.css', destination));
console.log('Updated offline SwiftUI editor resources. Commit these with Swift package changes.');
