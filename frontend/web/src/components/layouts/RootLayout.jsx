import { Outlet, Navigate } from "react-router-dom";
import useAuthStore from "../../store/authStore";
import Navbar from "../Navbar";
import BottomNav from "../BottomNav";

export default function RootLayout() {
  const { token } = useAuthStore();

  if (!token) return <Navigate to="/auth/login" replace />;

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <Navbar />
      <main className="flex-1 max-w-5xl mx-auto w-full px-4 py-4 pb-24">
        <Outlet />
      </main>
      <BottomNav />
    </div>
  );
}
