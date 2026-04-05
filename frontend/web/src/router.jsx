import { createBrowserRouter } from "react-router-dom";

// Layouts
import RootLayout from "./components/layouts/RootLayout";
import AuthLayout from "./components/layouts/AuthLayout";
import AdminLayout from "./components/layouts/AdminLayout";

// Placeholder pages (we'll build these next)
import Home from "./pages/Home";
import Login from "./pages/Login";
import NotFound from "./pages/NotFound";

const router = createBrowserRouter([
  {
    path: "/",
    element: <RootLayout />,
    children: [
      { index: true, element: <Home /> },
      // We'll add: search, restaurant, cart, checkout, tracking, nutrition, recipes
    ],
  },
  {
    path: "/auth",
    element: <AuthLayout />,
    children: [{ path: "login", element: <Login /> }],
  },
  {
    path: "/admin",
    element: <AdminLayout />,
    children: [
      // Admin pages go here
    ],
  },
  { path: "*", element: <NotFound /> },
]);

export default router;
