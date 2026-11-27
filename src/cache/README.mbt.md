# connect0459/halcyon/cache

In-memory cache for processed images.

| Item | Purpose |
| :--- | :--- |
| `MemoryCache` | LRU cache bounded by total byte size, with an optional time to live measured from the moment of storing. |
| `Clock` | Abstraction over the current time in milliseconds, injected into the cache. |
| `ManualClock` | A `Clock` that only moves when `advance` is called. |

An image larger than the whole cost limit is never stored.
