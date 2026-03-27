import { useEffect, useState } from 'react'
import api from '../api/client'
import { showLoadError, showError } from '../utils/error'
import toast from 'react-hot-toast'

interface ArticleRow {
  id: string
  title: string
  title_sw: string
  category: string
  published: boolean
  read_time_min: number
  created_at: string
}

interface ArticleForm {
  title: string
  title_sw: string
  body: string
  body_sw: string
  category: string
  read_time_min: number
}

const emptyForm: ArticleForm = {
  title: '',
  title_sw: '',
  body: '',
  body_sw: '',
  category: 'saving',
  read_time_min: 3,
}

export default function ContentAdmin() {
  const [articles, setArticles] = useState<ArticleRow[]>([])
  const [page, setPage] = useState(1)
  const [totalPages, setTotalPages] = useState(1)
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState<ArticleForm>(emptyForm)
  const [submitting, setSubmitting] = useState(false)
  const [toggling, setToggling] = useState<string | null>(null)

  const fetchArticles = () => {
    setLoading(true)
    api.get('/content/articles', { params: { page } })
      .then((res) => {
        setArticles(res.data.articles || [])
        setTotalPages(res.data.total_pages || 1)
      })
      .catch((err: unknown) => showLoadError(err, 'articles'))
      .finally(() => setLoading(false))
  }

  useEffect(() => { fetchArticles() }, [page])

  const handleTogglePublished = (articleId: string, currentPublished: boolean) => {
    setToggling(articleId)
    api.put(`/content/articles/${articleId}/publish`, { published: !currentPublished })
      .then(() => {
        toast.success(currentPublished ? 'Article unpublished' : 'Article published')
        fetchArticles()
      })
      .catch((err: unknown) => showError(err, 'Failed to update article'))
      .finally(() => setToggling(null))
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.title.trim() || !form.body.trim()) {
      toast.error('Title and body are required')
      return
    }
    setSubmitting(true)
    api.post('/content/articles', { ...form, published: false })
      .then(() => {
        toast.success('Article created')
        setForm(emptyForm)
        setShowForm(false)
        fetchArticles()
      })
      .catch((err: unknown) => showError(err, 'Failed to create article'))
      .finally(() => setSubmitting(false))
  }

  const categoryColor = (c: string) => {
    switch (c) {
      case 'savings_tips': return 'bg-emerald-100 text-emerald-700'
      case 'investment': return 'bg-blue-100 text-blue-700'
      case 'security': return 'bg-red-100 text-red-700'
      case 'announcements': return 'bg-purple-100 text-purple-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Content Management</h1>
        <button onClick={() => setShowForm(!showForm)} className="btn-primary">
          {showForm ? 'Cancel' : 'New Article'}
        </button>
      </div>

      {showForm && (
        <div className="card mb-6">
          <h2 className="text-lg font-semibold mb-4">Create Article</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Title (English)</label>
                <input
                  type="text"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="input-field"
                  placeholder="Article title"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Title (Swahili)</label>
                <input
                  type="text"
                  value={form.title_sw}
                  onChange={(e) => setForm({ ...form, title_sw: e.target.value })}
                  className="input-field"
                  placeholder="Kichwa cha makala"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Body (English)</label>
                <textarea
                  value={form.body}
                  onChange={(e) => setForm({ ...form, body: e.target.value })}
                  className="input-field min-h-[120px]"
                  placeholder="Article body content..."
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Body (Swahili)</label>
                <textarea
                  value={form.body_sw}
                  onChange={(e) => setForm({ ...form, body_sw: e.target.value })}
                  className="input-field min-h-[120px]"
                  placeholder="Maudhui ya makala..."
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                <select
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                  className="input-field"
                >
                  <option value="saving">Saving</option>
                  <option value="investing">Investing</option>
                  <option value="budgeting">Budgeting</option>
                  <option value="insurance">Insurance</option>
                  <option value="credit">Credit</option>
                  <option value="general">General</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Read Time (minutes)</label>
                <input
                  type="number"
                  min={1}
                  max={60}
                  value={form.read_time_min}
                  onChange={(e) => setForm({ ...form, read_time_min: parseInt(e.target.value) || 1 })}
                  className="input-field"
                />
              </div>
            </div>

            <div className="flex justify-end">
              <button type="submit" disabled={submitting} className="btn-primary disabled:opacity-50">
                {submitting ? 'Creating...' : 'Create Article'}
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="card p-0 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-32"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-emerald-600" /></div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Title</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Category</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Published</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Read Time</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Created</th>
                <th className="text-left px-4 py-3 font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {articles.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">No articles found</td></tr>
              ) : articles.map((a) => (
                <tr key={a.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{a.title}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${categoryColor(a.category)}`}>
                      {a.category.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${a.published ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'}`}>
                      {a.published ? 'Published' : 'Draft'}
                    </span>
                  </td>
                  <td className="px-4 py-3">{a.read_time_min} min</td>
                  <td className="px-4 py-3">{new Date(a.created_at).toLocaleString()}</td>
                  <td className="px-4 py-3">
                    <button
                      onClick={() => handleTogglePublished(a.id, a.published)}
                      disabled={toggling === a.id}
                      className={`text-xs px-2 py-1 rounded font-medium disabled:opacity-50 ${
                        a.published
                          ? 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                          : 'bg-emerald-600 text-white hover:bg-emerald-700'
                      }`}
                    >
                      {a.published ? 'Unpublish' : 'Publish'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex justify-center gap-4 mt-4">
          <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1} className="btn-secondary">Prev</button>
          <span className="self-center text-sm text-gray-600">Page {page} / {totalPages}</span>
          <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages} className="btn-secondary">Next</button>
        </div>
      )}
    </div>
  )
}
