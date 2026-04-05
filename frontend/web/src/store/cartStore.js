import { create } from "zustand";
import { persist } from "zustand/middleware";

const useCartStore = create(
  persist(
    (set, get) => ({
      items: [],
      sourceId: null, // restaurant or chef id
      sourceType: null, // 'restaurant' | 'chef'

      addItem: (item, sourceId, sourceType) => {
        const { sourceId: existingSource, items } = get();

        // Block mixing from different restaurants
        if (existingSource && existingSource !== sourceId) {
          return { error: "You can only order from one restaurant at a time." };
        }

        const existing = items.find((i) => i.id === item.id);
        if (existing) {
          set({
            items: items.map((i) =>
              i.id === item.id ? { ...i, qty: i.qty + 1 } : i,
            ),
          });
        } else {
          set({ items: [...items, { ...item, qty: 1 }], sourceId, sourceType });
        }
        return { error: null };
      },

      removeItem: (itemId) => {
        const items = get().items.filter((i) => i.id !== itemId);
        set({
          items,
          sourceId: items.length ? get().sourceId : null,
          sourceType: items.length ? get().sourceType : null,
        });
      },

      updateQty: (itemId, qty) => {
        if (qty <= 0) return get().removeItem(itemId);
        set({
          items: get().items.map((i) => (i.id === itemId ? { ...i, qty } : i)),
        });
      },

      clearCart: () => set({ items: [], sourceId: null, sourceType: null }),

      getTotal: () => get().items.reduce((sum, i) => sum + i.price * i.qty, 0),

      getCount: () => get().items.reduce((sum, i) => sum + i.qty, 0),
    }),
    { name: "cart-storage" },
  ),
);

export default useCartStore;
