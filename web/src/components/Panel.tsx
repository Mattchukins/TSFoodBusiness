import type { ReactNode } from 'react'

/** Shared surface and form styling for the management screens. */
export function Panel({ children }: { children: ReactNode }) {
  return <div className="max-w-[680px] p-6 border border-solid border-border rounded-[18px] bg-raised [&_h2]:mt-0 [&_p]:leading-[1.55] [&_p]:text-muted [&_form]:grid [&_form]:gap-3 [&_form]:mt-6 [&_label]:grid [&_label]:gap-1.5 [&_input]:p-2.5 [&_select]:p-2.5 [&_button]:p-2.5 [&_input]:border [&_select]:border [&_button]:border [&_input]:border-solid [&_select]:border-solid [&_button]:border-solid [&_input]:border-border [&_select]:border-border [&_button]:border-border [&_input]:rounded-lg [&_select]:rounded-lg [&_button]:rounded-lg [&_input]:bg-control [&_select]:bg-control [&_button]:bg-accent [&_input]:text-[#f8f7ff] [&_select]:text-[#f8f7ff]">{children}</div>
}
