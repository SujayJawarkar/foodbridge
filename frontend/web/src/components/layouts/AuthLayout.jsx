import { Outlet, Navigate } from "react-router-dom";
import useAuthStore from "../../store/authStore";

export default function AuthLayout() {
  const { token } = useAuthStore();

  if (token) return <Navigate to="/" replace />;

  return (
    <div className="min-h-screen bg-orange-50 flex items-center justify-center px-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-sm p-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-orange-500">FoodBridge</h1>
          <p className="text-gray-500 text-sm mt-1">Pune's food, connected.</p>
        </div>
        <Outlet />
      </div>
    </div>
  );
}
