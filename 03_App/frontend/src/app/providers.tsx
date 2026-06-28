"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        // 5 phút: data không bị coi là stale → không refetch khi navigate giữa trang
        staleTime: 5 * 60 * 1000,
        // 10 phút: giữ cache sau khi component unmount → navigate quay lại tức thì
        gcTime: 10 * 60 * 1000,
        refetchOnWindowFocus: false,
        // Giảm retry 3 → 1: lỗi thật sự sẽ báo nhanh hơn, không chờ 3 lần
        retry: 1,
        retryDelay: 1000,
      },
    },
  }));

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}
