interface Props {
  title: string
  message?: string
  confirmLabel: string
  danger: boolean
  onCancel: () => void
  onConfirm: () => void
}

export default function ConfirmDialog({ title, message, confirmLabel, danger, onCancel, onConfirm }: Props) {
  return (
    <>
      <div className="modal-backdrop" onClick={onCancel} />
      <div className="modal" role="dialog" aria-modal="true" aria-labelledby="confirm-title">
        <h3 id="confirm-title" className="modal-title">{title}</h3>
        {message && <p className="modal-message">{message}</p>}
        <div className="modal-actions">
          <button className="btn" onClick={onCancel}>Cancel</button>
          <button
            className={`btn ${danger ? 'btn-danger-solid' : 'btn-primary'}`}
            onClick={onConfirm}
            autoFocus
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </>
  )
}
