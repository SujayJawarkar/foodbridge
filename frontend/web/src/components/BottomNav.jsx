import { NavLink } from "react-router-dom";

const tabs = [
  { label: "Home", to: "/" },
  { label: "Search", to: "/search" },
  { label: "Orders", to: "/orders" },
  { label: "Nutrition", to: "/nutrition" },
  { label: "Profile", to: "/profile" },
];

export default function BottomNav() {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-white border-t border-gray-100 flex justify-around items-center h-16 md:hidden">
      {tabs.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          end={tab.to === "/"}
          className={({ isActive }) =>
            `flex flex-col items-center text-xs font-medium transition-colors ${
              isActive ? "text-orange-500" : "text-gray-400 hover:text-gray-600"
            }`
          }
        >
          {tab.label}
        </NavLink>
      ))}
    </nav>
  );
}
