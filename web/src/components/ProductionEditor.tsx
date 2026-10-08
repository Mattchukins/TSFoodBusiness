import { useEffect, useState } from 'react'

type Profile = { station_type: string; output_item: string; output_quantity: number; duration_seconds: number }
type Plan = { ingredients: { item: string; quantity: number }[]; outputItem: string; outputQuantity: number; durationSeconds: number; stationType: string; batches: number }
type Response = { stockReport?: { available: boolean; ingredients: { item: string; required: number; available: number; missing: number }[] }; productionPlan?: Plan; ok: boolean; error?: string; productionProfile?: Profile | null; stationTypes?: string[] }

export function ProductionEditor({ businessId, recipe, request, busy, onBusy, onClose }: {
  businessId: string; recipe: { id: string; name: string }
  request: (action: string, payload: Record<string, unknown>) => Promise<Response>
  busy: boolean; onBusy: (busy: boolean) => void; onClose: () => void
}) {
  const [stock, setStock] = useState<Response['stockReport']>(undefined)
  const [batches, setBatches] = useState('1')
  const [plan, setPlan] = useState<Plan | null>(null)
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading')
  const [reload, setReload] = useState(0)
  const [types, setTypes] = useState<string[]>([])
  const [stationType, setStationType] = useState('')
  const [outputItem, setOutputItem] = useState('')
  const [quantity, setQuantity] = useState('1')
  const [seconds, setSeconds] = useState('30')
  const [message, setMessage] = useState('')
  useEffect(() => {
    let active = true
    setState('loading'); setMessage(''); setPlan(null); setStock(undefined)
    void Promise.all([
      request('getProductionProfile', { businessId, recipeId: recipe.id }),
      request('listStationTypes', {}),
    ]).then(([result, equipment]) => {
      if (!active) return
      if (!result.ok || !equipment.ok) throw new Error(result.error || equipment.error || 'Could not load production settings')
      const profile = result.productionProfile
      setTypes(equipment.stationTypes || []); setStationType(profile?.station_type || '')
      setOutputItem(profile?.output_item || ''); setQuantity(String(profile?.output_quantity ?? 1))
      setSeconds(String(profile?.duration_seconds ?? 30)); setState('ready')
      if (!profile) setMessage('No production settings saved for this recipe yet.')
    }).catch(error => { if (active) { setState('error'); setMessage(error instanceof Error ? error.message : 'Could not load production settings') } })
    return () => { active = false }
  }, [businessId, recipe.id, request, reload])
  async function save(event: React.FormEvent) {
    event.preventDefault()
    if (busy || state !== 'ready' || !types.includes(stationType)) return
    onBusy(true); setMessage(''); setPlan(null); setStock(undefined)
    try {
      const result = await request('setProductionProfile', { businessId, recipeId: recipe.id,
        profile: { stationType, outputItem: outputItem.trim(), outputQuantity: Number(quantity), durationSeconds: Number(seconds) } })
      setMessage(result.ok ? 'Production settings saved.' : result.error || 'Could not save production settings')
    } catch { setMessage('The server did not respond. Reload settings to check whether the save completed.') }
    finally { onBusy(false) }
  }
  async function preview(checkStock = false) {
    if (busy || state !== 'ready' || !Number.isInteger(Number(batches)) || Number(batches) < 1 || Number(batches) > 100) return
    onBusy(true); setPlan(null); setStock(undefined); setMessage('')
    try {
      const result = await request(checkStock ? 'checkProductionStock' : 'previewProduction', { businessId, recipeId: recipe.id, batches: Number(batches) })
      if (result.ok && result.productionPlan) { setPlan(result.productionPlan); setStock(result.stockReport) }
      else setMessage(result.error === 'inventory_unavailable' ? 'Stock checking is unavailable. Configure and start the inventory adapter first.' : result.error || 'Could not preview production')
    } catch { setMessage('Could not preview production') }
    finally { onBusy(false) }
  }
  async function remove() {
    if (busy || !window.confirm(`Remove production settings for ${recipe.name}?`)) return
    onBusy(true); setPlan(null); setStock(undefined); setMessage('')
    try {
      const result = await request('deleteProductionProfile', { businessId, recipeId: recipe.id })
      if (result.ok) { setStationType(''); setOutputItem(''); setQuantity('1'); setSeconds('30'); setMessage('Production settings removed.') }
      else setMessage(result.error || 'Could not remove production settings')
    } catch { setMessage('The server did not respond. Reload settings to verify removal.') }
    finally { onBusy(false) }
  }
  return <section className="my-5 rounded-lg border border-solid border-border p-4" aria-label={`Production settings for ${recipe.name}`}>
    <h3>Production: {recipe.name}</h3>
    <p>Configure one preparation stage. Cooking requires a verified inventory adapter and an enabled kitchen module.</p>
    {state === 'loading' && <p role="status">Loading production settings…</p>}
    {state === 'ready' && <form onSubmit={event => void save(event)}>
      <label>Required equipment<select required disabled={busy} value={stationType} onChange={event => setStationType(event.target.value)}><option value="">Select equipment</option>{types.map(type => <option key={type} value={type}>{type}</option>)}</select></label>
      <label>Output item<input required disabled={busy} minLength={2} maxLength={64} pattern="[A-Za-z0-9_-]+" value={outputItem} onChange={event => setOutputItem(event.target.value)} /></label>
      <label>Output quantity<input required disabled={busy} type="number" min="1" max="100" step="1" value={quantity} onChange={event => setQuantity(event.target.value)} /></label>
      <label>Preparation time in seconds<input required disabled={busy} type="number" min="1" max="3600" step="1" value={seconds} onChange={event => setSeconds(event.target.value)} /></label>
      <button type="submit" disabled={busy || !types.includes(stationType)}>Save production settings</button>
    </form>}
    {state === 'ready' && <section className="mt-5" aria-label="Batch preview">
      <h4>Preview saved recipe</h4><p>This uses saved settings. Save any changes first. No stock is reserved or consumed.</p>
      <label>Batches<input type="number" min="1" max="100" step="1" disabled={busy} value={batches} onChange={event => { setBatches(event.target.value); setPlan(null); setStock(undefined) }} /></label>
      <button type="button" disabled={busy || !Number.isInteger(Number(batches)) || Number(batches) < 1 || Number(batches) > 100} onClick={() => void preview()}>Preview requirements</button>
      <button type="button" disabled={busy || !Number.isInteger(Number(batches)) || Number(batches) < 1 || Number(batches) > 100} onClick={() => void preview(true)}>Check ingredient stock</button>
      {stock && <div aria-live="polite"><p>{stock.available ? "All ingredients are available." : "Ingredients are missing."} This snapshot does not reserve stock or authorize cooking.</p><table className="mt-3 w-full text-left"><thead><tr><th>Ingredient</th><th>Required</th><th>Available</th><th>Missing</th></tr></thead><tbody>{stock.ingredients.map(entry => <tr key={entry.item}><td>{entry.item}</td><td>{entry.required}</td><td>{entry.available}</td><td>{entry.missing}</td></tr>)}</tbody></table></div>}
      {plan && <div aria-live="polite"><p>{plan.batches} batches · {plan.outputQuantity} × {plan.outputItem} · {plan.durationSeconds} seconds in sequence · {plan.stationType}</p>
        <table className="mt-3 w-full text-left"><thead><tr><th>Ingredient</th><th>Required quantity</th></tr></thead><tbody>{plan.ingredients.map(entry => <tr key={entry.item}><td>{entry.item}</td><td>{entry.quantity}</td></tr>)}</tbody></table>
      </div>}
    </section>}
    <div className="mt-3 flex flex-wrap gap-2">{state === 'ready' && <button type="button" disabled={busy} onClick={() => void remove()}>Remove production settings</button>}<button type="button" disabled={busy || state === 'loading'} onClick={() => setReload(value => value + 1)}>Reload settings</button><button type="button" disabled={busy} onClick={onClose}>Close settings</button></div>
    <p role="status" aria-live="polite">{message}</p>
  </section>
}
