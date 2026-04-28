// Shared input validators for edge functions.
// Throws plain `Error` (not AuthError) so callers map them to HTTP 500.

export function assertString(val: unknown, name: string): string {
  if (typeof val !== "string" || val.trim().length === 0) {
    throw new Error(`"${name}" must be a non-empty string`);
  }
  return val.trim();
}

export function assertNumber(val: unknown, name: string): number {
  if (typeof val !== "number" || !Number.isFinite(val)) {
    throw new Error(`"${name}" must be a finite number`);
  }
  return val;
}

export function assertDate(val: unknown, name: string): string {
  const s = assertString(val, name);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    throw new Error(`"${name}" must be YYYY-MM-DD`);
  }
  return s;
}

export function assertStringArray(val: unknown, name: string): string[] {
  if (!Array.isArray(val)) throw new Error(`"${name}" must be an array`);
  return val.map((v: unknown) => {
    if (typeof v !== "string") throw new Error(`"${name}" items must be strings`);
    return v.trim();
  });
}
