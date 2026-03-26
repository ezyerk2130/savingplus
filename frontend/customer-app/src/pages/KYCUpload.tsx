import { useEffect, useState, useRef } from 'react'
import { Upload, CheckCircle, XCircle, Clock } from 'lucide-react'
import toast from 'react-hot-toast'
import { kycApi } from '../api/services'
import { showError, showLoadError } from '../utils/error'
import type { KYCStatus } from '../types'

const documentTypes = [
  { value: 'national_id', label: 'National ID (NIDA)' },
  { value: 'passport', label: 'Passport' },
  { value: 'driving_license', label: 'Driving License' },
  { value: 'voter_id', label: 'Voter ID' },
  { value: 'selfie', label: 'Selfie Photo' },
  { value: 'proof_of_address', label: 'Proof of Address' },
]

export default function KYCUpload() {
  const [kycStatus, setKycStatus] = useState<KYCStatus | null>(null)
  const [uploading, setUploading] = useState(false)
  const [selectedType, setSelectedType] = useState('national_id')
  const fileRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    kycApi.getStatus().then((res) => setKycStatus(res.data)).catch((err: unknown) => showLoadError(err, 'KYC status'))
  }, [])

  const handleUpload = async () => {
    const file = fileRef.current?.files?.[0]
    if (!file) {
      toast.error('Please select a file')
      return
    }
    if (file.size > 10 * 1024 * 1024) {
      toast.error('File size must be under 10MB')
      return
    }

    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('document_type', selectedType)
      await kycApi.upload(formData)
      toast.success('Document uploaded successfully!')
      // Refresh status
      const res = await kycApi.getStatus()
      setKycStatus(res.data)
      if (fileRef.current) fileRef.current.value = ''
    } catch (err: unknown) {
      showError(err, 'Upload failed')
    } finally {
      setUploading(false)
    }
  }

  const statusIcon = (status: string) => {
    switch (status) {
      case 'approved': return <CheckCircle className="w-5 h-5 text-green-500" />
      case 'rejected': return <XCircle className="w-5 h-5 text-red-500" />
      default: return <Clock className="w-5 h-5 text-amber-500" />
    }
  }

  const tierLabels = ['Unverified', 'Basic', 'Enhanced', 'Premium']

  return (
    <div className="max-w-lg mx-auto space-y-6">
      <h1 className="text-2xl font-bold">KYC Verification</h1>

      {/* Status card */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <div>
            <p className="text-sm text-gray-500">KYC Status</p>
            <p className={`font-semibold capitalize ${
              kycStatus?.kyc_status === 'approved' ? 'text-green-600' :
              kycStatus?.kyc_status === 'rejected' ? 'text-red-600' : 'text-amber-600'
            }`}>
              {kycStatus?.kyc_status || 'Loading...'}
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-500">KYC Tier</p>
            <p className="font-semibold">
              Tier {kycStatus?.kyc_tier ?? 0} - {tierLabels[kycStatus?.kyc_tier ?? 0]}
            </p>
          </div>
        </div>

        {/* Tier info */}
        <div className="bg-gray-50 rounded-lg p-3 text-xs text-gray-600">
          <p><strong>Tier 0:</strong> Deposit up to TZS 50,000/day (no withdrawals)</p>
          <p><strong>Tier 1:</strong> TZS 500,000/day deposit, TZS 200,000/day withdrawal</p>
          <p><strong>Tier 2:</strong> TZS 5,000,000/day deposit, TZS 2,000,000/day withdrawal</p>
          <p><strong>Tier 3:</strong> Premium limits for verified businesses</p>
        </div>
      </div>

      {/* Upload form */}
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">Upload Document</h2>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Document Type</label>
            <select value={selectedType} onChange={(e) => setSelectedType(e.target.value)} className="input-field">
              {documentTypes.map((dt) => (
                <option key={dt.value} value={dt.value}>{dt.label}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">File</label>
            <input
              ref={fileRef}
              type="file"
              accept="image/*,.pdf"
              className="input-field file:mr-3 file:py-1 file:px-3 file:rounded file:border-0 file:text-sm file:font-medium file:bg-primary-50 file:text-primary-700"
            />
            <p className="text-xs text-gray-500 mt-1">Max 10MB. Supported: JPG, PNG, PDF</p>
          </div>

          <button onClick={handleUpload} disabled={uploading} className="btn-primary w-full flex items-center justify-center gap-2">
            <Upload className="w-4 h-4" />
            {uploading ? 'Uploading...' : 'Upload Document'}
          </button>
        </div>
      </div>

      {/* Uploaded documents */}
      {kycStatus?.documents && kycStatus.documents.length > 0 && (
        <div className="card">
          <h2 className="text-lg font-semibold mb-4">Uploaded Documents</h2>
          <div className="space-y-3">
            {kycStatus.documents.map((doc) => (
              <div key={doc.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  {statusIcon(doc.status)}
                  <div>
                    <p className="text-sm font-medium capitalize">{doc.document_type.replace('_', ' ')}</p>
                    <p className="text-xs text-gray-500">{new Date(doc.created_at).toLocaleDateString()}</p>
                  </div>
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  doc.status === 'approved' ? 'bg-green-100 text-green-700' :
                  doc.status === 'rejected' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'
                }`}>
                  {doc.status}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
