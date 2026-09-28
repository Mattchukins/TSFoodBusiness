import React, { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './style.css'

type Page = 'overview' | 'businesses' | 'kitchen' | 'orders' | 'finance'
const pages: { id: Page; label: string }[] = [
  { id: 'overview', label: 'Overview' }, { id: 'businesses', label: 'Businesses' },
  { id: 'kitchen', label: 'Kitchen' }, { id: 'orders', label: 'Orders' },
  { id: 'finance', label: 'Finance' },
]
function App() {
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState<Page>('overview')
  const closeRef = useRef<HTMLButtonElement>(null)
  useEffect(() => {
    const listener = (event: MessageEvent<unknown>) => {
      if (!event.data || typeof event.data !== 'object' || !('action' in event.data)) return
      if (event.data.action === 'open') { setPage('overview'); setOpen(true) }
      if (event.data.action === 'close') setOpen(false)
    }
    window.addEventListener('message', listener)
    return () => window.removeEventListener('message', listener)
  }, [])
  useEffect(() => { if (open) closeRef.current?.focus() }, [open])
  async function close() {
    setOpen(false)
    const name = (window as Window & { GetParentResourceName?: () => string }).GetParentResourceName?.()
    if (name) {
      try {
        const response = await fetch(`https://${name}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
        if (!response.ok) throw new Error('Close callback failed')
      } catch (error) { console.error(error) }
    }
  }
  useEffect(() => {
    if (!open) return
    const keydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { event.preventDefault(); void close() }
      if (event.key !== 'Tab') return
      const elements = [...document.querySelectorAll<HTMLButtonElement>('.device button:not([disabled])')]
      if (event.shiftKey && document.activeElement === elements[0]) { event.preventDefault(); elements[elements.length - 1]?.focus() }
      else if (!event.shiftKey && document.activeElement === elements[elements.length - 1]) { event.preventDefault(); elements[0]?.focus() }
    }
    document.addEventListener('keydown', keydown)
    return () => document.removeEventListener('keydown', keydown)
  }, [open])
  if (!open) return null
  return <main className="overlay" role="dialog" aria-modal="true" aria-label="TwilightStore Food Business">
    <section className="device"><header><div className="brand"><span className="mark">TS</span><div><strong>Food Business</strong><small>TwilightStore hospitality</small></div></div><button ref={closeRef} onClick={() => void close()} aria-label="Close Food Business">Close</button></header>
      <div className="layout"><nav aria-label="Food Business sections">{pages.map(item => <button key={item.id} onClick={() => setPage(item.id)} aria-current={page === item.id ? 'page' : undefined}>{item.label}</button>)}<small>Bootstrap · v0.0.0</small></nav>
        <section className="workspace" aria-labelledby="page-title"><p className="eyebrow">FOOD BUSINESS</p><h1 id="page-title">{pages.find(item => item.id === page)?.label}</h1><div className="panel"><h2>Coming in the next milestone</h2><p>This workspace is a navigation and NUI lifecycle preview. No business data or transactions are available yet.</p></div></section>
      </div>
    </section>
  </main>
}
const root = document.getElementById('root')
if (!root) throw new Error('Missing React root')
createRoot(root).render(<React.StrictMode><App /></React.StrictMode>)
