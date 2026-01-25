# Optimization Guidelines for Disk Inventory Y

This document outlines optimization principles and checks for keeping the app performant without over-engineering.

## Memory Optimization

### FileNode Model
The app scans millions of files. Each byte per node matters.

**Current optimizations:**
- Store `path` (String) instead of `URL` (~300 bytes saved per node)
- Derive `name` from path instead of storing separately (~50 bytes saved)
- Use `ObjectIdentifier(self)` instead of UUID for Identifiable (~16 bytes saved per node)
- Icons computed on-demand, not cached in model
- `kindName` and `utType` lazy-loaded only when accessed

**Check for regressions:**
- Don't add new stored properties to FileNode without justification
- Prefer computed properties that derive from `path`
- Don't cache data that's rarely accessed

**Memory budget:** ~150-200 bytes per FileNode
- 3M files should use ~500-600MB, not gigabytes

### Scanning

**Current optimizations:**
- Files processed inline (no Task overhead)
- Directories processed in batches of 8 (limits concurrent tasks)
- Sequential mode available for constrained systems
- Resource values prefetched by contentsOfDirectory, subsequent lookups use cache

**Check for regressions:**
- Don't spawn a Task for every file
- Don't hold entire directory listings in memory longer than needed
- Ensure cancellation works promptly

## CPU Optimization

### SwiftUI Rendering

**Current optimizations:**
- TreeMap uses Canvas for efficient batch rendering
- Layout cache stored in plain class (not @State) to avoid re-render loops
- Layout computation cached - only recalculated when size or root changes
- Color brightness adjustments cached by (color, depth) to avoid NSColor allocations
- Children assumed pre-sorted by scanner - no redundant sort in layout algorithm

**Check for regressions:**
- Never update @State from inside Canvas draw closure
- Never update @State from inside GeometryReader body
- Use `let _ = expression` for side effects, not state updates
- App should idle at 0% CPU when not scanning
- Don't re-sort children in layout - scanner already sorts them
- Don't allocate NSColor per rectangle - use cached color pairs

**Common pitfalls that cause render loops:**
```swift
// BAD - causes infinite re-render
Canvas { context, size in
    DispatchQueue.main.async {
        self.someState = newValue  // Triggers re-render!
    }
}

// GOOD - use non-reactive storage
private class Cache { var data: [Key: Value] = [:] }
private let cache = Cache()

Canvas { context, size in
    cache.data = newValue  // No re-render
}
```

### Hit Testing
- TreeMap stores layout in dictionary keyed by ObjectIdentifier
- Lookup is O(n) scan but n is small (visible rects only)
- Don't over-optimize unless profiling shows it's a bottleneck

## What NOT to Optimize

### Acceptable Costs
- Creating URL from path on-demand (rare, fast)
- Computing icons on-demand (only for visible items)
- String operations on paths (fast, infrequent)

### Avoid Premature Optimization
- Don't add caching without measuring first
- Don't add complexity for theoretical gains
- Don't optimize code paths that run once (app launch, scan completion)

## Performance Testing Checklist

Run these checks after significant changes:

### Memory Test
1. Scan a large volume (1M+ files)
2. Check Activity Monitor memory usage
3. Should be ~150-200 bytes per file scanned
4. Memory should not grow after scan completes

### CPU Test
1. Complete a scan and let app sit idle
2. CPU should drop to 0% within seconds
3. Hover over treemap - brief CPU spike is OK
4. No sustained CPU usage when idle

### Responsiveness Test
1. During scan, UI should remain responsive
2. Cancel button should stop scan within 1-2 seconds
3. Treemap should render without lag after scan

## Architecture Decisions

### Why Actor for FileScanner?
- Provides safe cancellation state
- But actual scanning is static methods (allows parallelism)
- Actor only coordinates, doesn't serialize scan work

### Why Class for FileNode (not Struct)?
- Tree structure needs parent/child references
- Struct would require copying entire subtrees
- Weak parent reference prevents retain cycles

### Why Canvas for TreeMap (not SwiftUI shapes)?
- Single draw call for thousands of rectangles
- No view hierarchy overhead
- Direct control over rendering order

## Profiling Commands

```bash
# Check memory allocations
leaks --atExit -- ./build/Build/Products/Debug/DiskInventoryY.app/Contents/MacOS/DiskInventoryY

# CPU profiling
sample DiskInventoryY 10 -file profile.txt

# Instruments (GUI)
open -a Instruments
```
