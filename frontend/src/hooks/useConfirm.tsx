import { useState, useCallback } from 'react'
import ConfirmDialog from '../components/ConfirmDialog'

interface ConfirmOptions {
  title: string
  message?: string
  confirmLabel?: string
  danger?: boolean
}

type Resolver = (ok: boolean) => void

/**
 * Drop-in replacement for `window.confirm()` with a styled modal.
 *
 * Usage:
 *   const { confirm, dialog } = useConfirm()
 *   const ok = await confirm({ title: 'Delete?', danger: true })
 *   if (!ok) return
 *   // ...do the thing
 *
 *   // and in the JSX:
 *   return <>{...}{dialog}</>
 */
export function useConfirm() {
  const [state, setState] = useState<{ options: ConfirmOptions; resolve: Resolver } | null>(null)

  const confirm = useCallback((options: ConfirmOptions): Promise<boolean> => {
    return new Promise(resolve => setState({ options, resolve }))
  }, [])

  const handleClose = useCallback((ok: boolean) => {
    setState(current => {
      current?.resolve(ok)
      return null
    })
  }, [])

  const dialog = state ? (
    <ConfirmDialog
      title={state.options.title}
      message={state.options.message}
      confirmLabel={state.options.confirmLabel ?? 'Confirm'}
      danger={state.options.danger ?? false}
      onCancel={() => handleClose(false)}
      onConfirm={() => handleClose(true)}
    />
  ) : null

  return { confirm, dialog }
}
