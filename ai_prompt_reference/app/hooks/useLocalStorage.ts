import { useCallback, useSyncExternalStore } from 'react';

/**
 * Per-key subscribers, so a write in one hook instance reaches every other
 * instance reading the same key.
 */
const listeners = new Map<string, Set<() => void>>();

/**
 * Snapshot cache. `useSyncExternalStore` compares snapshots by identity, so
 * parsing the JSON afresh on every read would hand back a new object each
 * time and spin forever. The cache holds the raw string it was parsed from
 * and only re-parses when that string actually changes.
 */
const snapshots = new Map<string, { raw: string | null; value: unknown }>();

function emit(key: string) {
  listeners.get(key)?.forEach((listener) => listener());
}

function subscribe(key: string, listener: () => void) {
  let set = listeners.get(key);
  if (!set) {
    set = new Set();
    listeners.set(key, set);
  }
  set.add(listener);

  // Another tab writing the same key counts as a change here too.
  const onStorage = (event: StorageEvent) => {
    if (event.key === key) {
      snapshots.delete(key);
      listener();
    }
  };
  window.addEventListener('storage', onStorage);

  return () => {
    set.delete(listener);
    window.removeEventListener('storage', onStorage);
  };
}

function readSnapshot<T>(key: string, initialValue: T): T {
  let raw: string | null = null;
  try {
    raw = window.localStorage.getItem(key);
  } catch (error) {
    console.warn(`Error reading localStorage key "${key}":`, error);
    return initialValue;
  }

  const cached = snapshots.get(key);
  if (cached && cached.raw === raw) return cached.value as T;

  let value: T = initialValue;
  if (raw !== null) {
    try {
      value = JSON.parse(raw) as T;
    } catch (error) {
      console.warn(`Error parsing localStorage key "${key}":`, error);
    }
  }

  snapshots.set(key, { raw, value });
  return value;
}

/**
 * `useState`, but persisted to localStorage.
 *
 * Built on `useSyncExternalStore` rather than an effect that calls setState:
 * the effect version rendered once with the default, then immediately again
 * with the stored value, so every mount paid for a second full render of the
 * tree — and on the server it had no value to give at all.
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((val: T) => T)) => void] {
  const storedValue = useSyncExternalStore(
    useCallback((listener: () => void) => subscribe(key, listener), [key]),
    () => readSnapshot(key, initialValue),
    // The server has no localStorage; render the default and let the client
    // reconcile on hydration.
    () => initialValue
  );

  const setValue = useCallback(
    (value: T | ((val: T) => T)) => {
      try {
        const current = readSnapshot(key, initialValue);
        const valueToStore = value instanceof Function ? value(current) : value;
        const raw = JSON.stringify(valueToStore);
        window.localStorage.setItem(key, raw);
        snapshots.set(key, { raw, value: valueToStore });
        emit(key);
      } catch (error) {
        console.warn(`Error setting localStorage key "${key}":`, error);
      }
    },
    [key, initialValue]
  );

  return [storedValue, setValue];
}
