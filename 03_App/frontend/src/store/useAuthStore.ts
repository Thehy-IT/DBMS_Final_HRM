import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { clearTokenCache } from '@/lib/axios';

type User = {
  username: string;
  role: string;
  empId: string | null;
};

type AuthState = {
  token: string | null;
  user: User | null;
  login: (token: string, user: User) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      login: (token, user) => set({ token, user }),
      logout: () => {
        // Xóa token cache trong axios module để request tiếp theo không dùng token cũ
        clearTokenCache();
        set({ token: null, user: null });
      },
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => sessionStorage),
    }
  )
);

