/**
 * Skeleton loading components
 * Sử dụng animation pulse để hiển thị placeholder trong khi data đang load.
 * Mỗi section của dashboard tự render skeleton của mình → không block toàn trang.
 */
import type { CSSProperties } from 'react';

interface SkeletonProps {
  className?: string;
  style?: CSSProperties;
}

export function Skeleton({ className = '', style }: SkeletonProps) {
  return (
    <div
      className={`animate-pulse bg-slate-200 rounded ${className}`}
      style={style}
      aria-hidden="true"
    />
  );
}

/** Skeleton cho 1 stat card */
export function StatCardSkeleton() {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-6 shadow-sm flex items-center justify-between">
      <div className="space-y-3 flex-1">
        <Skeleton className="h-3 w-28" />
        <Skeleton className="h-7 w-20" />
        <Skeleton className="h-2.5 w-36" />
      </div>
      <Skeleton className="w-12 h-12 rounded-full shrink-0" />
    </div>
  );
}

/** Skeleton cho grid stat cards */
export function StatGridSkeleton({ count = 5 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
      {Array.from({ length: count }).map((_, i) => (
        <StatCardSkeleton key={i} />
      ))}
    </div>
  );
}

/** Skeleton cho chart card */
export function ChartCardSkeleton() {
  return (
    <div className="relative overflow-hidden bg-white rounded-3xl border border-slate-100 shadow-sm p-7 flex flex-col">
      <div className="flex items-center justify-between mb-6">
        <div className="space-y-2">
          <Skeleton className="h-5 w-36" />
          <Skeleton className="h-3 w-48" />
        </div>
        <Skeleton className="w-9 h-9 rounded-xl" />
      </div>
      {/* Chart placeholder */}
      <div className="flex items-end justify-center gap-3 h-[280px] px-4 pb-4">
        {[60, 85, 45, 95, 70, 55, 80].map((h, i) => (
          <Skeleton
            key={i}
            className="flex-1 rounded-t-lg"
            style={{ height: `${h}%` }}
          />
        ))}
      </div>
    </div>
  );
}

/** Skeleton cho table rows */
export function TableRowsSkeleton({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <>
      {Array.from({ length: rows }).map((_, i) => (
        <tr key={i} className="border-b border-slate-100">
          {Array.from({ length: cols }).map((_, j) => (
            <td key={j} className="px-6 py-4">
              <Skeleton className={`h-4 ${j === 0 ? 'w-24' : j === cols - 1 ? 'w-16' : 'w-full max-w-[120px]'}`} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}
