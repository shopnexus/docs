import { existsSync } from "node:fs";
import { join } from "node:path";
import sharp from "sharp";

const sizes = new Map<string, { width: number; height: number }>();

/** Intrinsic size of a file under `public/`, read once per build. */
export async function publicImageSize(url: string): Promise<{ width: number; height: number }> {
  const cached = sizes.get(url);
  if (cached) return cached;
  const file = join(process.cwd(), "public", url);
  if (!existsSync(file)) {
    throw new Error(`Image ${url} is missing from public/.`);
  }
  const { width, height } = await sharp(file).metadata();
  if (!width || !height) throw new Error(`Could not read the size of ${url}.`);
  const size = { width, height };
  sizes.set(url, size);
  return size;
}
