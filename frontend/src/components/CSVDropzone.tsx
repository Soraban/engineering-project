import { useCallback } from 'react'
import { useDropzone } from 'react-dropzone'

interface Props {
  onFile: (file: File) => void
  disabled?: boolean
}

export default function CSVDropzone({ onFile, disabled }: Props) {
  const onDrop = useCallback((acceptedFiles: File[]) => {
    if (acceptedFiles.length > 0) {
      onFile(acceptedFiles[0])
    }
  }, [onFile])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: { 'text/csv': ['.csv'] },
    maxFiles: 1,
    disabled,
  })

  return (
    <div {...getRootProps()} className={`dropzone ${isDragActive ? 'active' : ''}`}>
      <input {...getInputProps()} />
      <p>{isDragActive ? 'Drop your CSV here...' : 'Drop CSV here or click to browse'}</p>
      <p style={{ fontSize: 12, marginTop: 8, color: 'var(--text3)' }}>
        Expected columns: date, description, amount, category
      </p>
    </div>
  )
}
