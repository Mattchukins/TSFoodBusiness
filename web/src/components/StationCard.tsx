export type Station = {
  id: string; name: string; type: string
  x: number | string; y: number | string; z: number | string
  heading: number | string; routing_bucket: number | string
}

function coordinate(value: number | string) {
  if (value === '' || value == null) return 'Unavailable'
  const number = Number(value)
  return Number.isFinite(number) ? number.toFixed(2) : 'Unavailable'
}

export function StationCard({ station, disabled, onEdit, onMove, onRemove }: {
  station: Station; disabled: boolean
  onEdit: () => void; onMove: () => void; onRemove: () => void
}) {
  return <li className="mb-3 rounded-lg border border-solid border-border p-3 list-none">
    <strong>{station.name}</strong><span className="ml-2 text-muted">{station.type}</span>
    <details className="my-3">
      <summary className="cursor-pointer">Saved position</summary>
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
        <dt>X</dt><dd className="m-0">{coordinate(station.x)}</dd>
        <dt>Y</dt><dd className="m-0">{coordinate(station.y)}</dd>
        <dt>Z</dt><dd className="m-0">{coordinate(station.z)}</dd>
        <dt>Direction</dt><dd className="m-0">{coordinate(station.heading)}°</dd>
        <dt>Routing bucket</dt><dd className="m-0">{station.routing_bucket ?? 'Unavailable'}</dd>
      </dl>
    </details>
    <div className="flex flex-wrap gap-2">
      <button type="button" disabled={disabled} onClick={onEdit} aria-label={`Edit ${station.name}`}>Edit</button>
      <button type="button" disabled={disabled} onClick={onMove} aria-label={`Move ${station.name} here`}>Move here</button>
      <button type="button" disabled={disabled} onClick={onRemove} aria-label={`Remove ${station.name}`}>Remove</button>
    </div>
  </li>
}
