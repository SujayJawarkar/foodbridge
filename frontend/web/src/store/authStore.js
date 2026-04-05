import { create } from "zustand";
import { persist } from "zustand/middleware";

const useAuthStore = create(
  persist(
    (set) => ({
      user: null,
      token: null,
      role: null,

      setAuth: (user, token) => {
        localStorage.setItem("token", token);
        set({ user, token, role: user.role });
      },

      clearAuth: () => {
        localStorage.removeItem("token");
        set({ user: null, token: null, role: null });
      },
    }),
    { name: "auth-storage" },
  ),
);

export default useAuthStore;
