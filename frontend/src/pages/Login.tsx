import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { signIn, signUp } from '../api/client'

export default function Login() {
  const [email, setEmail] = useState('demo@test.com')
  const [password, setPassword] = useState('password123')
  const [error, setError] = useState('')
  const [isSignUp, setIsSignUp] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      if (isSignUp) {
        await signUp(email, password)
      }
      await signIn(email, password)
      navigate('/dashboard')
      window.location.reload()
    } catch {
      setError('Invalid credentials')
    }
  }

  return (
    <div className="login-page">
      <div className="login-box">
        <h1>{isSignUp ? 'Sign Up' : 'Sign In'}</h1>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} required />
          </div>
          {error && <p className="error-text">{error}</p>}
          <button type="submit" className="btn btn-primary">{isSignUp ? 'Sign Up' : 'Sign In'}</button>
        </form>
        <p style={{ textAlign: 'center', marginTop: 16, fontSize: 13, color: 'var(--text3)' }}>
          <span style={{ cursor: 'pointer', color: 'var(--accent)' }} onClick={() => setIsSignUp(!isSignUp)}>
            {isSignUp ? 'Already have an account? Sign in' : 'Need an account? Sign up'}
          </span>
        </p>
      </div>
    </div>
  )
}
