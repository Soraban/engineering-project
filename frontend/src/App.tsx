import { BrowserRouter, Routes, Route, NavLink, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import Dashboard from './pages/Dashboard'
import Transactions from './pages/Transactions'
import Rules from './pages/Rules'
import Import from './pages/Import'
import Login from './pages/Login'
import NotificationToaster from './components/NotificationToaster'
import './App.css'

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 30_000 } }
})

function isAuthenticated() {
  return !!localStorage.getItem('auth_token')
}

function Layout() {
  return (
    <>
      <nav className="sidebar">
        <div className="logo">
          <div className="logo-mark">B</div>
          Bookkeeping
        </div>
        <div className="nav-section">
          <div className="nav-label">Overview</div>
          <NavLink to="/dashboard" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
            Dashboard
          </NavLink>
          <NavLink to="/transactions" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
            Transactions
          </NavLink>
        </div>
        <div className="nav-section">
          <div className="nav-label">Automation</div>
          <NavLink to="/rules" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
            Rules
          </NavLink>
          <NavLink to="/import" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
            Import CSV
          </NavLink>
        </div>
      </nav>
      <main className="main">
        <Routes>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/transactions" element={<Transactions />} />
          <Route path="/rules" element={<Rules />} />
          <Route path="/import" element={<Import />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </main>
      <NotificationToaster />
    </>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/*" element={isAuthenticated() ? <Layout /> : <Navigate to="/login" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  )
}
