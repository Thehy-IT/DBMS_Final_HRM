"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        // Tự động load lại ngầm mỗi 3 giây để cập nhật dữ liệu realtime
        refetchInterval: 3000,
        refetchIntervalInBackground: true,
        // Dữ liệu luôn được coi là cũ để refetchInterval hoạt động đúng
        staleTime: 0,
        gcTime: 10 * 60 * 1000,
        // Tự động load lại khi người dùng quay lại tab
        refetchOnWindowFocus: true,
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
