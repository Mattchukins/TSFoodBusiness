import { useEffect, useState } from 'react'
export type DutyBusiness = { id: string; name: string; role: string; on_duty: number | string; duty_revision: number | string }
export type DutyResponse = { ok: boolean; error?: string; staffBusinesses?: DutyBusiness[] }
export function MyDuty({ request, busy, onBusy }: { request: (action: string, payload: Record<string, unknown>) => Promise<DutyResponse>; busy: boolean; onBusy: (value: boolean) => void }) {
  const [businesses, setBusinesses] = useState<DutyBusiness[]>([])
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading')
  const [reload, setReload] = useState(0)
  const [message, setMessage] = useState('')
  useEffect(() => {
    let active = true
    setState('loading'); setMessage('')
    void request('listMyStaffBusinesses', {}).then(result => {
      if (!active) return
      if (!result.ok) throw new Error(result.error || 'Could not load duty status')
      setBusinesses(result.staffBusinesses || []); setState('ready')
    }).catch(error => { if (active) { setState('error'); setMessage(error instanceof Error ? error.message : 'Could not load duty status') } })
    return () => { active = false }
  }, [request, reload])
  async function change(business: DutyBusiness) {
    if (busy || state !== 'ready') return
    onBusy(true)
    try {
      const result = await request('setMyStaffDuty', { businessId: business.id, revision: Number(business.duty_revision), onDuty: Number(business.on_duty) !== 1 })
      if (!result.ok) { setState('error'); setMessage(result.error === 'staff_conflict' ? 'Duty status changed. Reload before trying again.' : result.error || 'Could not change duty status'); return }
      setReload(value => value + 1)
    } catch { setState('error'); setMessage('The server did not respond. Reload to verify your saved duty status.') }
    finally { onBusy(false) }
  }
  return <section aria-label="My duty status"><p>Start or end your shift at a business where this character is on the staff roster. Disconnecting does not end a shift automatically.</p>
    {state === 'loading' && <p role="status">Loading duty status…</p>}
    {state === 'ready' && (businesses.length ? <ul className="p-0">{businesses.map(business => <li key={business.id} className="my-3 list-none rounded-lg border border-solid border-border p-3"><p><strong>{business.name}</strong> · {business.role} · {Number(business.on_duty) === 1 ? 'On duty' : 'Off duty'}</p><button type="button" disabled={busy} onClick={() => void change(business)}>{Number(business.on_duty) === 1 ? 'End shift' : 'Start shift'} at {business.name}</button></li>)}</ul> : <p>This character has no staff assignments.</p>)}
    <button type="button" disabled={busy || state === 'loading'} onClick={() => setReload(value => value + 1)}>Reload my duty status</button><p role="status" aria-live="polite">{message}</p>
  </section>
}
