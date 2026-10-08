import { useEffect, useRef, useState } from 'react'

type Plan = { ingredients: { item: string; quantity: number }[]; outputItem: string; outputQuantity: number; durationSeconds: number; stationType: string; batches: number }
export type CookingJob = { id: string; recipeId: string; stationId: string; batches: number; state: string; readyAt: number; revision: number; productionPlan: Plan; canMutate: boolean; serverNow: number }
export type CookingResponse = { ok: boolean; error?: string; jobs?: CookingJob[]; job?: CookingJob; cookingEnabled?: boolean; stations?: { id: string; name: string; type: string }[] }
const terminal = (job: CookingJob) => ['completed', 'cancelled'].includes(job.state)
const labels: Record<string, string> = { reserving: 'Reserving ingredients', cooking: 'Cooking', committing: 'Waiting for output', releasing: 'Returning ingredients', completed: 'Completed', cancelled: 'Cancelled' }
const errors: Record<string, string> = {
  cooking_disabled: 'Cooking is disabled. The server needs a verified inventory adapter.',
  station_not_near: 'Stand within two metres of the selected equipment in the same instance.',
  cooking_not_ready: 'The server preparation timer has not finished yet.',
  output_full: 'Your output inventory is full. Free space, then retry finish.',
  insufficient_stock: 'There are not enough ingredients. Retry after restocking or cancel this job.',
  inventory_outcome_unknown: 'The inventory result is uncertain. Check the saved job before retrying.',
  job_outcome_unknown: 'The job result is uncertain. Reload saved jobs before starting another.',
  job_reconciliation_required: 'The saved job needs a recovery check. Reload and check its status.',
  job_conflict_or_database_error: 'Another active job may hold this player or station, or the database write failed. Reload jobs.',
  inventory_mutations_disabled: 'The inventory adapter is unavailable or mutations are disabled.',
  invalid_reservation: 'This job cannot be verified against the configured inventory adapter. Contact the server administrator.',
}
export function KitchenJobs({ businessId, recipes, request, busy, onBusy }: {
  businessId: string; recipes: { id: string; name: string }[]
  request: (action: string, payload: Record<string, unknown>) => Promise<CookingResponse>
  busy: boolean; onBusy: (value: boolean) => void
}) {
  const [jobs, setJobs] = useState<CookingJob[]>([])
  const [stations, setStations] = useState<{ id: string; name: string; type: string }[]>([])
  const [enabled, setEnabled] = useState(false)
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading')
  const [recipeId, setRecipeId] = useState('')
  const [stationId, setStationId] = useState('')
  const [batches, setBatches] = useState('1')
  const [message, setMessage] = useState('')
  const [reload, setReload] = useState(0)
  const [clock, setClock] = useState(Date.now())
  const receivedAt = useRef(Date.now())
  const token = useRef<string | null>(null)
  const mounted = useRef(true)
  useEffect(() => { mounted.current = true; return () => { mounted.current = false } }, [])
  useEffect(() => {
    const interval = window.setInterval(() => setClock(Date.now()), 1000)
    return () => window.clearInterval(interval)
  }, [])
  useEffect(() => {
    let active = true
    setState('loading'); setMessage(''); setJobs([]); setStations([]); setEnabled(false)
    void Promise.all([request('listCookingJobs', { businessId }), request('listStations', { businessId })])
      .then(([saved, equipment]) => {
        if (!active) return
        if (!saved.ok || !equipment.ok) throw new Error(saved.error || equipment.error || 'Could not load kitchen jobs')
        setJobs(saved.jobs || []); setStations(equipment.stations || []); setEnabled(saved.cookingEnabled === true)
        receivedAt.current = Date.now(); setState('ready')
      }).catch(error => { if (active) { setState('error'); setMessage(error instanceof Error ? error.message : 'Could not load kitchen jobs') } })
    return () => { active = false }
  }, [businessId, reload, request])
  async function run(action: string, payload: Record<string, unknown>) {
    if (busy || state !== 'ready') return
    onBusy(true); setMessage('')
    try {
      const result = await request(action, { businessId, ...payload })
      if (!mounted.current) return
      if (result.job) {
        const job = result.job
        setJobs(current => [job, ...current.filter(item => item.id !== job.id)])
        receivedAt.current = Date.now()
      }
      setMessage(result.ok ? 'Saved job status updated.' : errors[result.error || ''] || result.error || 'Could not update this job')
      if (action === 'startCookingJob' && result.job) token.current = null
      // A saved result still needs a refresh to verify current capacity/other jobs.
      const saved = await request('listCookingJobs', { businessId })
      if (!mounted.current) return
      if (!saved.ok) { setState('error'); setMessage('Could not verify the saved job list. Reload jobs before continuing.'); return }
      setJobs(saved.jobs || []); setEnabled(saved.cookingEnabled === true); receivedAt.current = Date.now()
    } catch { if (mounted.current) { setState('error'); setMessage('The server did not respond. Reload saved jobs before starting or retrying a job.') } }
    finally { onBusy(false) }
  }
  function start(event: React.FormEvent) {
    event.preventDefault()
    if (!enabled || !recipeId || !stationId || jobs.some(job => !terminal(job))) return
    token.current ||= window.crypto.randomUUID()
    void run('startCookingJob', { recipeId, stationId, batches: Number(batches), token: token.current })
  }
  const activeJobs = jobs.filter(job => !terminal(job))
  const recentJobs = jobs.filter(terminal)
  const elapsed = Math.max(0, Math.floor((clock - receivedAt.current) / 1000))
  return <section className="my-5 rounded-lg border border-solid border-border p-4" aria-label="Cooking jobs">
    <h3>Cooking jobs</h3>
    {state === 'loading' && <p role="status">Loading saved jobs…</p>}
    {state === 'ready' && <>
      {!enabled && <p>Cooking is disabled until the server has a verified inventory adapter. Saved jobs remain visible.</p>}
      <form onSubmit={start}>
        <label>Recipe<select required disabled={busy || !enabled} value={recipeId} onChange={event => { setRecipeId(event.target.value); token.current = null }}><option value="">Select recipe</option>{recipes.map(recipe => <option key={recipe.id} value={recipe.id}>{recipe.name}</option>)}</select></label>
        <label>Equipment<select required disabled={busy || !enabled} value={stationId} onChange={event => { setStationId(event.target.value); token.current = null }}><option value="">Select equipment</option>{stations.map(station => <option key={station.id} value={station.id}>{station.name} ({station.type})</option>)}</select></label>
        <label>Batches<input required type="number" min="1" max="100" step="1" disabled={busy || !enabled} value={batches} onChange={event => { setBatches(event.target.value); token.current = null }} /></label>
        <button type="submit" disabled={busy || !enabled || activeJobs.length > 0 || !recipeId || !stationId}>Start cooking</button>
      </form>
      <p>Stand near the selected equipment to start and finish. Each player and station can hold one active job. Timings below are estimates; the server decides when output can be collected.</p>
      <h4>Active jobs</h4>
      {activeJobs.length === 0 && <p>No active jobs in the loaded list.</p>}
      {activeJobs.map(job => <article key={job.id} className="my-3 rounded-lg border border-solid border-border p-3" aria-label={`Cooking job ${job.id}`}>
        <p>{job.productionPlan.outputQuantity} × {job.productionPlan.outputItem} · {labels[job.state] || job.state}</p>
        {['cooking', 'committing'].includes(job.state) && <p>Approximately {Math.max(0, job.readyAt - job.serverNow - elapsed)} seconds remaining.</p>}
        <p className="break-all text-sm">Job {job.id}</p>
        <div className="flex flex-wrap gap-2">
          <button type="button" disabled={busy || !enabled} onClick={() => void run('inspectCookingJob', { jobId: job.id })}>Check recovery status</button>
          {job.state === 'reserving' && <button type="button" disabled={busy || !enabled} onClick={() => void run('resumeCookingJob', { jobId: job.id })}>Retry reservation</button>}
          {['cooking', 'committing'].includes(job.state) && <button type="button" disabled={busy || !enabled} onClick={() => void run('finishCookingJob', { jobId: job.id })}>Finish / retry output</button>}
          <button type="button" disabled={busy || !enabled} onClick={() => { if (window.confirm('Cancel this job and release reserved ingredients?')) void run('cancelCookingJob', { jobId: job.id }) }}>Cancel / retry return</button>
        </div>
      </article>)}
      <details className="mt-4"><summary>Recent completed and cancelled jobs ({recentJobs.length})</summary><ul>{recentJobs.map(job => <li key={job.id}>{job.productionPlan.outputQuantity} × {job.productionPlan.outputItem} · {labels[job.state]} <span className="break-all text-sm">{job.id}</span></li>)}</ul></details>
      <p className="text-sm">Latest 100 saved jobs. Recipes and production settings can change; saved jobs keep their original plan.</p>
    </>}
    <button className="mt-3" type="button" disabled={busy || state === 'loading'} onClick={() => setReload(value => value + 1)}>Reload jobs</button>
    <p role="status" aria-live="polite">{message}</p>
  </section>
}
