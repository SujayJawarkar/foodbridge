import { Link } from "react-router-dom";
import useAuthStore from "../store/authStore";
import useCartStore from "../store/cartStore";

export default function Navbar() {
  const { user, clearAuth } = useAuthStore();
  const count = useCartStore((s) => s.getCount());

  return (
    <header className="sticky top-0 z-50 bg-white border-b border-gray-100 shadow-sm">
      <div className="max-w-5xl mx-auto px-4 h-14 flex items-center justify-between">
        <Link to="/" className="text-orange-500 font-bold text-xl">
          FoodBridge
        </Link>

        <div className="flex items-center gap-4">
          <Link
            to="/cart"
            className="relative text-gray-600 hover:text-orange-500"
          >
            Cart
            {count > 0 && (
              <span className="absolute -top-2 -right-3 bg-orange-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
                {count}
              </span>
            )}
          </Link>
          <span className="text-sm text-gray-500">{user?.name}</span>
          <button
            onClick={clearAuth}
            className="text-sm text-gray-400 hover:text-red-500 transition-colors"
          >
            Logout
          </button>
        </div>
      </div>
    </header>
  );
}
