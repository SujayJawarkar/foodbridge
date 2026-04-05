import { Outlet, Navigate, NavLink } from "react-router-dom";
import useAuthStore from "../../store/authStore";

const navItems = [
  { label: "Dashboard", to: "/admin" },
  { label: "Users", to: "/admin/users" },
  { label: "Restaurants", to: "/admin/restaurants" },
  { label: "Orders", to: "/admin/orders" },
  { label: "Donations", to: "/admin/donations" },
  { label: "Analytics", to: "/admin/analytics" },
];

export default function AdminLayout() {
  const { role } = useAuthStore();

  if (role !== "SUPER_ADMIN") return <Navigate to="/" replace />;

  return (
    <div className="min-h-screen flex bg-gray-100">
      {/* Sidebar */}
      <aside className="w-56 bg-white border-r border-gray-200 flex flex-col py-6 px-4 gap-1 shrink-0">
        <p className="text-orange-500 font-bold text-lg mb-6 px-2">
          FoodBridge Admin
        </p>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === "/admin"}
            className={({ isActive }) =>
              `px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                isActive
                  ? "bg-orange-50 text-orange-600"
                  : "text-gray-600 hover:bg-gray-50"
              }`
            }
          >
            {item.label}
          </NavLink>
        ))}
      </aside>

      {/* Content */}
      <main className="flex-1 p-8 overflow-y-auto">
        <Outlet />
      </main>
    </div>
  );
}
