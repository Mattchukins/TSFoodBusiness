import React, { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './style.css'
import { KitchenJobs, type CookingResponse } from './components/KitchenJobs'
import { ProductionEditor } from './components/ProductionEditor'
import { Panel } from './components/Panel'
import { StationCard, type Station } from './components/StationCard'

type Page = 'overview' | 'businesses' | 'operations' | 'kitchen' | 'stations' | 'orders' | 'finance' | 'suppliers' | 'activity'
const pages: { id: Page; label: string }[] = [
  { id: 'overview', label: 'Overview' }, { id: 'businesses', label: 'Businesses' }, { id: 'operations', label: 'Operations' },
  { id: 'kitchen', label: 'Kitchen' }, { id: 'orders', label: 'Orders' },
  { id: 'finance', label: 'Finance' }, { id: 'suppliers', label: 'Suppliers' },
  { id: 'activity', label: 'Activity' },
  { id: 'stations', label: 'Stations' },
]
type Business = { id: string; name: string; type: string }
type Preset = { id: string; label: string; opensMinute: number; closesMinute: number; seatCapacity: number; queueCapacity: number }
type Ingredient = { item: string; quantity: number }
type Recipe = { id: string; name: string; price_cents: number; ingredients: Ingredient[] }
type Supplier = { id: string; name: string; item_name: string; unit_price_cents: number }
type Operations = { opens_minute: number; closes_minute: number; seat_capacity: number; queue_capacity: number }
type AuditEntry = { action: string; details: string; created_at: string | number }
type Result = CookingResponse & { stockReport?: { available: boolean; ingredients: { item: string; required: number; available: number; missing: number }[] }; productionPlan?: { ingredients: Ingredient[]; outputItem: string; outputQuantity: number; durationSeconds: number; stationType: string; batches: number }; productionProfile?: { station_type: string; output_item: string; output_quantity: number; duration_seconds: number } | null; ok: boolean; error?: string; businesses?: Business[]; presets?: Preset[]; stationTypes?: string[]; recipes?: Recipe[]; suppliers?: Supplier[]; quote?: Recipe; operations?: Operations | null; audit?: AuditEntry[]; stations?: Station[] }
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
  const [presets, setPresets] = useState<Preset[]>([])
  const [businessName, setBusinessName] = useState('')
  const [renamingBusiness, setRenamingBusiness] = useState('')
  const [newBusinessName, setNewBusinessName] = useState('')
  const [businessType, setBusinessType] = useState('restaurant')
  const [message, setMessage] = useState('')
  const [busy, setBusy] = useState(false)
  const [selectedBusiness, setSelectedBusiness] = useState('')
  const [recipes, setRecipes] = useState<Recipe[]>([])
  const [suppliers, setSuppliers] = useState<Supplier[]>([])
  const [entryName, setEntryName] = useState('')
  const [itemName, setItemName] = useState('')
  const [entryPrice, setEntryPrice] = useState('')
  const [ingredients, setIngredients] = useState<Ingredient[]>([{ item: '', quantity: 1 }])
  const [productionRecipe, setProductionRecipe] = useState<Recipe | null>(null)
  const [editingRecipe, setEditingRecipe] = useState('')
  const [editingSupplier, setEditingSupplier] = useState('')
  const [opensMinute, setOpensMinute] = useState('540')
  const [closesMinute, setClosesMinute] = useState('1020')
  const [seatCapacity, setSeatCapacity] = useState('0')
  const [queueCapacity, setQueueCapacity] = useState('0')
  const [loadedOperationsBusiness, setLoadedOperationsBusiness] = useState('')
  const [audit, setAudit] = useState<AuditEntry[]>([])
  const [stationLoad, setStationLoad] = useState<'idle' | 'loading' | 'ready' | 'error'>('idle')
  const [stationSearch, setStationSearch] = useState('')
  const [stationFilter, setStationFilter] = useState('')
  const [stationReload, setStationReload] = useState(0)
  const [stations, setStations] = useState<Station[]>([])
  const [editingStation, setEditingStation] = useState('')
  const [stationName, setStationName] = useState('')
  const [stationTypes, setStationTypes] = useState<string[]>([])
  const [stationType, setStationType] = useState('')
  useEffect(() => {
    setProductionRecipe(null); setEditingRecipe(''); setEditingSupplier(''); setEntryName(''); setItemName(''); setEntryPrice('')
    setIngredients([{ item: '', quantity: 1 }]); setMessage('')
  }, [page, selectedBusiness])
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
    let active = true
    void request('listPresets', {}).then(result => {
      if (!active) return
      if (result.ok) setPresets(result.presets || [])
      else setMessage(result.error || 'Could not load business types')
    }).catch(() => { if (active) setMessage('Could not load business types') })
    void request('listBusinesses', {}).then(result => {
      if (!active) return
      if (result.ok) setBusinesses(result.businesses || [])
      else setMessage(result.error || 'Could not load businesses')
    }).catch(() => { if (active) setMessage('Could not load businesses') })
    return () => { active = false }
  }, [open, page])
  useEffect(() => {
    setRecipes([]); setSuppliers([])
    if (!open || !selectedBusiness || !['kitchen', 'suppliers'].includes(page)) return
    let active = true
    const action = page === 'kitchen' ? 'listRecipes' : 'listSuppliers'
    void request(action, { businessId: selectedBusiness }).then(result => {
      if (!active) return
      if (!result.ok) { setMessage(result.error || 'Could not load catalog'); return }
      if (page === 'kitchen') setRecipes(result.recipes || [])
      else setSuppliers(result.suppliers || [])
    }).catch(() => { if (active) setMessage('Could not load catalog') })
    return () => { active = false }
  }, [open, page, selectedBusiness])
  useEffect(() => {
    setStations([]); setStationSearch(''); setStationFilter(''); setStationLoad('idle'); setStationName(''); setEditingStation(''); setStationType('')
    if (!open || !selectedBusiness || page !== 'stations') return
    let active = true
    setStationTypes([]); setStationLoad('loading')
    void request('listStationTypes', {}).then(result => {
      if (!active) return
      if (result.ok) setStationTypes(result.stationTypes || [])
      else setMessage(result.error || 'Could not load equipment types')
    }).catch(() => { if (active) setMessage('Could not load equipment types') })
    void request('listStations', { businessId: selectedBusiness }).then(result => {
      if (!active) return
      if (result.ok) { setStations(result.stations || []); setStationLoad('ready') }
      else { setStationLoad('error'); setMessage(result.error || 'Could not load stations') }
    }).catch(() => { if (active) { setStationLoad('error'); setMessage('Could not load stations') } })
    return () => { active = false }
  }, [open, page, selectedBusiness, stationReload])
  async function refreshStationsAfterChange(successMessage: string) {
    setStationLoad('loading')
    try {
      const refreshed = await request('listStations', { businessId: selectedBusiness })
      if (!refreshed.ok) throw new Error('Refresh failed')
      setStations(refreshed.stations || []); setStationLoad('ready'); setMessage(successMessage)
    } catch {
      setStations([]); setStationLoad('error')
      setMessage(`${successMessage}. Could not refresh the station list; reload it before making another change.`)
    }
  }
  const filteredStations = stations.filter(station =>
    (!stationFilter || station.type === stationFilter)
    && station.name.toLocaleLowerCase().includes(stationSearch.trim().toLocaleLowerCase()))
  async function saveStation(event: React.FormEvent) {
    event.preventDefault()
    if (busy || stationLoad !== 'ready' || !selectedBusiness || !stationTypes.includes(stationType)) return
    setBusy(true); setMessage('')
    try {
      const result = await request(editingStation ? 'updateStation' : 'createStation', { businessId: selectedBusiness, ...(editingStation ? { stationId: editingStation } : {}), name: stationName.trim(), type: stationType })
      if (!result.ok) { setMessage(result.error || 'Could not place station'); return }
      setStationName(''); setEditingStation(''); setStationType('')
      await refreshStationsAfterChange(editingStation ? 'Station details saved' : 'Station position saved')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  async function changeStation(stationId: string, moving: boolean) {
    if (busy || stationLoad !== 'ready' || !selectedBusiness || !window.confirm(moving ? 'Move this station to your current position?' : 'Remove this station?')) return
    setBusy(true); setMessage('')
    try {
      const result = await request(moving ? 'moveStation' : 'deleteStation', { businessId: selectedBusiness, stationId })
      if (!result.ok) { setMessage(result.error || 'Could not change station'); return }
      if (!moving && editingStation === stationId) { setEditingStation(''); setStationName(''); setStationType('') }
      await refreshStationsAfterChange(moving ? 'Station moved' : 'Station removed')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  useEffect(() => {
    setAudit([])
    if (!open || !selectedBusiness || page !== 'activity') return
    let active = true
    void request('listAudit', { businessId: selectedBusiness }).then(result => {
      if (!active) return
      if (result.ok) setAudit(result.audit || [])
      else setMessage(result.error || 'Could not load activity')
    }).catch(() => { if (active) setMessage('Could not load activity') })
    return () => { active = false }
  }, [open, page, selectedBusiness])
  useEffect(() => {
    setLoadedOperationsBusiness('')
    if (!open || !selectedBusiness || page !== 'operations') return
    let active = true
    void request('getOperations', { businessId: selectedBusiness }).then(result => {
      if (!active) return
      if (!result.ok) { setMessage(result.error || 'Could not load operations'); return }
      const profile = result.operations
      setOpensMinute(String(profile?.opens_minute ?? 540))
      setClosesMinute(String(profile?.closes_minute ?? 1020))
      setSeatCapacity(String(profile?.seat_capacity ?? 0))
      setQueueCapacity(String(profile?.queue_capacity ?? 0))
      setLoadedOperationsBusiness(selectedBusiness)
    }).catch(() => { if (active) setMessage('Could not load operations') })
    return () => { active = false }
  }, [open, page, selectedBusiness])
  async function saveOperations(event: React.FormEvent) {
    event.preventDefault()
    if (busy || !selectedBusiness || loadedOperationsBusiness !== selectedBusiness) return
    const values = [opensMinute, closesMinute, seatCapacity, queueCapacity].map(Number)
    if (values.some(value => !Number.isSafeInteger(value)) || values[0] < 0 || values[0] > 1439
      || values[1] < 0 || values[1] > 1439 || values[0] === values[1]
      || values[2] < 0 || values[2] > 200 || values[3] < 0 || values[3] > 100) {
      setMessage('Check the hours and capacities'); return
    }
    setBusy(true); setMessage('')
    try {
      const result = await request('setOperations', { businessId: selectedBusiness,
        opensMinute: values[0], closesMinute: values[1], seatCapacity: values[2], queueCapacity: values[3] })
      setMessage(result.ok ? 'Operating profile saved' : result.error || 'Could not save operations')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  async function createCatalogEntry(event: React.FormEvent) {
    event.preventDefault()
    if (busy || !selectedBusiness) return
    const cents = Number(entryPrice)
    if (!Number.isSafeInteger(cents) || cents < 1 || cents > 10000000) { setMessage('Enter a valid price in cents'); return }
    if (page === 'kitchen' && (ingredients.length < 1 || ingredients.length > 16
      || new Set(ingredients.map(entry => entry.item)).size !== ingredients.length
      || ingredients.some(entry => !/^[A-Za-z0-9_-]{2,64}$/.test(entry.item)
        || !Number.isSafeInteger(entry.quantity) || entry.quantity < 1 || entry.quantity > 1000))) {
      setMessage('Use 1–16 unique item IDs and whole quantities from 1–1000'); return
    }
    setBusy(true); setMessage('')
    try {
      const result = page === 'kitchen'
        ? editingRecipe
          ? await request('updateRecipe', { businessId: selectedBusiness, recipeId: editingRecipe, name: entryName.trim(), priceCents: cents, ingredients })
          : await request('createRecipe', { businessId: selectedBusiness, name: entryName.trim(), priceCents: cents, ingredients })
        : editingSupplier
          ? await request('updateSupplier', { businessId: selectedBusiness, supplierId: editingSupplier, name: entryName.trim(), itemName: itemName.trim(), unitPriceCents: cents })
          : await request('createSupplier', { businessId: selectedBusiness, name: entryName.trim(), itemName: itemName.trim(), unitPriceCents: cents })
      if (!result.ok) { setMessage(result.error || 'Could not save'); return }
      const refreshed = await request(page === 'kitchen' ? 'listRecipes' : 'listSuppliers', { businessId: selectedBusiness })
      if (refreshed.ok) { setRecipes(refreshed.recipes || []); setSuppliers(refreshed.suppliers || []) }
      setEntryName(''); setItemName(''); setEntryPrice(''); setEditingRecipe(''); setEditingSupplier(''); setMessage('Saved')
      setIngredients([{ item: '', quantity: 1 }])
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  async function deleteRecipe(recipeId: string) {
    if (busy || !selectedBusiness || !window.confirm('Delete this recipe?')) return
    setBusy(true); setMessage('')
    try {
      const result = await request('deleteRecipe', { businessId: selectedBusiness, recipeId })
      if (!result.ok) { setMessage(result.error || 'Could not delete recipe'); return }
      const refreshed = await request('listRecipes', { businessId: selectedBusiness })
      if (refreshed.ok) setRecipes(refreshed.recipes || [])
      if (editingRecipe === recipeId) { setEditingRecipe(''); setEntryName(''); setEntryPrice('') }
      setMessage('Recipe deleted')
    } catch { setMessage('The server did not respond') }
    finally { setBusy(false) }
  }
  async function deleteSupplier(supplierId: string) {
    if (busy || !selectedBusiness || !window.confirm('Delete this supplier item?')) return
    setBusy(true); setMessage('')
    try {
      const result = await request('deleteSupplier', { businessId: selectedBusiness, supplierId })
      if (!result.ok) { setMessage(result.error || 'Could not delete supplier item'); return }
      const refreshed = await request('listSuppliers', { businessId: selectedBusiness })
      if (refreshed.ok) setSuppliers(refreshed.suppliers || [])
      if (editingSupplier === supplierId) { setEditingSupplier(''); setEntryName(''); setItemName(''); setEntryPrice('') }
      setMessage('Supplier item deleted')
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
  async function renameBusiness(event: React.FormEvent) {
    event.preventDefault()
    if (busy || !renamingBusiness) return
    setBusy(true); setMessage('')
    try {
      const result = await request('renameBusiness', { businessId: renamingBusiness, name: newBusinessName.trim() })
      if (!result.ok) { setMessage(result.error || 'Could not rename business'); return }
      const refreshed = await request('listBusinesses', {})
      if (refreshed.ok) setBusinesses(refreshed.businesses || [])
      setRenamingBusiness(''); setNewBusinessName(''); setMessage('Business renamed')
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
      const elements = [...document.querySelectorAll<HTMLElement>('.device summary, .device button:not([disabled]), .device input:not([disabled]), .device select:not([disabled]), .device textarea:not([disabled]), .device a[href]')]
      if (event.shiftKey && document.activeElement === elements[0]) { event.preventDefault(); elements[elements.length - 1]?.focus() }
      else if (!event.shiftKey && document.activeElement === elements[elements.length - 1]) { event.preventDefault(); elements[0]?.focus() }
    }
    document.addEventListener('keydown', keydown)
    return () => document.removeEventListener('keydown', keydown)
  }, [open])
  if (!open) return null
  return <main className="fixed inset-0 flex items-center justify-center p-[2vh] bg-[rgba(1,3,10,.8)] compact:p-0" role="dialog" aria-modal="true" aria-label="TwilightStore Food Business">
    <section className="flex flex-col w-[min(1400px,97vw)] h-[94vh] overflow-hidden bg-surface border border-solid border-border rounded-[18px] shadow-device compact:h-screen compact:w-screen compact:rounded-none"><header className="flex items-center justify-between min-h-[72px] py-3 px-5 bg-raised border-0 border-b border-solid border-border [&_button]:py-[9px] [&_button]:px-[15px] [&_button]:border [&_button]:border-solid [&_button]:border-border [&_button]:rounded-lg [&_button]:bg-control"><div className="flex items-center gap-3 [&_strong]:block [&_small]:block [&_small]:text-muted"><span className="grid place-items-center w-[38px] h-[38px] rounded-xl bg-accent font-bold">TS</span><div><strong>Food Business</strong><small>TwilightStore hospitality</small></div></div><button ref={closeRef} onClick={() => void close()} aria-label="Close Food Business">Close</button></header>
      <div className="grid grid-cols-[240px_minmax(0,1fr)] flex-1 min-h-0 compact:grid-cols-[115px_minmax(0,1fr)]"><nav className="flex flex-col gap-1 p-4 border-0 border-r border-solid border-border compact:p-2 [&_button]:text-left [&_button]:p-[11px] [&_button]:border-0 [&_button]:rounded-lg [&_button]:bg-transparent [&_button:hover]:bg-[#36244f] [&_button[aria-current=page]]:bg-[#36244f] compact:[&_button]:p-2 compact:[&_button]:text-[.85rem] [&_small]:mt-auto [&_small]:text-muted" aria-label="Food Business sections">{pages.map(item => <button key={item.id} disabled={busy} onClick={() => setPage(item.id)} aria-current={page === item.id ? 'page' : undefined}>{item.label}</button>)}<small>Development · v0.8.0-dev</small></nav>
        <section className="overflow-auto p-[clamp(20px,4vw,50px)] compact:p-[18px] [&_h1]:mt-0 [&_h1]:mb-7" aria-labelledby="page-title"><p className="text-[#c9a7f5] tracking-[.14em] text-xs">FOOD BUSINESS</p><h1 id="page-title">{pages.find(item => item.id === page)?.label}</h1>
          {page === 'businesses' ? <Panel><h2>Your businesses</h2>
            {businesses.length ? <ul>{businesses.map(business => <li key={business.id}>{business.name} · {business.type} <button type="button" disabled={busy} onClick={() => { setRenamingBusiness(business.id); setNewBusinessName(business.name) }}>Rename</button></li>)}</ul> : <p>No businesses found for this character.</p>}
            {renamingBusiness && <form onSubmit={event => void renameBusiness(event)}><label>New business name<input required minLength={2} maxLength={80} value={newBusinessName} onChange={event => setNewBusinessName(event.target.value)} /></label><button type="submit" disabled={busy}>Save name</button><button type="button" onClick={() => setRenamingBusiness('')}>Cancel</button></form>}
            <form onSubmit={event => void createBusiness(event)}><label>Business name<input required minLength={2} maxLength={80} value={businessName} onChange={event => setBusinessName(event.target.value)}/></label>
              <label>Type<select value={businessType} onChange={event => setBusinessType(event.target.value)}>{presets.map(preset => <option key={preset.id} value={preset.id}>{preset.label}</option>)}</select></label>
              <button disabled={busy || presets.length === 0} type="submit">Create business</button></form><p role="status" aria-live="polite">{message}</p>
            <p>Creation requires server ACE permission <code>tsfoodbusiness.create</code>.</p></Panel>
          : page === 'stations' ? <Panel><h2>Kitchen stations</h2>
            <label>Business<select disabled={busy} value={selectedBusiness} onChange={event => setSelectedBusiness(event.target.value)}><option value="">Select a business</option>{businesses.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
            <p>Stand where the station belongs before opening this screen. Placement saves your current position and direction. Cooking and equipment props are still in development.</p>
            {selectedBusiness && <><button type="button" disabled={busy || stationLoad === 'loading'} onClick={() => { setMessage(''); setStationReload(value => value + 1) }}>Reload stations</button>
            {stationLoad === 'loading' && <p role="status">Loading stations…</p>}
            {stationLoad === 'ready' && stations.length === 0 && <p>No stations placed for this business.</p>}
            {stationLoad === 'ready' && <><div className="my-4 grid gap-3">
              <label>Search station names<input type="search" maxLength={80} value={stationSearch} onChange={event => setStationSearch(event.target.value)} /></label>
              <label>Filter equipment<select value={stationFilter} onChange={event => setStationFilter(event.target.value)}><option value="">All equipment</option>{stationTypes.map(kind => <option key={kind} value={kind}>{kind}</option>)}</select></label>
              {(stationSearch || stationFilter) && <button type="button" onClick={() => { setStationSearch(''); setStationFilter('') }}>Clear filters</button>}
            </div><p role="status">Showing {filteredStations.length} of {stations.length} loaded stations.</p>
            {stations.length > 0 && filteredStations.length === 0 && <p>No stations match these filters.</p>}
            {stations.length === 200 && <p>The first 200 stations are loaded. Search and filters apply to this list.</p>}</>}
            <ul className="p-0" aria-busy={stationLoad === 'loading'}>{filteredStations.map(station => <StationCard key={station.id} station={station} disabled={busy || stationLoad !== 'ready'}
              onEdit={() => { setEditingStation(station.id); setStationName(station.name); setStationType(station.type) }}
              onMove={() => void changeStation(station.id, true)} onRemove={() => void changeStation(station.id, false)} />)}</ul>
            <form onSubmit={event => void saveStation(event)}><label>Station name<input required minLength={2} maxLength={80} value={stationName} onChange={event => setStationName(event.target.value)} /></label>
            <label>Equipment<select value={stationType} onChange={event => setStationType(event.target.value)}><option value="">Select equipment</option>{stationTypes.map(kind => <option key={kind} value={kind}>{kind}</option>)}</select></label>
            <button disabled={busy || stationLoad !== 'ready' || !stationTypes.includes(stationType)} type="submit">{editingStation ? 'Save details' : 'Place at current position'}</button>{editingStation && <button type="button" disabled={busy} onClick={() => { setEditingStation(''); setStationName(''); setStationType('') }}>Cancel edit</button>}</form></>}
            <p role="status" aria-live="polite">{message}</p></Panel>
          : page === 'activity' ? <Panel><h2>Recent business changes</h2>
            <label>Business<select disabled={busy} value={selectedBusiness} onChange={event => setSelectedBusiness(event.target.value)}><option value="">Select a business</option>{businesses.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
            <p>The latest 100 recorded changes, newest first.</p>
            {selectedBusiness && <ul>{audit.map((entry, index) => <li key={index}><strong>{entry.action}</strong><p>{String(entry.created_at)}</p><details><summary>Change details</summary><pre className="whitespace-pre-wrap [overflow-wrap:anywhere]">{entry.details}</pre></details></li>)}</ul>}
            <p role="status" aria-live="polite">{message}</p></Panel>
          : page === 'operations' ? <Panel><p>Configuration only. NPC customers and offline sales are disabled.</p>
            <label>Business<select disabled={busy} value={selectedBusiness} onChange={event => setSelectedBusiness(event.target.value)}><option value="">Select a business</option>{businesses.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
            {selectedBusiness && <form onSubmit={event => void saveOperations(event)}>
              <label>Opening minute after midnight<input type="number" min="0" max="1439" required value={opensMinute} onChange={event => setOpensMinute(event.target.value)} /></label>
              <label>Closing minute after midnight<input type="number" min="0" max="1439" required value={closesMinute} onChange={event => setClosesMinute(event.target.value)} /></label>
              <label>Seat capacity<input type="number" min="0" max="200" required value={seatCapacity} onChange={event => setSeatCapacity(event.target.value)} /></label>
              <label>Queue capacity<input type="number" min="0" max="100" required value={queueCapacity} onChange={event => setQueueCapacity(event.target.value)} /></label>
              <button type="submit" disabled={busy || loadedOperationsBusiness !== selectedBusiness}>Save operating profile</button></form>}
            <p role="status" aria-live="polite">{message}</p></Panel>
          : page === 'kitchen' || page === 'suppliers' ? <Panel>
            <p>Configure recipes and suppliers. Cooking requires a verified inventory adapter; purchasing and payments remain disabled.</p>
            <label>Business<select disabled={busy} value={selectedBusiness} onChange={event => { setSelectedBusiness(event.target.value); setEditingRecipe(''); setEditingSupplier(''); setEntryName(''); setItemName(''); setEntryPrice('') }}><option value="">Select a business</option>{businesses.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}</select></label>
            {selectedBusiness && <><ul>{page === 'kitchen'
              ? recipes.map(r => <li key={r.id}>{r.name} · {r.price_cents} cents <button type="button" disabled={busy} onClick={() => setProductionRecipe(r)}>Production settings</button> <button disabled={busy} type="button" onClick={() => { setEditingRecipe(r.id); setEntryName(r.name); setEntryPrice(String(r.price_cents)); setIngredients(r.ingredients.map(entry => ({ ...entry }))) }}>Edit</button> <button disabled={busy} type="button" onClick={() => void deleteRecipe(r.id)}>Delete</button></li>)
              : suppliers.map(s => <li key={s.id}>{s.name}: {s.item_name} · {s.unit_price_cents} cents each <button disabled={busy} type="button" onClick={() => { setEditingSupplier(s.id); setEntryName(s.name); setItemName(s.item_name); setEntryPrice(String(s.unit_price_cents)) }}>Edit</button> <button disabled={busy} type="button" onClick={() => void deleteSupplier(s.id)}>Delete</button></li>)}</ul>
              {page === 'kitchen' && <KitchenJobs key={selectedBusiness} businessId={selectedBusiness} recipes={recipes} request={request} busy={busy} onBusy={setBusy} />}
              {page === 'kitchen' && productionRecipe && <ProductionEditor key={`${selectedBusiness}:${productionRecipe.id}`} businessId={selectedBusiness} recipe={productionRecipe} request={request} busy={busy} onBusy={setBusy} onClose={() => setProductionRecipe(null)} />}
              <form onSubmit={event => void createCatalogEntry(event)}>
                <label>{page === 'kitchen' ? 'Recipe name' : 'Supplier name'}<input required minLength={2} maxLength={80} value={entryName} onChange={event => setEntryName(event.target.value)}/></label>
                {page === 'suppliers' && <label>Catalog item<input required minLength={2} maxLength={64} value={itemName} onChange={event => setItemName(event.target.value)}/></label>}
                {page === 'kitchen' && <fieldset><legend>Ingredients</legend>{ingredients.map((entry, index) => <div key={index}>
                  <label>Item {index + 1}<input required minLength={2} maxLength={64} pattern="[A-Za-z0-9_-]+" value={entry.item} onChange={event => setIngredients(current => current.map((item, i) => i === index ? { ...item, item: event.target.value } : item))}/></label>
                  <label>Quantity<input required type="number" min="1" max="1000" value={entry.quantity} onChange={event => setIngredients(current => current.map((item, i) => i === index ? { ...item, quantity: Number(event.target.value) } : item))}/></label>
                  <button type="button" disabled={ingredients.length === 1 || busy} onClick={() => setIngredients(current => current.filter((_, i) => i !== index))}>Remove ingredient {index + 1}</button>
                </div>)}<button type="button" disabled={ingredients.length >= 16 || busy} onClick={() => setIngredients(current => [...current, { item: '', quantity: 1 }])}>Add ingredient</button></fieldset>}
                <label>Price in cents<input required type="number" min="1" max="10000000" value={entryPrice} onChange={event => setEntryPrice(event.target.value)}/></label>
                <button type="submit" disabled={busy}>{editingRecipe && page === 'kitchen' ? 'Update recipe' : editingSupplier && page === 'suppliers' ? 'Update supplier item' : `Save ${page === 'kitchen' ? 'recipe' : 'supplier item'}`}</button>
                {editingRecipe && page === 'kitchen' && <button type="button" onClick={() => { setEditingRecipe(''); setEntryName(''); setEntryPrice('') }}>Cancel edit</button>}
                {editingSupplier && page === 'suppliers' && <button type="button" onClick={() => { setEditingSupplier(''); setEntryName(''); setItemName(''); setEntryPrice('') }}>Cancel edit</button>}
              </form></>}
            <p role="status" aria-live="polite">{message}</p></Panel>
          : <Panel><h2>Coming in a later milestone</h2><p>This workspace has no live gameplay actions yet.</p></Panel>}</section>
      </div>
    </section>
  </main>
}
const root = document.getElementById('root')
if (!root) throw new Error('Missing React root')
createRoot(root).render(<React.StrictMode><App /></React.StrictMode>)
