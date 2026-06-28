import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Gzip tất cả static assets
  compress: true,
  // Ẩn thông tin server, giảm response header size
  poweredByHeader: false,
  allowedDevOrigins: [
    "192.168.1.240",
    "localhost",
  ],
  experimental: {
    // Tree-shake: chỉ import icon/component thực sự dùng → giảm bundle ~40%
    optimizePackageImports: ['lucide-react', 'recharts'],
  },
};

export default nextConfig;