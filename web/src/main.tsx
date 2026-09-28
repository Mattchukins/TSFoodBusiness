import React, { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './style.css'

type Page = 'overview' | 'businesses' | 'kitchen' | 'orders' | 'finance' | 'suppliers'
const pages: { id: Page; label: string }[] = [
  { id: 'overview', label: 'Overview' }, { id: 'businesses', label: 'Businesses' },
  { id: 'kitchen', label: 'Kitchen' }, { id: 'orders', label: 'Orders' },
  { id: 'finance', label: 'Finance' }, { id: 'suppliers', label: 'Suppliers' },
]
type Business = { id: string; name: string; type: string }
type Recipe = { id: string; name: string; price_cents: number }
type Supplier = { id: string; name: string; item_name: string; unit_price_cents: number }
type Result = { ok: boolean; error?: string; businesses?: Business[]; recipes?: Recipe[]; suppliers?: Supplier[]; quote?: Recipe }
async function request(action: string, payload: Record<string, unknown>): Promise<Result> {
  const name = (window as Window & { GetParentResourceName?: () => string }).GetParentResourceName?.()
  if (!name) return { ok: false, error: 'FiveM resource unavailable' }
  const response = await fetch(`https://${name}/request`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action, payload }),
  })
  if (!response.ok) throw new Error('NUI request failed')
  return response.json()
}
function App() {
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState<Page>('overview')
  const closeRef = useRef<HTMLButtonElement>(null)
  const [businesses, setBusinesses] = useState<Business[]>([])
  const [businessName, setBusinessName] = useState('')
  const [businessType, setBusinessType] = useState('restaurant')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [selectedBusiness, setSelectedBusiness] = useState('')
  const [recipes, setRecipes] = useState<Recipe[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [entryName, setEntryName] = useState('')
  const [itemName, setItemName] = useState('')
  const [entryPrice, setEntryPrice] = useState('')
  const [quantity, setQuantity] = useState('1')
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
  useEffect(() => {
    if (!open) return
    void request('listBusinesses', {}).then(result => {
      if (result.ok) setBusinesses(result.businesses || [])
      else setMessage(result.error || 'Could not load businesses')
    }).catch(() => setMessage('Could not load businesses'))
  }, [open, page])
  useEffect(() => {
    if (!open || !selectedBusiness || !['kitchen', 'suppliers'].includes(page)) return
    const action = page === 'kitchen' ? 'listRecipes' : 'listSuppliers'
    void request(action, { businessId: selectedBusiness }).then(result => {
      if (!result.ok) { setMessage(result.error || 'Could not load catalog'); return }
      if (page === 'kitchen') setRecipes(result.recipes || [])
      else setSuppliers(result.suppliers || [])
    }).catch(() => setMessage('Could not load catalog'))
  }, [open, page, selectedBusiness])
  async function createCatalogEntry(event: React.FormEvent) {
    event.preventDefault()
    if (busy || !selectedBusiness) return
    const cents = Number(entryPrice)
    const count = Number(quantity)
    if (!Number.isSafeInteger(cents) || cents < 1 || cents > 10000000) { setMessage('Enter a valid price in cents'); return }
    if (page === 'kitchen' && (!Number.isSafeInteger(count) || count < 1 || count > 1000)) { setMessage('Enter a valid ingredient quantity'); return }
    setBusy(true); setMessage('')
    try {
      const result = page === 'kitchen'
        ? await request('createRecipe', { businessId: selectedBusiness, name: entryName.trim(), priceCents: cents, ingredients: [{ item: itemName.trim(), quantity: count }] })
        : await request('createSupplier', { businessId: selectedBusiness, name: entryName.trim(), itemName: itemName.trim(), unitPriceCents: cents })
      if (!result.ok) { setMessage(result.error || 'Could not save'); return }
      const refreshed = await request(page === 'kitchen' ? 'listRecipes' : 'listSuppliers', { businessId: selectedBusiness })
      if (refreshed.ok) { setRecipes(refreshed.recipes || []); setSuppliers(refreshed.suppliers || []) }
      setEntryName(''); setItemName(''); setEntryPrice(''); setMessage('Saved')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  async function createBusiness(event: React.FormEvent) {
    event.preventDefault()
    if (busy) return
    setBusy(true); setMessage('')
    try {
      const result = await request('createBusiness', { name: businessName.trim(), type: businessType, config: {} })
      if (!result.ok) { setMessage(result.error || 'Could not create business'); return }
      setBusinessName('')
      const refreshed = await request('listBusinesses', {})
      if (refreshed.ok) setBusinesses(refreshed.businesses || [])
      setMessage('Business created')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
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
      <div className="layout"><nav aria-label="Food Business sections">{pages.map(item => <button key={item.id} onClick={() => setPage(item.id)} aria-current={page === item.id ? 'page' : undefined}>{item.label}</button>)}<small>Development · v0.4.0-dev</small></nav>
        <section className="workspace" aria-labelledby="page-title"><p className="eyebrow">FOOD BUSINESS</p><h1 id="page-title">{pages.find(item => item.id === page)?.label}</h1>
          {page === 'businesses' ? <div className="panel"><h2>Your businesses</h2>
            {businesses.length ? <ul>{businesses.map(business => <li key={business.id}>{business.name} · {business.type}</li>)}</ul> : <p>No businesses found for this character.</p>}
            <form onSubmit={event => void createBusiness(event)}><label>Business name<input required minLength={2} maxLength={80} value={businessName} onChange={event => setBusinessName(event.target.value)}/></label>
              <label>Type<select value={businessType} onChange={event => setBusinessType(event.target.value)}>{['restaurant','cafe','bakery','bar','takeaway','kiosk','truck'].map(type => <option key={type} value={type}>{type}</option>)}</select></label>
              <button disabled={busy} type="submit">Create business</button></form><p role="status" aria-live="polite">{message}</p>
            <p>Creation requires server ACE permission <code>tsfoodbusiness.create</code>.</p></div>
          : page === 'kitchen' || page === 'suppliers' ? <div className="panel">
            <p>Catalog setup only. Cooking, inventory purchasing and payment are disabled.</p>
            <label>Business<select value={selectedBusiness} onChange={event => setSelectedBusiness(event.target.value)}><option value="">Select a business</option>{businesses.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
            {selectedBusiness && <><ul>{page === 'kitchen'
              ? recipes.map(r => <li key={r.id}>{r.name} · {r.price_cents} cents</li>)
              : suppliers.map(s => <li key={s.id}>{s.name}: {s.item_name} · {s.unit_price_cents} cents each</li>)}</ul>
              <form onSubmit={event => void createCatalogEntry(event)}>
                <label>{page === 'kitchen' ? 'Recipe name' : 'Supplier name'}<input required minLength={2} maxLength={80} value={entryName} onChange={event => setEntryName(event.target.value)}/></label>
                <label>{page === 'kitchen' ? 'Ingredient item' : 'Catalog item'}<input required minLength={2} maxLength={64} value={itemName} onChange={event => setItemName(event.target.value)}/></label>
                {page === 'kitchen' && <label>Ingredient quantity<input required type="number" min="1" max="1000" value={quantity} onChange={event => setQuantity(event.target.value)}/></label>}
                <label>Price in cents<input required type="number" min="1" max="10000000" value={entryPrice} onChange={event => setEntryPrice(event.target.value)}/></label>
                <button type="submit" disabled={busy}>Save {page === 'kitchen' ? 'recipe' : 'supplier item'}</button>
              </form></>}
            <p role="status" aria-live="polite">{message}</p></div>
          : <div className="panel"><h2>Coming in a later milestone</h2><p>This workspace has no live gameplay actions yet.</p></div>}</section>
      </div>
    </section>
  </main>
}
const root = document.getElementById('root')
if (!root) throw new Error('Missing React root')
createRoot(root).render(<React.StrictMode><App /></React.StrictMode>)
