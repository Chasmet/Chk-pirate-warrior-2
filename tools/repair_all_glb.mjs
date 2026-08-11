import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize } from '@gltf-transform/functions';
import draco3d from 'draco3dgltf';
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2];
const reportPath = process.argv[3];
if (!root || !reportPath) {
  throw new Error('Usage: node repair_all_glb.mjs <racine> <rapport>');
}

const decoder = await draco3d.createDecoderModule();
const encoder = await draco3d.createEncoderModule();
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'draco3d.decoder': decoder,
  'draco3d.encoder': encoder,
});

const files = [];
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(entryPath);
    else if (entry.name.toLowerCase().endsWith('.glb')) files.push(entryPath);
  }
}
walk(root);
files.sort();

let normalized = 0;
let dracoDecoded = 0;
let dequantized = 0;
let quarantined = 0;
const broken = [];

for (const file of files) {
  const temporaryPath = `${file}.normalized.glb`;
  try {
    const document = await io.read(file);
    const extensions = document.getRoot().listExtensionsUsed();
    const dracoExtension = extensions.find((extension) => extension.extensionName === 'KHR_draco_mesh_compression');
    const quantizationExtension = extensions.find((extension) => extension.extensionName === 'KHR_mesh_quantization');

    if (quantizationExtension) {
      await document.transform(dequantize());
      dequantized += 1;
    }
    if (dracoExtension) {
      dracoExtension.dispose();
      dracoDecoded += 1;
    }

    // Réécrire aussi les GLB non compressés normalise les bufferViews, offsets,
    // images et animations qui provoquent sinon des erreurs silencieuses Godot.
    await io.write(temporaryPath, document);
    if (!fs.existsSync(temporaryPath) || fs.statSync(temporaryPath).size < 20) {
      throw new Error('sortie normalisée vide');
    }
    fs.renameSync(temporaryPath, file);
    normalized += 1;
  } catch (error) {
    if (fs.existsSync(temporaryPath)) fs.unlinkSync(temporaryPath);
    quarantined += 1;
    const relative = path.relative(root, file);
    broken.push(`${relative} | ${String(error)}`);
    if (fs.existsSync(file)) fs.renameSync(file, `${file}.invalid`);
  }
}

const report = [
  `GLB analysés=${files.length}`,
  `Normalisés=${normalized}`,
  `Draco décodés=${dracoDecoded}`,
  `Déquantifiés=${dequantized}`,
  `Isolés=${quarantined}`,
  '',
  ...broken,
  '',
].join('\n');
fs.writeFileSync(reportPath, report);
process.stdout.write(report);
