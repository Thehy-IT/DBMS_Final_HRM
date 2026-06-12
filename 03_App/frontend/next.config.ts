import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // @ts-ignore
  allowedDevOrigins: ['192.168.1.240', 'localhost'],
  experimental: {
    // @ts-ignore
    allowedDevOrigins: ['192.168.1.240', 'localhost']
  }
};

export default nextConfig;
