import { useEffect, useState } from 'react'
import { BookOpen, Clock, ChevronLeft } from 'lucide-react'
import { contentApi } from '../api/services'
import { showLoadError } from '../utils/error'
import type { ContentArticle } from '../types'

const categories = ['All', 'Saving', 'Investing', 'Budgeting', 'Insurance', 'Credit']

const categoryBadge = (category: string) => {
  switch (category.toLowerCase()) {
    case 'saving': return 'bg-green-100 text-green-700'
    case 'investing': return 'bg-blue-100 text-blue-700'
    case 'budgeting': return 'bg-purple-100 text-purple-700'
    case 'insurance': return 'bg-amber-100 text-amber-700'
    case 'credit': return 'bg-red-100 text-red-700'
    default: return 'bg-gray-100 text-gray-600'
  }
}

export default function Learn() {
  const [articles, setArticles] = useState<ContentArticle[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [activeCategory, setActiveCategory] = useState('All')
  const [selectedArticle, setSelectedArticle] = useState<ContentArticle | null>(null)

  const loadArticles = (category?: string) => {
    setLoading(true)
    setError(false)
    const params = category && category !== 'All' ? { category: category.toLowerCase() } : {}
    contentApi.listArticles(params).then((res) => {
      setArticles(res.data.articles || [])
    }).catch((err: unknown) => {
      showLoadError(err, 'articles')
      setError(true)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { loadArticles(activeCategory) }, [activeCategory])

  if (selectedArticle) {
    return (
      <div className="space-y-6">
        <button
          onClick={() => setSelectedArticle(null)}
          className="flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-900 transition-colors"
        >
          <ChevronLeft className="w-4 h-4" /> Back to articles
        </button>

        <article className="card">
          <div className="flex items-center gap-2 mb-3">
            <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${categoryBadge(selectedArticle.category)}`}>
              {selectedArticle.category}
            </span>
            <span className="flex items-center gap-1 text-xs text-gray-500">
              <Clock className="w-3 h-3" /> {selectedArticle.read_time_min} min read
            </span>
          </div>

          {selectedArticle.image_url && (
            <img
              src={selectedArticle.image_url}
              alt={selectedArticle.title}
              className="w-full h-48 object-cover rounded-lg mb-4"
            />
          )}

          <h1 className="text-2xl font-bold text-gray-900 mb-4">{selectedArticle.title}</h1>
          <p className="text-xs text-gray-400 mb-6">
            {new Date(selectedArticle.created_at).toLocaleDateString('en-TZ', { year: 'numeric', month: 'long', day: 'numeric' })}
          </p>

          <div className="prose prose-sm max-w-none text-gray-700 leading-relaxed whitespace-pre-wrap">
            {selectedArticle.body}
          </div>
        </article>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Learn</h1>

      {/* Category filter tabs */}
      <div className="flex gap-2 overflow-x-auto pb-1">
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
              activeCategory === cat
                ? 'bg-primary-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
        </div>
      ) : error ? (
        <div className="card text-center py-12">
          <p className="text-gray-600 mb-4">Failed to load articles</p>
          <button onClick={() => loadArticles(activeCategory)} className="btn-primary">Retry</button>
        </div>
      ) : articles.length === 0 ? (
        <div className="card text-center py-12">
          <BookOpen className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">No articles available{activeCategory !== 'All' ? ` in ${activeCategory}` : ''}</p>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {articles.map((article) => (
            <button
              key={article.id}
              onClick={() => setSelectedArticle(article)}
              className="card border border-gray-200 text-left hover:border-primary-300 hover:shadow-md transition-all"
            >
              {article.image_url && (
                <img
                  src={article.image_url}
                  alt={article.title}
                  className="w-full h-32 object-cover rounded-lg mb-3"
                />
              )}

              <div className="flex items-center gap-2 mb-2">
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${categoryBadge(article.category)}`}>
                  {article.category}
                </span>
                <span className="flex items-center gap-1 text-xs text-gray-500">
                  <Clock className="w-3 h-3" /> {article.read_time_min} min
                </span>
              </div>

              <h3 className="font-semibold text-gray-900 mb-1">{article.title}</h3>
              <p className="text-xs text-gray-500 line-clamp-2">
                {article.body.slice(0, 120)}{article.body.length > 120 ? '...' : ''}
              </p>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
