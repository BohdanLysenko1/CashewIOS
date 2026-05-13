// Generic async helpers shared across edge functions.

/// Resolves with `promise`'s value if it settles within `ms` milliseconds;
/// otherwise resolves with `fallback`. Rejections are also swallowed into
/// `fallback` and logged with `[async]` prefix so they remain diagnosable
/// without bubbling and taking down the caller.
///
/// Use this to bound side-quests (enrichment lookups, optional logs) that
/// should never block or fail the primary response path.
export function withTimeout<T>(
  promise: Promise<T>,
  ms: number,
  fallback: T,
): Promise<T> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(fallback), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (err) => {
        clearTimeout(timer);
        console.error("[async] withTimeout caught:", err instanceof Error ? err.message : String(err));
        resolve(fallback);
      },
    );
  });
}
