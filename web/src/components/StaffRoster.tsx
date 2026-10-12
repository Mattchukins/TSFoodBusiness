import { useEffect, useRef, useState } from 'react'
export type StaffMember = { id: string; display_name: string; role: string; revision: number; on_duty: number | string; duty_revision: number | string }
export type StaffRole = { id: string; label: string; permissions: string[] }
type Shift = { id: string; staff_label: string; role: string; started_at: number | string; ended_at: number | string; end_reason: string; duration_seconds: number | string }
export type StaffResponse = { ok: boolean; error?: string; staff?: StaffMember[]; staffRoles?: StaffRole[]; shifts?: Shift[] }
const errors: Record<string, string> = {
  target_unavailable: 'That server ID has no available character. Ask the player to connect first.',
  target_changed: 'That server ID changed character or disconnected. Verify the player and try again.',
  already_staff: 'That character is already on this roster. Edit their existing entry.',
  owner_is_not_staff: 'The business owner already has owner access and cannot be added as staff.',
  staff_conflict: 'This roster entry changed. Reload the roster before trying again.',
  transaction_failed: 'The roster change failed. Reload to verify the saved roster.',
  staff_disabled: 'Staff management is disabled on this server.',
}
export function StaffRoster({ businessId, request, busy, onBusy }: {
  businessId: string; request: (action: string, payload: Record<string, unknown>) => Promise<StaffResponse>
  busy: boolean; onBusy: (value: boolean) => void
}) {
  const [members, setMembers] = useState<StaffMember[]>([])
  const [shifts, setShifts] = useState<Shift[]>([])
  const [roles, setRoles] = useState<StaffRole[]>([])
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading')
  const [reload, setReload] = useState(0)
  const [editing, setEditing] = useState<StaffMember | null>(null)
  const [source, setSource] = useState('')
  const [name, setName] = useState('')
  const [role, setRole] = useState('')
  const [search, setSearch] = useState('')
  const [message, setMessage] = useState('')
  const mounted = useRef(true)
  useEffect(() => { mounted.current = true; return () => { mounted.current = false } }, [])
  useEffect(() => {
    let active = true
    setState('loading'); setMembers([]); setRoles([]); setEditing(null); setName(''); setSource(''); setRole(''); setMessage('')
    void Promise.all([request('listStaff', { businessId }), request('listStaffRoles', {}), request('listStaffShifts', { businessId })]).then(([saved, supported, history]) => {
      if (!active) return
      if (!saved.ok || !supported.ok || !history.ok) throw new Error(errors[saved.error || supported.error || ''] || saved.error || supported.error || history.error || 'Could not load staff')
      setMembers(saved.staff || []); setShifts(history.shifts || []); setRoles(supported.staffRoles || []); setState('ready')
    }).catch(error => { if (active) { setState('error'); setMessage(error instanceof Error ? error.message : 'Could not load staff') } })
    return () => { active = false }
  }, [businessId, reload, request])
  function reset() { setEditing(null); setSource(''); setName(''); setRole('') }
  async function mutate(action: string, payload: Record<string, unknown>) {
    if (busy || state !== 'ready') return
    onBusy(true); setMessage('')
    try {
      const result = await request(action, { businessId, ...payload })
      if (!mounted.current) return
      if (!result.ok) {
        setMessage(errors[result.error || ''] || result.error || 'Could not change staff')
        if (['staff_conflict', 'transaction_failed', 'not_found'].includes(result.error || '')) setState('error')
        return
      }
      reset(); setMessage('Staff roster updated.'); setState('loading')
      const saved = await request('listStaff', { businessId })
      if (!mounted.current) return
      if (!saved.ok) { setMembers([]); setState('error'); setMessage('Staff roster updated, but refresh failed. Reload it before making another change.'); return }
      const history = await request('listStaffShifts', { businessId })
      if (!mounted.current) return
      if (!history.ok) throw new Error('Shift refresh failed')
      setShifts(history.shifts || []); setMembers(saved.staff || []); setState('ready')
    } catch { if (mounted.current) { setState('error'); setMessage('The server did not respond. Reload the roster to verify whether the change completed.') } }
    finally { onBusy(false) }
  }
  function save(event: React.FormEvent) {
    event.preventDefault()
    if (!roles.some(entry => entry.id === role)) return
    void mutate(editing ? 'updateStaffMember' : 'assignStaffMember', editing
      ? { staffId: editing.id, revision: Number(editing.revision), displayName: name.trim(), role }
      : { targetSource: Number(source), displayName: name.trim(), role })
  }
  const filtered = members.filter(member => member.display_name.toLowerCase().includes(search.trim().toLowerCase()))
  return <section aria-label="Business staff roster">
    <p>Assign an online character using their current server ID. The roster keeps their character assignment after disconnects. Labels can be edited while staff are offline.</p>
    <p>Staff can change their own status in My duty; owners can also change it here. Status persists until changed. Shift start/end times are recorded. Disconnects do not clock staff out automatically.</p>
    <p>Roles are saved for permission integrations. Staff access to this management interface and cooking is still being developed.</p>
    {state === 'loading' && <p role="status">Loading staff roster…</p>}
    {state === 'ready' && <>
      <label>Search roster labels<input type="search" maxLength={80} value={search} onChange={event => setSearch(event.target.value)} /></label>
      <p>Showing {filtered.length} of {members.length} loaded staff.</p>
      {members.length === 200 && <p>The first 200 roster entries are loaded.</p>}
      {members.length === 0 && <p>No staff assigned to this business.</p>}
      {members.length > 0 && filtered.length === 0 && <p>No roster labels match this search.</p>}
      <ul className="p-0">{filtered.map(member => <li key={member.id} className="my-3 list-none rounded-lg border border-solid border-border p-3">
        <p><strong>{member.display_name}</strong> · {roles.find(entry => entry.id === member.role)?.label || member.role} · {Number(member.on_duty) === 1 ? 'On duty' : 'Off duty'}</p>
        <div className="flex flex-wrap gap-2"><button type="button" disabled={busy} onClick={() => void mutate('setStaffDuty', { staffId: member.id, revision: Number(member.duty_revision), onDuty: Number(member.on_duty) !== 1 })}>{Number(member.on_duty) === 1 ? 'Mark off duty' : 'Mark on duty'}</button><button type="button" disabled={busy} aria-label={`Edit ${member.display_name}`} onClick={() => { setEditing(member); setName(member.display_name); setRole(member.role); setSource('') }}>Edit</button>
          <button type="button" disabled={busy} aria-label={`Remove ${member.display_name}`} onClick={() => { if (window.confirm(`Remove ${member.display_name} from this business?`)) void mutate('removeStaffMember', { staffId: member.id, revision: Number(member.revision) }) }}>Remove</button></div>
      </li>)}</ul>
      <details className="my-4"><summary>Recent shifts ({shifts.length})</summary><p>Latest 100 shifts. Open shift durations are snapshots from the last reload.</p><ul>{shifts.map(shift => <li key={shift.id}><strong>{shift.staff_label}</strong> · {shift.role} · {Math.floor(Number(shift.duration_seconds) / 60)} minutes · {Number(shift.ended_at) === 0 ? 'Open' : shift.end_reason}<p>Started {new Date(Number(shift.started_at) * 1000).toLocaleString()}{Number(shift.ended_at) > 0 && ` · Ended ${new Date(Number(shift.ended_at) * 1000).toLocaleString()}`}</p></li>)}</ul></details>
      <h3>{editing ? 'Edit staff member' : 'Assign staff member'}</h3>
      <form onSubmit={save}>
        {!editing && <label>Online player server ID<input required disabled={busy} type="number" min="1" max="2147483647" step="1" value={source} onChange={event => setSource(event.target.value)} /></label>}
        <label>Roster label<input required disabled={busy} minLength={2} maxLength={80} value={name} onChange={event => setName(event.target.value)} /></label>
        <label>Role<select required disabled={busy} value={role} onChange={event => setRole(event.target.value)}><option value="">Select role</option>{roles.map(entry => <option key={entry.id} value={entry.id}>{entry.label}</option>)}</select></label>
        <button type="submit" disabled={busy || !roles.some(entry => entry.id === role)}>{editing ? 'Save staff details' : 'Assign staff'}</button>
        {editing && <button type="button" disabled={busy} onClick={reset}>Cancel edit</button>}
      </form>
    </>}
    <button className="mt-4" type="button" disabled={busy || state === 'loading'} onClick={() => setReload(value => value + 1)}>Reload roster</button>
    <p role="status" aria-live="polite">{message}</p>
  </section>
}
