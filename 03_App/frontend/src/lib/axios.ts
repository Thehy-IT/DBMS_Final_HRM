import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/v1',
  headers: {
    'Content-Type': 'application/json',
  },
  // Timeout 15s: tránh request treo vô thời hạn
  timeout: 0,
});

// Cache token trong module scope để tránh JSON.parse localStorage mỗi request
let _cachedToken: string | null = null;

/**
 * Xóa cache token — gọi khi logout hoặc nhận 401
 */
export const clearTokenCache = () => { _cachedToken = null; };

api.interceptors.request.use((config) => {
  if (typeof window === 'undefined') return config;

  // Dùng cache trước, chỉ parse localStorage khi chưa có
  if (!_cachedToken) {
    try {
      const authStorage = sessionStorage.getItem('auth-storage');
      if (authStorage) {
        const parsed = JSON.parse(authStorage);
        _cachedToken = parsed?.state?.token ?? null;
      }
    } catch {
      _cachedToken = null;
    }
  }

  if (_cachedToken && config.headers) {
    config.headers.Authorization = `Bearer ${_cachedToken}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
        clearTokenCache();
        sessionStorage.removeItem('auth-storage');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;
