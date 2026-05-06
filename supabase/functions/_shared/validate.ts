// Shared input validators for edge functions.

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export interface StringOptions {
  /// Maximum length after trim. Excess characters trigger a ValidationError.
  /// Use `clampString` if you want silent truncation instead.
  maxLength?: number;
}

export function assertString(
  val: unknown,
  name: string,
  options: StringOptions = {},
): string {
  if (typeof val !== "string" || val.trim().length === 0) {
    throw new ValidationError(`"${name}" must be a non-empty string`);
  }
  const trimmed = val.trim();
  if (options.maxLength != null && trimmed.length > options.maxLength) {
    throw new ValidationError(
      `"${name}" must be ${options.maxLength} characters or fewer`,
    );
  }
  return trimmed;
}

export function assertNumber(val: unknown, name: string): number {
  if (typeof val !== "number" || !Number.isFinite(val)) {
    throw new ValidationError(`"${name}" must be a finite number`);
  }
  return val;
}

export function assertDate(val: unknown, name: string): string {
  const s = assertString(val, name);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    throw new ValidationError(`"${name}" must be YYYY-MM-DD`);
  }
  return s;
}

export interface StringArrayOptions {
  /// Maximum number of items. Excess items trigger a ValidationError.
  maxItems?: number;
  /// Maximum length per trimmed item. Excess characters trigger a ValidationError.
  maxItemLength?: number;
}

export function assertStringArray(
  val: unknown,
  name: string,
  options: StringArrayOptions = {},
): string[] {
  if (!Array.isArray(val)) throw new ValidationError(`"${name}" must be an array`);
  if (options.maxItems != null && val.length > options.maxItems) {
    throw new ValidationError(
      `"${name}" must contain ${options.maxItems} items or fewer`,
    );
  }
  return val.map((v: unknown, idx: number) => {
    if (typeof v !== "string") throw new ValidationError(`"${name}" items must be strings`);
    const trimmed = v.trim();
    if (options.maxItemLength != null && trimmed.length > options.maxItemLength) {
      throw new ValidationError(
        `"${name}[${idx}]" must be ${options.maxItemLength} characters or fewer`,
      );
    }
    return trimmed;
  });
}

/// Coerces an unknown value to a trimmed string clamped to `maxLength`.
/// Returns "" if the input is not a string. Use for optional free-text
/// fields embedded inside larger user-supplied objects (e.g. activity notes)
/// where silent truncation is preferable to a 400 response.
export function clampString(val: unknown, maxLength: number): string {
  if (typeof val !== "string") return "";
  const trimmed = val.trim();
  return trimmed.length > maxLength ? trimmed.slice(0, maxLength) : trimmed;
}
